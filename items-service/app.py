from flask import Flask, request, jsonify
import psycopg2
import psycopg2.extras
import os
from datetime import datetime, timezone
import uuid
import requests
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Audit service configuration
AUDIT_SERVICE_URL = os.environ.get('AUDIT_SERVICE_URL', 'http://audit-service:8081')

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

def log_audit(action, details):
    """Send audit log to the audit service. Non-blocking - failures won't stop the request."""
    try:
        response = requests.post(
            f'{AUDIT_SERVICE_URL}/audit/log',
            json={
                'action': action,
                'details': details,
                'timestamp': datetime.now(timezone.utc).isoformat()
            },
            timeout=2
        )
        if response.status_code != 201:
            logger.warning(f"Audit logging returned status {response.status_code}")
    except requests.exceptions.Timeout:
        logger.warning(f"Audit logging timed out for action: {action}")
    except requests.exceptions.RequestException as e:
        logger.warning(f"Audit logging failed for action {action}: {e}")
    except Exception as e:
        logger.error(f"Unexpected error in audit logging: {e}")

@app.route('/', methods=['GET'])
def root():
    """Welcome endpoint."""
    return jsonify({
        'service': 'Items Service',
        'version': '1.0.0',
        'endpoints': {
            'create': 'POST /items',
            'list': 'GET /items',
            'health': 'GET /health'
        }
    })

@app.route('/items', methods=['POST'])
def create_item():
    """Create a new item."""
    try:
        data = request.get_json()
        
        # Validate input
        if not data or 'name' not in data:
            return jsonify({'error': 'Name is required'}), 400
        
        # Generate item data
        item_id = str(uuid.uuid4())
        name = data.get('name')
        description = data.get('description', '')
        created_at = datetime.now(timezone.utc)
        
        # Save to database
        conn = get_db_connection()
        cur = conn.cursor()
        
        cur.execute(
            'INSERT INTO items (id, name, description, created_at) VALUES (%s, %s, %s, %s)',
            (item_id, name, description, created_at)
        )
        
        conn.commit()
        cur.close()
        conn.close()
        
        # Log audit event (non-blocking)
        log_audit('CREATE_ITEM', {
            'item_id': item_id,
            'name': name
        })
        
        logger.info(f"Created item: {item_id}")
        
        return jsonify({
            'id': item_id,
            'name': name,
            'description': description,
            'created_at': created_at.isoformat()
        }), 201
        
    except Exception as e:
        logger.error(f"Error creating item: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/items', methods=['GET'])
def list_items():
    """List all items."""
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        
        cur.execute('SELECT * FROM items ORDER BY created_at DESC')
        items = cur.fetchall()
        
        cur.close()
        conn.close()
        
        # Convert datetime and UUID to string for JSON serialization
        for item in items:
            item['id'] = str(item['id'])
            item['created_at'] = item['created_at'].isoformat()
        
        # Log audit event (non-blocking)
        log_audit('LIST_ITEMS', {
            'count': len(items)
        })
        
        logger.info(f"Listed {len(items)} items")
        
        return jsonify(items)
        
    except Exception as e:
        logger.error(f"Error listing items: {e}")
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
            'service': 'items-service',
            'database': 'connected'
        }), 200
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return jsonify({
            'status': 'unhealthy',
            'service': 'items-service',
            'database': 'disconnected',
            'error': str(e)
        }), 503

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
