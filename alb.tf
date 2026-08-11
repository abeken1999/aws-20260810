# ALB用のセキュリティグループ（80番ポートを全解放）
resource "aws_security_group" "alb" {
  name        = "aws-20260810-alb-sg"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "HTTP from anywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "aws-20260810-alb-sg"
  }
}

# ALB本体
resource "aws_lb" "main" {
  name               = "aws-20260810-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_1a.id, aws_subnet.public_1c.id]

  tags = {
    Name = "aws-20260810-alb"
  }
}

# ターゲットグループ（ALBからECSタスクへの転送先設定）
resource "aws_lb_target_group" "app" {
  name        = "aws-20260810-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  # Qiita記事用に工夫したヘルスチェック設定
  health_check {
    enabled             = true
    path                = "/health"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name = "aws-20260810-tg"
  }
}

# HTTPリスナー（80番ポートで受けたトラフィックをターゲットグループへ流す）
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# 外部アクセス用のURL（DNS名）を出力
output "alb_dns_name" {
  value       = aws_lb.main.dns_name
  description = "The public DNS name of the ALB"
}
