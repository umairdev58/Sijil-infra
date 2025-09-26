variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "key_name" {
  description = "Existing EC2 key pair name"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed for SSH (e.g. your IP/32)"
  type        = string
}

variable "app_port" {
  description = "Application listen port"
  type        = number
  default     = 8000
}

variable "allocate_eip" {
  description = "Whether to allocate an Elastic IP"
  type        = bool
  default     = false
}

variable "app_repo_url" {
  description = "Git repository URL for the app"
  type        = string
}

variable "app_repo_branch" {
  description = "Git branch to checkout"
  type        = string
  default     = "main"
}

variable "backend_env" {
  description = "Map of environment variables for backend .env"
  type        = map(string)
}


