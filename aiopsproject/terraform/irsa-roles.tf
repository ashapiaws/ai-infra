# IRSA Roles - Created after EKS cluster and S3 buckets
# These roles use IAM Roles for Service Accounts (IRSA) for secure workload access

# Training Service Role for IRSA
resource "aws_iam_role" "training_service_role" {
  name = "${var.cluster_config.cluster_name}-training-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(module.eks.oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:ml-training:ray-training-sa"
            "${replace(module.eks.oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_config.cluster_name}-training-service-role"
    Environment = var.environment
    Purpose     = "ray-training"
  }

  depends_on = [module.eks]
}

# Training Service S3 Policy
resource "aws_iam_policy" "training_service_s3_policy" {
  name        = "${var.cluster_config.cluster_name}-training-s3-policy"
  description = "S3 access policy for Ray training service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          module.s3.model_registry_bucket_arn,
          "${module.s3.model_registry_bucket_arn}/*",
          module.s3.artifacts_bucket_arn,
          "${module.s3.artifacts_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = [module.iam.kms_key_arn]
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_config.cluster_name}-training-s3-policy"
    Environment = var.environment
  }
}

# Attach S3 policy to training role
resource "aws_iam_role_policy_attachment" "training_service_s3_policy_attachment" {
  policy_arn = aws_iam_policy.training_service_s3_policy.arn
  role       = aws_iam_role.training_service_role.name
}

# Inference Service Role for IRSA
resource "aws_iam_role" "inference_service_role" {
  name = "${var.cluster_config.cluster_name}-inference-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(module.eks.oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:ml-inference:vllm-inference-sa"
            "${replace(module.eks.oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_config.cluster_name}-inference-service-role"
    Environment = var.environment
    Purpose     = "vllm-inference"
  }

  depends_on = [module.eks]
}

# Inference Service S3 Policy (read-only)
resource "aws_iam_policy" "inference_service_s3_policy" {
  name        = "${var.cluster_config.cluster_name}-inference-s3-policy"
  description = "S3 access policy for vLLM inference service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          module.s3.model_registry_bucket_arn,
          "${module.s3.model_registry_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = [module.iam.kms_key_arn]
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_config.cluster_name}-inference-s3-policy"
    Environment = var.environment
  }
}

# Attach S3 policy to inference role
resource "aws_iam_role_policy_attachment" "inference_service_s3_policy_attachment" {
  policy_arn = aws_iam_policy.inference_service_s3_policy.arn
  role       = aws_iam_role.inference_service_role.name
}