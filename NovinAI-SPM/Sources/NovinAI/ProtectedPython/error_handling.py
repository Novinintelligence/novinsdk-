"""Centralised error primitives for the NovinAI security platform."""

from __future__ import annotations

import asyncio
import json
import logging
import time
import traceback
from dataclasses import dataclass, field
from typing import Any, Dict, Optional


logger = logging.getLogger(__name__)


@dataclass(slots=True)
class NovinAIError(Exception):
    """Base exception for NovinAI with structured, serialisable payloads."""

    code: str
    message: str
    details: Optional[Dict[str, Any]] = None
    stack_trace: Optional[str] = field(default=None, repr=False)

    def __post_init__(self) -> None:
        if self.stack_trace is None:
            self.stack_trace = traceback.format_exc(limit=12)

    # ------------------------------------------------------------------
    # Serialisation helpers
    # ------------------------------------------------------------------
    def to_dict(self) -> Dict[str, Any]:
        payload: Dict[str, Any] = {
            "error": True,
            "errorCode": self.code,
            "message": self.message,
            "details": self.details or {},
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        }
        if self.stack_trace:
            payload["stackTrace"] = self.stack_trace
        return payload

    def to_json(self) -> str:
        return json.dumps(self.to_dict(), default=self._json_default)

    @staticmethod
    def _json_default(value: Any) -> Any:
        if isinstance(value, set):
            return sorted(value)
        if isinstance(value, bytes):
            return value.decode("utf-8", errors="replace")
        raise TypeError(f"Object of type {type(value).__name__} is not JSON serialisable")

    # ------------------------------------------------------------------
    # Logging helpers
    # ------------------------------------------------------------------
    def log(self, level: int = logging.ERROR) -> None:
        logger.log(level, self.to_json())

    async def log_async(self, level: int = logging.ERROR) -> None:
        loop = asyncio.get_running_loop()
        await loop.run_in_executor(None, self.log, level)


class ValidationError(NovinAIError):
    def __init__(self, message: str, fields: Dict[str, str]):
        super().__init__(
            code="VALIDATION_ERROR",
            message=message,
            details={"validationErrors": fields},
        )


class RateLimitError(NovinAIError):
    def __init__(self, window_seconds: int, max_requests: int, retry_after: Optional[int] = None):
        super().__init__(
            code="RATE_LIMIT_EXCEEDED",
            message=f"Rate limit exceeded: {max_requests} requests per {window_seconds} seconds",
            details={
                "windowSeconds": window_seconds,
                "maxRequests": max_requests,
                "retryAfter": retry_after or window_seconds,
                "backoffStrategy": "exponential",
            },
        )


class ProcessingError(NovinAIError):
    def __init__(self, message: str, original_error: Optional[Exception] = None):
        details: Dict[str, Any] = {}
        if original_error is not None:
            details["originalError"] = repr(original_error)
            details["retryable"] = isinstance(original_error, (TimeoutError, ConnectionError))
        super().__init__(
            code="PROCESSING_ERROR",
            message=message,
            details=details or None,
        )


class InitializationError(NovinAIError):
    def __init__(self, message: str, component: str):
        super().__init__(
            code="INITIALIZATION_ERROR",
            message=message,
            details={
                "component": component,
                "recoverySteps": ["verify configuration", "restart service"],
            },
        )


class MemoryError(NovinAIError):
    def __init__(self, current_mb: float, max_mb: float):
        super().__init__(
            code="MEMORY_LIMIT_EXCEEDED",
            message=f"Memory usage ({current_mb:.1f}MB) exceeds limit ({max_mb:.1f}MB)",
            details={
                "currentMb": current_mb,
                "maxMb": max_mb,
                "gcAttempted": True,
            },
        )


__all__ = [
    "NovinAIError",
    "ValidationError",
    "RateLimitError",
    "ProcessingError",
    "InitializationError",
    "MemoryError",
]
