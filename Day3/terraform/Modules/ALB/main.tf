resource "aws_lb" "apdev_alb" {
  name               = "apdev-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.app_sg_id]
  subnets            = var.public_subnet_ids

  tags = {
    Name = "apdev-alb"
  }
}

resource "aws_lb_target_group" "apdev_product_tg" {
  name        = "apdev-product-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/healthcheck"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "apdev-product-tg"
  }
}

resource "aws_lb_target_group" "apdev_user_tg" {
  name        = "apdev-user-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/healthcheck"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "apdev-user-tg"
  }
}

resource "aws_lb_target_group" "apdev_stress_tg" {
  name        = "apdev-stress-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/healthcheck"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "apdev-stress-tg"
  }
}

resource "aws_lb_listener" "apdev_alb_listener" {
  load_balancer_arn = aws_lb.apdev_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404 Not Found"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_rule" "healthcheck_rule" {
  listener_arn = aws_lb_listener.apdev_alb_listener.arn
  priority     = 100

  action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.apdev_product_tg.arn
        weight = 33
      }
      target_group {
        arn    = aws_lb_target_group.apdev_user_tg.arn
        weight = 33
      }
      target_group {
        arn    = aws_lb_target_group.apdev_stress_tg.arn
        weight = 34
      }
    }
  }

  condition {
    path_pattern {
      values = ["/healthcheck"]
    }
  }
}

resource "aws_lb_listener_rule" "product_rule" {
  listener_arn = aws_lb_listener.apdev_alb_listener.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.apdev_product_tg.arn
  }

  condition {
    path_pattern {
      values = ["/v1/product"]
    }
  }
}

resource "aws_lb_listener_rule" "user_rule" {
  listener_arn = aws_lb_listener.apdev_alb_listener.arn
  priority     = 300

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.apdev_user_tg.arn
  }

  condition {
    path_pattern {
      values = ["/v1/user"]
    }
  }
}

resource "aws_lb_listener_rule" "stress_rule" {
  listener_arn = aws_lb_listener.apdev_alb_listener.arn
  priority     = 400

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.apdev_stress_tg.arn
  }

  condition {
    path_pattern {
      values = ["/v1/stress"]
    }
  }
}