# Data Model: Health Check Endpoint

**Feature Branch**: `001-health-endpoint`
**Date**: 2026-02-22

## Entities

### HealthStatus (Enum)

Overall application health indicator.

| Value | Description |
|-------|-------------|
| `UP` | All components healthy, service can accept traffic |
| `DOWN` | One or more critical components unhealthy |
| `WARNING` | Components approaching thresholds but still operational |

**Validation Rules**:
- Must be one of the defined enum values
- Response HTTP status: 200 for UP/WARNING, 503 for DOWN

---

### ComponentHealth

Individual health indicator for a monitored dependency.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `status` | HealthStatus | Yes | Component health status |
| `response_time_ms` | float | No | Time taken for health check in milliseconds |
| `error` | string | No | Sanitized error message (only when DOWN) |
| `details` | object | No | Component-specific details |

**Validation Rules**:
- `response_time_ms` must be >= 0 when present
- `error` must not contain sensitive information (credentials, paths)
- `details` schema varies by component type

---

### DatabaseHealth (extends ComponentHealth)

Health indicator for database connectivity.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `status` | HealthStatus | Yes | Database connection status |
| `response_time_ms` | float | Yes | Query execution time in milliseconds |
| `error` | string | No | Sanitized connection error |

**Validation Rules**:
- Check must complete within 200ms timeout
- Uses `SELECT 1` query for minimal overhead
- Error messages must be sanitized (no connection strings)

**State Transitions**:
```
[Start] --> Check Connection --> [Connected?]
                                    |
                          Yes ------+------ No
                           |               |
                           v               v
                     Execute Query    Return DOWN
                           |          + error
                           v
                     [Success?]
                        |
              Yes ------+------ No/Timeout
               |               |
               v               v
          Return UP       Return DOWN
          + timing        + error
```

---

### DiskHealth (extends ComponentHealth)

Health indicator for disk space availability.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `status` | HealthStatus | Yes | Disk space status |
| `path` | string | Yes | Monitored filesystem path |
| `total_bytes` | integer | No | Total disk space in bytes |
| `free_bytes` | integer | No | Available disk space in bytes |
| `percent_free` | float | No | Percentage of free space |
| `threshold` | integer | No | Critical threshold percentage |

**Validation Rules**:
- `path` must be a valid filesystem path
- `percent_free` must be 0-100
- `threshold` default is 10 (10% free = critical)

**State Transitions**:
```
[Start] --> Read Disk Stats --> [Success?]
                                    |
                          Yes ------+------ No
                           |               |
                           v               v
                    Calculate %       Return DOWN
                    Free Space        + error
                           |
                           v
                    [% Free >= 20?]
                        |
              Yes ------+------ No
               |               |
               v               v
          Return UP     [% Free >= 10?]
                            |
                  Yes ------+------ No
                   |               |
                   v               v
             Return WARNING   Return DOWN
```

---

### HealthResponse

Complete health check response structure.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `status` | HealthStatus | Yes | Overall health (worst of all components) |
| `timestamp` | datetime | Yes | ISO 8601 timestamp of check |
| `checks` | object | No | Map of component name to ComponentHealth |

**Validation Rules**:
- `status` is computed as worst status among all components
- `timestamp` must be UTC in ISO 8601 format
- `checks` is optional for liveness probe (always empty)

**Status Aggregation Logic**:
```
If ANY component is DOWN -> overall DOWN
Else if ANY component is WARNING -> overall WARNING
Else -> overall UP
```

---

## Pydantic Models (Python)

```python
from enum import Enum
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field

class HealthStatus(str, Enum):
    UP = "UP"
    DOWN = "DOWN"
    WARNING = "WARNING"

class ComponentHealth(BaseModel):
    status: HealthStatus
    response_time_ms: Optional[float] = None
    error: Optional[str] = None

class DatabaseHealth(ComponentHealth):
    pass  # Uses base fields

class DiskHealth(ComponentHealth):
    path: str
    total_bytes: Optional[int] = None
    free_bytes: Optional[int] = None
    percent_free: Optional[float] = None
    threshold: int = 10

class HealthResponse(BaseModel):
    status: HealthStatus
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    checks: Optional[dict[str, ComponentHealth]] = None
```

---

## Response Examples

### Healthy System

```json
{
  "status": "UP",
  "timestamp": "2026-02-22T10:30:00Z",
  "checks": {
    "database": {
      "status": "UP",
      "response_time_ms": 12.5
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

### Database Failure

```json
{
  "status": "DOWN",
  "timestamp": "2026-02-22T10:30:00Z",
  "checks": {
    "database": {
      "status": "DOWN",
      "response_time_ms": 200.0,
      "error": "Database connection failed"
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

### Low Disk Space Warning

```json
{
  "status": "WARNING",
  "timestamp": "2026-02-22T10:30:00Z",
  "checks": {
    "database": {
      "status": "UP",
      "response_time_ms": 15.0
    },
    "disk": {
      "status": "WARNING",
      "path": "/",
      "percent_free": 15.3,
      "threshold": 10
    }
  }
}
```

### Liveness Probe Response

```json
{
  "status": "UP",
  "timestamp": "2026-02-22T10:30:00Z"
}
```
