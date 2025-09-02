import os
import logging
import ydb
import json
from datetime import datetime

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
                elif col == 'time' and isinstance(value, int):
                    # Handle timestamp - convert microseconds to YDB Timestamp
                    values.append(f"Timestamp({value})")
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

def handler(event, context):
    statusCode = 500

    if verboseLogging:
        logger.info(f"Event: {event}")
        logger.info(f"Context: {context}")

    # Get YDB connection parameters from environment
    ydb_endpoint = os.environ['YDB_ENDPOINT']
    ydb_database = os.environ['YDB_DATABASE']
    table_name = os.environ.get('YDB_TABLE_NAME', 'load_balancer_requests')

    if verboseLogging:
        logger.info(f'Connecting to YDB: {ydb_endpoint}, database: {ydb_database}')

    try:
        with SimpleYDB(ydb_endpoint, ydb_database) as db:
            messages = event['messages'][0]['details']['messages']

            # Prepare rows for insertion
            rows_to_insert = []

            for message in messages:
                alb_message = message['json_payload']
                print(alb_message)
                
                # Parse timestamp to proper format
                time_str = alb_message.get('time', '')
                try:
                    # Convert ISO format to timestamp
                    dt = datetime.fromisoformat(time_str.replace('Z', '+00:00'))
                    timestamp = int(dt.timestamp() * 1000000)  # YDB Timestamp in microseconds
                except:
                    timestamp = 0
                
                # Prepare row data with all relevant fields
                row = {
                    'request_id': alb_message.get('request_id', ''),
                    'time': timestamp,
                    'type': alb_message.get('type', ''),
                    'client_ip': alb_message.get('client_ip', ''),
                    'backend_ip': alb_message.get('backend_ip', ''),
                    'http_method': alb_message.get('http_method', ''),
                    'http_status': alb_message.get('http_status', 0),
                    'request_uri': alb_message.get('request_uri', ''),
                    'user_agent': alb_message.get('user_agent', ''),
                    'authority': alb_message.get('authority', ''),
                    'request_time': alb_message.get('request_processing_times', {}).get('request_time', 0.0),
                    'backend_processing_time': alb_message.get('request_processing_times', {}).get('backend_processing_time', 0.0),
                    'request_body_bytes': alb_message.get('request_body_bytes', 0),
                    'response_body_bytes': alb_message.get('response_body_bytes', 0),
                    'load_balancer_id': alb_message.get('load_balancer_id', ''),
                    'backend_name': alb_message.get('backend_name', ''),
                    'route_name': alb_message.get('route_name', '')
                }

                rows_to_insert.append(row)

                if verboseLogging:
                    logger.info(f'Prepared row: {row}')

            # Insert all rows at once
            if db.insert_rows(table_name, rows_to_insert):
                statusCode = 200
                logger.info(f'Successfully inserted {len(rows_to_insert)} rows')
            else:
                logger.error('Failed to insert rows')

    except Exception as error:
        logger.error(f'Error processing messages: {error}')

    return {
        'statusCode': statusCode,
        'headers': {
            'Content-Type': 'text/plain'
        }
    }
