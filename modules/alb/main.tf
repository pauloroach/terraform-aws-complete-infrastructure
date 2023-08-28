#Create Security Group
resource "aws_security_group" "alb" {
  name        = "alb_security_group"
  description = "ALB security group"
  vpc_id      = var.vpc_id

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

  # Allow all outbound traffic.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "app-alb-security-group"
  }
}

#Create myapp ALB
resource "aws_alb" "alb" {
  name               = "myapp-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.alb.id}"]
  subnets            = [for subnet in var.public_subnets : subnet.id]
  tags = {
    Name = "myapp-alb"
  }

  enable_deletion_protection = true
  enable_http2               = false
}

#Redirect http to https
resource "aws_lb_listener" "redirect_http_to_https" {
  load_balancer_arn = aws_alb.alb.id
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener_rule" "myapp_com" {
  listener_arn = "arn:aws:elasticloadbalancing:us-west-2:333522297589:listener/app/myapp-alb/10659459eb3a59f8/2d282a6c32fc04c6"
  priority     = 102

  action {
    
      type = "redirect"

      redirect {
        host        = "www.${var.domain_name}"
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    
  }

  condition {
    host_header {
      values = [(var.domain_name)]
    }
  }
}

