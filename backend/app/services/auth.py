"""Auth orchestration service.

Kept as a thin module around the security helpers so the business rules live
in one place and the auth provider (JWT today, Firebase tomorrow) stays swappable.
"""

from __future__ import annotations

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.core.config import Settings, get_settings
from app.core.errors import AuthenticationError, BadRequestError, ConflictError
from app.core.security import (
    create_access_token,
    create_password_reset_token,
    create_refresh_token,
    decode_token,
    hash_password,
    password_problems,
    verify_password,
)
from app.models.daily_log import DailyLog
from app.models.user import User
from app.repositories.user import UserRepository
from app.schemas.auth import RegisterRequest
from app.services.firebase_auth import verify_id_token

users = UserRepository()


def _settings() -> Settings:
    return get_settings()


def register(db: Session, payload: RegisterRequest) -> tuple[User, str, str]:
    """Create a user (email/password) and return ``(user, access, refresh)``."""
    email = payload.email.lower().strip()
    if users.get_by_email(db, email) is not None:
        raise ConflictError("An account with this email already exists.")

    user = User(
        email=email,
        name=payload.name.strip(),
        password_hash=hash_password(payload.password),
        auth_provider="jwt",
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    access, _ = create_access_token(user.id, user.token_version, _settings())
    refresh, _ = create_refresh_token(user.id, user.token_version, _settings())
    return user, access, refresh


def authenticate(db: Session, email: str, password: str) -> tuple[User, str, str]:
    """Verify credentials and return ``(user, access, refresh)``."""
    user = users.get_by_email(db, email.lower().strip())
    if user is None or not verify_password(password, user.password_hash):
        raise AuthenticationError("Incorrect email or password.")
    access, _ = create_access_token(user.id, user.token_version, _settings())
    refresh, _ = create_refresh_token(user.id, user.token_version, _settings())
    return user, access, refresh


def authenticate_firebase(db: Session, id_token: str) -> tuple[User, str, str]:
    """Verify a Firebase ID token, provision the user, and issue app tokens."""
    settings = _settings()
    if settings.auth_provider != "firebase":
        raise AuthenticationError("Firebase sign-in is disabled.")
    claims = verify_id_token(id_token, settings)
    email = str(claims["email"]).lower().strip()
    name = str(claims.get("name") or email.split("@", 1)[0]).strip()
    user = users.get_by_email(db, email)

    if user is None:
        user = User(
            email=email,
            name=name[:120],
            password_hash=None,
            auth_provider="firebase",
            email_verified=True,
        )
        db.add(user)
    else:
        user.email_verified = True
        if not user.name:
            user.name = name[:120]

    db.commit()
    db.refresh(user)
    access, _ = create_access_token(user.id, user.token_version, settings)
    refresh, _ = create_refresh_token(user.id, user.token_version, settings)
    return user, access, refresh


def refresh_access_token(db: Session, refresh_token: str) -> tuple[User, str, str]:
    claims = decode_token(refresh_token, _settings(), "refresh")
    user = db.get(User, int(claims.subject))
    if user is None or user.token_version != claims.token_version:
        raise AuthenticationError("This session is no longer valid. Please sign in again.")
    access, _ = create_access_token(user.id, user.token_version, _settings())
    new_refresh, _ = create_refresh_token(user.id, user.token_version, _settings())
    return user, access, new_refresh


def logout(db: Session, user: User) -> None:
    """Invalidate outstanding JWTs by bumping the token version."""
    user.token_version += 1
    db.commit()


def request_password_reset(db: Session, email: str) -> tuple[User, str]:
    """Return the reset token; does not send email in Phase 1 (no SMTP)."""
    user = users.get_by_email(db, email.lower().strip())
    if user is None:
        raise BadRequestError("No account found with this email.")
    token, _ = create_password_reset_token(user.id, user.token_version, _settings())
    return user, token


def reset_password(db: Session, token: str, new_password: str) -> User:
    settings = _settings()
    problems = password_problems(new_password, settings.password_min_length)
    if problems:
        raise BadRequestError(problems[0])
    claims = decode_token(token, settings, "password_reset")
    user = db.get(User, int(claims.subject))
    if user is None or user.token_version != claims.token_version:
        raise AuthenticationError("This reset link has expired. Please try again.")
    user.password_hash = hash_password(new_password)
    user.token_version += 1  # invalidate all old tokens
    db.commit()
    db.refresh(user)
    return user


def delete_account(db: Session, user: User) -> None:
    """Permanently delete a user and all of their data.

    Rows are removed in explicit dependency order rather than relying on DB
    cascade, so behaviour is identical on SQLite, Postgres and any future
    backend. Several user-scoped tables (``daily_logs``,
    ``coach_conversations``, ``personal_learnings``) keep plain integer
    ``user_id`` columns with no FK - their rows MUST be deleted here before
    the user row itself.
    """
    from app.models.coach import CoachConversation, CoachMessage
    from app.models.consent import ConsentRecord
    from app.models.daily_log import DailyLog
    from app.models.evaluation import (
        ExperimentEvidence,
        ExperimentMetricResult,
        LearningCandidate,
    )
    from app.models.experiment import Experiment, ExperimentDailyLog, ExperimentResult
    from app.models.health import DailyHealthData, HealthConnection
    from app.models.personal_learning import PersonalLearning, PersonalLearningEvidence

    # --- Experiment subgraph (all keyed off the user's experiment ids). ------
    experiment_ids = select(Experiment.id).where(Experiment.user_id == user.id)
    db.execute(
        delete(ExperimentDailyLog).where(ExperimentDailyLog.experiment_id.in_(experiment_ids))
    )
    db.execute(
        delete(ExperimentMetricResult).where(
            ExperimentMetricResult.experiment_id.in_(experiment_ids)
        )
    )
    db.execute(
        delete(ExperimentEvidence).where(ExperimentEvidence.experiment_id.in_(experiment_ids))
    )
    db.execute(
        delete(ExperimentResult).where(ExperimentResult.experiment_id.in_(experiment_ids))
    )
    db.execute(delete(LearningCandidate).where(LearningCandidate.user_id == user.id))
    db.execute(delete(Experiment).where(Experiment.user_id == user.id))

    # --- Personal learnings (evidence references the learning rows). ---------
    learning_ids = select(PersonalLearning.id).where(PersonalLearning.user_id == user.id)
    db.execute(
        delete(PersonalLearningEvidence).where(
            PersonalLearningEvidence.learning_id.in_(learning_ids)
        )
    )
    db.execute(delete(PersonalLearning).where(PersonalLearning.user_id == user.id))

    # --- Coach conversations (messages reference the conversations). ---------
    conversation_ids = select(CoachConversation.id).where(
        CoachConversation.user_id == user.id
    )
    db.execute(
        delete(CoachMessage).where(CoachMessage.conversation_id.in_(conversation_ids))
    )
    db.execute(delete(CoachConversation).where(CoachConversation.user_id == user.id))

    # --- Remaining user-scoped records. --------------------------------------
    db.execute(delete(DailyLog).where(DailyLog.user_id == user.id))
    db.execute(delete(DailyHealthData).where(DailyHealthData.user_id == user.id))
    db.execute(delete(HealthConnection).where(HealthConnection.user_id == user.id))
    db.execute(delete(ConsentRecord).where(ConsentRecord.user_id == user.id))

    if user.profile is not None:
        db.delete(user.profile)
    db.delete(user)
    db.commit()


def demo_seed_for(db: Session, user: User) -> None:
    """Seed 7 days of clearly-labelled demo daily logs (dev + demo accounts only)."""
    from datetime import date, timedelta

    today = date.today()
    demo_pattern = [
        dict(sleep_hours=7.1, steps=8423, active_minutes=38, exercise_level="moderate", water_liters=2.1, meal_quality="mixed", mood="good", energy=7, stress=2, caffeine="low", late_night_screen=False),
        dict(sleep_hours=6.2, steps=4305, active_minutes=14, exercise_level="none", water_liters=1.4, meal_quality="processed", mood="low", energy=5, stress=4, caffeine="moderate", late_night_screen=True),
        dict(sleep_hours=6.8, steps=6211, active_minutes=26, exercise_level="light", water_liters=1.8, meal_quality="healthy", mood="okay", energy=6, stress=3, caffeine="low", late_night_screen=False),
        dict(sleep_hours=7.6, steps=11204, active_minutes=54, exercise_level="intense", water_liters=2.6, meal_quality="healthy", mood="great", energy=8, stress=1, caffeine="low", late_night_screen=False),
        dict(sleep_hours=5.9, steps=3810, active_minutes=9, exercise_level="none", water_liters=1.1, meal_quality="processed", mood="very_low", energy=4, stress=5, caffeine="high", late_night_screen=True),
        dict(sleep_hours=7.3, steps=7412, active_minutes=32, exercise_level="moderate", water_liters=2.2, meal_quality="mixed", mood="good", energy=7, stress=2, caffeine="moderate", late_night_screen=False),
        dict(sleep_hours=7.0, steps=6530, active_minutes=22, exercise_level="light", water_liters=1.9, meal_quality="mixed", mood="okay", energy=6, stress=3, caffeine="low", late_night_screen=True),
    ]
    for i, values in enumerate(demo_pattern):
        offset = 6 - i
        day = today - timedelta(days=offset)
        existing = db.scalars(
            select(DailyLog).where(DailyLog.user_id == user.id, DailyLog.date == day)
        ).first()
        if existing is not None:
            continue
        db.add(DailyLog(user_id=user.id, source="demo", date=day, **values))
    db.commit()
