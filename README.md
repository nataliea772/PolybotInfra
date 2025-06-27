**Kubernetes Cluster Provisioning with Terraform and kubeadm**

📌 Overview
  
  This project provisions a Kubernetes cluster on AWS using Terraform for infrastructure-as-code and kubeadm for cluster initialization. 
  It includes:
    
    - EC2-based control plane and worker nodes
    
    - Custom user-data scripts
    
    - GitHub Actions for automated provisioning and initialization
    
    - Auto Scaling Group (ASG) for worker nodes
    
    - Secure kubeadm join using AWS SSM Parameter Store

🛠️ Architecture

  AWS EC2 Infrastructure:

                    +--------------------+
                    |  Control Plane EC2 |
                    +--------+-----------+
                             |
                             | Kubeadm init + Calico CNI
                             |
                +------------+-------------+
                |                          |
    +------------------+        +------------------+
    | Worker Node EC2  |        | Worker Node EC2  |
    +------------------+        +------------------+
      (via Auto Scaling Group)
    
    - Single control plane
    
    - ASG-managed worker nodes
    
    - All nodes have CRI-O, kubelet, kubeadm pre-installed

🌍 Infrastructure with Terraform

  Directory Structure:
    
    tf/
    ├── modules/
    │   └── k8s-cluster/
    │       ├── main.tf
    │       ├── variables.tf
    │       └── outputs.tf
    ├── main.tf
    ├── outputs.tf
    ├── variables.tf
    ├── region.us-west-1.tfvars

Resources Provisioned:
    
    - VPC (shared)
    
    - Security groups
    
    - IAM roles for EC2 SSM
    
    - Control plane EC2 instance
    
    - Launch template + Auto Scaling Group for workers

Usage:

    terraform workspace select us-west-1 || terraform workspace new us-west-1
    terraform apply -var-file=region.us-west-1.tfvars

🚀 Kubernetes Cluster Initialization

    Cluster is initialized with a separate GitHub Actions pipeline:
    
    - Dynamically fetches control plane IP
    
    - SSH into the machine using GitHub secret
    
    - Runs kubeadm init
    
    - Configures kubectl
    
    - Installs Calico CNI
    
    - Stores kubeadm join command securely in AWS SSM

⚙️ Worker Node Auto Join via ASG

    Worker nodes are created via ASG. Their startup process includes:
    
    - Installing Kubernetes and CRI-O using user-data
    
    - Enabling IP forwarding and swap off
    
    - Fetching latest kubeadm join command from AWS SSM
    
    - Joining the cluster on boot

  Supports automatic joining even if token has rotated (via secure SSM fetch).

🔄 GitHub Actions Workflows
  
  1. Provision Infrastructure
  
    - Trigger: Push to main branch
  
    - Runs: Terraform apply
  
  2. Init Control Plane
  
    - Trigger: After provisioning workflow completes
  
    - Runs: SSH into control plane and run init script

🧹 Destroy Infrastructure

  To clean up resources:
  
    terraform destroy -var-file=region.us-west-1.tfvars

✅ Final Result

  kubectl get nodes
  NAME             STATUS   ROLES           AGE   VERSION
  control-plane    Ready    control-plane   XXm   v1.32.6
  ip-10-0-x-xxx    Ready    <none>          XXm   v1.32.6

🧪 How to Demo

  - Show GitHub Actions pipelines (2 stages)
  
  - SSH into control plane and run kubectl get nodes
  
  - Scale up the ASG in AWS Console and watch new workers auto-join
