terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.60"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region     = (var.aws_region)
  access_key = (var.aws_access_key)
  secret_key = (var.aws_secret_key)
}
# Provider Alias for us-east-1
provider "aws" {
  alias      = "us-east-1"
  region     = "us-east-1"
  access_key = (var.aws_access_key)
  secret_key = (var.aws_secret_key)
}

#VPC
module "myapp-vpc" {
  source               = "./modules/vpc"
  azs                  = (var.azs)
  public_subnet_cidrs  = (var.public_subnet_cidrs)
  private_subnet_cidrs = (var.private_subnet_cidrs)
  cidr_block           = (var.cidr_block)
}

#Request SSL Certificate
module "acm" {
  source      = "terraform-aws-modules/acm/aws"
  version     = "~> 4.0"
  domain_name = (var.domain_name)
  zone_id     = (var.route53_zone_id) #Route 53 Hosted Zone
  subject_alternative_names = [
    "*.${var.domain_name}"
  ]
  wait_for_validation = true
  tags = {
    Name = (var.domain_name)
  }
}
output "certificate_arn_value" {
  value = module.acm.acm_certificate_arn
}

#Request SSL Certificate
module "acm-east1" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 4.0"
  providers = {
    aws = aws.us-east-1
  }
  domain_name = (var.domain_name)
  zone_id     = "Z00714729FM34HPJJCBL" #Route 53 Hosted Zone
  subject_alternative_names = [
    "*.${var.domain_name}"
  ]
  wait_for_validation = true
  tags = {
    Name = (var.domain_name)
  }
}
output "east1_certificate_arn_value" {
  value = module.acm-east1.acm_certificate_arn
}


#WWW site s3 & cloudfront
module "site-s3" {
  source          = "./modules/site"
  site_hostname   = "www.${var.domain_name}"
  certificate_arn = module.acm-east1.acm_certificate_arn
}

#Second website if needed site s3 & cloudfront
# module "admin-s3" {
#   source          = "./modules/site"
#   site_hostname   = "admin.${var.domain_name}"
#   certificate_arn = module.acm-east1.acm_certificate_arn
# }

#App Balancer
module "main-alb" {
  source         = "./modules/alb"
  vpc_id         = module.myapp-vpc.vpc_id
  public_subnets = module.myapp-vpc.public_subnets
  domain_name    = (var.domain_name)
  depends_on = [
    module.myapp-vpc
  ]
}

#ECS Cluster
module "ecs-cluster" {
  source          = "./modules/ecs"
  app_environment = var.app_environment
  depends_on = [
    module.myapp-vpc
  ]
}
#ECR for GraphQL
module "graph-ecr" {
  source          = "./modules/ecr"
  repository_name = "graphql"
}

#ECS Fargate GraphQL Service & Task Definition
module "graphql" {
  source                = "./modules/graphql-service"
  app_environment       = var.app_environment
  app_name              = "graphql"
  host_header           = "graphql.${var.domain_name}"
  aws_region            = var.aws_region
  repository_url        = module.graph-ecr.repository_url
  vpc_id                = module.myapp-vpc.vpc_id
  cluster_id            = module.ecs-cluster.cluster_id
  cluster_name          = module.ecs-cluster.cluster_name
  private_subnets       = module.myapp-vpc.private_subnets
  alb_security_group_id = module.main-alb.alb_security_group_id
  alb_arn               = module.main-alb.alb_arn
  alb_id                = module.main-alb.alb_id
  certificate_arn       = module.acm.acm_certificate_arn
  depends_on = [
    module.ecs-cluster,
    module.main-alb
  ]
}