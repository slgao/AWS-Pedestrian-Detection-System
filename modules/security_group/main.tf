data "http" "my_ip" {
  url = "https://ipinfo.io/ip"
}

resource "aws_security_group" "bastion" {
  name   = "bastion-sg"
  vpc_id = var.vpc_id
  tags = {
    Name = "bastion-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  security_group_id = aws_security_group.bastion.id
  from_port         = 22
  to_port           = 22
  ip_protocol          = "tcp"
  cidr_ipv4         = "${data.http.my_ip.response_body}/32"
}

resource "aws_vpc_security_group_egress_rule" "bastion_all" {
  security_group_id = aws_security_group.bastion.id
  from_port         = 0
  to_port           = 0
  ip_protocol          = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}


resource "aws_security_group" "frontend" {
  name   = "frontend-sg"
  vpc_id = var.vpc_id
  tags = {
    Name = "frontend-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "frontend_http" {
  security_group_id = aws_security_group.frontend.id
  from_port         = 80
  to_port           = 80
  ip_protocol          = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "frontend_react" {
  security_group_id = aws_security_group.frontend.id
  from_port         = 3000
  to_port           = 3000
  ip_protocol          = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "frontend_all" {
  security_group_id = aws_security_group.frontend.id
  from_port         = 0
  to_port           = 0
  ip_protocol          = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}


resource "aws_security_group" "backend" {
  name   = "backend-sg"
  vpc_id = var.vpc_id
  tags = {
    Name = "backend-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "backend_ssh" {
  security_group_id            = aws_security_group.backend.id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                     = "tcp"
  referenced_security_group_id = aws_security_group.bastion.id
}

resource "aws_vpc_security_group_egress_rule" "backend_all" {
  security_group_id = aws_security_group.backend.id
  from_port         = 0
  to_port           = 0
  ip_protocol          = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}


resource "aws_security_group" "alb" {
  name   = "alb-sg"
  vpc_id = var.vpc_id
  tags = {
    Name = "alb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  from_port         = 80
  to_port           = 80
  ip_protocol          = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow traffic from the internet on port 80"
}

resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  from_port         = 0
  to_port           = 0
  ip_protocol          = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}


resource "aws_security_group" "rds" {
  name   = "rds-sg"
  vpc_id = var.vpc_id
  tags = {
    Name = "rds-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_backend" {
  security_group_id            = aws_security_group.rds.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                     = "tcp"
  referenced_security_group_id = aws_security_group.backend.id
}

resource "aws_vpc_security_group_ingress_rule" "rds_frontend" {
  security_group_id            = aws_security_group.rds.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                     = "tcp"
  referenced_security_group_id = aws_security_group.frontend.id
}

resource "aws_vpc_security_group_ingress_rule" "rds_bastion" {
  security_group_id            = aws_security_group.rds.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                     = "tcp"
  referenced_security_group_id = aws_security_group.bastion.id
}

resource "aws_vpc_security_group_egress_rule" "rds_all" {
  security_group_id = aws_security_group.rds.id
  from_port         = 0
  to_port           = 0
  ip_protocol          = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
