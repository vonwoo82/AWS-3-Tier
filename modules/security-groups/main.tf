###############################################################################
# Module: Security Groups
# Four groups: public ALB | web EC2 | private ALB | app EC2 | RDS
###############################################################################

# --- Public ALB (internet-facing) ---
resource "aws_security_group" "public_alb" {
  name        = "${var.project_name}-${var.environment}-public-alb-sg"
  description = "Allow HTTP/HTTPS from the internet to the public ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-${var.environment}-public-alb-sg" }
}

# --- Web EC2 instances ---
resource "aws_security_group" "web" {
  name        = "${var.project_name}-${var.environment}-web-sg"
  description = "Allow traffic from the public ALB only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from public ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.public_alb.id]
  }

  ingress {
    description     = "HTTPS from public ALB"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.public_alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-${var.environment}-web-sg" }
}

# --- Private ALB (internal, web → app) ---
resource "aws_security_group" "private_alb" {
  name        = "${var.project_name}-${var.environment}-private-alb-sg"
  description = "Allow traffic from web tier to the internal ALB"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from web instances"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-${var.environment}-private-alb-sg" }
}

# --- App EC2 instances ---
resource "aws_security_group" "app" {
  name        = "${var.project_name}-${var.environment}-app-sg"
  description = "Allow traffic from the private ALB only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from private ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.private_alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-${var.environment}-app-sg" }
}

# --- RDS (database) ---
resource "aws_security_group" "db" {
  name        = "${var.project_name}-${var.environment}-db-sg"
  description = "Allow MySQL traffic from the app tier only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from app instances"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-${var.environment}-db-sg" }
}
