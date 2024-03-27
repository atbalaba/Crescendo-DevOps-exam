resource "aws_subnet" "private_subnet_1" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-southeast-1a"
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-southeast-1b"
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "ap-southeast-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "ap-southeast-1b"
  map_public_ip_on_launch = true
}

resource "aws_security_group" "ec2_sec_group" {
  name = "Allow vital ports"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Accessible in public
  }
  
  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "public_subnet_1" {
  value = aws_subnet.public_subnet_1
}
