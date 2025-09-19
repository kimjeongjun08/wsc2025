resource "aws_ecs_service" "product_svc" {
  name            = "product-svc"
  cluster         = aws_ecs_cluster.apdev_cluster.id
  task_definition = aws_ecs_task_definition.product_td.arn
  desired_count   = 1
  availability_zone_rebalancing = "ENABLED"

  load_balancer {
    target_group_arn = var.product_tg_arn
    container_name   = "product"
    container_port   = 8080
  }

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.apdev_cp.name
    weight            = 100
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  enable_ecs_managed_tags = true

  tags = {
    Name = "product-svc"
  }
}

resource "aws_ecs_service" "user_svc" {
  name            = "user-svc"
  cluster         = aws_ecs_cluster.apdev_cluster.id
  task_definition = aws_ecs_task_definition.user_td.arn
  desired_count   = 1
  availability_zone_rebalancing = "ENABLED"

  load_balancer {
    target_group_arn = var.user_tg_arn
    container_name   = "user"
    container_port   = 8080
  }

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.apdev_cp.name
    weight            = 100
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  enable_ecs_managed_tags = true

  tags = {
    Name = "user-svc"
  }
}

resource "aws_ecs_service" "stress_svc" {
  name            = "stress-svc"
  cluster         = aws_ecs_cluster.apdev_cluster.id
  task_definition = aws_ecs_task_definition.stress_td.arn
  desired_count   = 1
  availability_zone_rebalancing = "ENABLED"

  load_balancer {
    target_group_arn = var.stress_tg_arn
    container_name   = "stress"
    container_port   = 8080
  }

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.apdev_cp.name
    weight            = 100
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  enable_ecs_managed_tags = true

  tags = {
    Name = "stress-svc"
  }
}