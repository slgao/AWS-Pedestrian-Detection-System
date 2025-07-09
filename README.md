# AWS 3-Tier WordPress Application with Image Recognition

This Terraform project deploys a highly available, scalable WordPress application on AWS with integrated image recognition capabilities using AWS Rekognition.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                    AWS Cloud                                    │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────────┐│
│  │                              VPC (10.0.0.0/16)                             ││
│  │                                                                             ││
│  │  ┌─────────────────────────┐    ┌─────────────────────────┐                ││
│  │  │    Availability Zone A  │    │    Availability Zone B  │                ││
│  │  │                         │    │                         │                ││
│  │  │  ┌─────────────────────┐│    │┌─────────────────────┐  │                ││
│  │  │  │   Public Subnet     ││    ││   Public Subnet     │  │                ││
│  │  │  │   (10.0.1.0/24)     ││    ││   (10.0.2.0/24)     │  │                ││
│  │  │  │                     ││    ││                     │  │                ││
│  │  │  │  ┌─────────────────┐││    ││┌─────────────────┐  │  │                ││
│  │  │  │  │  Bastion Host   │││    │││  Auto Scaling   │  │  │                ││
│  │  │  │  │   (EC2)         │││    │││   WordPress     │  │  │                ││
│  │  │  │  └─────────────────┘││    │││   Frontend      │  │  │                ││
│  │  │  └─────────────────────┘│    ││└─────────────────┘  │  │                ││
│  │  │                         │    │└─────────────────────┘  │                ││
│  │  │  ┌─────────────────────┐│    │┌─────────────────────┐  │                ││
│  │  │  │  Private Subnet     ││    ││  Private Subnet     │  │                ││
│  │  │  │  (10.0.3.0/24)      ││    ││  (10.0.4.0/24)      │  │                ││
│  │  │  │                     ││    ││                     │  │                ││
│  │  │  │  ┌─────────────────┐││    ││┌─────────────────┐  │  │                ││
│  │  │  │  │  Backend EC2    │││    │││   RDS MySQL     │  │  │                ││
│  │  │  │  │                 │││    │││   (Multi-AZ)    │  │  │                ││
│  │  │  │  └─────────────────┘││    ││└─────────────────┘  │  │                ││
│  │  │  └─────────────────────┘│    │└─────────────────────┘  │                ││
│  │  └─────────────────────────┘    └─────────────────────────┘                ││
│  │                                                                             ││
│  │  ┌─────────────────────────────────────────────────────────────────────────┐││
│  │  │                    Application Load Balancer                           │││
│  │  └─────────────────────────────────────────────────────────────────────────┘││
│  └─────────────────────────────────────────────────────────────────────────────┘│
│                                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────────────┐ │
│  │   S3 Bucket     │  │   SNS Topic     │  │        Lambda Function          │ │
│  │   (File Storage)│──│   (Notifications)│──│    (Image Recognition)          │ │
│  │                 │  │                 │  │      AWS Rekognition            │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────────────────────┘ │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘

Internet Gateway
       │
   ┌───▼───┐
   │ Users │
   └───────┘
```

## Infrastructure Components

### **Network Layer**
- **VPC**: Custom Virtual Private Cloud (10.0.0.0/16)
- **Public Subnets**: 2 subnets across different AZs for high availability
- **Private Subnets**: 2 subnets for database and backend services
- **Internet Gateway**: Provides internet access to public subnets
- **Route Tables**: Separate routing for public and private traffic

### **Compute Layer**
- **Bastion Host**: Secure access point for administration
- **Auto Scaling Group**: Automatically scales WordPress frontend instances
- **Application Load Balancer**: Distributes traffic across multiple instances
- **Backend EC2**: Private instance for backend processing

### **Database Layer**
- **RDS MySQL 8.0**: Multi-AZ deployment for high availability
- **Private Subnet Deployment**: Database isolated from public internet
- **Automated Backups**: Configured with backup retention

### **Serverless & Storage**
- **S3 Bucket**: File storage with event notifications
- **Lambda Function**: Processes images using AWS Rekognition
- **SNS Topic**: Coordinates events between S3 and Lambda

### **Security**
- **Security Groups**: Layer-specific firewall rules
- **Key Pair Authentication**: SSH access using EC2 key pairs
- **Private Subnet Isolation**: Database and backend in private subnets

## Prerequisites

Before deploying this infrastructure, ensure you have:

1. **AWS CLI configured** with appropriate credentials
2. **Terraform installed** (version 1.0+)
3. **Valid AWS credentials** with necessary permissions
4. **EC2 Key Pair created** in your target region
5. **S3 Bucket created** for file storage

## Deployment Instructions

### 1. Prepare Prerequisites

```bash
# Create EC2 Key Pair
./ec2_create_key_pair.sh

