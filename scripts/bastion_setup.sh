#!/bin/bash

# Bastion Host Setup Script
# Sets up WordPress database and Image Recognition database schema

# Redirect all output to a log file for debugging
LOG_FILE="/tmp/bastion-setup.log"
sudo touch $LOG_FILE
echo "=== Bastion Host Setup Started ===" >> $LOG_FILE 2>&1
echo "Timestamp: $(date)" >> $LOG_FILE 2>&1

# Database connection parameters (passed via template variables)
RDS_ENDPOINT="${rds_endpoint}"
DB_USERNAME="${db_username}"
DB_PASSWORD="${db_password}"
DB_NAME="${db_name}"
WP_DB_NAME="${wp_db_name}"
WP_USERNAME="${wp_username}"
WP_PASSWORD="${wp_password}"

echo "RDS Endpoint: $RDS_ENDPOINT" >> $LOG_FILE 2>&1
echo "Database Name: $DB_NAME" >> $LOG_FILE 2>&1
echo "WordPress DB: $WP_DB_NAME" >> $LOG_FILE 2>&1

# Update system
echo "Updating system packages..." >> $LOG_FILE 2>&1
sudo yum update -y >> $LOG_FILE 2>&1

# Install MySQL client (compatible with both AL2 and AL2023)
echo "Installing MySQL client..." >> $LOG_FILE 2>&1
if command -v amazon-linux-extras &> /dev/null; then
    # Amazon Linux 2
    echo "Detected Amazon Linux 2" >> $LOG_FILE 2>&1
    sudo amazon-linux-extras enable mariadb10.5 >> $LOG_FILE 2>&1
    sudo yum clean metadata >> $LOG_FILE 2>&1
    sudo yum install -y mariadb >> $LOG_FILE 2>&1
else
    # Amazon Linux 2023
    echo "Detected Amazon Linux 2023" >> $LOG_FILE 2>&1
    sudo dnf install -y mysql >> $LOG_FILE 2>&1
fi

# Wait for RDS to be ready
echo "Waiting for RDS to be ready..." >> $LOG_FILE 2>&1
sleep 60

# Test database connection
echo "Testing database connection..." >> $LOG_FILE 2>&1
mysql -h "$RDS_ENDPOINT" -u "$DB_USERNAME" -p"$DB_PASSWORD" -e "SELECT 1;" >> $LOG_FILE 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Database connection successful" >> $LOG_FILE 2>&1
else
    echo "❌ Database connection failed" >> $LOG_FILE 2>&1
    echo "Retrying in 30 seconds..." >> $LOG_FILE 2>&1
    sleep 30
    mysql -h "$RDS_ENDPOINT" -u "$DB_USERNAME" -p"$DB_PASSWORD" -e "SELECT 1;" >> $LOG_FILE 2>&1
    if [ $? -ne 0 ]; then
        echo "❌ Database connection failed after retry" >> $LOG_FILE 2>&1
        exit 1
    fi
fi

# Create WordPress database setup SQL
echo "Creating WordPress database setup..." >> $LOG_FILE 2>&1
cat > /tmp/wordpress_setup.sql << EOF
CREATE DATABASE IF NOT EXISTS $WP_DB_NAME;
CREATE USER IF NOT EXISTS '$WP_USERNAME'@'%' IDENTIFIED BY '$WP_PASSWORD';
GRANT ALL PRIVILEGES ON $WP_DB_NAME.* TO '$WP_USERNAME'@'%';
FLUSH PRIVILEGES;
EOF

# Create Image Recognition database setup SQL
echo "Creating Image Recognition database schema..." >> $LOG_FILE 2>&1
cat > /tmp/image_recognition_setup.sql << EOF
-- Image Recognition Database Schema
USE $DB_NAME;

-- Main images table
CREATE TABLE IF NOT EXISTS images (
    id INT AUTO_INCREMENT PRIMARY KEY,
    s3_key VARCHAR(500) NOT NULL UNIQUE,
    original_name VARCHAR(255) NOT NULL,
    file_size BIGINT,
    upload_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processing_status ENUM('pending', 'processing', 'completed', 'failed') DEFAULT 'pending',
    processed_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_s3_key (s3_key),
    INDEX idx_upload_time (upload_time),
    INDEX idx_processing_status (processing_status)
);

