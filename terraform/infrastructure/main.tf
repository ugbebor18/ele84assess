provider "aws" {
  region = var.aws_region
}

# Create a remote backend for your terraform
terraform {
  backend "s3" {
    bucket = "fridayelement-backend-bkt"
    dynamodb_table = "fridayelement-locks"
    key    = "LockID"
    region = "us-east-1"
  }
}

# S3 Bucket for datasets
resource "aws_s3_bucket" "datasets" {
  bucket = "fridayelement-datasets"
  acl    = "private"

  tags = {
    Name = "Dataset Bucket"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      tags,
      acl
    ]
  }
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.datasets.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.merge_function.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".csv"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

# IAM Role for Lambda execution
resource "aws_iam_role" "lambda_exec" {
  name               = "lambda-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "Lambda Execution Role"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      tags
    ]
  }
}

# Attach the basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_execution_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM Policy for Lambda
resource "aws_iam_role_policy" "lambda_exec_policy" {
  name   = "lambda-exec-policy"
  role   = aws_iam_role.lambda_exec.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject"
        ],
        Resource = [
          "arn:aws:s3:::fridayelement-datasets",
          "arn:aws:s3:::fridayelement-datasets/*"
        ]
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Lambda Function
resource "aws_lambda_function" "merge_function" {
  filename         = "lambda_function.zip"
  function_name    = "merge-homeless-data"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.8"
  source_code_hash = filebase64sha256("lambda_function.zip")
  timeout      = 900
  memory_size  = 512
  # Add the AWS Data Wrangler Layer
  layers = [
    "arn:aws:lambda:us-east-1:336392948345:layer:AWSSDKPandas-Python38:27"
  ]

  environment {
    variables = {
      S3_BUCKET_NAME = aws_s3_bucket.datasets.bucket
    }
  }
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invocation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.merge_function.function_name
  principal     = "s3.amazonaws.com"

  source_arn = aws_s3_bucket.datasets.arn
}

# Iterate over all CSV files in the files directory and upload them
resource "aws_s3_object" "csv_files" {
  for_each = fileset("${path.module}/../../files", "*.csv") # Path to the local directory containing CSV files
  bucket   = aws_s3_bucket.datasets.bucket
  key      = each.value
  source   = "${path.module}/../../files/${each.value}"

  tags = {
    UploadedBy = "Terraform"
  }
}

# Create S3 bucket for Athena query results
resource "aws_s3_bucket" "athena_results" {
  bucket = "fridayelement-athena-results-bucket"
  acl    = "private"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

# Create Athena workgroup
resource "aws_athena_workgroup" "default" {
  name        = "fridayelement-workgroup"
  state       = "ENABLED"
  description = "Workgroup for querying the merged dataset"

  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/results/"
    }
  }
}

# IAM Policy for Athena Access
resource "aws_iam_policy" "athena_access" {
  name        = "athena-access-policy"
  description = "Policy to allow Athena to query S3 and Lambda access"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:GetObject", "s3:ListBucket"],
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.datasets.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.datasets.bucket}/*"
        ]
      },
      {
        Effect   = "Allow",
        Action   = "athena:*",
        Resource = "*"
      }
    ]
  })
}

# IAM Role for Athena
resource "aws_iam_role" "athena" {
  name               = "athena-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          Service = "athena.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "Athena Role"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      tags
    ]
  }
}

# Attach the policy to Athena role
resource "aws_iam_role_policy_attachment" "athena_access" {
  role       = aws_iam_role.athena.name
  policy_arn = aws_iam_policy.athena_access.arn
}
# QuickSight Role
resource "aws_iam_role" "quicksight_access_role" {
  name = "QuickSightAccessRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "quicksight.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# QuickSight Policy for S3 Access
resource "aws_iam_policy" "quicksight_s3_access" {
  name = "QuickSightS3Access"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:GetObject", "s3:ListBucket"],
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.athena_results.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.athena_results.bucket}/*"
        ]
      }
    ]
  })
}

# Attach Policy to QuickSight Role
resource "aws_iam_role_policy_attachment" "quicksight_s3_access_attachment" {
  role       = aws_iam_role.quicksight_access_role.name
  policy_arn = aws_iam_policy.quicksight_s3_access.arn
}

