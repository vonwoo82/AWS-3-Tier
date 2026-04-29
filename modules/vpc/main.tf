###############################################################################
# Module: VPC
# Creates: VPC, 3 subnet tiers (public/app/db) × N AZs, IGW, NAT GWs,
#          route tables, and a VPC flow-log CloudWatch log group.
###############################################################################

###############################################################################
# VPC
###############################################################################

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.project_name}-${var.environment}-vpc" }
}

###############################################################################
# Internet Gateway
###############################################################################

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-${var.environment}-igw" }
}

###############################################################################
# Subnets — one per AZ per tier
###############################################################################

# Public (Web ALB + Bastion)
resource "aws_subnet" "public" {
  count = var.az_count

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-${var.environment}-public-${var.availability_zones[count.index]}"
    Tier = "Public"
  }
}

# Private App
resource "aws_subnet" "private_app" {
  count = var.az_count

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-${var.environment}-app-${var.availability_zones[count.index]}"
    Tier = "App"
  }
}

# Private DB
resource "aws_subnet" "private_db" {
  count = var.az_count

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 20)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-${var.environment}-db-${var.availability_zones[count.index]}"
    Tier = "Database"
  }
}

###############################################################################
# Elastic IPs + NAT Gateways (one per AZ for HA)
###############################################################################

resource "aws_eip" "nat" {
  count  = var.az_count
  domain = "vpc"
  tags   = { Name = "${var.project_name}-${var.environment}-nat-eip-${count.index + 1}" }
}

resource "aws_nat_gateway" "main" {
  count = var.az_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = { Name = "${var.project_name}-${var.environment}-nat-${count.index + 1}" }

  depends_on = [aws_internet_gateway.main]
}

###############################################################################
# Route Tables
###############################################################################

# Public route table — shared across all public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${var.project_name}-${var.environment}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private route tables — one per AZ (each pointing to its own NAT GW)
resource "aws_route_table" "private_app" {
  count  = var.az_count
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = { Name = "${var.project_name}-${var.environment}-app-rt-${count.index + 1}" }
}

resource "aws_route_table_association" "private_app" {
  count          = var.az_count
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app[count.index].id
}

resource "aws_route_table" "private_db" {
  count  = var.az_count
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = { Name = "${var.project_name}-${var.environment}-db-rt-${count.index + 1}" }
}

resource "aws_route_table_association" "private_db" {
  count          = var.az_count
  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private_db[count.index].id
}

###############################################################################
# VPC Flow Logs
###############################################################################

resource "aws_cloudwatch_log_group" "flow_log" {
  name              = "/aws/vpc/${var.project_name}-${var.environment}/flow-logs"
  retention_in_days = 30
}

resource "aws_iam_role" "flow_log" {
  name = "${var.project_name}-${var.environment}-vpc-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "flow_log" {
  name = "vpc-flow-log-policy"
  role = aws_iam_role.flow_log.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_flow_log" "main" {
  iam_role_arn    = aws_iam_role.flow_log.arn
  log_destination = aws_cloudwatch_log_group.flow_log.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = { Name = "${var.project_name}-${var.environment}-flow-log" }
}

###############################################################################
# RDS Subnet Group (created here so the DB module stays thin)
###############################################################################

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = aws_subnet.private_db[*].id
  tags       = { Name = "${var.project_name}-${var.environment}-db-subnet-group" }
}
