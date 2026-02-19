#!/bin/bash
set -e

exec > /var/log/user-data.log 2>&1

echo "Starting Jenkins installation..."

# Update system
sudo apt update -y
sudo apt upgrade -y

# Install required packages
sudo apt install -y openjdk-17-jre wget curl gnupg2 software-properties-common ca-certificates apt-transport-https docker.io

# Verify Java
java -version

# Download latest Jenkins LTS .deb directly (bypasses GPG repo issue)
sudo cd /tmp
wget https://pkg.jenkins.io/debian-stable/binary/jenkins_2.452.3_all.deb

# Install Jenkins
sudo dpkg -i jenkins_2.452.3_all.deb || apt-get -f install -y

# Enable and start Jenkins
sudo systemctl enable jenkins
sudo systemctl start jenkins

# Add Jenkins to Docker group
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins

# Optional: Allow port 8080 if UFW is active
if command -v ufw > /dev/null; then
    ufw allow 8080
fi

echo "Jenkins installation completed successfully."
