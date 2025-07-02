aws ec2 create-key-pair \
    --key-name labsuser \
    --key-type rsa \
    --key-format pem \
    --query "KeyMaterial" \
    --output text > labsuser.pem
