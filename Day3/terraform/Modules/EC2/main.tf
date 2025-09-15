data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.bastion_instance_type
  vpc_security_group_ids      = [var.bastion_sg]
  subnet_id                   = var.puba_subnet_id
  key_name                    = aws_key_pair.keypair.key_name
  iam_instance_profile        = var.iam_instance_profile
  associate_public_ip_address = true

  user_data = base64encode(<<-EOF
#!/bin/bash
exec > >(tee /var/log/user-data.log) 2>&1
set -x

aws configure set region ap-northeast-2

echo "Starting user data execution at $(date)"

# 시스템 업데이트 및 패키지 설치
yum update -y
yum install -y docker mariadb105 unzip
yum install -y pip
pip3 install boto3 pymysql

# Docker 시작
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# 폴더 구조 생성
mkdir -p /home/ec2-user/apdev/application/{product,user,stress}

# S3에서 모든 파일 다운로드
aws s3 sync s3://${var.s3_bucket_id}/ /home/ec2-user/ --region ap-northeast-2

# 파일들을 적절한 폴더로 이동
cp /home/ec2-user/product /home/ec2-user/apdev/application/product/
cp /home/ec2-user/user /home/ec2-user/apdev/application/user/
cp /home/ec2-user/stress /home/ec2-user/apdev/application/stress/

# Dockerfile 생성 - product
cat > /home/ec2-user/apdev/application/product/Dockerfile << 'DOCKERFILE'
FROM golang:alpine
WORKDIR /app
COPY product .
RUN chmod +x product
RUN apk add --no-cache libc6-compat curl
CMD ["./product"]
DOCKERFILE

# Dockerfile 생성 - user
cat > /home/ec2-user/apdev/application/user/Dockerfile << 'DOCKERFILE'
FROM golang:alpine
WORKDIR /app
COPY user .
RUN chmod +x user
RUN apk add --no-cache libc6-compat curl
CMD ["./user"]
DOCKERFILE

# Dockerfile 생성 - stress
cat > /home/ec2-user/apdev/application/stress/Dockerfile << 'DOCKERFILE'
FROM golang:alpine
WORKDIR /app
COPY stress .
RUN chmod +x stress
RUN apk add --no-cache libc6-compat curl
CMD ["./stress"]
DOCKERFILE

# MySQL 테이블 생성
if [ -f /home/ec2-user/query.sql ]; then
    echo "Waiting for RDS to be ready..."
    sleep 60
    
    echo "Testing RDS connection..."
    for i in {1..10}; do
        if mysql -h ${var.rds_endpoint} -u admin -pSkill53## -e "SELECT 1;" > /dev/null 2>&1; then
            echo "RDS connection successful"
            break
        else
            echo "RDS connection attempt $i failed, retrying in 30 seconds..."
            sleep 30
        fi
    done
    
    echo "Executing query.sql"
    mysql -h ${var.rds_endpoint} -u admin -pSkill53## < /home/ec2-user/query.sql
    if [ $? -eq 0 ]; then
        echo "query.sql executed successfully"
    else
        echo "Failed to execute query.sql"
    fi
else
    echo "query.sql file not found in /home/ec2-user/"
fi

# 소유자 변경
chown -R ec2-user:ec2-user /home/ec2-user/apdev

# Docker 준비 대기
sleep 30

# ECR 로그인
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin $ACCOUNT.dkr.ecr.ap-northeast-2.amazonaws.com

# Docker 이미지 빌드 및 푸시 - product
cd /home/ec2-user/apdev/application/product
docker build -t $ACCOUNT.dkr.ecr.ap-northeast-2.amazonaws.com/product:latest .
docker push $ACCOUNT.dkr.ecr.ap-northeast-2.amazonaws.com/product:latest

# Docker 이미지 빌드 및 푸시 - user
cd /home/ec2-user/apdev/application/user
docker build -t $ACCOUNT.dkr.ecr.ap-northeast-2.amazonaws.com/user:latest .
docker push $ACCOUNT.dkr.ecr.ap-northeast-2.amazonaws.com/user:latest

# Docker 이미지 빌드 및 푸시 - stress
cd /home/ec2-user/apdev/application/stress
docker build -t $ACCOUNT.dkr.ecr.ap-northeast-2.amazonaws.com/stress:latest .
docker push $ACCOUNT.dkr.ecr.ap-northeast-2.amazonaws.com/stress:latest

echo "User data execution completed at $(date)"

# 자기 자신 종료
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region ap-northeast-2
  EOF
  )

  tags = {
    Name = "${var.name}-bastion-ec2"
  }
}
