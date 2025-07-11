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
  user_data = <<-EOF
              #!/bin/bash
              # Redirect all output to a log file for debugging
              LOG_FILE="/tmp/user-data.log"
              sudo touch $LOG_FILE

              sudo yum update -y
              sudo amazon-linux-extras enable mariadb10.5
              sudo yum clean metadata
              sudo yum install -y mariadb
              # Add your business logic installation here
              sudo cat <<SQL > /tmp/rds_setup.sql
              ${templatefile("${path.module}/../../scripts/rds_setup.sql", {
  wp_db_name  = var.wp_db_name,
  wp_username = var.wp_username,
  wp_password = var.wp_password
})}
SQL

              # Verify the SQL file was created
	      if [ -f /tmp/rds_setup.sql ]; then
		echo "SQL file created successfully: /tmp/rds_setup.sql" >> $LOG_FILE 2>&1
	      else
		echo "Failed to create SQL file." >> $LOG_FILE 2>&1
		exit 1
	      fi

              # Connect to RDS and execute the SQL script
	      sudo mysql -h ${var.rds_endpoint} -u ${var.db_username} -p${var.db_password} < /tmp/rds_setup.sql >> $LOG_FILE 2>&1
	      if [ $? -eq 0 ]; then
		echo "Database and user created successfully." >> $LOG_FILE 2>&1
	      else
		echo "Failed to execute SQL script." >> $LOG_FILE 2>&1
		exit 1
	      fi
              echo "User-data script execution completed." >> $LOG_FILE 2>&1
              EOF
tags = {
  Name = "bastion-host"
}
}
