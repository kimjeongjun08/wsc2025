data "aws_caller_identity" "current" {}

module "iam" {
  source = "./Modules/IAM"
  name   = "apdev"
}

module "ec2" {
  source = "./Modules/EC2"

  name                 = "apdev"
  bastion_instance_type = "t3.small"
  bastion_sg           = aws_security_group.apdev_bastion_sg.id
  puba_subnet_id       = aws_subnet.apdev_pub_a.id
  iam_instance_profile = module.iam.apdev_admin_instance_profile
  rds_endpoint         = module.rds.rds_proxy_endpoint
  s3_bucket_id         = aws_s3_bucket.bucket.id

  depends_on = [module.rds]
}

module "dynamodb" {
  source = "./Modules/DynamoDB"
}

module "ecs" {
  source = "./Modules/ECS"

  vpc_id                      = aws_vpc.apdev_vpc.id
  private_subnet_ids          = [aws_subnet.apdev_priv_a.id, aws_subnet.apdev_priv_b.id]
  app_sg_id                   = aws_security_group.apdev_app_sg.id
  iam_instance_profile        = module.iam.apdev_admin_instance_profile
  ecs_task_execution_role_arn = module.iam.ecs_task_execution_role_arn
  product_tg_arn              = module.alb.product_tg_arn
  user_tg_arn                 = module.alb.user_tg_arn
  stress_tg_arn               = module.alb.stress_tg_arn
  rds_proxy_endpoint          = module.rds.rds_proxy_endpoint

  depends_on = [module.ec2]
}

module "rds" {
  source = "./Modules/RDS"

  data_subnet_ids       = [aws_subnet.apdev_data_a.id, aws_subnet.apdev_data_b.id]
  rds_security_group_id = aws_security_group.apdev_rds_instance_sg.id
}

module "alb" {
  source = "./Modules/ALB"

  vpc_id             = aws_vpc.apdev_vpc.id
  public_subnet_ids  = [aws_subnet.apdev_pub_a.id, aws_subnet.apdev_pub_b.id]
  app_sg_id          = aws_security_group.apdev_app_sg.id
}

module "ecr" {
  source = "./Modules/ECR"
}

module "cloudfront" {
  source = "./Modules/CloudFront"

  alb_domain_name         = module.alb.alb_dns_name
  cloudfront_function_arn = null

  depends_on = [module.alb]
}