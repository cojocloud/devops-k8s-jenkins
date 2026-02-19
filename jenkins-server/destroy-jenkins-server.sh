#!/bin/bash
set -euo pipefail

if [ ! -f jenkins-server-resources.txt ]; then
    echo "ERROR: Resource file jenkins-server-resources.txt not found."
    exit 1
fi

source jenkins-server-resources.txt

echo "Terminating instance $INSTANCE_ID..."
aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" >/dev/null
aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID" --region "$AWS_REGION"

echo "Releasing Elastic IP $ALLOCATION_ID..."
aws ec2 release-address --allocation-id "$ALLOCATION_ID" --region "$AWS_REGION" >/dev/null

echo "Deleting security group $SG_ID..."
aws ec2 delete-security-group --group-id "$SG_ID" --region "$AWS_REGION" >/dev/null

echo "Cleanup complete."
rm -f jenkins-server-resources.txt