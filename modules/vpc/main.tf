resource "aws_vpc" "main" {
  cidr_block = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
    Name = "myapp VPC"
  }
}

resource "aws_subnet" "public_subnets" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.public_subnet_cidrs, count.index)
  availability_zone = element(var.azs, count.index)
  enable_resource_name_dns_a_record_on_launch = true
  tags = {
    Name = "Public Subnet ${count.index + 1}"
  }
}

resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.private_subnet_cidrs, count.index)
  availability_zone = element(var.azs, count.index)
  enable_resource_name_dns_a_record_on_launch = true
  tags = {
    Name = "Private Subnet ${count.index + 1}"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "myapp VPC IG"
  }
}

resource "aws_route_table" "internet_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  route {
    cidr_block = "192.168.248.0/21"
    vpc_peering_connection_id  = "pcx-034d240b92619cca3"
  }

  tags = {
    Name = "Internet Route Table"
  }
}

resource "aws_route_table_association" "public_subnet_asso" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
  route_table_id = aws_route_table.internet_rt.id
}

resource "aws_eip" "nat_gateway" {
  vpc = true
  tags = {
    Name = "myapp NAT"
  }
}

resource "aws_nat_gateway" "nat_gateway" {
  subnet_id     = aws_subnet.public_subnets[1].id
  allocation_id = aws_eip.nat_gateway.id
  tags = {
    Name = "myapp NAT"
  }
  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.gw]
}

output "nat_gateway_ip" {
  value = aws_eip.nat_gateway.public_ip
}

resource "aws_route_table" "nat_gateway" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
  route {
    cidr_block = "192.168.248.0/21"
    vpc_peering_connection_id = "pcx-034d240b92619cca3"
  }
  tags = {
    Name = "Intranet Route Table"
  }
}

resource "aws_route_table_association" "nat_gateway" {
       count          = length(var.private_subnet_cidrs)
     subnet_id      =         element(aws_subnet.private_subnets[*].id, count.index)

     
  route_table_id = aws_route_table.nat_gateway.id
}