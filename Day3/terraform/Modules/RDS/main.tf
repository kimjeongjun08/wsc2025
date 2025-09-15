resource "aws_db_subnet_group" "apdev_db_subnet_group" {
  name       = "apdev-db-subnet-group"
  subnet_ids = var.data_subnet_ids

  tags = {
    Name = "apdev-db-subnet-group"
  }
}

resource "aws_db_instance" "apdev_rds_instance" {
  identifier     = "apdev-rds-instance"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"
  
  allocated_storage     = 400
  storage_type          = "gp3"
  iops                  = 12000
  storage_throughput    = 500
  
  db_name  = "dev"
  username = "admin"
  password = "Skill53##"
  
  vpc_security_group_ids = [var.rds_security_group_id]
  db_subnet_group_name   = aws_db_subnet_group.apdev_db_subnet_group.name
  
  multi_az               = true
  deletion_protection    = false
  skip_final_snapshot    = true
  
  monitoring_interval = 5
  monitoring_role_arn = aws_iam_role.rds_enhanced_monitoring.arn
  
  tags = {
    Name = "apdev-rds-instance"
  }
}

resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_proxy" "apdev_rds_proxy" {
  name                   = "apdev-rds-proxy"
  engine_family         = "MYSQL"
  auth {
    auth_scheme = "SECRETS"
    secret_arn  = aws_secretsmanager_secret.rds_credentials.arn
  }
  role_arn               = aws_iam_role.proxy_role.arn
  vpc_subnet_ids         = var.data_subnet_ids
  vpc_security_group_ids = [var.rds_security_group_id]
  require_tls            = false

  tags = {
    Name = "apdev-rds-proxy"
  }

  depends_on = [aws_secretsmanager_secret_version.rds_credentials]
}

resource "aws_db_proxy_default_target_group" "apdev_proxy_target_group" {
  db_proxy_name = aws_db_proxy.apdev_rds_proxy.name
}

resource "aws_db_proxy_target" "apdev_proxy_target" {
  db_instance_identifier = aws_db_instance.apdev_rds_instance.identifier
  db_proxy_name          = aws_db_proxy.apdev_rds_proxy.name
  target_group_name      = aws_db_proxy_default_target_group.apdev_proxy_target_group.name
}

resource "aws_secretsmanager_secret" "rds_credentials" {
  name                    = "apdev-rds-credentials-v2"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "rds_credentials" {
  secret_id = aws_secretsmanager_secret.rds_credentials.id
  secret_string = jsonencode({
    username = "admin"
    password = "Skill53##"
  })
}

resource "aws_iam_role" "proxy_role" {
  name = "apdev-rds-proxy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "proxy_policy" {
  name = "apdev-rds-proxy-policy"
  role = aws_iam_role.proxy_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds"
        ]
        Resource = aws_secretsmanager_secret.rds_credentials.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.ap-northeast-2.amazonaws.com"
          }
        }
      }
    ]
  })
}