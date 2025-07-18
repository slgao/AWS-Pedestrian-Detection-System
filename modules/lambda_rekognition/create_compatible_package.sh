#!/bin/bash

# Create Lambda package with Linux compatibility from macOS
set -e

echo "📦 Creating Lambda package with Linux compatibility..."

cd "$(dirname "$0")"

# Clean up
rm -rf package lambda_function.zip

# Create package directory
mkdir package

# Copy Lambda function
echo "📄 Copying Lambda function..."
cp lambda_function.py package/

echo "🐧 Installing dependencies for Linux platform..."

# Install pymysql (pure Python, no binary dependencies)
echo "Installing pymysql..."
pip3 install pymysql==1.1.0 -t package/ --no-deps

# For cryptography, try multiple approaches
echo "Installing cryptography with platform targeting..."

# Method 1: Try manylinux2014 (most compatible)
if pip3 install cryptography==41.0.7 \
  --platform manylinux2014_x86_64 \
  --target package/ \
  --implementation cp \
  --python-version 3.10 \
  --only-binary=:all: \
  --no-deps 2>/dev/null; then
    echo "✅ Cryptography installed with manylinux2014"
    CRYPTO_SUCCESS=true
# Method 2: Try manylinux1
elif pip3 install cryptography==41.0.7 \
  --platform manylinux1_x86_64 \
  --target package/ \
  --implementation cp \
  --python-version 3.10 \
  --only-binary=:all: \
  --no-deps 2>/dev/null; then
    echo "✅ Cryptography installed with manylinux1"
    CRYPTO_SUCCESS=true
# Method 3: Try without version specification
elif pip3 install cryptography \
  --platform manylinux2014_x86_64 \
  --target package/ \
  --implementation cp \
  --python-version 3.10 \
  --only-binary=:all: \
  --no-deps 2>/dev/null; then
    echo "✅ Cryptography installed (latest version)"
    CRYPTO_SUCCESS=true
else
    echo "⚠️  Could not install cryptography with platform-specific flags"
    echo "Installing without platform specification (may work in Lambda)..."
    pip3 install cryptography -t package/ --no-deps || echo "❌ Cryptography installation failed"
    CRYPTO_SUCCESS=false
fi

# Install cffi if cryptography was successful
if [ "$CRYPTO_SUCCESS" = true ]; then
    echo "Installing cffi dependency..."
    pip3 install cffi \
      --platform manylinux2014_x86_64 \
      --target package/ \
      --implementation cp \
      --python-version 3.10 \
      --only-binary=:all: \
      --no-deps 2>/dev/null || echo "⚠️  cffi installation failed"
fi

# Create zip
echo "🗜️  Creating zip package..."
cd package
zip -r ../lambda_function.zip .
cd ..

# Clean up
rm -rf package

echo "✅ Lambda package created!"
echo "📊 Package size: $(ls -lh lambda_function.zip | awk '{print $5}')"

# Verify contents
echo "📋 Package contents:"
unzip -l lambda_function.zip | head -15

echo ""
echo "🎯 Next steps:"
echo "1. Run: terraform apply"
echo "2. The Lambda function will use this package"

if [ "$CRYPTO_SUCCESS" != true ]; then
    echo ""
    echo "⚠️  WARNING: Cryptography may not be Linux-compatible"
    echo "If Lambda fails, try the Docker approach instead"
fi
