# Research: Health Check Endpoint

**Feature Branch**: `001-health-endpoint`
**Date**: 2026-02-22
**Status**: Complete

## Summary

Research to resolve NEEDS CLARIFICATION items from Technical Context for implementing an HTTP health check endpoint with database and disk space monitoring for Kubernetes environments.

---

## Decision 1: Language and Framework

**Decision**: Python 3.11 + FastAPI

**Rationale**:
- Best balance of simplicity and proper patterns for a test repository
- Native async support enables concurrent health checks (DB + disk within 500ms budget)
- Built-in JSON serialization with Pydantic models
- Automatic OpenAPI/Swagger documentation generation
- Excellent testability with built-in TestClient
- Strong Kubernetes health check pattern support in ecosystem

**Alternatives Considered**:

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| Go + net/http | Single binary, K8s native, fastest | More verbose, overkill for test repo | Good for production, not ideal here |
| Python + Flask | Simple, minimal | No async, less modern | FastAPI is strictly better for this use case |
| Node.js + Express | Familiar to web devs | node_modules bloat, callback complexity | Dependency overhead not justified |
| Shell + HTTP server | No compilation | Fragile, poor JSON handling, hard to test | Not suitable for HTTP services |

---

## Decision 2: Database Type

**Decision**: SQLite (file-based)

**Rationale**:
- Zero configuration - no external server required
- Portable and CI/CD friendly (runs anywhere Python runs)
- Demonstrates all important health check patterns
- File-based allows testing real I/O health (vs pure in-memory)
- Sufficient for test repository scope

**Alternatives Considered**:

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| PostgreSQL | Production-realistic, network testing | Requires server/Docker, complex setup | Overkill for test repo |
| SQLite in-memory | Fastest, no persistence | Resets on restart, no I/O testing | Good for unit tests only |
| No database | Simplest | Doesn't demonstrate DB health patterns | Doesn't meet spec requirements |

**Implementation Pattern**:
- Health check query: `SELECT 1` (industry standard, minimal overhead)
- Timeout: 200ms (fits within 500ms total budget)
- Connection per check (no connection pooling for simplicity)

---

## Decision 3: Disk Space Monitoring

**Decision**: Python `shutil.disk_usage()` with configurable thresholds

**Rationale**:
- Built into Python standard library (no external dependencies)
- Returns total, used, and free bytes directly
- Cross-platform (works on Linux and macOS)
- Simpler than parsing `df` output

**Thresholds** (industry standard):

| Level | Threshold | Status |
|-------|-----------|--------|
| HEALTHY | >= 20% free | UP |
| WARNING | 10-20% free | WARNING |
| CRITICAL | < 10% free | DOWN |

**Configuration**:
- Default path: `/` (root filesystem)
- Configurable via `HEALTH_DISK_PATH` environment variable
- Configurable thresholds via `DISK_SPACE_WARNING_THRESHOLD` and `DISK_SPACE_CRITICAL_THRESHOLD`

**Alternatives Considered**:

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| `df` command parsing | Universal, POSIX | Shell dependency, parsing complexity | `shutil` is cleaner in Python |
| `os.statvfs()` | Low-level control | More complex API | `shutil.disk_usage()` wraps this |
| `psutil` library | Rich system info | External dependency | Unnecessary for disk space only |

---

## Decision 4: Testing Framework

**Decision**: pytest with FastAPI TestClient

**Rationale**:
- pytest is the de facto Python testing standard
- FastAPI's TestClient allows synchronous testing of async endpoints
- Native assertion introspection (no need for `self.assertEqual`)
- Rich plugin ecosystem (coverage, fixtures, etc.)

**Test Structure**:
```
tests/
├── unit/
│   ├── test_database_check.py
│   └── test_disk_check.py
├── integration/
│   └── test_health_endpoint.py
└── conftest.py
```

---

## Decision 5: Project Structure

**Decision**: Single service structure (src/ layout)

**Rationale**:
- Simple feature with single endpoint
- No frontend/backend separation needed
- Standard Python project layout

**Structure**:
```
src/
├── app/
│   ├── __init__.py
│   ├── main.py              # FastAPI app, routes
│   ├── models.py            # Pydantic response models
│   └── checks/
│       ├── __init__.py
│       ├── database.py      # DB connectivity check
│       └── disk.py          # Disk space check
└── config.py                # Configuration management

tests/
├── unit/
├── integration/
└── conftest.py

requirements.txt
Dockerfile
```

---

## Decision 6: API Design

**Decision**: Separate liveness and readiness endpoints following Kubernetes conventions

**Endpoints**:

| Path | Purpose | Checks | K8s Probe |
|------|---------|--------|-----------|
| `GET /health/live` | Is process alive? | None (always returns UP) | livenessProbe |
| `GET /health/ready` | Can serve traffic? | DB + Disk | readinessProbe |
| `GET /health` | Full status | DB + Disk + details | Manual inspection |

**Response Format**:
```json
{
  "status": "UP",
  "timestamp": "2026-02-22T10:30:00Z",
  "checks": {
    "database": {
      "status": "UP",
      "response_time_ms": 12
    },
    "disk": {
      "status": "UP",
      "path": "/",
      "percent_free": 45.2,
      "threshold": 10
    }
  }
}
```

---

## Decision 7: Error Handling and Security

**Decision**: Sanitized error messages with categorization

**Rationale**:
- Health endpoints may be unauthenticated (K8s probes)
- Error details must not expose sensitive information
- Generic categories provide debugging value without risk

**Safe to Include**:
- Component name (database, disk)
- Status (UP/DOWN/WARNING)
- Generic error category ("Connection failed", "Timeout")
- Response time
- Threshold values

**Never Include**:
- Connection strings or credentials
- Internal file paths
- Stack traces
- Query details

---

## Implementation Dependencies

**Python Packages** (requirements.txt):
```
fastapi>=0.109.0
uvicorn[standard]>=0.27.0
pydantic>=2.0.0
pytest>=8.0.0
httpx>=0.27.0  # For TestClient
```

**No external dependencies needed for**:
- SQLite (built into Python)
- Disk space monitoring (shutil, stdlib)

---

## Timeout Budget

Total endpoint timeout: 500ms

| Component | Allocated | Notes |
|-----------|-----------|-------|
| Database check | 200ms | With asyncio.wait_for() |
| Disk space check | 50ms | Very fast, local syscall |
| JSON serialization | 10ms | Pydantic overhead |
| Network/overhead | 240ms | Buffer for HTTP, routing |

Concurrent execution of DB and disk checks ensures both complete within budget.

---

## Resolved NEEDS CLARIFICATION

| Item | Resolution |
|------|------------|
| Language/Version | Python 3.11 |
| Primary Dependencies | FastAPI, uvicorn, pydantic |
| Storage | SQLite (file-based) |
| Testing | pytest with FastAPI TestClient |
| Target Platform | Linux server (K8s) - confirmed |
| Performance Goals | <500ms response time - achievable |
| Constraints | <500ms p95, real-time - design supports |
