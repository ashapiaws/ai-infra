# S3 Module - Model Registry and Artifacts Storage
# Creates S3 buckets with encryption and lifecycle policies for ML workloads

# Model Registry Bucket
resource "aws_s3_bucket" "model_registry" {
  bucket = "ml-platform-model-registry-${var.environment}-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "ML Platform Model Registry"
    Environment = var.environment
    Purpose     = "model-storage"
  }
}

# Training Artifacts Bucket
resource "aws_s3_bucket" "artifacts" {
  bucket = "ml-platform-artifacts-${var.environment}-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "ML Platform Training Artifacts"
    Environment = var.environment
    Purpose     = "training-artifacts"
  }
}

# Random suffix for bucket names to ensure uniqueness
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Model Registry Bucket Versioning
resource "aws_s3_bucket_versioning" "model_registry" {
  bucket = aws_s3_bucket.model_registry.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Artifacts Bucket Versioning
resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Model Registry Bucket Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "model_registry" {
  bucket = aws_s3_bucket.model_registry.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# Artifacts Bucket Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# Model Registry Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "model_registry" {
  bucket = aws_s3_bucket.model_registry.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Artifacts Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Model Registry Lifecycle Configuration
resource "aws_s3_bucket_lifecycle_configuration" "model_registry" {
  bucket = aws_s3_bucket.model_registry.id

  rule {
    id     = "model_lifecycle"
    status = "Enabled"

    # Transition to IA after 30 days
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # Transition to Glacier after 90 days
    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    # Delete old versions after 365 days
    noncurrent_version_expiration {
      noncurrent_days = 365
    }

    # Clean up incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Artifacts Lifecycle Configuration
resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "artifacts_lifecycle"
    status = "Enabled"

    # Transition to IA after 7 days (artifacts accessed less frequently)
    transition {
      days          = 7
      storage_class = "STANDARD_IA"
    }

    # Transition to Glacier after 30 days
    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    # Delete old versions after 90 days (shorter retention for artifacts)
    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    # Clean up incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Model Registry Bucket Notification for model updates
resource "aws_s3_bucket_notification" "model_registry" {
  bucket = aws_s3_bucket.model_registry.id

  # Future: Can be extended to trigger Lambda functions or SNS notifications
  # when new models are uploaded
}

# CORS configuration for model registry (if web access needed)
resource "aws_s3_bucket_cors_configuration" "model_registry" {
  bucket = aws_s3_bucket.model_registry.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# Bucket logging for audit trail
resource "aws_s3_bucket_logging" "model_registry" {
  bucket = aws_s3_bucket.model_registry.id

  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "model-registry-access-logs/"
}

resource "aws_s3_bucket_logging" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "artifacts-access-logs/"
}

# Access logs bucket
resource "aws_s3_bucket" "access_logs" {
  bucket = "ml-platform-access-logs-${var.environment}-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "ML Platform Access Logs"
    Environment = var.environment
    Purpose     = "access-logs"
  }
}

# Access logs bucket public access block
resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Access logs lifecycle (delete after 90 days)
resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    id     = "access_logs_lifecycle"
    status = "Enabled"

    expiration {
      days = 90
    }
  }
}