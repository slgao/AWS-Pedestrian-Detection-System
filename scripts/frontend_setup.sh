#!/bin/bash
sudo yum update -y	
sudo amazon-linux-extras enable php8.0 mariadb10.5
sudo yum clean metadata
sudo yum install -y php php-mysqlnd mariadb unzip httpd
sudo systemctl start httpd
sudo systemctl enable httpd
sudo systemctl start mariadb
sudo systemctl enable mariadb
cd /var/www/html
sudo wget https://wordpress.org/latest.zip
sudo unzip latest.zip
sudo cp -r wordpress/* .
sudo rm -rf wordpress latest.zip
sudo chown -R apache:apache /var/www/html
sudo cp wp-config-sample.php wp-config.php
sudo sed -i "s/database_name_here/wordpress/" wp-config.php
sudo sed -i "s/username_here/wpuser/" wp-config.php
sudo sed -i "s/password_here/wp-password123!/" wp-config.php
sudo sed -i "s/localhost/$rds_endpoint/" wp-config.php
sudo systemctl restart httpd
