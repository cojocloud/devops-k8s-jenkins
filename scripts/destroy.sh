#!/bin/bash
set -e

echo "========================================"
echo "🧨 Destroying entire infrastructure"
echo "========================================"

# Skip confirmation if AUTO_DESTROY is set to true
if [ "$AUTO_DESTROY" != "true" ]; then
    read -p "Are you sure? Type 'yes' to continue: " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo "❌ Cancelled."
        exit 0
    fi
fi

cd ../terraform
terraform init
terraform destroy -auto-approve

echo "🚪 Logging out from Docker Hub..."
docker logout

# Optional: remove kubeconfig context – ensure the cluster name is dynamic
CLUSTER_NAME="${TF_VAR_cluster_name:-automated-demo-cluster}"
REGION="${TF_VAR_region:-us-west-2}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
CONTEXT_NAME="arn:aws:eks:${REGION}:${ACCOUNT_ID}:cluster/${CLUSTER_NAME}"
kubectl config delete-context "$CONTEXT_NAME" 2>/dev/null || true

echo "✅ All resources destroyed."