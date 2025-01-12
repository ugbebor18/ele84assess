output "datasets_bucket" {
  value       = aws_s3_bucket.datasets.bucket
  description = "S3 bucket for storing datasets"
}

output "lambda_function_name" {
  value       = aws_lambda_function.merge_function.function_name
  description = "Name of the deployed Lambda function"
}

output "lambda_execution_role" {
  value       = aws_iam_role.lambda_exec.name
  description = "IAM Role assigned to the Lambda function"
}