# Create S3 Bucket
./s3_create.sh

# Verify your IP for security group access
echo "$(curl -s ifconfig.me)/32" > my_ip.txt
```

### 2. Configure Variables

Edit `terraform.tfvars` with your specific values:

```hcl
region = "us-west-2"
key_name = "your-key-pair-name"
s3_bucket_name = "your-unique-bucket-name"
db_password = "your-secure-db-password"
wp_password = "your-wordpress-password"
```

### 3. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Plan deployment
./plan.sh
# or: terraform plan -out=plan.out

# Apply configuration
./apply.sh
# or: terraform apply plan.out

# Validate deployment
./validate.sh
```

### 4. Access Your Application

After successful deployment:

1. **WordPress Site**: Access via the ALB DNS name (output: `alb_dns_name`)
2. **Bastion Host**: SSH using the public IP (output: `bastion_public_ip`)
3. **Database**: Connect via RDS endpoint (output: `rds_endpoint`)

## File Structure

```
├── main.tf                 # Main Terraform configuration
├── variables.tf            # Variable definitions
├── outputs.tf             # Output definitions
├── provider.tf            # AWS provider configuration
├── terraform.tfvars       # Variable values (customize this)
├── modules/               # Modular Terraform components
│   ├── vpc/              # VPC configuration
│   ├── subnet/           # Subnet configuration
│   ├── security_group/   # Security group rules
│   ├── ec2_bastion/      # Bastion host configuration
│   ├── ec2_frontend/     # Frontend EC2 configuration
│   ├── ec2_backend/      # Backend EC2 configuration
│   ├── autoscaling/      # Auto Scaling Group
│   ├── load_balancer/    # Application Load Balancer
│   ├── rds/              # RDS MySQL database
│   ├── s3/               # S3 bucket configuration
│   ├── sns/              # SNS topic configuration
│   └── lambda_rekognition/ # Lambda function for image processing
├── scripts/              # Setup and configuration scripts
└── assets/               # Static assets and documentation
```

## Key Features

### **High Availability**
- Multi-AZ deployment across 2 availability zones
- Auto Scaling Group maintains desired capacity
- Application Load Balancer with health checks
- RDS Multi-AZ for database redundancy

### **Security**
- Private subnets for sensitive components
- Security groups with least privilege access
- Bastion host for secure administrative access
- Encrypted RDS storage

### **Scalability**
- Auto Scaling Group responds to traffic demands
- Load balancer distributes traffic efficiently
- Modular Terraform design for easy expansion

### **Image Processing**
- Automatic image analysis using AWS Rekognition
- Event-driven architecture with S3 and Lambda
- SNS notifications for processing status

## Monitoring and Maintenance

### **Accessing Instances**

```bash
# Connect to bastion host
./ec2_connect.sh

# Copy files to bastion
./scp_pem.sh
```

### **Database Management**

```bash
# Connect to RDS from bastion host
mysql -h <rds-endpoint> -u admin -p
```

### **S3 Operations**

```bash
# Upload images for processing
./s3_upload_image.sh
```

## Cost Optimization

This infrastructure uses cost-optimized instance types:
- **EC2 Instances**: t3.micro (eligible for free tier)
- **RDS Instance**: db.t3.micro (eligible for free tier)
- **Load Balancer**: Application Load Balancer (pay per use)
- **Lambda**: Pay per execution
- **S3**: Pay per storage and requests

## Cleanup

To destroy the infrastructure:

```bash
terraform destroy
```

**Warning**: This will permanently delete all resources. Ensure you have backups of any important data.

## Troubleshooting

### Common Issues

1. **Key Pair Not Found**: Ensure the key pair exists in your target region
2. **S3 Bucket Name Conflict**: S3 bucket names must be globally unique
3. **Permission Denied**: Verify AWS credentials have necessary permissions
4. **Resource Limits**: Check AWS service limits in your account

### Support

For issues related to this infrastructure:
1. Check Terraform logs: `terraform apply -debug`
2. Verify AWS credentials: `aws sts get-caller-identity`
3. Check resource limits in AWS console

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

---

**Note**: This infrastructure is designed for development and testing purposes. For production use, consider additional security hardening, monitoring, and backup strategies.
