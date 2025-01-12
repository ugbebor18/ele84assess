variable "aws_region" {
  description = "AWS region where resources will be created"
  default     = "us-east-1"
}

variable "datasets_bucket_name" {
  description = "Name of the S3 bucket for datasets"
  default     = "fridayelement-datasets"
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  default     = "merge-homeless-data"
}

variable "lambda_execution_role_name" {
  description = "Name of the Lambda execution role"
  default     = "lambda-exec-role"
}

