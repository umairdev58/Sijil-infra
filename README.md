Infrastructure (Terraform) for Sijil Backend on AWS Free Tier

Overview

This Terraform stack provisions a minimal, free-tier–friendly AWS setup to host the Node.js/Express backend on a single t2.micro EC2 instance in the default VPC. It bootstraps the instance with Node.js, PM2, clones your repo, installs dependencies, writes the .env, and launches the backend on port 8000.

What it creates

- Security group allowing:
  - SSH (22) from your IP (configurable)
  - App port (8000) from 0.0.0.0/0 (adjust if you use a reverse proxy)
- EC2 t2.micro (free tier eligible)
- Optional Elastic IP association (disabled by default)

Assumptions

- You will use MongoDB Atlas (free tier) or an existing MongoDB. Provide MONGODB_URI via variables.
- You have a public Git repo, or the instance has access to your private repo (e.g., deploy key). Provide app_repo_url and app_repo_branch.
- You have an existing EC2 key pair in the target region.

Prerequisites

1) Install Terraform (>= 1.3)
2) Configure AWS credentials (env vars or shared credentials file)
3) Have a key pair in AWS (EC2 → Key Pairs). Note the key name.

Quick start

1) Copy example variables and fill them in:

   cp terraform.tfvars.example terraform.tfvars

2) Edit terraform.tfvars:

- region               = "ap-south-1"
- key_name             = "your-keypair-name"
- allowed_ssh_cidr     = "YOUR.PUBLIC.IP.0/24"  # or a single IP /32
- app_repo_url         = "https://github.com/your-user/Sijil.git"
- app_repo_branch      = "main"
- backend_env = {
    PORT         = "8000"
    JWT_SECRET   = "change-me"
    MONGODB_URI  = "your-atlas-uri"
    NODE_ENV     = "production"
  }

3) Init, plan, and apply:

   terraform -chdir=infra init
   terraform -chdir=infra plan
   terraform -chdir=infra apply

4) Outputs show public_ip and SSH command.

Accessing the app

- Once apply completes, wait ~1–2 minutes for bootstrap. Visit: http://PUBLIC_IP:8000

Notes

- Free tier optimization: single t2.micro, default VPC, no ALB.
- For production hardening, place the app behind an ALB/CloudFront + ACM, restrict 8000, and add SSM for SSH-less access.

Destroy

   terraform -chdir=infra destroy


