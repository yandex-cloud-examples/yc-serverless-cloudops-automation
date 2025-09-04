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
                    dt = datetime.fromtimestamp(value / 1000000)
                    iso_string = dt.strftime('%Y-%m-%dT%H:%M:%SZ')
                    values.append(f"Timestamp('{iso_string}')")
                elif col == 'smartwebsecurity' and isinstance(value, dict):
                    json_str = json.dumps(value).replace("'", "''")
                    values.append(f"Json('{json_str}')")
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

    ydb_endpoint = os.environ['YDB_ENDPOINT']
    ydb_database = os.environ['YDB_DATABASE']
    table_name = os.environ.get('YDB_TABLE_NAME', 'load_balancer_requests')

    if verboseLogging:
        logger.info(f'Connecting to YDB: {ydb_endpoint}, database: {ydb_database}')

    try:
        with SimpleYDB(ydb_endpoint, ydb_database) as db:
            messages = event['messages'][0]['details']['messages']

            rows_to_insert = []

            for message in messages:
                alb_message = message['json_payload']
                print(alb_message)
                
                time_str = alb_message.get('time', '')
                try:
                    dt = datetime.fromisoformat(time_str.replace('Z', '+00:00'))
                    timestamp = int(dt.timestamp() * 1000000)
                except:
                    timestamp = 0
                
                processing_times = alb_message.get('request_processing_times', {})
                
                row = {
                    'request_id': alb_message.get('request_id', ''),
                    'time': timestamp,
                    'type': alb_message.get('type', ''),
                    'authority': alb_message.get('authority', ''),
                    'backend_group_id': alb_message.get('backend_group_id', ''),
                    'backend_ip': alb_message.get('backend_ip', ''),
                    'backend_name': alb_message.get('backend_name', ''),
                    'backend_port': alb_message.get('backend_port', 0),
                    'cipher_suite': alb_message.get('cipher_suite', ''),
                    'client_certificate_subject': alb_message.get('client_certificate_subject', ''),
                    'client_ip': alb_message.get('client_ip', ''),
                    'client_port': alb_message.get('client_port', 0),
                    'http_method': alb_message.get('http_method', ''),
                    'http_router_id': alb_message.get('http_router_id', ''),
                    'http_status': alb_message.get('http_status', 0),
                    'http_version': alb_message.get('http_version', ''),
                    'load_balancer_id': alb_message.get('load_balancer_id', ''),
                    'request_body_bytes': alb_message.get('request_body_bytes', 0),
                    'request_headers_bytes': alb_message.get('request_headers_bytes', 0),
                    'request_uri': alb_message.get('request_uri', ''),
                    'response_body_bytes': alb_message.get('response_body_bytes', 0),
                    'response_headers_bytes': alb_message.get('response_headers_bytes', 0),
                    'route_name': alb_message.get('route_name', ''),
                    'server_certificate_subject': alb_message.get('server_certificate_subject', ''),
                    'sni_hostname': alb_message.get('sni_hostname', ''),
                    'tls_version': alb_message.get('tls_version', ''),
                    'user_agent': alb_message.get('user_agent', ''),
                    'virtual_host_name': alb_message.get('virtual_host_name', ''),
                    'x_forwarded_for': alb_message.get('x_forwarded_for', ''),
                    # Request processing times
                    'backend_processing_time': processing_times.get('backend_processing_time', 0.0),
                    'backend_response_time': processing_times.get('backend_response_time', 0.0),
                    'request_processing_time': processing_times.get('request_processing_time', 0.0),
                    'request_rx_time': processing_times.get('request_rx_time', 0.0),
                    'request_time': processing_times.get('request_time', 0.0),
                    'request_tx_time': processing_times.get('request_tx_time', 0.0),
                    'response_processing_time': processing_times.get('response_processing_time', 0.0),
                    'response_rx_time': processing_times.get('response_rx_time', 0.0),
                    'response_start_time': processing_times.get('response_start_time', 0.0),
                    'response_tx_time': processing_times.get('response_tx_time', 0.0),
                    # SmartWebSecurity as JSON
                    'smartwebsecurity': alb_message.get('smartwebsecurity', {})
                }

                rows_to_insert.append(row)

                if verboseLogging:
                    logger.info(f'Prepared row: {row}')

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
