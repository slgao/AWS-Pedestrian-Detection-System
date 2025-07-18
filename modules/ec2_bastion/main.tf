# Reference AMI data module
module "ami_data" {
  source = "../ami_data"
}

resource "aws_instance" "bastion" {
  ami                    = var.use_amazon_linux_2023 ? module.ami_data.amazon_linux_2023_id : module.ami_data.amazon_linux_2_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.key_name
  user_data_base64 = base64encode(templatefile("${path.module}/../../scripts/bastion_setup.sh", {
    rds_endpoint = var.rds_endpoint
    db_username  = var.db_username
    db_password  = var.db_password
    db_name      = var.db_name
    wp_db_name   = var.wp_db_name
    wp_username  = var.wp_username
    wp_password  = var.wp_password
  }))
  tags = {
    Name = "bastion-host"
  }
}
