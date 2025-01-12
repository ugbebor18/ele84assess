
# AWS Lambda Data Processing Workflow

## Overview
This project demonstrates a data processing workflow using AWS services. It automates the merging of datasets stored in S3, processes them with AWS Lambda, and makes the processed data available for analytics and visualization.

---

## Architecture Diagram
Below is the architecture diagram illustrating the workflow:

```
+-----------+            +-------------+           +----------------+
| S3 Bucket |  ------->  | AWS Lambda  |  -------> | Processed Data |
| (Raw Data)|  Event     | (Merge CSV) |  Process  |    in S3       |
+-----------+            +-------------+           +----------------+ 
                                                            |
                                                            v
                                    +.........................................................       
                                    |                                                         |
                             +-----------------+                                   +-----------------+
                             | Visualization   |                                   |  Query          |
                             | AWS QuickSight  |                                   |  AWS Athena     |
                             +-----------------+                                   +.................+
```

---

## Features
- **Event-Driven Processing**: S3 triggers invoke an AWS Lambda function when raw data is uploaded.
- **Data Transformation**: The Lambda function standardizes identifiers, merges datasets, and uploads the processed data back to S3.
- **Visualization and Querying**: The processed data can be visualized with AWS QuickSight and queried using AWS Athena.

---

## Files in the Repository
1. **`Diagram.md`**  
   Contains the architecture diagram of the project.

2. **`lambda_function.py`**  
   The core Lambda function script for:
   - Standardizing identifiers.
   - Merging datasets using `pandas`.
   - Handling S3 events.

3. **`README.md`**  
   Documentation for the project.

---

## Lambda Function Details
The Lambda function processes two datasets:
- `SF_HOMELESS_ANXIETY.csv`
- `SF_HOMELESS_DEMOGRAPHICS.csv`

### Key Steps in the Function:
1. **Standardize Identifiers**: 
   - The `Homeless ID` column is renamed to `HID` and formatted for consistency.
2. **Data Merge**: 
   - The datasets are merged on the `HID` column using an outer join.
3. **Save to S3**: 
   - The merged dataset is saved in the `processed/` folder in S3.

#### Environment Variables:
- `S3_BUCKET_NAME`: Name of the S3 bucket containing the datasets.

---

## How to Use
### Prerequisites:
1. AWS account with access to:
   - S3
   - Lambda
2. AWS CLI configured with necessary permissions.

### Setup:
1. **Deploy the Lambda Function:**
   - Upload `lambda_function.py` to your AWS Lambda environment.
   - Set the environment variable `S3_BUCKET_NAME` with your bucket's name.
2. **Upload Raw Data to S3:**
   - Place the raw datasets (`SF_HOMELESS_ANXIETY.csv` and `SF_HOMELESS_DEMOGRAPHICS.csv`) in the S3 bucket.
3. **Trigger the Function:**
   - Configure an S3 event notification to invoke the Lambda function when new files are uploaded.

---

## GitHub Repository Variables
To integrate GitHub Actions with AWS, configure repository variables:

| Variable Name             | Description                 |
|---------------------------|-----------------------------|
| `AWS_ACCESS_KEY_ID`       | Your AWS Access Key ID      |
| `AWS_SECRET_ACCESS_KEY`   | Your AWS Secret Access Key  |
| `AWS_REGION`              | Your AWS region (e.g., `us-east-1`) |

### Sample Workflow:
```yaml
name: Deploy AWS Lambda

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v3

      - name: Configure AWS Credentials
        env:
          AWS_ACCESS_KEY_ID: ${{ vars.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ vars.AWS_SECRET_ACCESS_KEY }}
          AWS_REGION: ${{ vars.AWS_REGION }}
        run: |
          aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
          aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
          aws configure set region $AWS_REGION
```

---

## Testing and Monitoring
1. **Verify Functionality**:
   - Upload a test CSV file to S3 and check if the processed data appears in the `processed/` folder.
2. **Monitor Logs**:
   - Use AWS CloudWatch Logs to monitor the Lambda function's execution.

---


