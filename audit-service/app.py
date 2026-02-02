from flask import Flask, request, jsonify
import psycopg2
import psycopg2.extras
import os
from datetime import datetime, timezone
import logging
import json
import time
from prometheus_flask_exporter import PrometheusMetrics
from prometheus_client import Counter, Histogram

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Initialize Prometheus metrics
metrics = PrometheusMetrics(app)

# Add static info metric
metrics.info('app_info', 'Application info', version='1.0.0', service='audit-service')

# Custom metrics
audit_events_total = Counter(
    'audit_events_total',
    'Total number of audit events processed'
)

audit_events_by_action = Counter(
    'audit_events_by_action_total',
    'Total number of audit events by action type',
    ['action']
)

db_query_duration = Histogram(
    'db_query_duration_seconds',
    'Database query duration in seconds',
    ['operation'],
    buckets=[0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0]
)


def get_db_connection():
    """Create a connection to the PostgreSQL database."""
    try:
        conn = psycopg2.connect(
            host=os.environ.get('DB_HOST', 'localhost'),
            port=os.environ.get('DB_PORT', '5432'),
            database=os.environ.get('DB_NAME', 'itemsdb'),
            user=os.environ.get('DB_USER', 'postgres'),
            password=os.environ.get('DB_PASSWORD', 'password')
        )
        return conn
    except Exception as e:
        logger.error(f"Database connection failed: {e}")
        raise


@app.route('/', methods=['GET'])
def root():
    """Welcome endpoint."""
    return jsonify({
        'service': 'Audit Service',
        'version': '1.0.0',
        'endpoints': {
            'log': 'POST /audit/log',
            'list': 'GET /audit/logs',
            'health': 'GET /health',
            'metrics': 'GET /metrics'
        }
    })


@app.route('/audit/log', methods=['POST'])
def log_event():
    """Log an audit event."""
    try:
        data = request.get_json()

        # Validate input
        if not data or 'action' not in data:
            return jsonify({'error': 'Action is required'}), 400

        action = data.get('action')
        details = data.get('details', {})
        timestamp = data.get('timestamp', datetime.now(timezone.utc).isoformat())

        # Save to database with timing
        start_time = time.time()
        conn = get_db_connection()
        cur = conn.cursor()

        cur.execute(
            'INSERT INTO audit_logs (action, details, timestamp) VALUES (%s, %s, %s)',
            (action, json.dumps(details), timestamp)
        )

        conn.commit()
        cur.close()
        conn.close()
        db_query_duration.labels(operation='insert').observe(time.time() - start_time)

        # Increment counters
        audit_events_total.inc()
        audit_events_by_action.labels(action=action).inc()

        logger.info(f"Logged audit event: {action}")

        return jsonify({
            'status': 'logged',
            'action': action,
            'timestamp': timestamp
        }), 201

    except Exception as e:
        logger.error(f"Error logging audit event: {e}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/audit/logs', methods=['GET'])
def list_logs():
    """List audit logs (for testing/debugging)."""
    try:
        # Get optional query parameters
        limit = request.args.get('limit', 100, type=int)
        action = request.args.get('action', None)

        # Query with timing
        start_time = time.time()
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

        if action:
            cur.execute(
                'SELECT * FROM audit_logs WHERE action = %s ORDER BY created_at DESC LIMIT %s',
                (action, limit)
            )
        else:
            cur.execute(
                'SELECT * FROM audit_logs ORDER BY created_at DESC LIMIT %s',
                (limit,)
            )

        logs = cur.fetchall()

        cur.close()
        conn.close()
        db_query_duration.labels(operation='select').observe(time.time() - start_time)

        # Convert datetime and parse JSON details
        for log in logs:
            log['created_at'] = log['created_at'].isoformat()
            if isinstance(log['details'], str):
                try:
                    log['details'] = json.loads(log['details'])
                except:
                    pass

        logger.info(f"Retrieved {len(logs)} audit logs")

        return jsonify(logs)

    except Exception as e:
        logger.error(f"Error retrieving audit logs: {e}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint."""
    try:
        # Check database connection
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute('SELECT 1')
        cur.close()
        conn.close()

        return jsonify({
            'status': 'healthy',
            'service': 'audit-service',
            'database': 'connected'
        }), 200
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return jsonify({
            'status': 'unhealthy',
            'service': 'audit-service',
            'database': 'disconnected',
            'error': str(e)
        }), 503


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8081)
