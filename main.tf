# Configure the AWS provider to use the "us-west-2" region for resource provisioning.

provider "aws" {
  region = "us-west-2"
}

# Create a new AWS VPC with a /16 CIDR block, providing up to 65,536 IP addresses.
# The VPC is tagged with "Name = MainVPC" for easy identification in AWS.

resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "MainVPC"
  }
}

# Internet Gateway to allow internet access
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "MainInternetGateway"
  }
}

# Public Subnet 1
resource "aws_subnet" "public_subnet1" {
  vpc_id                  = aws_vpc.main_vpc.id
  availability_zone = "us-west-2a"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true  # Automatically assign public IPs to instances

  tags = {
    Name = "PublicSubnet1"
  }
}

# Public Subnet 2
resource "aws_subnet" "public_subnet2" {
  vpc_id                  = aws_vpc.main_vpc.id
  availability_zone = "us-west-2b"
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true  # Automatically assign public IPs to instances

  tags = {
    Name = "PublicSubnet2"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name = "PublicRouteTable"
  }
}

# Associate Public Subnet 1 with the Route Table
resource "aws_route_table_association" "public_association1" {
  subnet_id      = aws_subnet.public_subnet1.id
  route_table_id = aws_route_table.public_route_table.id
}

# Associate Public Subnet 2 with the Route Table
resource "aws_route_table_association" "public_association2" {
  subnet_id      = aws_subnet.public_subnet2.id
  route_table_id = aws_route_table.public_route_table.id
}



# Launch an EC2 instance for the web server using the Amazon Linux 2 AMI.
# It is deployed in the public subnet1 to allow external access, with the "Name" tag set to "WebServer".

resource "aws_instance" "web_server" {
  ami           = "ami-07c5ecd8498c59db5"  # Amazon Linux 2 AMI
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet1.id # replaced "aws_subnet.public_subnet.id" WITH "aws_subnet.public_subnet1.id"

  tags = {
    Name = "WebServer"
  }
}

# Create a subnet group for the RDS database, specifying the subnets for deployment.
# - Named "main_db_subnet_group" to group subnets designated for the database.
# - Uses multiple subnets for high availability across different availability zones.

resource "aws_db_subnet_group" "main" {
  name       = "main_db_subnet_group"
  subnet_ids = [aws_subnet.public_subnet1.id, aws_subnet.public_subnet2.id]  # Reference your subnets

  # Tags: Label the subnet group with "Name = MainDBSubnetGroup" for easy identification.

  tags = {
    Name = "MainDBSubnetGroup"
  }
}



# Create an RDS database instance with MySQL engine.
# - Allocates 20 GB of storage for the database.
# - Uses MySQL engine version 5.7, suitable for applications needing this specific version.
# - Runs on instance type "db.t2.micro" for low-cost, small-scale use.
# - Database name is set to "mydb," with "admin" as the username and a defined password.
# - Links to the "db_sg" security group for controlled network access.
# - Associates with the "main" DB subnet group to ensure availability across selected subnets.

resource "aws_db_instance" "database" {
  allocated_storage      = 20
  engine                 = "mysql"  # or other DB engine type
  engine_version         = "5.7"
  instance_class         = "db.t3.micro" # switched db.t2.micro to db.t3.micro
  identifier             = "mydb" # REPLACED name WITH identifier
  skip_final_snapshot    = true
  username               = "admin"
  password               = "password123"
  vpc_security_group_ids = [aws_security_group.db_sg.id]  # Link to db_sg security group
  db_subnet_group_name   = aws_db_subnet_group.main.name  # Link to main DB subnet group

  # Tags: Label the database instance with "Name = MyDatabase" for easy identification.

  tags = {
    Name = "MyDatabase"
  }
}


# Create an S3 bucket for application storage with private access.
# - Sets the bucket name to "my-app-bucket-cloudit" (must be globally unique).
# - Configures access control as "private" to restrict access.

# S3 Bucket Resource (unchanged except acl line removed)
resource "aws_s3_bucket" "app_bucket" {
  bucket = "my-app-bucket-cloudit"
  # Remove the acl line here
}

# S3 Bucket Policy - Define the access policy for the bucket
resource "aws_s3_bucket_policy" "app_bucket_policy" {
  bucket = aws_s3_bucket.app_bucket.bucket

  # Example policy to allow public read access (adjust as needed)
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowPublicRead"
        Effect    = "Allow"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.app_bucket.arn}/*"
        Principal = "*"
      }
    ]
  })
}


# Create a security group for the database, allowing controlled access.
# - Named "db_security_group" with a description "Allow database access."
# - Assigned to the specified VPC for network isolation.

resource "aws_security_group" "db_sg" {
  name        = "db_security_group"
  description = "Allow database access"
  vpc_id      = aws_vpc.main_vpc.id  # Reference the VPC created above

  # Ingress rules: Define inbound traffic permissions.
  # - Allows MySQL traffic (port 3306) from all IPs (0.0.0.0/0). 
  # - Note: For security, restrict access to trusted IPs as needed.

  ingress {
    from_port   = 3306  # Change to the port your DB uses (3306 for MySQL)
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Limit access as needed, e.g., to specific IPs
  }

  # Egress rules: Define outbound traffic permissions.
  # - Allows all outbound traffic to any destination.

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Tags: Label the security group with "Name = DBSecurityGroup" for easy identification.

  tags = {
    Name = "DBSecurityGroup"
  }
}


