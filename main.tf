terraform {
	required_version = ">= 1.0.0"
	required_providers {
		aws = {
			source  = "hashicorp/aws"
			version = ">= 5.0.0"
		}
	}
}

provider "aws" {
	region = "ap-southeast-2"
}

locals {
	services = ["nginx", "php"]
}


# create ALB
resource "aws_lb" "my-alb-1" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [ "sg-XXXXXXX" ]
  subnets            = ["subnet-XXXXXXXXX","subnet-YYYYYYY"]
  enable_deletion_protection = false
  enable_cross_zone_load_balancing = true
}

# create 3 TGs

resource "aws_lb_target_group" "my-tg-1" {

	name        = "my-target-group-1"
	port        = 80
	protocol    = "HTTP"
	target_type = "instance"
	vpc_id      =  "vpc-XXXXXXXX"
	health_check {
		healthy_threshold   = 2
		interval            = 30
		protocol            = "HTTP"
		unhealthy_threshold = 2
	}

	load_balancing_algorithm_type = "least_outstanding_requests"

	stickiness {
		enabled = true
		type    = "lb_cookie"
	}

	lifecycle {
		create_before_destroy = true
	}

}

resource "aws_autoscaling_attachment" "target" {
	autoscaling_group_name = "PLACE HOLDER"
	lb_target_group_arn    = aws_lb_target_group .my-tg-1.arn

}

resource "aws_lb_target_group" "my-tg-2" {
	name        = "my-target-group-2"
	port        = 80
	protocol    = "HTTP"
	target_type = "instance"
	vpc_id      =  "vpc-XXXXXXXX"
	health_check {
	}
}

resource "aws_lb_target_group" "my-tg-3" {
  name        = "my-target-group-3"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      =  "vpc-XXXXXXXXX"
  health_check {
   }
}

# creatr LB listener for port 80 with default TG

resource "aws_lb_listener" "my-alb-listener-443" {
  load_balancer_arn = aws_lb.my-alb-1.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.this.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my-tg-3.arn
  }

}

resource "aws_lb_listener" "my-alb-listener-80" {
  load_balancer_arn = aws_lb.my-alb-1.arn
  port              = 80
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

# attach 3 rules to Listener based on path

resource "aws_lb_listener_rule" "content-1" {
  listener_arn = "${aws_lb_listener.my-alb-listener-443.arn}"
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.my-tg-1.arn}"
  }
  condition {
    path_pattern {
      values = ["/content-1/*"]
     }
   }
}

resource "aws_lb_listener_rule" "content-2" {
  listener_arn = "${aws_lb_listener.my-alb-listener-443.arn}"
  priority     = 20
  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.my-tg-2.arn}"
  }
  condition {
    path_pattern {
      values = ["/content-2/*"]
     }
   }
}


resource "aws_lb_listener_rule" "header-1" {
  listener_arn = aws_lb_listener.my-alb-listener-443.arn
  priority     = 2

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.proxy.arn}"
  }

  condition {
    host_header {
      values = ["proxy.portsite.com"]
    }
  }
}