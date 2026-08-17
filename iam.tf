# GitHub Actions 用の OIDC プロバイダー設定
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  # GitHub公式のサムプリント（過去の証明書更新に対応するため両方記述）
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c3d215b070979b1a110759ff1183b263a4658a3"
  ]
}

# GitHub Actions が使用する IAM ロール
resource "aws_iam_role" "github_actions" {
  name = "aws-20260810-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:abeken1999/aws-20260810:*"
          }
        }
      }
    ]
  })
}

# 開発用の管理者権限付与
resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# 出力: GitHub Actions 設定で使う ロール ARN
output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "IAM Role ARN for GitHub Actions"
}
