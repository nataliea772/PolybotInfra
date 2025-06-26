terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.55"
    }
  }

  backend "s3" {
    bucket = "natalie-tf-state"
    key    = "tfstate.json"
    region = "us-west-1"
    # optional: dynamodb_table = "<table-name>"
  }

  required_version = ">= 1.7.0"
}

provider "aws" {
  region = var.aws_region # "us-west-1"
}

module "network" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "k8s-main-vpc"
  cidr = "10.0.0.0/16"

  azs            = [var.availability_zones[0]]
  public_subnets = ["10.0.1.0/24"]

  enable_nat_gateway   = false
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Project = "Polybot"
    # Env = var.env
  }
}

module "k8s_cluster" {
  source           = "./modules/k8s-cluster"
  vpc_id           = module.network.vpc_id
  subnet_id        = module.network.public_subnets[0]
  key_name         = var.key_name
  instance_type    = var.instance_type
  ami_id           = var.ami_id
  desired_capacity = var.desired_capacity
  min_size         = var.min_size
  max_size         = var.max_size
}
