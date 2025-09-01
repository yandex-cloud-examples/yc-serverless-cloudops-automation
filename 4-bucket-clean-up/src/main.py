import boto3
import json
import os
from botocore.exceptions import ClientError

def handler(event, context):
    try:
        # Get environment variables
        bucket_name = os.environ.get('S3_BUCKET')
        prefix = os.environ.get('S3_PREFIX', '')
        s3_key = os.environ.get('S3_KEY')
        s3_secret = os.environ.get('S3_SECRET')

        # Validate required environment variables
        if not all([bucket_name, s3_key, s3_secret]):
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': 'Missing required environment variables: S3_BUCKET, S3_KEY, S3_SECRET'
                })
            }

        # Initialize S3 client for Yandex Cloud
        s3_client = boto3.client(
            's3',
            endpoint_url='https://storage.yandexcloud.net',
            region_name='ru-central1',
            aws_access_key_id=s3_key,
            aws_secret_access_key=s3_secret
        )

        deleted_objects = []

        print(f"Starting deletion from bucket: {bucket_name}, prefix: '{prefix}'")

        # List objects with the specified prefix
        paginator = s3_client.get_paginator('list_objects_v2')
        pages = paginator.paginate(Bucket=bucket_name, Prefix=prefix)

        for page in pages:
            if 'Contents' in page:
                # Prepare objects for batch deletion
                objects_to_delete = []
                for obj in page['Contents']:
                    objects_to_delete.append({'Key': obj['Key']})
                    deleted_objects.append(obj['Key'])

                # Delete objects in batches (max 1000 per request)
                if objects_to_delete:
                    response = s3_client.delete_objects(
                        Bucket=bucket_name,
                        Delete={'Objects': objects_to_delete}
                    )

                    # Log any errors
                    if 'Errors' in response:
                        for error in response['Errors']:
                            print(f"Error deleting {error['Key']}: {error['Message']}")

        print(f"Successfully deleted {len(deleted_objects)} objects")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Successfully deleted {len(deleted_objects)} objects',
                'deleted_objects': deleted_objects[:100],
                'total_deleted': len(deleted_objects)
            })
        }

    except ClientError as e:
        error_message = f"S3 error: {e.response['Error']['Message']}"
        print(error_message)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': error_message})
        }

    except Exception as e:
        error_message = f"Unexpected error: {str(e)}"
        print(error_message)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': error_message})
        }