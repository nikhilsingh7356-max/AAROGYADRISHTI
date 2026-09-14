"""Authentication + account endpoints."""

from __future__ import annotations

from fastapi import APIRouter

from app.api.deps import CurrentUser, DbSession
from app.core.errors import AuthenticationError
from app.schemas.auth import (
    AuthStatusResponse,
    ForgotPasswordRequest,
    FirebaseAuthRequest,
    LoginRequest,
    RefreshTokenRequest,
    RegisterRequest,
    ResetPasswordRequest,
    TokenResponse,
    UserResponse,
)
from app.schemas.common import Message
from app.services.auth import (
    authenticate,
    authenticate_firebase,
    logout,
    refresh_access_token,
    register,
    request_password_reset,
    reset_password,
)
from app.services.demo import seed_demo_user

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=TokenResponse, status_code=201)
def register_user(payload: RegisterRequest, db: DbSession):
    user, access, refresh = register(db, payload)
    return TokenResponse(access_token=access, refresh_token=refresh, user=UserResponse.model_validate(user))


@router.post("/login", response_model=TokenResponse)
def login_user(payload: LoginRequest, db: DbSession):
    user, access, refresh = authenticate(db, payload.email, payload.password)
    return TokenResponse(access_token=access, refresh_token=refresh, user=UserResponse.model_validate(user))


@router.post("/logout", response_model=Message)
def logout_user(db: DbSession, user: CurrentUser):
    logout(db, user)
    return Message(message="Signed out successfully.")


@router.get("/status", response_model=AuthStatusResponse)
def auth_status(user: CurrentUser):
    """Return the currently authenticated user (used to restore a session)."""
    return AuthStatusResponse(
        authenticated=True,
        user=UserResponse.model_validate(user),
    )


@router.post("/refresh", response_model=TokenResponse)
def refresh_token(payload: RefreshTokenRequest, db: DbSession):
    user, access, new_refresh = refresh_access_token(db, payload.refresh_token)
    return TokenResponse(access_token=access, refresh_token=new_refresh, user=UserResponse.model_validate(user))


@router.post("/forgot-password", response_model=Message)
def forgot_password(payload: ForgotPasswordRequest, db: DbSession):
    _, token = request_password_reset(db, payload.email)
    # Phase 1: no SMTP integration - the token is returned so the mobile
    # app / dev console can open a reset flow. Production wires an emailer.
    return Message(message="If this account exists, a reset link has been issued.")


@router.post("/reset-password", response_model=Message)
def reset_password_route(payload: ResetPasswordRequest, db: DbSession):
    reset_password(db, payload.token, payload.new_password)
    return Message(message="Password updated. Please sign in again.")


@router.post("/demo", response_model=TokenResponse)
def demo_account(db: DbSession):
    """Dev-only demo account with 7 days of clearly-labelled demo data."""
    from app.core.config import get_settings

    if not get_settings().allow_demo_data:
        raise AuthenticationError("Demo access is disabled.")
    user, _, _ = seed_demo_user(db)
    _, access, refresh = authenticate(db, user.email, "demo12345")
    return TokenResponse(access_token=access, refresh_token=refresh, user=UserResponse.model_validate(user))


@router.post("/firebase", response_model=TokenResponse)
def firebase_login(payload: FirebaseAuthRequest, db: DbSession):
    user, access, refresh = authenticate_firebase(db, payload.id_token)
    return TokenResponse(access_token=access, refresh_token=refresh, user=UserResponse.model_validate(user))