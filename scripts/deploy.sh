#!/bin/bash
set -euo pipefail  # exit on error, undefined var, or pipe failure

# Get the directory where this script resides
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "========================================"
echo "🚀 Full Pipeline: Terraform + Docker + EKS"
echo "========================================"

# ------------------------------------------------------------
# 0. Configuration – change these to match your environment
# ------------------------------------------------------------
export TF_VAR_dockerhub_username="${DOCKER_USERNAME:-thiexco}"
export TF_VAR_region="${AWS_REGION:-us-east-1}"
export TF_VAR_cluster_name="${CLUSTER_NAME:-automated-demo-cluster}"
export TF_VAR_environment="${ENVIRONMENT:-dev}"

DOCKER_IMAGE_NAME="automated-k8s-app"
DOCKER_TAG="latest"
K8S_MANIFEST_DIR="$REPO_ROOT/k8s"
DEPLOYMENT_NAME="myapp-deployment"      # must match metadata.name in deployment.yaml
SERVICE_NAME="myapp-service"             # must match metadata.name in service.yaml

# ------------------------------------------------------------
# 1. Verify prerequisites
# ------------------------------------------------------------
command -v terraform >/dev/null 2>&1 || { echo "❌ Terraform not found"; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "❌ Docker not found"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl not found"; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "❌ AWS CLI not found"; exit 1; }

# ------------------------------------------------------------
# 2. Docker Hub login (password must be in $DOCKER_PASSWORD)
# ------------------------------------------------------------
if [ -z "${DOCKER_PASSWORD:-}" ]; then
    echo "❌ DOCKER_PASSWORD environment variable is not set."
    echo "   Run: export DOCKER_PASSWORD='your-docker-hub-password'"
    exit 1
fi
echo "🔐 Logging into Docker Hub..."
echo "$DOCKER_PASSWORD" | docker login --username "$TF_VAR_dockerhub_username" --password-stdin

# ------------------------------------------------------------
# 3. Terraform – provision EKS cluster
# ------------------------------------------------------------
echo "🏗️  Provisioning EKS cluster with Terraform..."
cd "$REPO_ROOT/terraform"
terraform init -upgrade
terraform apply -auto-approve

# ------------------------------------------------------------
# 4. Configure kubectl
# ------------------------------------------------------------
echo "☸️  Configuring kubectl..."
aws eks update-kubeconfig --region "$TF_VAR_region" --name "$TF_VAR_cluster_name"

# ------------------------------------------------------------
# 5. Build Docker image
# ------------------------------------------------------------
echo "🐳 Building Docker image..."
cd "$REPO_ROOT/app"
docker build -t "$TF_VAR_dockerhub_username/$DOCKER_IMAGE_NAME:$DOCKER_TAG" .

# Get git commit hash for additional tag (if inside a git repo)
SHORT_SHA=""
if git rev-parse --git-dir > /dev/null 2>&1; then
    SHORT_SHA=$(git rev-parse --short HEAD)
    docker tag "$TF_VAR_dockerhub_username/$DOCKER_IMAGE_NAME:$DOCKER_TAG" \
               "$TF_VAR_dockerhub_username/$DOCKER_IMAGE_NAME:$SHORT_SHA"
fi

# ------------------------------------------------------------
# 6. Push images to Docker Hub
# ------------------------------------------------------------
echo "📤 Pushing images..."
docker push "$TF_VAR_dockerhub_username/$DOCKER_IMAGE_NAME:$DOCKER_TAG"
if [ -n "$SHORT_SHA" ]; then
    docker push "$TF_VAR_dockerhub_username/$DOCKER_IMAGE_NAME:$SHORT_SHA"
fi

# ------------------------------------------------------------
# 7. Update Kubernetes deployment manifest with the image name
# ------------------------------------------------------------
DEPLOYMENT_FILE="$K8S_MANIFEST_DIR/deployment.yaml"
if [ ! -f "$DEPLOYMENT_FILE" ]; then
    echo "❌ Deployment file not found: $DEPLOYMENT_FILE"
    exit 1
fi

echo "🔄 Updating image in $DEPLOYMENT_FILE..."
sed -i.bak "s|image:.*|image: $TF_VAR_dockerhub_username/$DOCKER_IMAGE_NAME:$DOCKER_TAG|g" "$DEPLOYMENT_FILE"
rm -f "${DEPLOYMENT_FILE}.bak"

# ------------------------------------------------------------
# 8. Deploy to EKS
# ------------------------------------------------------------
echo "🚀 Deploying to Kubernetes..."
kubectl apply -f "$K8S_MANIFEST_DIR"

# ------------------------------------------------------------
# 9. Wait for rollout and show service URL
# ------------------------------------------------------------
echo "⏳ Waiting for deployment to roll out..."
kubectl rollout status "deployment/$DEPLOYMENT_NAME" --timeout=120s

echo ""
echo "✅ Deployment successful!"
echo ""
echo "📡 Getting service external IP..."
EXTERNAL_IP=""
for i in {1..30}; do
    EXTERNAL_IP=$(kubectl get svc "$SERVICE_NAME" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
    if [ -n "$EXTERNAL_IP" ]; then
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

if [ -n "$EXTERNAL_IP" ]; then
    echo "🌍 Application URL: http://$EXTERNAL_IP"
else
    echo "⚠️  LoadBalancer is still provisioning. Check manually with: kubectl get svc $SERVICE_NAME"
fi

echo ""
echo "🎯 All done! To destroy everything later, run: $SCRIPT_DIR/destroy.sh"
