### 🚀 Kubernetes CI/CD Deployment on AWS (Jenkins + Docker + Terraform)

## 📌 Project Overview

This project demonstrates a complete DevOps automation pipeline for deploying a Python FastAPI application to a Kubernetes cluster running on AWS.

It integrates:

GitHub (Source Control)

Jenkins (CI/CD Automation)

Docker (Containerization)

DockerHub (Image Registry)

Kubernetes (Container Orchestration)

Kops (Kubernetes Cluster Provisioning)

Terraform (Infrastructure as Code)

AWS EC2 + S3

## 🎯 Key Features

Fully automated CI/CD

Infrastructure as Code

Containerized microservice architecture

Kubernetes LoadBalancer exposure

Scalable and production-ready foundation


## 🧠 What This Project Demonstrates

This project showcases real-world DevOps skills:

CI/CD design

Infrastructure provisioning

Kubernetes operations

Container lifecycle management

Cloud architecture automation

## 📐 Architecture

![Architecture Diagram](images/architecture.png)

## 📂 Repository Structure

```bash

K8S-TF-DOC-JEN/
├── app/
│   ├── Dockerfile
│   ├── form.html
│   ├── requirements.txt 
│   └── main.py
│ 
├── images/
│   └── architecture.png
│
├── jenkins-server/
│   ├── deploy-jenkins-server.sh
│   └── destroy-jenkins-server.sh
│ 
├── K8S/
│   ├── deployment.yaml
│   └── service.yaml
│ 
├── scripts/
│   ├── deploy.sh
|   └── destroy.sh 
│           
├── terraform/
|       |-- main.tf 
│       ├── outputs.tf
│       ├── providers.tf
│       ├── terraform.tfvars
│       └── variables.tf
│
│--- .gitignore
│
│--- Jenkinsfile
│
│--- Jenkinsfile.destroy
|
└── README.md
```

## Flow:

Launch jenkins server

Jenkins pipeline triggered via webhook

Docker image built and pushed to DockerHub

Kubernetes deployment updated automatically

Application exposed via AWS LoadBalancer

## 🛠 Technologies Used

Python FastAPI

Bashscripting 

Docker

Kubernetes

Kops

Terraform

Jenkins

AWS EC2

DockerHub

GitHub Webhooks

## ⚙️ Infrastructure Setup

1. Prepare Your Local Machine

Ensure you have Terraform installed locally (≥1.0).

Configure AWS credentials via environment variables or ~/.aws/credentials.

Have an EC2 key pair in the same region you'll use. If you don't have one, create it in the AWS Console (EC2 → Key Pairs) and download the .pem file.

2. Create the Jenkins Server

```bash
cd K8S-TF-DOC-JEN/jenkins-server
chmod +x deploy-jenkins-server.sh
./deploy-jenkins-server.sh
```

3. SSH into the Jenkins Server
Use the key pair you specified:

```bash
ssh -i /path/to/your-key.pem ubuntu@<jenkins_public_ip>
```

Once logged in, you are on the fresh Ubuntu server with all tools installed.

4. Clone Your Project Repository on the Server

```bash
git clone https://github.com/Joebaho/K8S-TF-DOC-JEN.git
cd K8S-TF-DOC-JEN
```

5. Build Infranstructure ( VPC and EKS cluster)

```bash
cd scripts
chmod +x deploy.sh
./deploy.sh
```

6. 🐳 Manual Docker Image Build & push (Until Jenkins is automated)

```bash
docker build -t yourdockerhubusername/fastapi-app .
docker push yourdockerhubusername/fastapi-app:latest
```

7. ☸️ Kubernetes Deployment(Manual):

```bash
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

8. Get Application Access:

```bash
kubectl get svc -w
```

Wait for the LoadBalancer EXTERNAL-IP to appear and note it. Access via LoadBalancer external IP.

## 🔁 Jenkins Pipeline

1 - Install required plugins:

* Pipeline

* Git

* Credentials Binding

* Docker Pipeline, AWS Steps

2 - Add Docker credentials in Jenkins:

* dockerhub-username (type: "Secret text") – your Docker Hub username.

* dockerhub-password (type: "Secret text") – your Docker Hub password/token.

* aws-access-key-id and aws-secret-access-key (both "Secret text") – your AWS credentials.

3 - Create a new Pipeline job:

* Select Pipeline script from SCM.

* Set Git repository URL to https://github.com/Joebaho/K8S-TF-DOC-JEN.git.

* Set script path to Jenkinsfile 

* Save and run.

Ensure your Jenkins agent has the following tools installed and available in PATH:

* terraform

* kubectl

* aws CLI

* docker (and the Docker daemon must be running, or use a Docker agent)

Webhook triggers automatic deployment on every commit.

## 🧹 Clean Up When Done

To avoid incurring costs, destroy both the Jenkins server and the EKS cluster:

Destroy the EKS cluster (from the Jenkins server or your local machine):

```bash
cd ~/K8S-TF-DOC-JEN/scripts
export AUTO_DESTROY=true
./destroy.sh
```

Destroy the Jenkins server (from your local machine):

```bash
cd K8S-TF-DOC-JEN/jenkins-server
chmod +x destroy-jenkins-server.sh
./destroy-jenkins-server.sh
```

## 🏁 Conclusion

This project is a simple and practical way to understand how Terraform manages **infrastructures deployments**. Then we can build an image with **Docker** and finally ensure the automation with CI/CD pipeline. 

---

## 👨‍💻 Author

**Joseph Mbatchou**
• DevOps / Cloud / Platform  Engineer   • Content Creator

## 🔗 Connect With Me

🌐 Website: [https://platform.joebahocloud.com](https://platform.joebahocloud.com)

💼 LinkedIn: [https://www.linkedin.com/in/josephmbatchou/](https://www.linkedin.com/in/josephmbatchou/)

🐦 X/Twitter: [https://www.twitter.com/Joebaho237](https://www.twitter.com/Joebaho237)

▶️ YouTube: [https://www.youtube.com/@josephmbatchou5596](https://www.youtube.com/@josephmbatchou5596)

🔗 Github: [https://github.com/Joebaho](https://github.com/Joebaho)

📦 Dockerhub: [https://hub.docker.com/u/joebaho2](https://hub.docker.com/u/joebaho2)

---

## 📄 License

This project is open-source and available under the **MIT License**.
Docker