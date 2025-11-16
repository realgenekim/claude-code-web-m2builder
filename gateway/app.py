#!/usr/bin/env python3
"""
GCS Mailbox Gateway - HTTP proxy for sandboxed agents

Allows agents with only `curl` to submit requests to the GCS mailbox.
"""

import os
import json
import subprocess
from datetime import datetime
from flask import Flask, request, jsonify
from functools import wraps

app = Flask(__name__)

# Configuration
GCS_BUCKET = os.environ.get(
    'GCS_BUCKET',
    'gs://gene-m2-bundler-f9a6d1b69e17b97714b0e9cbe141e4ac2c14b18ad6cd'
)
GCS_MAILBOX_PATH = f"{GCS_BUCKET}/mailbox"
GATEWAY_USER = os.environ.get('GATEWAY_USER', 'claude')
GATEWAY_PASS = os.environ.get('GATEWAY_PASS', 'f9a6d1b69e17b97714b0e9cbe141e4ac2c14b18ad6cd')

def check_auth(username, password):
    """Check if username/password combo is valid"""
    return username == GATEWAY_USER and password == GATEWAY_PASS

def requires_auth(f):
    """Decorator for HTTP Basic Auth"""
    @wraps(f)
    def decorated(*args, **kwargs):
        auth = request.authorization
        if not auth or not check_auth(auth.username, auth.password):
            return jsonify({'error': 'Authentication required'}), 401
        return f(*args, **kwargs)
    return decorated

def gsutil_cp(content, gcs_path):
    """Upload content to GCS using gsutil"""
    # Write to temp file first
    import tempfile
    with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.edn') as f:
        f.write(content)
        temp_path = f.name

    try:
        result = subprocess.run(
            ['gsutil', '-q', 'cp', temp_path, gcs_path],
            capture_output=True,
            text=True
        )
        return result.returncode == 0
    finally:
        os.unlink(temp_path)

def gsutil_cat(gcs_path):
    """Read content from GCS"""
    result = subprocess.run(
        ['gsutil', 'cat', gcs_path],
        capture_output=True,
        text=True
    )
    if result.returncode == 0:
        return result.stdout
    return None

def gsutil_ls(gcs_path):
    """List GCS objects"""
    result = subprocess.run(
        ['gsutil', 'ls', gcs_path],
        capture_output=True,
        text=True
    )
    if result.returncode == 0:
        return [line.strip() for line in result.stdout.strip().split('\n') if line.strip()]
    return []

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'gcs-mailbox-gateway',
        'bucket': GCS_BUCKET,
        'timestamp': datetime.utcnow().isoformat() + 'Z'
    })

@app.route('/request', methods=['POST'])
@requires_auth
def submit_request():
    """
    Submit a bundle request to the mailbox

    Body (JSON):
        bundle_id: str - Which bundle to request
        session_id: str (optional) - Your session ID

    Returns:
        request_id: str - ID to check status
        session_id: str - Session ID used
        gcs_path: str - Where request was written
    """
    data = request.get_json()

    if not data or 'bundle_id' not in data:
        return jsonify({'error': 'bundle_id required'}), 400

    bundle_id = data['bundle_id']

    # Generate IDs
    timestamp = int(datetime.utcnow().timestamp() * 1000)
    session_id = data.get('session_id', f'gateway-session-{timestamp}')
    request_id = f'req-{timestamp}'

    # Create EDN request
    edn_request = f'''{{:schema-version "1.0.0"
 :timestamp "{datetime.utcnow().isoformat()}Z"
 :from "{session_id}"
 :session-id "{session_id}"
 :message-id "{request_id}"
 :type :request
 :payload {{:bundle-id "{bundle_id}"
           :priority :normal}}}}'''

    # Upload to GCS
    gcs_path = f"{GCS_MAILBOX_PATH}/requests/{session_id}/{request_id}.edn"

    if gsutil_cp(edn_request, gcs_path):
        return jsonify({
            'status': 'submitted',
            'request_id': request_id,
            'session_id': session_id,
            'gcs_path': gcs_path,
            'bundle_id': bundle_id
        })
    else:
        return jsonify({'error': 'Failed to upload request to GCS'}), 500

@app.route('/status/<session_id>/<request_id>', methods=['GET'])
@requires_auth
def check_status(session_id, request_id):
    """
    Check status of a bundle request

    Returns:
        status: 'pending' | 'completed' | 'error'
        response: dict (if completed)
    """
    # Check for response
    response_path = f"{GCS_MAILBOX_PATH}/responses/{session_id}/{request_id}.edn"

    content = gsutil_cat(response_path)
    if content:
        return jsonify({
            'status': 'completed',
            'response_edn': content,
            'response_path': response_path
        })

    # Check if request still pending
    request_path = f"{GCS_MAILBOX_PATH}/requests/{session_id}/{request_id}.edn"
    if gsutil_cat(request_path):
        return jsonify({
            'status': 'pending',
            'message': 'Request is still being processed'
        })

    # Check if processed (archived)
    processed_path = f"{GCS_MAILBOX_PATH}/processed/{session_id}/{request_id}.edn"
    if gsutil_cat(processed_path):
        return jsonify({
            'status': 'processed',
            'message': 'Request was processed but response not found'
        })

    return jsonify({
        'status': 'not_found',
        'message': 'Request not found'
    }), 404

@app.route('/requests', methods=['GET'])
@requires_auth
def list_requests():
    """List all pending requests"""
    requests_path = f"{GCS_MAILBOX_PATH}/requests/"
    files = gsutil_ls(f"{requests_path}**/*.edn")

    requests = []
    for f in files:
        if f.endswith('.edn') and not f.endswith('.gitkeep'):
            parts = f.split('/')
            if len(parts) >= 2:
                session_id = parts[-2]
                request_id = parts[-1].replace('.edn', '')
                requests.append({
                    'session_id': session_id,
                    'request_id': request_id,
                    'gcs_path': f
                })

    return jsonify({
        'count': len(requests),
        'requests': requests
    })

@app.route('/responses/<session_id>', methods=['GET'])
@requires_auth
def list_responses(session_id):
    """List all responses for a session"""
    responses_path = f"{GCS_MAILBOX_PATH}/responses/{session_id}/"
    files = gsutil_ls(f"{responses_path}*.edn")

    responses = []
    for f in files:
        if f.endswith('.edn') and not f.endswith('.gitkeep'):
            request_id = f.split('/')[-1].replace('.edn', '')
            responses.append({
                'request_id': request_id,
                'gcs_path': f
            })

    return jsonify({
        'session_id': session_id,
        'count': len(responses),
        'responses': responses
    })

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    print(f"Starting GCS Mailbox Gateway on port {port}")
    print(f"  Bucket: {GCS_BUCKET}")
    print(f"  User: {GATEWAY_USER}")
    print(f"  Password: {'*' * len(GATEWAY_PASS)}")
    print()
    print("Endpoints:")
    print("  GET  /health                    - Health check")
    print("  POST /request                   - Submit bundle request")
    print("  GET  /status/<session>/<req>    - Check request status")
    print("  GET  /requests                  - List pending requests")
    print("  GET  /responses/<session>       - List responses for session")
    print()
    app.run(host='0.0.0.0', port=port, debug=True)
