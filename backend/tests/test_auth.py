"""Authentication API tests."""

from __future__ import annotations

import json


def test_healthcheck(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"


def test_database_failure_returns_safe_envelope(client, monkeypatch):
    from sqlalchemy.exc import OperationalError

    from app.database import session as db_session_module

    class BrokenSessionLocal:
        def __init__(self, *args, **kwargs):
            raise OperationalError("BEGIN", {}, Exception("underlying driver error"))

    monkeypatch.setattr(db_session_module, "SessionLocal", BrokenSessionLocal)

    resp = client.post(
        "/api/v1/auth/register",
        json={"name": "A", "email": "dbdown@example.com", "password": "H3althy!Life"},
    )
    assert resp.status_code == 503
    body = resp.json()
    assert body["error"]["code"] == "service_unavailable"
    # No driver internals / connection string details are exposed to clients.
    assert "underlying driver error" not in json.dumps(body)


def test_register_and_login(client):
    reg = client.post(
        "/api/v1/auth/register",
        json={"name": "Priya", "email": "priya@example.com", "password": "H3althy!Life"},
    )
    assert reg.status_code == 201, reg.text
    body = reg.json()
    assert body["access_token"]
    assert body["user"]["email"] == "priya@example.com"

    login = client.post(
        "/api/v1/auth/login",
        json={"email": "priya@example.com", "password": "H3althy!Life"},
    )
    assert login.status_code == 200
    assert login.json()["access_token"]


def test_firebase_login_provisions_user(client, monkeypatch):
    from app.core.config import get_settings
    from app.services import auth as auth_service

    settings = get_settings()
    monkeypatch.setattr(settings, "auth_provider", "firebase")
    monkeypatch.setattr(
        auth_service,
        "verify_id_token",
        lambda token, configured_settings: {
            "email": "google@example.com",
            "email_verified": True,
            "name": "Google User",
            "aud": configured_settings.firebase_project_id,
        },
    )

    response = client.post("/api/v1/auth/firebase", json={"id_token": "firebase-id-token"})
    assert response.status_code == 200, response.text
    assert response.json()["user"]["email"] == "google@example.com"
    assert response.json()["user"]["email_verified"] is True


def test_register_duplicate_email(client):
    payload = {"name": "A", "email": "dup@example.com", "password": "H3althy!Life"}
    assert client.post("/api/v1/auth/register", json=payload).status_code == 201
    resp = client.post("/api/v1/auth/register", json=payload)
    assert resp.status_code == 409
    assert resp.json()["error"]["code"] == "conflict"


def test_login_wrong_password(client):
    client.post(
        "/api/v1/auth/register",
        json={"name": "A", "email": "a@example.com", "password": "H3althy!Life"},
    )
    resp = client.post("/api/v1/auth/login", json={"email": "a@example.com", "password": "wrong-pass"})
    assert resp.status_code == 401
    assert resp.json()["error"]["code"] == "authentication_failed"


def test_register_weak_password(client):
    # All alphabetical - fails the "must mix letters/numbers/symbols" policy.
    resp = client.post(
        "/api/v1/auth/register",
        json={"name": "A", "email": "weak@example.com", "password": "password"},
    )
    assert resp.status_code == 422


def test_register_invalid_email(client):
    resp = client.post(
        "/api/v1/auth/register",
        json={"name": "A", "email": "not-an-email", "password": "H3althy!Life"},
    )
    assert resp.status_code == 422


def test_protected_route_requires_token(client):
    resp = client.get("/api/v1/profile")
    assert resp.status_code == 401


def test_protected_route_rejects_garbage_token(client):
    resp = client.get("/api/v1/profile", headers={"Authorization": "Bearer nonsense.token.here"})
    assert resp.status_code == 401


def test_auth_status_returns_user(client, auth_headers):
    headers = auth_headers("status@example.com")
    resp = client.get("/api/v1/auth/status", headers=headers)
    assert resp.status_code == 200
    body = resp.json()
    assert body["authenticated"] is True
    assert body["user"]["email"] == "status@example.com"


def test_auth_status_requires_token(client):
    resp = client.get("/api/v1/auth/status")
    assert resp.status_code == 401


def test_logout_invalidates_token(client, auth_headers):
    headers = auth_headers("logout@example.com")
    resp = client.post("/api/v1/auth/logout", headers=headers)
    assert resp.status_code == 200
    resp2 = client.get("/api/v1/profile", headers=headers)
    assert resp2.status_code == 401


def test_forgot_and_reset_password(client):
    email = "reset@example.com"
    client.post("/api/v1/auth/register", json={"name": "R", "email": email, "password": "H3althy!Life"})

    forgot = client.post("/api/v1/auth/forgot-password", json={"email": email})
    assert forgot.status_code == 200

    # Phase 1 has no SMTP: obtain the reset token directly from the service to
    # exercise the full reset endpoint.
    from app.core.config import get_settings
    from app.database.session import SessionLocal
    from app.services.auth import request_password_reset

    with SessionLocal() as db:
        _, token = request_password_reset(db, email)

    resp = client.post(
        "/api/v1/auth/reset-password",
        json={"token": token, "new_password": "Br4nd!NewPass"},
    )
    assert resp.status_code == 200
    # Old password no longer works.
    old = client.post("/api/v1/auth/login", json={"email": email, "password": "H3althy!Life"})
    assert old.status_code == 401


def test_demo_account_seed(client):
    resp = client.post("/api/v1/auth/demo")
    assert resp.status_code == 200, resp.text
    assert resp.json()["access_token"]

    dashboard = client.get(
        "/api/v1/dashboard/today",
        headers={"Authorization": f"Bearer {resp.json()['access_token']}"},
    )
    assert dashboard.status_code == 200
    # Demo user already has 7 days recorded.
    assert dashboard.json()["baseline"]["days_recorded"] == 7


def test_refresh_token_flow(client):
    reg = client.post(
        "/api/v1/auth/register",
        json={"name": "R", "email": "refresh@example.com", "password": "H3althy!Life"},
    )
    refresh = reg.json()["refresh_token"]
    # The refresh token travels in the JSON body - never in the URL query.
    resp = client.post("/api/v1/auth/refresh", json={"refresh_token": refresh})
    assert resp.status_code == 200
    assert resp.json()["access_token"]
    assert resp.json()["refresh_token"] != refresh  # rotation


def test_refresh_token_rejected_in_query_string(client):
    reg = client.post(
        "/api/v1/auth/register",
        json={"name": "R", "email": "q@example.com", "password": "H3althy!Life"},
    )
    refresh = reg.json()["refresh_token"]
    # Passing the token as a query parameter is no longer supported.
    resp = client.post("/api/v1/auth/refresh", params={"refresh_token": refresh})
    assert resp.status_code == 422


def test_delete_account_removes_all_data(client, auth_headers):
    headers = auth_headers("delete@example.com")
    # Create some data: a daily log and a Health Connect link + consent record.
    log = client.post(
        "/api/v1/daily-logs",
        headers=headers,
        json={"date": "2025-01-01", "energy": 7, "stress": 2, "source": "manual"},
    )
    assert log.status_code == 201, log.text
    conn = client.post(
        "/api/v1/health/connect",
        headers=headers,
        json={"provider": "health_connect", "steps_enabled": True, "sleep_enabled": True, "activity_enabled": True},
    )
    assert conn.status_code == 200, conn.text
    assert client.post(
        "/api/v1/consent", headers=headers, json={"data_type": "steps", "consent_given": True}
    ).status_code == 201

    resp = client.delete("/api/v1/auth/me", headers=headers)
    assert resp.status_code == 200
    assert "permanently deleted" in resp.json()["message"]

    # The deleted user's token is dead.
    dead = client.get("/api/v1/profile", headers=headers)
    assert dead.status_code == 401

    # The email is freed up - re-registration succeeds with a fresh account.
    reg = client.post(
        "/api/v1/auth/register",
        json={"name": "Delete", "email": "delete@example.com", "password": "H3althy!Life"},
    )
    assert reg.status_code == 201, reg.text
    new_headers = {"Authorization": f"Bearer {reg.json()['access_token']}"}
    # No orphaned daily logs, health connections or consents for the new account.
    assert client.get("/api/v1/daily-logs", headers=new_headers).json() == []
    assert client.get("/api/v1/health/status", headers=new_headers).json() is None
    assert client.get("/api/v1/consent", headers=new_headers).json() == {
        "steps": False,
        "sleep": False,
        "activity": False,
        "screen_time": False,
        "demographic_optional": False,
    }


def test_delete_account_requires_token(client):
    resp = client.delete("/api/v1/auth/me")
    assert resp.status_code == 401