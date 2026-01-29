data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_region" "current" {}

# 1a. VPC Definition
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "${var.project_name}-vpc" }
}

# 1b. Public Subnet (Used only for the NAT Gateway)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false # Security: no auto-assign public IPs
  tags = { Name = "${var.project_name}-public-subnet" }
}

# 1c. Private Subnets (Lambda and OpenSearch Endpoints reside here)
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 2) # 10.0.2.0/24, 10.0.3.0/24
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = { Name = "${var.project_name}-private-subnet-${count.index}" }
}

# 1d. Internet Gateway, EIP, and NAT Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "${var.project_name}-igw" }
}

resource "aws_eip" "nat" {
  depends_on = [aws_internet_gateway.gw]
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  tags = { Name = "${var.project_name}-nat" }
  depends_on = [aws_internet_gateway.gw]
}

# 1e. Route Tables to direct traffic (Private Route Table uses NAT Gateway)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "${var.project_name}-private-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# 1f. Security Group - tightened for HTTPS only (443 for Bedrock/OpenSearch APIs)
resource "aws_security_group" "sg_lambda_opensearch" {
  name        = "${var.project_name}-sg"
  description = "Security group for Lambda and OpenSearch Serverless"
  vpc_id      = aws_vpc.main.id

  # Ingress: Allow HTTPS from within the VPC (Lambda <-> VPC Endpoints)
  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  # Egress: Allow HTTPS only (Bedrock, OpenSearch, S3 are all HTTPS APIs)
  egress {
    description = "HTTPS outbound for AWS API calls"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-sg" }
}

# =============================================================================
# VPC Endpoints - keep Lambda traffic on AWS backbone (avoids NAT for AWS APIs)
# =============================================================================

# OpenSearch Serverless VPC Endpoint
resource "aws_opensearchserverless_vpc_endpoint" "aoss" {
  name               = "${var.project_name}-aoss-vpce"
  vpc_id             = aws_vpc.main.id
  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.sg_lambda_opensearch.id]
}

# Bedrock Runtime VPC Endpoint (for InvokeModel, RetrieveAndGenerate)
resource "aws_vpc_endpoint" "bedrock_runtime" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.bedrock-runtime"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.sg_lambda_opensearch.id]
  private_dns_enabled = true

  tags = { Name = "${var.project_name}-bedrock-runtime-vpce" }
}

# Bedrock Agent Runtime VPC Endpoint (for Retrieve, RetrieveAndGenerate via KB)
resource "aws_vpc_endpoint" "bedrock_agent_runtime" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.bedrock-agent-runtime"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.sg_lambda_opensearch.id]
  private_dns_enabled = true

  tags = { Name = "${var.project_name}-bedrock-agent-runtime-vpce" }
}

# S3 Gateway Endpoint (free, keeps S3 traffic off NAT)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = { Name = "${var.project_name}-s3-vpce" }
}

# CloudWatch Logs VPC Endpoint (for Lambda logging without NAT)
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.sg_lambda_opensearch.id]
  private_dns_enabled = true

  tags = { Name = "${var.project_name}-logs-vpce" }
}
