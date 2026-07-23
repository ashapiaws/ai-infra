# S3 Module Outputs

output "model_registry_bucket_name" {
  description = "Name of the model registry S3 bucket"
  value       = aws_s3_bucket.model_registry.bucket
}

output "model_registry_bucket_arn" {
  description = "ARN of the model registry S3 bucket"
  value       = aws_s3_bucket.model_registry.arn
}

output "artifacts_bucket_name" {
  description = "Name of the training artifacts S3 bucket"
  value       = aws_s3_bucket.artifacts.bucket
}

output "artifacts_bucket_arn" {
  description = "ARN of the training artifacts S3 bucket"
  value       = aws_s3_bucket.artifacts.arn
}

output "access_logs_bucket_name" {
  description = "Name of the access logs S3 bucket"
  value       = aws_s3_bucket.access_logs.bucket
}

output "access_logs_bucket_arn" {
  description = "ARN of the access logs S3 bucket"
  value       = aws_s3_bucket.access_logs.arn
}