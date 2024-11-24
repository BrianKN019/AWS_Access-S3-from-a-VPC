# Initialize Terraform Provider
provider "aws" {
  region = "us-east-1" # Change this to your preferred region
}

# Variables for Reusability
variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "subnet_cidr" {
  default = "10.0.1.0/24"
}

variable "instance_type" {
  default = "t2.micro"
}

# Create a VPC
resource "aws_vpc" "main_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "Main_VPC"
  }
}

# Create a Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = var.subnet_cidr
  map_public_ip_on_launch = true
  tags = {
    Name = "Public_Subnet"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    Name = "Internet_Gateway"
  }
}

# Create a Route Table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Public_Route_Table"
  }
}

# Associate the Route Table with the Subnet
resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# Security Group for EC2 Instance
resource "aws_security_group" "ec2_security_group" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allows SSH from anywhere, adjust as needed
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allows HTTP traffic
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allows all outbound traffic
  }

  tags = {
    Name = "EC2_Security_Group"
  }
}

# Create a Key Pair for EC2
resource "aws_key_pair" "main_key" {
  key_name   = "my-key-pair"
  public_key = file("~/.ssh/id_rsa.pub") # Replace with the path to your public key
}

# Launch an EC2 Instance
resource "aws_instance" "web_server" {
  ami           = "ami-0c02fb55956c7d316" # Replace with an appropriate AMI for your region
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public_subnet.id
  key_name      = aws_key_pair.main_key.key_name

  security_group = [aws_security_group.ec2_security_group.id]

  tags = {
    Name = "Web_Server"
  }
}

# Create an S3 Bucket for Static Hosting
resource "aws_s3_bucket" "static_site" {
  bucket = "my-static-site-${random_id.bucket.hex}" # Ensures unique bucket name
  acl    = "public-read"

  website {
    index_document = "index.html"
    error_document = "error.html"
  }

  tags = {
    Name = "Static_Site_Bucket"
  }
}

resource "aws_s3_bucket_object" "index_html" {
  bucket = aws_s3_bucket.static_site.id
  key    = "index.html"
  source = "index.html" # Replace with the path to your local HTML file
  acl    = "public-read"
}

# Outputs for Easy Access
output "vpc_id" {
  value = aws_vpc.main_vpc.id
}

output "public_instance_ip" {
  value = aws_instance.web_server.public_ip
}

output "s3_bucket_website_url" {
  value = aws_s3_bucket.static_site.website_endpoint
}
