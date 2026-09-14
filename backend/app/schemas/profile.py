"""Profile request/response schemas."""

from __future__ import annotations

from datetime import date

from pydantic import BaseModel, ConfigDict, Field, field_validator

ACTIVITY_LEVELS = ("mostly_sedentary", "lightly_active", "moderately_active", "very_active")
PRIMARY_GOALS = (
    "better_sleep",
    "more_energy",
    "physical_activity",
    "stress_management",
    "healthy_eating",
    "hydration",
    "overall_lifestyle",
)
AGE_GROUPS = ("under_18", "18_24", "25_34", "35_44", "45_54", "55_64", "65_plus")
GENDERS = ("female", "male", "non_binary", "prefer_not_to_say")

common = ConfigDict(from_attributes=True)


class ProfileUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    age_group: str | None = None
    gender: str | None = None
    height_cm: float | None = Field(default=None, ge=50, le=300)
    weight_kg: float | None = Field(default=None, ge=20, le=500)
    activity_level: str | None = None
    primary_goal: str | None = None
    onboarding_completed: bool | None = None

    @field_validator("activity_level")
    @classmethod
    def _activity(cls, v: str | None) -> str | None:
        if v is not None and v not in ACTIVITY_LEVELS:
            raise ValueError(f"activity_level must be one of {ACTIVITY_LEVELS}")
        return v

    @field_validator("primary_goal")
    @classmethod
    def _goal(cls, v: str | None) -> str | None:
        if v is not None and v not in PRIMARY_GOALS:
            raise ValueError(f"primary_goal must be one of {PRIMARY_GOALS}")
        return v

    @field_validator("age_group")
    @classmethod
    def _age(cls, v: str | None) -> str | None:
        if v is not None and v not in AGE_GROUPS:
            raise ValueError(f"age_group must be one of {AGE_GROUPS}")
        return v

    @field_validator("gender")
    @classmethod
    def _gender(cls, v: str | None) -> str | None:
        if v is not None and v not in GENDERS:
            raise ValueError(f"gender must be one of {GENDERS}")
        return v


class ProfileResponse(BaseModel):
    id: int
    user_id: int
    name: str | None = None
    age_group: str | None = None
    gender: str | None = None
    height_cm: float | None = None
    weight_kg: float | None = None
    activity_level: str | None = None
    primary_goal: str | None = None
    onboarding_completed: bool = False
    timeframe_start: date | None = None

    model_config = common


class OnboardingCompleteRequest(BaseModel):
    primary_goal: str
    age_group: str | None = None
    gender: str | None = None
    height_cm: float | None = Field(default=None, ge=50, le=300)
    weight_kg: float | None = Field(default=None, ge=20, le=500)
    activity_level: str | None = None

    @field_validator("primary_goal")
    @classmethod
    def _goal(cls, v: str) -> str:
        if v not in PRIMARY_GOALS:
            raise ValueError(f"primary_goal must be one of {PRIMARY_GOALS}")
        return v

    @field_validator("activity_level")
    @classmethod
    def _activity(cls, v: str | None) -> str | None:
        if v is not None and v not in ACTIVITY_LEVELS:
            raise ValueError(f"activity_level must be one of {ACTIVITY_LEVELS}")
        return v