-- General object detection labels
CREATE TABLE IF NOT EXISTS detection_labels (
    id INT AUTO_INCREMENT PRIMARY KEY,
    image_id INT NOT NULL,
    label_name VARCHAR(100) NOT NULL,
    confidence DECIMAL(5,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (image_id) REFERENCES images(id) ON DELETE CASCADE,
    INDEX idx_image_id (image_id),
    INDEX idx_label_name (label_name),
    INDEX idx_confidence (confidence)
);

-- Person detection bounding boxes
CREATE TABLE IF NOT EXISTS person_detections (
    id INT AUTO_INCREMENT PRIMARY KEY,
    image_id INT NOT NULL,
    confidence DECIMAL(5,2) NOT NULL,
    bbox_left DECIMAL(8,6) NOT NULL,
    bbox_top DECIMAL(8,6) NOT NULL,
    bbox_width DECIMAL(8,6) NOT NULL,
    bbox_height DECIMAL(8,6) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (image_id) REFERENCES images(id) ON DELETE CASCADE,
    INDEX idx_image_id (image_id),
    INDEX idx_confidence (confidence)
);

-- Face detection with detailed attributes
CREATE TABLE IF NOT EXISTS face_detections (
    id INT AUTO_INCREMENT PRIMARY KEY,
    image_id INT NOT NULL,
    confidence DECIMAL(5,2) NOT NULL,
    bbox_left DECIMAL(8,6) NOT NULL,
    bbox_top DECIMAL(8,6) NOT NULL,
    bbox_width DECIMAL(8,6) NOT NULL,
    bbox_height DECIMAL(8,6) NOT NULL,
    age_low INT,
    age_high INT,
    gender VARCHAR(10),
    gender_confidence DECIMAL(5,2),
    primary_emotion VARCHAR(20),
    emotion_confidence DECIMAL(5,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (image_id) REFERENCES images(id) ON DELETE CASCADE,
    INDEX idx_image_id (image_id),
    INDEX idx_confidence (confidence),
    INDEX idx_gender (gender),
    INDEX idx_primary_emotion (primary_emotion)
);

-- All emotions detected for each face
CREATE TABLE IF NOT EXISTS face_emotions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    face_detection_id INT NOT NULL,
    emotion_type VARCHAR(20) NOT NULL,
    confidence DECIMAL(5,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (face_detection_id) REFERENCES face_detections(id) ON DELETE CASCADE,
    INDEX idx_face_detection_id (face_detection_id),
    INDEX idx_emotion_type (emotion_type)
);

-- Processing logs for debugging and monitoring
CREATE TABLE IF NOT EXISTS processing_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    image_id INT,
    process_type ENUM('upload', 'rekognition', 'database') NOT NULL,
    status ENUM('started', 'completed', 'failed') NOT NULL,
    message TEXT,
    processing_time_ms INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (image_id) REFERENCES images(id) ON DELETE CASCADE,
    INDEX idx_image_id (image_id),
    INDEX idx_process_type (process_type),
    INDEX idx_status (status),
    INDEX idx_created_at (created_at)
);

-- Create a view for easy querying of complete image data
CREATE OR REPLACE VIEW image_summary AS
SELECT 
    i.id,
    i.s3_key,
    i.original_name,
    i.file_size,
    i.upload_time,
    i.processing_status,
    i.processed_at,
    COUNT(DISTINCT pd.id) as person_count,
    COUNT(DISTINCT fd.id) as face_count,
    COUNT(DISTINCT dl.id) as label_count
FROM images i
LEFT JOIN person_detections pd ON i.id = pd.image_id
LEFT JOIN face_detections fd ON i.id = fd.image_id  
LEFT JOIN detection_labels dl ON i.id = dl.image_id
GROUP BY i.id, i.s3_key, i.original_name, i.file_size, i.upload_time, i.processing_status, i.processed_at;
EOF

# Execute WordPress setup
echo "Setting up WordPress database..." >> $LOG_FILE 2>&1
mysql -h "$RDS_ENDPOINT" -u "$DB_USERNAME" -p"$DB_PASSWORD" < /tmp/wordpress_setup.sql >> $LOG_FILE 2>&1
if [ $? -eq 0 ]; then
    echo "✅ WordPress database setup completed" >> $LOG_FILE 2>&1
else
    echo "❌ WordPress database setup failed" >> $LOG_FILE 2>&1
fi

# Execute Image Recognition setup
echo "Setting up Image Recognition database schema..." >> $LOG_FILE 2>&1
mysql -h "$RDS_ENDPOINT" -u "$DB_USERNAME" -p"$DB_PASSWORD" < /tmp/image_recognition_setup.sql >> $LOG_FILE 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Image Recognition database schema created successfully" >> $LOG_FILE 2>&1
else
    echo "❌ Image Recognition database schema creation failed" >> $LOG_FILE 2>&1
fi

# Verify tables were created
echo "Verifying Image Recognition tables..." >> $LOG_FILE 2>&1
TABLES=$(mysql -h "$RDS_ENDPOINT" -u "$DB_USERNAME" -p"$DB_PASSWORD" -D "$DB_NAME" -e "SHOW TABLES;" 2>/dev/null | grep -v "Tables_in_")
TABLE_COUNT=$(echo "$TABLES" | wc -l)
echo "Created tables in $DB_NAME:" >> $LOG_FILE 2>&1
echo "$TABLES" >> $LOG_FILE 2>&1
echo "Total tables: $TABLE_COUNT" >> $LOG_FILE 2>&1

if [ "$TABLE_COUNT" -ge 5 ]; then
    echo "✅ Database setup completed successfully!" >> $LOG_FILE 2>&1
    echo "🎯 Ready for image recognition data storage" >> $LOG_FILE 2>&1
else
    echo "⚠️ Warning: Expected at least 5 tables, found $TABLE_COUNT" >> $LOG_FILE 2>&1
fi

# Clean up temporary files
rm -f /tmp/wordpress_setup.sql /tmp/image_recognition_setup.sql

echo "=== Bastion Host Setup Completed ===" >> $LOG_FILE 2>&1
echo "Timestamp: $(date)" >> $LOG_FILE 2>&1
