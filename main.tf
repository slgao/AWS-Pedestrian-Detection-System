provider "aws" {
  region = var.region
}

module "vpc" {
  source   = "./modules/vpc"
  vpc_cidr = var.vpc_cidr
}

module "subnet" {
  source                     = "./modules/subnet"
  vpc_id                     = module.vpc.vpc_id
  public_subnet_cidr_blocks  = var.public_subnet_cidr_blocks
  private_subnet_cidr_blocks = var.private_subnet_cidr_blocks
  availability_zones         = var.availability_zones
}

module "internet_gateway" {
  source = "./modules/internet_gateway"
  vpc_id = module.vpc.vpc_id
}

module "route_table" {
  source              = "./modules/route_table"
  vpc_id              = module.vpc.vpc_id
  internet_gateway_id = module.internet_gateway.internet_gateway_id
  public_subnet_ids   = module.subnet.public_subnet_ids
  private_subnet_ids  = module.subnet.private_subnet_ids
}

module "security_group" {
  source = "./modules/security_group"
  vpc_id = module.vpc.vpc_id
}

module "ec2_bastion" {
  source            = "./modules/ec2_bastion"
  subnet_id         = module.subnet.public_subnet_ids[0]
  security_group_id = module.security_group.bastion_sg_id
  key_name          = var.key_name
  instance_type     = var.instance_type
}

module "ec2_frontend" {
  source            = "./modules/ec2_frontend"
  subnet_id         = module.subnet.public_subnet_ids[1]
  security_group_id = module.security_group.frontend_sg_id
  key_name          = var.key_name
  instance_type     = var.instance_type
  ami               = module.ec2_bastion.ami
  user_data         = file("${path.module}/scripts/frontend_setup.sh")
}

module "ec2_backend" {
  source            = "./modules/ec2_backend"
  subnet_id         = module.subnet.private_subnet_ids[0]
  security_group_id = module.security_group.backend_sg_id
  key_name          = var.key_name
  instance_type     = var.instance_type
  ami               = module.ec2_bastion.ami
}

