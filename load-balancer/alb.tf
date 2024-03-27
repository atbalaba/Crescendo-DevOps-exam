resource "aws_alb" "load_balancer" {
  name = "test_load_balancer"
  internal = false
  load_balancer_type = "application"
  security_groups = [ aws_security_group.ec2_sec_group.id ]
  subnets = [ aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id ]
  enable_deletion_protection = false

  tags = {
    Name = "test_load_balancer"
  }
}