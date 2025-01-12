import boto3
import pandas as pd
import io
import os

s3 = boto3.client("s3")

def standardize_id(hid):
    # Transform IDs to a standard format, removing 'HM' prefix if it exists
    if isinstance(hid, str):
        return hid.replace("HM", "").replace("-", "-15")
    return hid

def lambda_handler(event, context):
    bucket_name = os.environ["S3_BUCKET_NAME"]

    # # Get the S3 object key from the event
    # for record in event['Records']:
    #     key = record['s3']['object']['key']

    #     # Ignore files in the processed/ folder
    #     if key.startswith("processed/"):
    #         print(f"Ignoring file in processed folder: {key}")
    #         return {"statusCode": 200, "body": "File ignored."}
    try:
        # Fetch CSV files from S3
        anxiety_obj = s3.get_object(Bucket=bucket_name, Key="SF_HOMELESS_ANXIETY.csv")
        demographics_obj = s3.get_object(Bucket=bucket_name, Key="SF_HOMELESS_DEMOGRAPHICS.csv")

        # Load data into pandas DataFrames
        df_anxiety = pd.read_csv(io.BytesIO(anxiety_obj["Body"].read()))
        df_demographics = pd.read_csv(io.BytesIO(demographics_obj["Body"].read()))

        # Rename 'Homeless ID' column to 'HID' in anxiety dataset
        if 'Homeless ID' in df_anxiety.columns:
            df_anxiety.rename(columns={'Homeless ID': 'HID'}, inplace=True)
            df_anxiety["HID"] = df_anxiety["HID"].apply(lambda x: f"{x[5:].zfill(3)}-15")

        # Standardize the HID columns in both datasets
        df_anxiety['HID'] = df_anxiety['HID'].apply(standardize_id)
        df_demographics['HID'] = df_demographics['HID'].apply(standardize_id)

        # Perform the merge operation
        merged_df = pd.merge(df_anxiety, df_demographics, on="HID", how="outer")

        # Save the merged data back to S3
        output_buffer = io.StringIO()
        merged_df.to_csv(output_buffer, index=False)
        output_buffer.seek(0)

        s3.put_object(Bucket=bucket_name, Key="processed/merged_data.csv", Body=output_buffer.getvalue())
        return {"statusCode": 200, "body": "Merged dataset uploaded successfully."}
    except Exception as e:
        return {"statusCode": 500, "body": str(e)}