terraform {
  backend "s3" {
    bucket         = "terraforms3project" 
    key            = "terraform.tfstate"
    region         = "us-east-1"  
    encrypt        = true
  }
}

variable "DB_NAME" {
  type        = string
}

variable "DB_USER" {
  type        = string
}

variable "DB_PASSWORD" {
  type        = string
}

module "sg" {
  source = "./modules/security_groups"

  vpc_id = module.vpc.vpc_id
}

provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source = "./modules/vpc"
}

module "rds" {
  source = "./modules/rds"

  DB_USER                     = var.DB_USER
  DB_PASSWORD                 = var.DB_PASSWORD
  vpc_id                      = module.vpc.vpc_id
  private_sub_1_id            = module.vpc.private_sub_1_id
  private_sub_2_id            = module.vpc.private_sub_2_id
}

module "iam" {
  source = "./modules/iam"
}

module "ec2" {
  source = "./modules/ec2"

  ami                         = "ami-0fc5d935ebf8bc3bc"
  instance_type               = "t2.micro"

  vpc_id                      = module.vpc.vpc_id
  public_sub_1_id             = module.vpc.public_sub_1_id
  public_sub_2_id             = module.vpc.public_sub_2_id
  private_sub_1_id            = module.vpc.private_sub_1_id
  private_sub_2_id            = module.vpc.private_sub_2_id

  ec2_sg_id                   = module.sg.ec2_sg_id
  alb_sg_id                   = module.sg.alb_sg_id

  DB_USER                     = var.DB_USER
  DB_PASSWORD                 = var.DB_PASSWORD
  DB_HOST                     = module.rds.db_host
  DB_NAME                     = var.DB_NAME

  ec2_profile_name            = module.iam.ec2_profile_name
}