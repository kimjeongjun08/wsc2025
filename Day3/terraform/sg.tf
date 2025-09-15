# Bastion Security Group
resource "aws_security_group" "apdev_bastion_sg" {
  name   = "apdev-bastion-sg"
  vpc_id = aws_vpc.apdev_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "apdev-bastion-sg"
  }
}

# RDS Instance Security Group
resource "aws_security_group" "apdev_rds_instance_sg" {
  name   = "apdev-rds-instance-sg"
  vpc_id = aws_vpc.apdev_vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "apdev-rds-instance-sg"
  }
}

# App Security Group
resource "aws_security_group" "apdev_app_sg" {
  name   = "apdev-app-sg"
  vpc_id = aws_vpc.apdev_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "apdev-app-sg"
  }
}