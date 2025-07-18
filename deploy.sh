#!/bin/bash

# Automated Deployment Script for Lambda + SNS Architecture
# This script deploys the complete serverless image recognition system

set -e

echo "🚀 Starting N-Tier Architecture Pedestrian Detection System Deployment..."
echo "Timestamp: $(date)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check prerequisites
print_status "Checking prerequisites..."

if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed."
    exit 1
fi
print_success "Terraform is installed"

if [ ! -f "terraform.tfvars" ]; then
    print_error "terraform.tfvars not found. Please create it from terraform.tfvars.example"
    exit 1
fi
print_success "terraform.tfvars found"

# Initialize and deploy
print_status "Initializing Terraform..."
terraform init

print_status "Validating configuration..."
terraform validate

print_status "Creating execution plan..."
terraform plan -out=lambda-deployment.tfplan

print_status "Applying configuration (this may take 10-15 minutes)..."
terraform apply lambda-deployment.tfplan

# Get outputs
ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "Not available")

echo ""
echo "🎉 DEPLOYMENT COMPLETED!"
echo "🌐 Application URL: http://$ALB_DNS"
echo "⚡ Architecture: Upload → S3 → SNS → Lambda → Rekognition → RDS"
echo ""
print_success "Ready for testing! 🚀"
