output "terraform_state_bucket" {
  value       = aws_s3_bucket.terraform_state.bucket
  description = "S3 bucket for storing Terraform state"
}

output "dynamodb_table_name" {
  value       = aws_dynamodb_table.terraform_locks.name
  description = "DynamoDB table for state locking"
}
