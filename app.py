from flask import Flask, jsonify
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import time

app = Flask(__name__)

REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint', 'status'])
REQUEST_LATENCY = Histogram('http_request_duration_seconds', 'HTTP request latency', ['endpoint'])

@app.route('/health')
def health():
    return jsonify(status='healthy', service='python-devops-app'), 200

@app.route('/ready')
def ready():
    return jsonify(status='ready'), 200

@app.route('/')
def index():
    REQUEST_COUNT.labels(method='GET', endpoint='/', status='200').inc()
    return jsonify(message='GitOps Demo App', version='1.0.0'), 200

@app.route('/metrics')
def metrics():
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
