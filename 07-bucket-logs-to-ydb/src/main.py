import os
import logging
import ydb
import json
import boto3
from datetime import datetime
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)
verboseLogging = eval(os.environ.get('VERBOSE_LOG', 'False'))

if verboseLogging:
    logger.info('Loading handler function')

class SimpleYDB:
    """Simple YDB client for basic operations."""

    def __init__(self, endpoint, database):
        """Initialize YDB connection using metadata credentials."""
        self.driver = ydb.Driver(
            endpoint=endpoint,
            database=database,
            credentials=ydb.iam.MetadataUrlCredentials(),
        )
        self.driver.wait(fail_fast=True, timeout=5)
        self.pool = ydb.SessionPool(self.driver)

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()

    def close(self):
        """Clean up resources."""
        if hasattr(self, 'pool'):
            self.pool.stop()
        if hasattr(self, 'driver'):
            self.driver.stop()

    def insert_rows(self, table_name, rows):
        """Insert rows into table."""
        if not rows:
            return True

        columns = list(rows[0].keys())
        columns_str = ", ".join(columns)

        values_list = []
        for row in rows:
            values = []
            for col in columns:
                value = row[col]
                if value is None:
                    values.append("NULL")
                elif col == 'timestamp' and isinstance(value, str):
                    # Parse ISO timestamp and convert to YDB Timestamp format
                    try:
                        dt = datetime.fromisoformat(value.replace('Z', '+00:00'))
                        iso_string = dt.strftime('%Y-%m-%dT%H:%M:%SZ')
                        values.append(f"Timestamp('{iso_string}')")
                    except:
                        values.append("NULL")
                elif isinstance(value, str):
                    escaped_value = value.replace("'", "''")
                    values.append(f"'{escaped_value}'")
                elif isinstance(value, bool):
                    values.append(str(value).lower())
                elif isinstance(value, (dict, list)):
                    json_str = json.dumps(value).replace("'", "''")
                    values.append(f"'{json_str}'")
                else:
                    values.append(str(value))

            values_list.append(f"({', '.join(values)})")

        values_str = ", ".join(values_list)
        query = f"REPLACE INTO {table_name} ({columns_str}) VALUES {values_str}"

        try:
            self.pool.retry_operation_sync(
                lambda session: session.transaction().execute(
                    query,
                    commit_tx=True,
                    settings=ydb.BaseRequestSettings().with_timeout(60)
                )
            )
            return True
        except Exception as e:
            logger.error(f"Failed to insert rows into {table_name}: {e}")
            return False

def get_s3_client():
    """Create S3 client using environment credentials."""
    return boto3.client(
        's3',
        endpoint_url=os.environ['S3_ENDPOINT'],
        aws_access_key_id=os.environ['AWS_ACCESS_KEY_ID'],
        aws_secret_access_key=os.environ['AWS_SECRET_ACCESS_KEY']
    )

def download_s3_object(s3_client, bucket_name, object_key):
    """Download S3 object content."""
    try:
        response = s3_client.get_object(Bucket=bucket_name, Key=object_key)
        content = response['Body'].read().decode('utf-8')
        return content
    except ClientError as e:
        logger.error(f"Failed to download S3 object {bucket_name}/{object_key}: {e}")
        return None

def parse_log_entries(log_content):
    """Parse log entries from S3 object content."""
    log_entries = []

    for line in log_content.strip().split('\n'):
        if not line.strip():
            continue

        try:
            log_entry = json.loads(line)
            log_entries.append(log_entry)
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse log line: {line[:100]}... Error: {e}")
            continue

    return log_entries

def convert_log_entry_to_row(log_entry):
    """Convert S3 log entry to YDB table row."""
    return {
        'timestamp': log_entry.get('timestamp', ''),
        'request_id': log_entry.get('request_id', ''),
        'bucket': log_entry.get('bucket', ''),
        'handler': log_entry.get('handler', ''),
        'object_key': log_entry.get('object_key', ''),
        'storage_class': log_entry.get('storage_class', ''),
        'requester': log_entry.get('requester', ''),
        'version_id': log_entry.get('version_id', ''),
        'status': log_entry.get('status', 0),
        'method': log_entry.get('method', ''),
        'protocol': log_entry.get('protocol', ''),
        'scheme': log_entry.get('scheme', ''),
        'http_referer': log_entry.get('http_referer', ''),
        'user_agent': log_entry.get('user_agent', ''),
        'vhost': log_entry.get('vhost', ''),
        'ip': log_entry.get('ip', ''),
        'request_path': log_entry.get('request_path', ''),
        'request_args': log_entry.get('request_args', ''),
        'ssl_protocol': log_entry.get('ssl_protocol', ''),
        'range': log_entry.get('range', ''),
        'bytes_send': log_entry.get('bytes_send', 0),
        'bytes_received': log_entry.get('bytes_received', 0),
        'request_time': log_entry.get('request_time', 0)
    }

def handler(event, context):
    statusCode = 500

    if verboseLogging:
        logger.info(f"Event: {event}")
        logger.info(f"Context: {context}")

    # Get environment variables
    ydb_endpoint = os.environ['YDB_ENDPOINT']
    ydb_database = os.environ['YDB_DATABASE']
    table_name = os.environ.get('YDB_TABLE_NAME', 's3_bucket_logs')
    s3_bucket = os.environ['S3_BUCKET']

    if verboseLogging:
        logger.info(f'Connecting to YDB: {ydb_endpoint}, database: {ydb_database}')
        logger.info(f'S3 bucket: {s3_bucket}')

    try:
        # Initialize S3 client
        s3_client = get_s3_client()

        # Initialize YDB connection
        with SimpleYDB(ydb_endpoint, ydb_database) as db:
            all_rows_to_insert = []

            # Process each message in the event
            for message in event.get('messages', []):
                details = message.get('details', {})
                object_key = details.get('object_id', '')

                if not object_key:
                    logger.warning(f"No object_id found in message: {message}")
                    continue

                logger.info(f"Processing S3 object: {s3_bucket}/{object_key}")

                # Download S3 object
                log_content = download_s3_object(s3_client, s3_bucket, object_key)
                if not log_content:
                    logger.error(f"Failed to download {s3_bucket}/{object_key}")
                    continue

                # Parse log entries
                log_entries = parse_log_entries(log_content)
                logger.info(f"Found {len(log_entries)} log entries in {object_key}")

                # Convert log entries to table rows
                for log_entry in log_entries:
                    row = convert_log_entry_to_row(log_entry)
                    all_rows_to_insert.append(row)

                    if verboseLogging:
                        logger.info(f'Prepared row: {row}')

            # Insert all rows into YDB
            if all_rows_to_insert:
                if db.insert_rows(table_name, all_rows_to_insert):
                    statusCode = 200
                    logger.info(f'Successfully inserted {len(all_rows_to_insert)} rows')
                else:
                    logger.error('Failed to insert rows')
            else:
                logger.warning('No rows to insert')
                statusCode = 200

    except Exception as error:
        logger.error(f'Error processing messages: {error}')

    return {
        'statusCode': statusCode,
        'headers': {
            'Content-Type': 'text/plain'
        }
    }