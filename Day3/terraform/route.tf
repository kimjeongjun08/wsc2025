# Public Route Table
resource "aws_route_table" "apdev_pub_rtb" {
  vpc_id = aws_vpc.apdev_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "apdev-pub-rtb"
  }
}

# Private Route Tables
resource "aws_route_table" "apdev_priv_rtb_a" {
  vpc_id = aws_vpc.apdev_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_a.id
  }

  tags = {
    Name = "apdev-priv-rtb-a"
  }
}

resource "aws_route_table" "apdev_priv_rtb_b" {
  vpc_id = aws_vpc.apdev_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_b.id
  }

  tags = {
    Name = "apdev-priv-rtb-b"
  }
}

# Data Route Table (no internet access)
resource "aws_route_table" "apdev_data_rtb" {
  vpc_id = aws_vpc.apdev_vpc.id

  tags = {
    Name = "apdev-data-rtb"
  }
}

# Route Table Associations
resource "aws_route_table_association" "pub_a" {
  subnet_id      = aws_subnet.apdev_pub_a.id
  route_table_id = aws_route_table.apdev_pub_rtb.id
}

resource "aws_route_table_association" "pub_b" {
  subnet_id      = aws_subnet.apdev_pub_b.id
  route_table_id = aws_route_table.apdev_pub_rtb.id
}

resource "aws_route_table_association" "priv_a" {
  subnet_id      = aws_subnet.apdev_priv_a.id
  route_table_id = aws_route_table.apdev_priv_rtb_a.id
}

resource "aws_route_table_association" "priv_b" {
  subnet_id      = aws_subnet.apdev_priv_b.id
  route_table_id = aws_route_table.apdev_priv_rtb_b.id
}

resource "aws_route_table_association" "data_a" {
  subnet_id      = aws_subnet.apdev_data_a.id
  route_table_id = aws_route_table.apdev_data_rtb.id
}

resource "aws_route_table_association" "data_b" {
  subnet_id      = aws_subnet.apdev_data_b.id
  route_table_id = aws_route_table.apdev_data_rtb.id
}