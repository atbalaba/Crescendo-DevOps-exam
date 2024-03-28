provider "aws" {
  region = "ap-southeast-1"
}

# VPC Provisioning
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Private Subnets
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-southeast-1a"
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-southeast-1b"
}

# Public Subnets
resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-southeast-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "ap-southeast-1b"
  map_public_ip_on_launch = true
}

# NAT Gateway
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

# Internet Gateway
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.main.id
}

# General Security Group
resource "aws_security_group" "ec2_sec_group" {
  name        = "Allow vital ports"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Accessible in public
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# CloudFront distrib
resource "aws_cloudfront_distribution" "cf_dist" {
  origin {
    domain_name = aws_alb.load_balancer.dns_name
    origin_id = "test-alb-origin"

    custom_origin_config {
      http_port = 80
      https_port = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols = [ "TLSv1", "TLSv1.1", "TLSv1.2" ]
    }
  }

  enabled = true
  is_ipv6_enabled = true 
  default_root_object = "index.html"

  default_cache_behavior {
    target_origin_id = "test-alb-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods = ["GET", "HEAD", "OPTIONS"]
    
    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl = 0
    default_ttl = 3600
    max_ttl = 86400
  }

  price_class = "PriceClass_All"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# Application Load Balancer
resource "aws_alb" "load_balancer" {
  name                        = "test-load-balancer"
  internal                    = false
  load_balancer_type          = "application"
  security_groups             = [aws_security_group.ec2_sec_group.id]
  subnets                     = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
  enable_deletion_protection = false

  tags = {
    Name = "test-load-balancer"
  }
}

# EC2 Instance Provisioning
resource "aws_instance" "ec2_instance" {
  ami             = "ami-06c4be2792f419b7b" #Ubuntu Server 22.04 LTS
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.private_subnet_1.id
  security_groups = [aws_security_group.ec2_sec_group.name]
  tags = {
    Name = "test_instance"
  }
  user_data = <<-EOF
  #!/bin/bash

  sudo apt-get update && sudo apt-get upgrade -y
  sudo apt-get install -y nginx
  systemctl start nginx
  systemctl enable nginx

  sudo apt-get install -y openjdk-8-jdk
  sudo apt-get install -y wget
  cd /tmp
  sudo wget https://downloads.apache.org/tomcat/tomcat-10/v10.1.20/bin/apache-tomcat-10.1.20-src.tar.gz
  sudo tar xzf apache-tomcat-10.1.20.tar.gz -C /opt
  sudo ln -s /opt/apache-tomcat-10.1.20 /opt/tomcat

  sudo groupadd tomcat
  sudo useradd -s /bin/false -g tomcat -d /opt/tomcat tomcat
  sudo chown -R tomcat:tomcat /opt/tomcat
  sudo chmod -R 755 /opt/tomcat/bin

  cat <<EOT > /etc/systemd/system/tomcat.service
  [Unit]
    Description=Tomcat 10 servlet container
    After=network.target
  [Service]
    Type=forking
    User=tomcat
    Group=tomcat
    Environment="JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk"
    Environment="JAVA_OPTS=-Djava.security.egd=file:///dev/urandom"
    Environment="CATALINA_BASE=/opt/tomcat"
    Environment="CATALINA_HOME=/opt/tomcat"
    Environment="CATALINA_PID=/opt/tomcat/temp/tomcat.pid"
    ExecStart=/opt/tomcat/bin/startup.sh
    ExecStop=/opt/tomcat/bin/shutdown.sh
  [Install]
    WantedBy=multi-user.target
  EOT

  sudo systemctl daemon-reload
  sudo systemctl enable tomcat
  sudo systemctl start tomcat
  EOF
}

# Magnolia Instance Provisioning
resource "aws_instance" "magnolia_instance" {
  ami             = "ami-06c4be2792f419b7b"
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.private_subnet_1.id
  security_groups = [aws_security_group.ec2_sec_group.name]
  tags = {
    Name = "test_instance"
  }
  user_data = <<-EOF
  #!/bin/bash
  sudo apt update
  sudo apt install -y default-jdk nginx unzip

  mkdir /magnolia && cd /magnolia
  wget https://nexus.magnolia-cms.com/repository/public/info/magnolia/bundle/magnolia-community-demo-webapp/6.2.43/magnolia-community-demo-webapp-6.2.43-tomcat-bundle.zip
  unzip magnolia-community-demo-webapp-6.2.43-tomcat-bundle.zip
  cd magnolia-6.2.43/apache-tomcat-9.0.86/bin
  ./magnolia_control.sh start --ignore-open-files-limit 
              
  sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt \
   -subj "/C=test/ST=test/L=test/O=test/OU=test/CN=test"

  sudo tee /etc/nginx/sites-available/magnolia > /dev/null <<EOT
    server {
        listen 443 ssl;
        server_name _;

        ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
        ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;

        location / {
            proxy_pass http://localhost:8080;
            proxy_set_header Host $host;
            roxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          }
      }
  EOT

  sudo ln -s /etc/nginx/sites-available/magnolia /etc/nginx/sites-enabled/
  sudo nginx -t
  sudo systemctl reload nginx
  EOF  
}