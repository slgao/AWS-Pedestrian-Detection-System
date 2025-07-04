CREATE DATABASE ${wp_db_name};
CREATE USER '${wp_username}'@'%' IDENTIFIED BY '${wp_password}';
GRANT ALL PRIVILEGES ON ${wp_db_name}.* TO '${wp_username}'@'%';
FLUSH PRIVILEGES;
