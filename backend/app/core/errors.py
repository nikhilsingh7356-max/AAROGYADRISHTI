"""Application error taxonomy and FastAPI exception handlers.

Every error returned to a client uses the same envelope::

    {"error": {"code": "not_found", "message": "...", "details": [...]}}

Internal exceptions are logged server-side; clients never receive stack
traces, SQL statements or driver messages.
"""

from __future__ import annotations

from typing import Any

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core.logging import get_logger

logger = get_logger(__name__)

# Machine-readable error codes (stable contract for mobile clients).
CODE_BAD_REQUEST = "bad_request"
CODE_VALIDATION_ERROR = "validation_error"
CODE_AUTHENTICATION_FAILED = "authentication_failed"
CODE_FORBIDDEN = "forbidden"
CODE_NOT_FOUND = "not_found"
CODE_CONFLICT = "conflict"
CODE_PAYLOAD_TOO_LARGE = "payload_too_large"
CODE_UNPROCESSABLE = "unprocessable_entity"
CODE_RATE_LIMITED = "rate_limited"
CODE_SERVICE_UNAVAILABLE = "service_unavailable"
CODE_INTERNAL_ERROR = "internal_error"

_STATUS_TO_CODE = {
    status.HTTP_400_BAD_REQUEST: CODE_BAD_REQUEST,
    status.HTTP_401_UNAUTHORIZED: CODE_AUTHENTICATION_FAILED,
    status.HTTP_403_FORBIDDEN: CODE_FORBIDDEN,
    status.HTTP_404_NOT_FOUND: CODE_NOT_FOUND,
    status.HTTP_405_METHOD_NOT_ALLOWED: CODE_BAD_REQUEST,
    status.HTTP_409_CONFLICT: CODE_CONFLICT,
    status.HTTP_413_REQUEST_ENTITY_TOO_LARGE: CODE_PAYLOAD_TOO_LARGE,
    status.HTTP_422_UNPROCESSABLE_ENTITY: CODE_UNPROCESSABLE,
    status.HTTP_429_TOO_MANY_REQUESTS: CODE_RATE_LIMITED,
    status.HTTP_503_SERVICE_UNAVAILABLE: CODE_SERVICE_UNAVAILABLE,
}


def error_body(code: str, message: str, details: Any | None = None) -> dict[str, Any]:
    """Build the standard error envelope."""
    body: dict[str, Any] = {"error": {"code": code, "message": message}}
    if details is not None:
        body["error"]["details"] = details
    return body


class AppError(Exception):
    """Base class for expected, user-safe application errors."""

    status_code: int = status.HTTP_500_INTERNAL_SERVER_ERROR
    code: str = CODE_INTERNAL_ERROR
    default_message: str = "Something went wrong. Please try again."

    def __init__(
        self,
        message: str | None = None,
        *,
        details: Any | None = None,
        code: str | None = None,
        status_code: int | None = None,
    ) -> None:
        self.message = message or self.default_message
        self.details = details
        if code:
            self.code = code
        if status_code:
            self.status_code = status_code
        super().__init__(self.message)


class BadRequestError(AppError):
    status_code = status.HTTP_400_BAD_REQUEST
    code = CODE_BAD_REQUEST
    default_message = "The request could not be processed."


class ValidationFailedError(AppError):
    status_code = status.HTTP_422_UNPROCESSABLE_ENTITY
    code = CODE_VALIDATION_ERROR
    default_message = "Some of the information provided is not valid."


class AuthenticationError(AppError):
    status_code = status.HTTP_401_UNAUTHORIZED
    code = CODE_AUTHENTICATION_FAILED
    default_message = "Your session has expired. Please sign in again."


class ForbiddenError(AppError):
    status_code = status.HTTP_403_FORBIDDEN
    code = CODE_FORBIDDEN
    default_message = "You do not have access to this resource."


class NotFoundError(AppError):
    status_code = status.HTTP_404_NOT_FOUND
    code = CODE_NOT_FOUND
    default_message = "We could not find what you were looking for."


class ConflictError(AppError):
    status_code = status.HTTP_409_CONFLICT
    code = CODE_CONFLICT
    default_message = "That entry already exists."


class ServiceUnavailableError(AppError):
    status_code = status.HTTP_503_SERVICE_UNAVAILABLE
    code = CODE_SERVICE_UNAVAILABLE
    default_message = "AarogyaDrishti is temporarily unavailable. Please try again shortly."


def register_exception_handlers(app: FastAPI) -> None:
    """Attach all exception handlers to the FastAPI application."""

    @app.exception_handler(AppError)
    async def _app_error(_: Request, exc: AppError) -> JSONResponse:
        headers = {"WWW-Authenticate": "Bearer"} if exc.status_code == 401 else None
        return JSONResponse(
            status_code=exc.status_code,
            content=error_body(exc.code, exc.message, exc.details),
            headers=headers,
        )

    @app.exception_handler(StarletteHTTPException)
    async def _http_error(_: Request, exc: StarletteHTTPException) -> JSONResponse:
        code = _STATUS_TO_CODE.get(exc.status_code, CODE_INTERNAL_ERROR)
        message = exc.detail if isinstance(exc.detail, str) else "Request failed."
        headers = {"WWW-Authenticate": "Bearer"} if exc.status_code == 401 else None
        return JSONResponse(status_code=exc.status_code, content=error_body(code, message), headers=headers)

    @app.exception_handler(RequestValidationError)
    async def _validation_error(_: Request, exc: RequestValidationError) -> JSONResponse:
        details = [
            {
                "field": ".".join(str(part) for part in error.get("loc", ()) if part not in ("body", "query", "path")),
                "message": error.get("msg", "Invalid value"),
                "type": error.get("type", "value_error"),
            }
            for error in exc.errors()
        ]
        return JSONResponse(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            content=error_body(
                CODE_VALIDATION_ERROR,
                "Some of the information provided is not valid.",
                details,
            ),
        )

    @app.exception_handler(IntegrityError)
    async def _integrity_error(_: Request, exc: IntegrityError) -> JSONResponse:
        logger.warning("Database integrity error: %s", exc.orig)
        return JSONResponse(
            status_code=status.HTTP_409_CONFLICT,
            content=error_body(CODE_CONFLICT, "That entry already exists or conflicts with existing data."),
        )

    @app.exception_handler(SQLAlchemyError)
    async def _database_error(_: Request, exc: SQLAlchemyError) -> JSONResponse:
        logger.exception("Database error: %s", type(exc).__name__)
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content=error_body(CODE_SERVICE_UNAVAILABLE, "We could not save your data right now. Please retry."),
        )

    @app.exception_handler(Exception)
    async def _unhandled(_: Request, exc: Exception) -> JSONResponse:
        logger.exception("Unhandled error: %s", type(exc).__name__)
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content=error_body(CODE_INTERNAL_ERROR, "Something went wrong on our side. Please try again."),
        )
