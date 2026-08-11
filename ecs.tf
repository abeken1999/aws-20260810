# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "aws-20260810-cluster"

  tags = {
    Name = "aws-20260810-cluster"
  }
}

# CloudWatch ロググループ（コンテナログ出力用）
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/aws-20260810-app"
  retention_in_days = 7
}

# ECSタスク実行ロール（ECRからイメージを引き引くためのIAMロール）
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "aws-20260810-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/servicerole/AmazonECSTaskExecutionRolePolicy"
}

# ECS用のセキュリティグループ（ALBからの80番ポート通信のみ許可）
resource "aws_security_group" "ecs" {
  name        = "aws-20260810-ecs-sg"
  description = "Allow inbound traffic from ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "aws-20260810-ecs-sg"
  }
}

# ECS タスク定義（Task Definition）
resource "aws_ecs_task_definition" "app" {
  family                   = "aws-20260810-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256" # 0.25 vCPU
  memory                   = "512" # 512 MiB
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "${aws_ecr_repository.app.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
      environment = [
        {
          name  = "APP_ENV"
          value = "production"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = "ap-northeast-1"
          "awslogs-stream-prefix" = "app"
        }
      }
    }
  ])
}

# ECS サービス（Service）
resource "aws_ecs_service" "main" {
  name            = "aws-20260810-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_1a.id, aws_subnet.public_1c.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.http]
}
