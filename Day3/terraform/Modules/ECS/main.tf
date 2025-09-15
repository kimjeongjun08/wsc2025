data "aws_ami" "bottlerocket" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["bottlerocket-aws-ecs-1-x86_64-*"]
  }
}

resource "aws_ecs_cluster" "apdev_cluster" {
  name = "apdev-ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "apdev-ecs-cluster"
  }
}

resource "aws_launch_template" "ecs_lt" {
  name_prefix   = "apdev-ecs-"
  image_id      = data.aws_ami.bottlerocket.id
  instance_type = "t3.medium"

  vpc_security_group_ids = [var.app_sg_id]

  iam_instance_profile {
    name = var.iam_instance_profile
  }

  user_data = base64encode(templatefile("${path.module}/user_data.toml", {
    cluster_name = aws_ecs_cluster.apdev_cluster.name
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "apdev-ecs-instance"
    }
  }
}

resource "aws_autoscaling_group" "ecs_asg" {
  name                = "apdev-ecs-asg"
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = []
  health_check_type   = "EC2"
  min_size            = 1
  max_size            = 10
  desired_capacity    = 1
  default_cooldown    = 60
  protect_from_scale_in = true

  launch_template {
    id      = aws_launch_template.ecs_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }
}

resource "aws_ecs_capacity_provider" "apdev_cp" {
  name = "apdev-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs_asg.arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      maximum_scaling_step_size = 1
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "apdev_cluster" {
  cluster_name = aws_ecs_cluster.apdev_cluster.name

  capacity_providers = [aws_ecs_capacity_provider.apdev_cp.name]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.apdev_cp.name
  }
}