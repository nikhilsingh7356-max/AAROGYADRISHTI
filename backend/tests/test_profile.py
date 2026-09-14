"""Profile API tests."""

from __future__ import annotations


def test_get_profile_initially_empty(client, auth_headers):
    headers = auth_headers("profile@example.com")
    resp = client.get("/api/v1/profile", headers=headers)
    assert resp.status_code == 200
    body = resp.json()
    assert body["primary_goal"] is None
    assert body["onboarding_completed"] is False


def test_create_profile(client, auth_headers):
    headers = auth_headers("create-profile@example.com")
    payload = {
        "primary_goal": "better_sleep",
        "age_group": "25_34",
        "gender": "female",
        "height_cm": 165,
        "weight_kg": 62,
        "activity_level": "moderately_active",
    }
    resp = client.post("/api/v1/profile", json=payload, headers=headers)
    assert resp.status_code == 200
    body = resp.json()
    assert body["primary_goal"] == "better_sleep"
    assert body["activity_level"] == "moderately_active"
    assert body["height_cm"] == 165


def test_update_profile(client, auth_headers):
    headers = auth_headers("update-profile@example.com")
    client.post(
        "/api/v1/profile",
        json={"primary_goal": "more_energy", "age_group": "25_34"},
        headers=headers,
    )
    resp = client.put(
        "/api/v1/profile",
        json={"primary_goal": "stress_management", "weight_kg": 70},
        headers=headers,
    )
    assert resp.status_code == 200
    assert resp.json()["primary_goal"] == "stress_management"
    # age_group unchanged from partial update.
    assert resp.json()["age_group"] == "25_34"


def test_profile_name_propagation(client, auth_headers):
    headers = auth_headers("name@example.com")
    resp = client.put("/api/v1/profile", json={"name": "Priya Sharma"}, headers=headers)
    assert resp.status_code == 200
    assert resp.json()["name"] == "Priya Sharma"


def test_invalid_goal_rejected(client, auth_headers):
    headers = auth_headers("invalid-goal@example.com")
    resp = client.post(
        "/api/v1/profile",
        json={"primary_goal": "lose_all_weight_fast", "age_group": "25_34"},
        headers=headers,
    )
    assert resp.status_code == 422


def test_hydration_goal_accepted(client, auth_headers):
    headers = auth_headers("hydration-goal@example.com")
    resp = client.post(
        "/api/v1/profile",
        json={"primary_goal": "hydration", "age_group": "25_34"},
        headers=headers,
    )
    assert resp.status_code == 200
    assert resp.json()["primary_goal"] == "hydration"


def test_invalid_activity_level_rejected(client, auth_headers):
    headers = auth_headers("invalid-activity@example.com")
    resp = client.post(
        "/api/v1/profile",
        json={"activity_level": "ultramarathon_runner"},
        headers=headers,
    )
    assert resp.status_code == 422


def test_onboarding_flag(client, auth_headers):
    headers = auth_headers("onboard@example.com")
    resp = client.put(
        "/api/v1/profile",
        json={"onboarding_completed": True, "primary_goal": "overall_lifestyle"},
        headers=headers,
    )
    assert resp.status_code == 200
    assert resp.json()["onboarding_completed"] is True