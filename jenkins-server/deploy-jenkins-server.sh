#!/bin/bash
set -euo pipefail

# ------------------------------------------------------------
# Configuration – change these variables to match your environment
# ------------------------------------------------------------
AWS_REGION="us-west-2"                     # AWS region
KEY_NAME="ansible-key"                # Existing EC2 key pair name
INSTANCE_TYPE="t3.medium"                   # At least t3.medium for Jenkins + Docker
NAME_PREFIX="jenkins-server"                 # Used for resource names
AMI_OWNER="099720109477"                     # Canonical (Ubuntu)
AMI_NAME_PATTERN="ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"

# ------------------------------------------------------------
# Colors for output
# ------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------
error_exit() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 1
}

info() {
    echo -e "${GREEN}INFO: $1${NC}"
}

warn() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

# ------------------------------------------------------------
# Check prerequisites
# ------------------------------------------------------------
command -v aws >/dev/null 2>&1 || error_exit "AWS CLI not found. Please install and configure it."
command -v jq >/dev/null 2>&1 || warn "jq not found. Output may be less readable, but script will continue."

# Verify AWS credentials
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    error_exit "AWS credentials not configured or insufficient permissions."
fi

# Check if key pair exists
if ! aws ec2 describe-key-pairs --region "$AWS_REGION" --key-names "$KEY_NAME" >/dev/null 2>&1; then
    error_exit "Key pair '$KEY_NAME' does not exist in region $AWS_REGION. Please create it first."
fi

info "Prerequisites verified."

# ------------------------------------------------------------
# Get the latest Ubuntu 22.04 AMI ID
# ------------------------------------------------------------
info "Fetching latest Ubuntu 22.04 AMI ID..."
AMI_ID=$(aws ec2 describe-images \
    --region "$AWS_REGION" \
    --owners "$AMI_OWNER" \
    --filters "Name=name,Values=$AMI_NAME_PATTERN" "Name=state,Values=available" \
    --query "Images | sort_by(@, &CreationDate) | [-1].ImageId" \
    --output text)

if [ -z "$AMI_ID" ] || [ "$AMI_ID" == "None" ]; then
    error_exit "Failed to retrieve AMI ID."
fi
info "Using AMI: $AMI_ID"

# ------------------------------------------------------------
# Create a security group
# ------------------------------------------------------------
SG_NAME="${NAME_PREFIX}-sg-$(date +%s)"
info "Creating security group: $SG_NAME"
SG_ID=$(aws ec2 create-security-group \
    --region "$AWS_REGION" \
    --group-name "$SG_NAME" \
    --description "Security group for Jenkins server" \
    --query 'GroupId' \
    --output text)

# Authorize SSH and Jenkins web UI
aws ec2 authorize-security-group-ingress \
    --region "$AWS_REGION" \
    --group-id "$SG_ID" \
    --protocol tcp --port 22 --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
    --region "$AWS_REGION" \
    --group-id "$SG_ID" \
    --protocol tcp --port 8080 --cidr 0.0.0.0/0

info "Security group created: $SG_ID"

# ------------------------------------------------------------
# User data script (installs Jenkins, Docker, Terraform, kubectl, AWS CLI)
# ------------------------------------------------------------
USER_DATA=$(cat <<'EOF'
#!/bin/bash
set -ex

# Update system
apt-get update -y
apt-get upgrade -y

# Install Docker
apt-get install -y docker.io
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
apt-get install -y unzip
unzip awscliv2.zip
sudo ./aws/install
rm -rf awscliv2.zip aws/

# Install Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
apt-get update && apt-get install -y terraform

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

# Install Jenkins (LTS)
apt-get update -y && apt upgrade -y
apt install -y openjdk-17-jre wget curl gnupg2 software-properties-common ca-certificates apt-transport-https docker.io
cd /tmp
wget https://pkg.jenkins.io/debian-stable/binary/jenkins_2.452.3_all.deb
dpkg -i jenkins_2.452.3_all.deb || apt-get -f install -y
systemctl start jenkins
systemctl enable jenkins
usermod -aG docker jenkins
systemctl restart jenkins
# Optional: Allow port 8080 if UFW is active
if command -v ufw > /dev/null; then
    ufw allow 8080
fi

echo "Jenkins installation completed successfully."

# Install git and other useful tools
apt-get install -y git curl wget

# Print initial Jenkins password to console log (visible in AWS console)
echo "===== JENKINS INITIAL PASSWORD ====="
cat /var/lib/jenkins/secrets/initialAdminPassword
echo "===================================="

EOF
)

# ------------------------------------------------------------
# Launch EC2 instance
# ------------------------------------------------------------
info "Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
    --region "$AWS_REGION" \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SG_ID" \
    --user-data "$USER_DATA" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${NAME_PREFIX}}]" \
    --query 'Instances[0].InstanceId' \
    --output text)

info "Instance launched: $INSTANCE_ID"

# Wait for instance to be running
info "Waiting for instance to reach 'running' state..."
aws ec2 wait instance-running --region "$AWS_REGION" --instance-ids "$INSTANCE_ID"

# ------------------------------------------------------------
# Allocate and associate an Elastic IP
# ------------------------------------------------------------
info "Allocating Elastic IP..."
ALLOCATION_ID=$(aws ec2 allocate-address \
    --region "$AWS_REGION" \
    --domain vpc \
    --query 'AllocationId' \
    --output text)

info "Associating Elastic IP with instance..."
aws ec2 associate-address \
    --region "$AWS_REGION" \
    --instance-id "$INSTANCE_ID" \
    --allocation-id "$ALLOCATION_ID" \
    >/dev/null

# Get the public IP
PUBLIC_IP=$(aws ec2 describe-addresses \
    --region "$AWS_REGION" \
    --allocation-ids "$ALLOCATION_ID" \
    --query 'Addresses[0].PublicIp' \
    --output text)

info "Elastic IP: $PUBLIC_IP"

# ------------------------------------------------------------
# Output connection info
# ------------------------------------------------------------
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Jenkins server deployment complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "SSH command:"
echo "  ssh -i /path/to/your-key.pem ubuntu@$PUBLIC_IP"
echo ""
echo "Jenkins URL:"
echo "  http://$PUBLIC_IP:8080"
echo ""
echo "To get the initial Jenkins password (if you missed it in console logs):"
echo "  ssh -i /path/to/your-key.pem ubuntu@$PUBLIC_IP 'sudo cat /var/lib/jenkins/secrets/initialAdminPassword'"
echo ""
echo "To destroy this server, run the destroy script or manually:"
echo "  aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region $AWS_REGION"
echo "  aws ec2 release-address --allocation-id $ALLOCATION_ID --region $AWS_REGION"
echo "  aws ec2 delete-security-group --group-id $SG_ID --region $AWS_REGION"
echo ""

# ------------------------------------------------------------
# Optional: Save resource IDs to a file for later destruction
# ------------------------------------------------------------
cat > jenkins-server-resources.txt <<EOF
INSTANCE_ID=$INSTANCE_ID
ALLOCATION_ID=$ALLOCATION_ID
SG_ID=$SG_ID
AWS_REGION=$AWS_REGION
EOF
info "Resource IDs saved to jenkins-server-resources.txt"