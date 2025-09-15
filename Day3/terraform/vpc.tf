# VPC
resource "aws_vpc" "apdev_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "apdev-vpc"
  }
}

# Public Subnets
resource "aws_subnet" "apdev_pub_a" {
  vpc_id                  = aws_vpc.apdev_vpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "apdev-pub-a"
  }
}

resource "aws_subnet" "apdev_pub_b" {
  vpc_id                  = aws_vpc.apdev_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "apdev-pub-b"
  }
}

# Private Subnets
resource "aws_subnet" "apdev_priv_a" {
  vpc_id            = aws_vpc.apdev_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "apdev-priv-a"
  }
}

resource "aws_subnet" "apdev_priv_b" {
  vpc_id            = aws_vpc.apdev_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "apdev-priv-b"
  }
}

# Data Subnets
resource "aws_subnet" "apdev_data_a" {
  vpc_id            = aws_vpc.apdev_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "apdev-data-a"
  }
}

resource "aws_subnet" "apdev_data_b" {
  vpc_id            = aws_vpc.apdev_vpc.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "apdev-data-b"
  }
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.apdev_vpc.id

  tags = {
    Name = "apdev-igw"
  }
}

resource "aws_eip" "nat_a" {
  tags = { Name = "nat-eip-a" }
}

resource "aws_eip" "nat_b" {
  tags = { Name = "nat-eip-b" }
}

resource "aws_nat_gateway" "nat_a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.apdev_pub_a.id
  tags          = { Name = "apdev-nat-gw-a" }
}

resource "aws_nat_gateway" "nat_b" {
  allocation_id = aws_eip.nat_b.id
  subnet_id     = aws_subnet.apdev_pub_b.id
  tags          = { Name = "apdev-nat-gw-b" }
}