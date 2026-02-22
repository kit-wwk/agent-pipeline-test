# Quickstart: Health Check Endpoint

**Feature Branch**: `001-health-endpoint`
**Date**: 2026-02-22

## Prerequisites

- Python 3.11+
- pip or uv package manager

## Setup

### 1. Create Virtual Environment

```bash
# Using venv
python3.11 -m venv .venv
source .venv/bin/activate

# Or using uv
uv venv
source .venv/bin/activate
```

### 2. Install Dependencies

```bash
pip install fastapi uvicorn[standard] pydantic pytest httpx
```

Or create `requirements.txt`:

```text
fastapi>=0.109.0
uvicorn[standard]>=0.27.0
pydantic>=2.0.0
pytest>=8.0.0
httpx>=0.27.0
```

Then run:

```bash
pip install -r requirements.txt
```

### 3. Initialize Database (for testing)

```bash
# Create test SQLite database
python -c "import sqlite3; sqlite3.connect('health_test.db').close()"
```

## Running the Service

### Development Server

```bash
uvicorn src.app.main:app --reload --port 8080
```

### Production Server

```bash
uvicorn src.app.main:app --host 0.0.0.0 --port 8080 --workers 4
```

## Testing Endpoints

### Liveness Probe

```bash
curl http://localhost:8080/health/live
```

Expected response:

```json
{"status": "UP", "timestamp": "2026-02-22T10:30:00Z"}
```

### Readiness Probe

```bash
curl http://localhost:8080/health/ready
```

Expected response (healthy):

```json
{
  "status": "UP",
  "timestamp": "2026-02-22T10:30:00Z",
  "checks": {
    "database": {"status": "UP", "response_time_ms": 12.5},
    "disk": {"status": "UP", "path": "/", "percent_free": 45.2, "threshold": 10}
  }
}
```

### Full Health Check

```bash
curl http://localhost:8080/health
```

## Running Tests

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=src --cov-report=term-missing

# Run specific test file
pytest tests/integration/test_health_endpoint.py -v
```

## Kubernetes Integration

### Deployment Configuration

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: health-service
spec:
  template:
    spec:
      containers:
        - name: health-service
          image: health-service:latest
          ports:
            - containerPort: 8080
          livenessProbe:
            httpGet:
              path: /health/live
              port: 8080
            initialDelaySeconds: 3
            periodSeconds: 10
            timeoutSeconds: 1
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 5
            timeoutSeconds: 2
            failureThreshold: 3
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_PATH` | `./health_test.db` | Path to SQLite database file |
| `HEALTH_DISK_PATH` | `/` | Filesystem path to monitor |
| `DISK_SPACE_WARNING_THRESHOLD` | `20` | Warning threshold (% free) |
| `DISK_SPACE_CRITICAL_THRESHOLD` | `10` | Critical threshold (% free) |
| `DB_CHECK_TIMEOUT_MS` | `200` | Database check timeout |

## Docker Build

```dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ ./src/

EXPOSE 8080
CMD ["uvicorn", "src.app.main:app", "--host", "0.0.0.0", "--port", "8080"]
```

Build and run:

```bash
docker build -t health-service .
docker run -p 8080:8080 health-service
```

## API Documentation

Once running, access the auto-generated API docs:

- Swagger UI: http://localhost:8080/docs
- ReDoc: http://localhost:8080/redoc
- OpenAPI JSON: http://localhost:8080/openapi.json

## Troubleshooting

### Database Check Fails

1. Verify database file exists: `ls -la health_test.db`
2. Check file permissions: `chmod 644 health_test.db`
3. Test connection manually: `sqlite3 health_test.db "SELECT 1;"`

### Disk Check Shows DOWN

1. Check disk space: `df -h /`
2. Verify monitored path exists: `ls -la $HEALTH_DISK_PATH`
3. Adjust threshold if needed: `export DISK_SPACE_CRITICAL_THRESHOLD=5`

### Timeout Issues

1. Increase timeout: `export DB_CHECK_TIMEOUT_MS=500`
2. Check for I/O bottlenecks: `iostat -x 1`
3. Verify no database locks: `fuser health_test.db`
