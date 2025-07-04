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
  db_name           = var.db_name
  db_username       = var.db_username
  db_password       = var.db_password
  wp_db_name        = var.wp_db_name
  wp_username       = var.wp_username
  wp_password       = var.wp_password
  rds_endpoint      = module.rds.rds_endpoint
}

module "ec2_frontend" {
  source            = "./modules/ec2_frontend"
  subnet_id         = module.subnet.public_subnet_ids[1]
  security_group_id = module.security_group.frontend_sg_id
  key_name          = var.key_name
  instance_type     = var.instance_type
  ami               = module.ec2_bastion.ami
  user_data = templatefile("${path.module}/scripts/frontend_setup.sh", {
    rds_endpoint = module.rds.rds_endpoint
    wp_db_name   = var.wp_db_name
    wp_username  = var.wp_username
    wp_password  = var.wp_password
  })
}

module "ec2_backend" {
  source            = "./modules/ec2_backend"
  subnet_id         = module.subnet.private_subnet_ids[0]
  security_group_id = module.security_group.backend_sg_id
  key_name          = var.key_name
  instance_type     = var.instance_type
  ami               = module.ec2_bastion.ami
  rds_endpoint      = module.rds.rds_endpoint
}

module "rds" {
  source                 = "./modules/rds"
  subnet_ids             = module.subnet.private_subnet_ids
  security_group_id      = module.security_group.rds_sg_id
  db_instance_identifier = var.db_instance_identifier
  db_engine              = var.db_engine
  db_engine_version      = var.db_engine_version
  db_instance_class      = var.db_instance_class
  allocated_storage      = var.allocated_storage
  skip_final_snapshot    = var.skip_final_snapshot
  multi_az               = var.db_multi_az
  db_name                = var.db_name
  db_username            = var.db_username
  db_password            = var.db_password
}
