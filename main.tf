provider "aws" {
  region = var.region
}

# Retrieve existing IAM role ARN
data "aws_iam_role" "lambda_role" {
  name = var.lambda_role_name
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
  source                = "./modules/ec2_bastion"
  subnet_id             = module.subnet.public_subnet_ids[0]
  security_group_id     = module.security_group.bastion_sg_id
  key_name              = var.key_name
  instance_type         = var.instance_type
  use_amazon_linux_2023 = var.bastion_use_amazon_linux_2023
  db_name               = var.db_name
  db_username           = var.db_username
  db_password           = var.db_password
  wp_db_name            = var.wp_db_name
  wp_username           = var.wp_username
  wp_password           = var.wp_password
  rds_endpoint          = module.rds.rds_endpoint
}

# Frontend App Deployment Module
module "frontend_deployment" {
  source = "./modules/frontend_deployment"

  gitlab_repo_url = var.gitlab_repo_url
  s3_bucket_name  = var.s3_bucket_name
  aws_region      = var.region
  api_endpoint    = "http://${module.load_balancer.alb_dns_name}"
  environment     = "production"

  # RDS Database Configuration
  rds_endpoint = module.rds.rds_endpoint
  db_name      = var.db_name
  db_username  = var.db_username
  db_password  = var.db_password

  use_amazon_linux_2023 = var.frontend_use_amazon_linux_2023
  instance_type         = var.instance_type
  key_name              = var.key_name
  security_group_ids    = [module.security_group.frontend_sg_id]

  depends_on = [module.s3, module.rds]
}

module "autoscaling" {
  source             = "./modules/autoscaling"
  launch_template_id = module.frontend_deployment.launch_template_id
  subnet_ids         = module.subnet.private_subnet_ids  # Changed from public to private subnets
  target_group_arn   = module.load_balancer.target_group_arn

  depends_on = [module.frontend_deployment]
}

module "load_balancer" {
  source            = "./modules/load_balancer"
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.subnet.public_subnet_ids
  security_group_id = module.security_group.alb_sg_id
}

# Add CloudFront distribution for HTTPS
module "cloudfront" {
  source       = "./modules/cloudfront"
  alb_dns_name = module.load_balancer.alb_dns_name
  
  depends_on = [module.load_balancer]
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

module "sns" {
  source = "./modules/sns"
}

module "s3" {
  source        = "./modules/s3"
  bucket_name   = var.s3_bucket_name
  sns_topic_arn = module.sns.sns_topic_arn
}

module "lambda_rekognition" {
  source          = "./modules/lambda_rekognition"
  sns_topic_arn   = module.sns.sns_topic_arn
  bucket_name     = module.s3.bucket_name
  lambda_role_arn = data.aws_iam_role.lambda_role.arn

  # RDS Database Configuration
  rds_endpoint = module.rds.rds_endpoint
  db_name      = var.db_name
  db_username  = var.db_username
  db_password  = var.db_password

  # VPC Configuration for Lambda networking
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.subnet.private_subnet_ids # Back to private with NAT Gateway
  vpc_cidr           = var.vpc_cidr

  depends_on = [module.rds, module.sns, module.vpc, module.subnet]
}

# Add Lambda access to RDS security group
resource "aws_security_group_rule" "lambda_to_rds" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = module.lambda_rekognition.lambda_security_group_id
  security_group_id        = module.security_group.rds_sg_id
  description              = "Allow Lambda access to RDS"

  depends_on = [
    module.lambda_rekognition,
    module.security_group
  ]
}
