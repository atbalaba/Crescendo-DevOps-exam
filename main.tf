provider "aws" {
  region = "ap-southeast-1"
}

module "vpc"{
    source = "./network"
}

module "subnets" {
  source = "./network"
}

module "ec2" {
  source = "./instance"
}

module "alb" {
  source = "./load-balancer"
}