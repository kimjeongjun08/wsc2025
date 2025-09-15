data "aws_caller_identity" "current" {}

resource "aws_ecs_task_definition" "product_td" {
  family                   = "product-td"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"
  task_role_arn           = var.ecs_task_execution_role_arn
  execution_role_arn      = var.ecs_task_execution_role_arn

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([
    {
      name      = "product"      
      image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.ap-northeast-2.amazonaws.com/product:latest"
      cpu       = 256
      essential = true
      portMappings = [
        {
          name          = "product-8080-tcp"
          containerPort = 8080
          hostPort      = 0
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]
      environment = [
        {
          name  = "TABLE_INDEX_NAME"
          value = "id-index"
        },
        {
          name  = "TABLE_NAME"
          value = "product"
        }
      ]
      environmentFiles = []
      mountPoints     = []
      volumesFrom     = []
      ulimits         = []
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/logs/product"
          "awslogs-create-group"  = "true"
          "awslogs-region"        = "ap-northeast-2"
          "awslogs-stream-prefix" = "ecs"
        }
        secretOptions = []
      }
      systemControls = []
    }
  ])

  tags = {
    Name = "product-td"
  }
}

resource "aws_ecs_task_definition" "stress_td" {
  family                   = "stress-td"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"
  task_role_arn           = var.ecs_task_execution_role_arn
  execution_role_arn      = var.ecs_task_execution_role_arn

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([
    {
      name      = "stress"
      image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.ap-northeast-2.amazonaws.com/stress:latest"
      cpu       = 256
      essential = true
      portMappings = [
        {
          name          = "stress-8080-tcp"
          containerPort = 8080
          hostPort      = 0
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]
      environment     = []
      environmentFiles = []
      mountPoints     = []
      volumesFrom     = []
      ulimits         = []
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/logs/stress"
          "awslogs-create-group"  = "true"
          "awslogs-region"        = "ap-northeast-2"
          "awslogs-stream-prefix" = "ecs"
        }
        secretOptions = []
      }
      systemControls = []
    }
  ])

  tags = {
    Name = "stress-td"
  }
}

resource "aws_ecs_task_definition" "user_td" {
  family                   = "user-td"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"
  task_role_arn           = var.ecs_task_execution_role_arn
  execution_role_arn      = var.ecs_task_execution_role_arn

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([
    {
      name      = "user"
      image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.ap-northeast-2.amazonaws.com/user:latest"
      cpu       = 256
      essential = true
      portMappings = [
        {
          name          = "user-8080-tcp"
          containerPort = 8080
          hostPort      = 0
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]
      environment = [
        {
          name  = "MYSQL_USER"
          value = "admin"
        },
        {
          name  = "MYSQL_PASSWORD"
          value = "Skill53##"
        },
        {
          name  = "MYSQL_HOST"
          value = var.rds_proxy_endpoint
        },
        {
          name  = "MYSQL_PORT"
          value = "3306"
        },
        {
          name  = "MYSQL_DBNAME"
          value = "dev"
        }
      ]
      environmentFiles = []
      mountPoints     = []
      volumesFrom     = []
      ulimits         = []
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/logs/user"
          "awslogs-create-group"  = "true"
          "awslogs-region"        = "ap-northeast-2"
          "awslogs-stream-prefix" = "ecs"
        }
        secretOptions = []
      }
      systemControls = []
    }
  ])

  tags = {
    Name = "user-td"
  }
}