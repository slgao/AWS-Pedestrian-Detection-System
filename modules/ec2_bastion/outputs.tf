output "public_ip" {
  value = aws_instance.bastion.public_ip
}

output "ami" {
  value = data.aws_ami.amazon_linux_2.id
}
