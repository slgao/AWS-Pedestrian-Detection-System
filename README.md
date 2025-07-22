# N-Tier Pedestrian Detection System - AWS Cloud-Native Application

![AWS Cloud Native](https://img.shields.io/badge/AWS-Cloud%20Native-orange)
![Status](https://img.shields.io/badge/Status-Production-green)
![License](https://img.shields.io/badge/License-MIT-blue)

A highly available, scalable cloud-native application that detects pedestrians and faces in images using AWS services including S3, SNS, Lambda, RDS, EC2, and Rekognition.

![Architecture Diagram](./assets/N-Tier_Architecture.drawio.svg)

## 🌟 Features

- **Real-time pedestrian and face detection** using AWS Rekognition
- **Lightweight HTML/CSS/JS frontend** with drag-and-drop image upload
- **Python Flask API backend** for S3 integration and image processing
- **Intelligent people counting** that includes both body detections and faces
- **Visual bounding box display** with confidence scores
- **Automatic image processing** with real-time status updates
- **Highly available architecture** across multiple availability zones
- **Secure bastion host** for administrative access
- **Event-driven processing** using SNS for decoupled architecture

## 🏗️ Architecture

The application follows a modern N-Tier architecture with event-driven processing:

### Frontend Layer (Presentation Tier)
- Lightweight HTML/CSS/JavaScript interface hosted on EC2 instances
- Drag-and-drop image upload functionality
- Real-time image gallery with processing status indicators
- Visual bounding box display for detected people and faces
- Auto-scaling group across multiple availability zones for high availability
- Application Load Balancer for traffic distribution

### API Layer (Application Tier)
- Python Flask API for backend processing
- RESTful endpoints for image upload and retrieval
- Integration with AWS S3 for image storage
- Nginx proxy for routing requests
- Presigned URL generation for secure image access

### Content Delivery Layer (HTTPS Security)
- CloudFront distribution provides secure HTTPS access
- Uses CloudFront's default SSL certificate (no custom domain required)
- Redirects HTTP requests to HTTPS automatically
- Global content delivery with edge location caching
- Built-in DDoS protection with AWS Shield Standard

### Processing Layer (Event-Driven Tier)
- Amazon S3 event notifications trigger SNS topics
- SNS topic acts as a publisher for the event-driven architecture
- AWS Lambda functions subscribe to SNS topics
- Lambda integrates with AWS Rekognition for image analysis
- Decoupled processing ensures scalability and fault tolerance

### Data Layer (Persistence Tier)
- Amazon RDS MySQL database for storing detection results
- Multi-AZ deployment for high availability
- Tables for images, detections, faces, and processing logs
- Amazon S3 for durable image storage with lifecycle policies

## 🔄 System Workflow

1. **Image Upload**: User uploads an image through the frontend interface (via HTTPS)
2. **Storage**: Frontend API stores the image in an S3 bucket
3. **Event Notification**: S3 triggers an event notification to an SNS topic
4. **Processing**: Lambda function subscribed to the SNS topic processes the image
5. **Image Analysis**: Lambda uses AWS Rekognition to detect people and faces
6. **Data Storage**: Detection results are stored in the RDS database
7. **Status Update**: Frontend periodically checks for processing status
8. **Visualization**: Processed images are displayed with bounding boxes and detection data

## 💪 Advantages of This Architecture

### Scalability
- **Decoupled Components**: Each tier can scale independently based on demand
- **Serverless Processing**: Lambda functions automatically scale with the number of image uploads
- **Auto-scaling Frontend**: EC2 instances in an Auto Scaling Group adjust to user traffic
- **Elastic Database**: RDS can be scaled vertically or with read replicas for higher throughput

### Reliability
- **Multi-AZ Deployment**: Components deployed across multiple availability zones
- **Event-Driven Design**: SNS ensures messages are delivered at least once
- **Asynchronous Processing**: Frontend doesn't wait for image processing to complete
- **Smart Refresh System**: Frontend intelligently polls for updates without overwhelming the backend

### Performance
- **Lightweight Frontend**: Vanilla HTML/CSS/JS minimizes resource usage
- **Optimized Image Processing**: Lambda functions process images in parallel
- **Efficient Data Storage**: Only relevant detection data is stored in the database
- **Content Delivery**: Images served via presigned URLs for secure, fast access

### Security
- **Private Subnets**: RDS and application components in private subnets
- **Bastion Host**: Secure administrative access to the environment
- **IAM Roles**: Least privilege access for all components
- **Presigned URLs**: Temporary, secure access to S3 objects
- **Security Groups**: Tight network controls between components

### Cost Efficiency
- **Pay-per-use Lambda**: Only pay for actual image processing time
- **Auto-scaling**: Resources scale down during low demand periods
- **S3 Lifecycle Policies**: Automatically manage storage costs for older images
- **Spot Instances**: Option to use spot instances for cost savings in non-critical components

### Maintainability
- **Infrastructure as Code**: Entire environment defined in Terraform
- **Modular Design**: Components can be updated independently
- **Centralized Logging**: CloudWatch logs for all components
- **Monitoring**: Built-in health checks and performance metrics

## 🚀 Deployment Instructions for AWS Sandbox Environment

### Prerequisites

- AWS account with appropriate permissions
- AWS CLI installed and configured
- Terraform installed (v1.0+)
- Git installed

### Sandbox Lab Environment IAM Configuration

This project is configured specifically for AWS Sandbox Lab environments:

- The Lambda function uses the existing **'LabRole'** IAM role, which has the necessary permissions for S3, Rekognition, and RDS access
- Frontend EC2 instances have the **'LabInstanceProfile'** attached, allowing them to access the S3 bucket for image uploads
- No additional IAM roles or policies need to be created, simplifying deployment in the lab environment

### Important S3 Bucket Configuration

In AWS Sandbox Lab environments:

- The S3 bucket must be created manually **before** running Terraform
- Terraform code references this pre-existing S3 bucket rather than creating it
- This approach is necessary because the lab environment has disabled object lock functionality
- If Terraform attempts to create the S3 bucket resource directly, it will check for object lock capabilities and throw an error
- Manual bucket creation bypasses this check and allows the deployment to proceed successfully

### Step 1: Clone the Repository

```bash
git clone https://github.com/yourusername/n-tier-detection-system.git
cd n-tier-detection-system
```

### Step 2: Create EC2 Key Pair

```bash
# Create a key pair for EC2 instances
aws ec2 create-key-pair --key-name detection-system-key --query 'KeyMaterial' --output text > detection-system-key.pem
chmod 400 detection-system-key.pem
```

### Step 3: Create S3 Bucket for Image Storage

```bash
# Create a unique S3 bucket for image storage
aws s3 mb s3://detection-system-images-$(date +%s)
```

### Step 4: Prepare Lambda Function Package

The Lambda function requires a deployment package with all necessary dependencies. Use the provided script to create it:

```bash
# Navigate to the Lambda function directory
cd modules/lambda_rekognition

# Make the script executable
chmod +x create_compatible_package.sh

# Run the script to create the Lambda deployment package
./create_compatible_package.sh

# Return to the project root directory
cd ../..
```

This script will:
- Install required dependencies with Linux compatibility
- Package everything into a zip file ready for Lambda deployment
- Handle platform-specific requirements for cryptography libraries
- Verify the package contents

### Step 5: Configure Terraform Variables

Create a `terraform.tfvars` file with your specific values:

```hcl
region = "us-west-2"
key_name = "detection-system-key"
s3_bucket_name = "detection-system-images-1234567890"  # Use your bucket name
db_password = "YourSecurePassword123!"
```

### Step 5: Deploy the application

```bash
# Run the deployment bash script
./deploy.sh
```

### Step 6: Access the Application

After successful deployment, you can access the application using two URLs:

```bash
# Get the ALB DNS name (HTTP)
terraform output alb_dns_name

# Get the CloudFront HTTPS URL
terraform output cloudfront_https_url
```

Open the CloudFront HTTPS URL in your web browser to access the N-Tier Detection System securely.

**Note**: CloudFront distribution deployment may take 15-30 minutes to complete. During this time, the HTTPS URL may not be immediately available.

## 🔧 Using the Application

### Uploading Images

1. Navigate to the application's main page
2. Drag and drop images onto the upload area or click to select files
3. Click "Upload" to start the upload process
4. The system will automatically process the images and display results

### Viewing Detection Results

1. Navigate to the "Recent Uploads" section
2. Click on any image to view detailed detection results
3. Hover over detected faces to see additional information
4. The system displays:
   - Total people count (including faces without visible bodies)
   - Bounding boxes around detected people and faces
   - Confidence scores for each detection
   - Age range and gender estimates for detected faces

### Administrative Access

To access the system via the bastion host:

```bash
# Connect to bastion host
ssh -i detection-system-key.pem ec2-user@<bastion-public-ip>

# From bastion, connect to frontend instances
ssh -i ~/.ssh/id_rsa ec2-user@<frontend-private-ip>
```

## 🔍 Technical Details

### Frontend Implementation

The frontend is built with vanilla HTML, CSS, and JavaScript for optimal performance:

- **Drag-and-drop upload** using the HTML5 File API
- **Real-time status updates** with smart refresh system
- **Responsive design** for mobile and desktop
- **Bounding box visualization** with hover effects
- **Modal view** for detailed image analysis
- **Special highlighting** for faces detected outside person bounding boxes

### Backend Implementation

The backend uses Python Flask with the following components:

- **RESTful API endpoints** for image operations
- **S3 integration** for secure image storage
- **Database connection pooling** for efficient RDS access
- **Presigned URL generation** for secure image retrieval
- **Health check endpoints** for load balancer integration
- **Nginx proxy** for routing and load balancing

### Lambda Processing

The Lambda function performs the following tasks:

- **Image retrieval** from S3 upon SNS notification
- **Rekognition API calls** for detecting people and faces
- **Metadata extraction** including confidence scores and attributes
- **Database updates** with detection results
- **Error handling** with automatic retries for transient failures
- **CloudWatch logging** for monitoring and debugging

### Database Schema

The database includes the following tables:

- `images`: Stores metadata about uploaded images
- `image_labels`: Stores labels detected in images
- `person_detections`: Stores information about detected persons
- `face_detections`: Stores information about detected faces
- `emotion_detections`: Stores emotional analysis data from detected faces
- `processing_logs`: Stores logs of the processing pipeline

## 🛠️ Maintenance and Troubleshooting

### Common Issues

#### Image Processing Fails

If image processing fails, check:
- S3 bucket permissions
- Lambda function logs
- SNS topic delivery status
- RDS database connectivity

#### Frontend Not Loading

If the frontend doesn't load, check:
- ALB health checks
- EC2 instance status
- Nginx configuration
- Security group rules

### Monitoring

The system can be monitored using:
- CloudWatch metrics for EC2, RDS, Lambda, and SNS
- CloudWatch Logs for application logs
- RDS Performance Insights for database performance
- S3 access logs for storage activity

## 📊 Performance Considerations

- The system is designed to handle images up to 5MB in size
- Processing time depends on image complexity and size
- The auto-scaling group adjusts capacity based on demand
- Lambda concurrency limits may need adjustment for high-volume scenarios
- Database performance may degrade with very large datasets

## 🔒 Security Considerations

- All S3 buckets are configured with appropriate access policies
- RDS database is deployed in private subnets
- EC2 instances use security groups with least privilege
- HTTPS is enforced for all communications
- Bastion host provides secure administrative access
- IAM roles follow the principle of least privilege
- Sensitive data is never exposed in logs or responses

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 💾 Backup Recommendations

The current system doesn't include backup solutions. Here are simple recommendations for future implementation:

### RDS Database Backups
- Enable automated daily backups with 7-day retention
- Create weekly manual snapshots for longer-term storage
- Consider cross-region snapshot copying for disaster recovery

### S3 Bucket Backups
- Enable bucket versioning to protect against accidental deletions
- Set up cross-region replication to a secondary region
- Implement lifecycle policies to manage storage costs

### AWS Backup Integration
- Use AWS Backup for centralized backup management
- Create a simple backup plan with daily and monthly schedules
- Include both RDS and S3 resources in the backup plan

These backup solutions will improve system resilience and provide recovery options in case of data loss.

## 🙏 Acknowledgments

- AWS for providing the cloud infrastructure
- The Terraform community for infrastructure as code tools
- The Flask community for the Python web framework
- The AWS Rekognition team for the image analysis capabilities

---

**Note**: This project was developed as part of the AWS Cloud Computing Bootcamp at neuefische GmbH.
