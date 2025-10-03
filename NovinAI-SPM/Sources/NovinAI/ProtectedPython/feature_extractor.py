"""Feature engineering pipeline for NovinAI security events."""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from datetime import datetime, timezone
from functools import lru_cache
from typing import Any, Dict, Iterable, List, Mapping, MutableMapping, Optional

import mmh3
import numpy as np

logger = logging.getLogger(__name__)


@dataclass(slots=True)
class FeatureConfig:
    max_features: int = 16_384
    time_window_hours: int = 24
    location_precision: int = 3
    event_types: tuple[str, ...] = (
        "motion",
        "sound",
        "door",
        "window",
        "face",
        "smoke",
        "fire",
        "glassbreak",
        "pet",
        "vehicle",
    )
    feature_scaling: bool = True
    dtype: np.dtype = field(default=np.float32, repr=False)


class FeatureExtraction:
    """Transforms heterogeneous sensor payloads into dense feature vectors."""

    def __init__(self, config: Any) -> None:
        self.config = config
        self.feature_config = FeatureConfig()
        self.scaling_params: Dict[str, np.ndarray] = {}

    def extract(self, request_data: Dict[str, Any], crime_context: Dict[str, Any]) -> np.ndarray:
        try:
            features: Dict[str, float] = {}
            features.update(self._extract_temporal_features(request_data))
            features.update(self._extract_spatial_features(request_data, crime_context))
            features.update(self._extract_event_features(request_data))
            features.update(self._extract_behavioral_features(request_data))
            features.update(self._extract_environmental_features(request_data, crime_context))

            vector = self._vectorize_features(features)
            if self.feature_config.feature_scaling:
                vector = self._scale_features(vector)
            return vector
        except Exception as exc:
            logger.exception("Feature extraction failure: %s", exc)
            return np.zeros(self.feature_config.max_features, dtype=self.feature_config.dtype)

    # ------------------------------------------------------------------
    # Individual feature families
    # ------------------------------------------------------------------
    def _extract_temporal_features(self, request_data: Mapping[str, Any]) -> Dict[str, float]:
        timestamp = request_data.get("timestamp", datetime.now(timezone.utc))
        if isinstance(timestamp, str):
            try:
                timestamp = datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
            except ValueError:
                timestamp = datetime.now(timezone.utc)

        hour = timestamp.hour
        weekday = timestamp.weekday()
        month = timestamp.month

        features = {
            "hour_sin": float(np.sin(2 * np.pi * hour / 24)),
            "hour_cos": float(np.cos(2 * np.pi * hour / 24)),
            "weekday_sin": float(np.sin(2 * np.pi * weekday / 7)),
            "weekday_cos": float(np.cos(2 * np.pi * weekday / 7)),
            "month_sin": float(np.sin(2 * np.pi * month / 12)),
            "month_cos": float(np.cos(2 * np.pi * month / 12)),
            "is_weekend": float(weekday >= 5),
        }

        last_event = request_data.get("last_event_time")
        if last_event:
            if isinstance(last_event, str):
                try:
                    last_event = datetime.fromisoformat(last_event.replace("Z", "+00:00"))
                except ValueError:
                    last_event = None
            if isinstance(last_event, datetime):
                delta = (timestamp - last_event).total_seconds() / 3600
                features["hours_since_last_event"] = float(np.clip(delta, 0, 24) / 24)
        else:
            features["hours_since_last_event"] = 1.0
        return features

    def _extract_spatial_features(self, request_data: Mapping[str, Any], crime_context: Mapping[str, Any]) -> Dict[str, float]:
        location = request_data.get("location", {})
        lat = float(location.get("latitude", 0.0))
        lng = float(location.get("longitude", 0.0))

        features = {
            "latitude_norm": (lat + 90.0) / 180.0,
            "longitude_norm": (lng + 180.0) / 360.0,
            "crime_rate_24h": float(crime_context.get("crime_rate_24h", 0.0)),
            "crime_rate_7d": float(crime_context.get("crime_rate_7d", 0.0)),
            "crime_rate_30d": float(crime_context.get("crime_rate_30d", 0.0)),
            "nearby_incidents": min(float(crime_context.get("nearby_incidents", 0.0)), 20.0) / 20.0,
            "crime_severity": float(crime_context.get("avg_severity", 0.0)),
        }
        return features

    def _extract_event_features(self, request_data: Mapping[str, Any]) -> Dict[str, float]:
        event_type = request_data.get("event_type", "unknown")
        event_data = request_data.get("event_data", {})

        features = {f"event_{etype}": float(event_type == etype) for etype in self.feature_config.event_types}
        features["event_confidence"] = float(event_data.get("confidence", 0.5))
        features["event_duration"] = float(min(event_data.get("duration", 0), 600) / 600)
        features["event_intensity"] = float(event_data.get("intensity", 0.5))
        features["sensor_count"] = float(min(len(event_data.get("sensors_triggered", [])), 6) / 6)
        return features

    def _extract_behavioral_features(self, request_data: Mapping[str, Any]) -> Dict[str, float]:
        history = request_data.get("activity_history", [])[-20:]
        risk_profile = request_data.get("user_risk_profile", {})

        features = {
            "recent_activity_freq": float(min(len(history), 20) / 20.0),
            "user_risk_score": float(risk_profile.get("risk_score", 0.5)),
            "user_trust_level": float(risk_profile.get("trust_level", 0.5)),
        }

        if history:
            hours = [entry.get("hour", 12) for entry in history]
            features["activity_consistency"] = float(1.0 - (np.std(hours) / 12.0))
        else:
            features["activity_consistency"] = 0.5
        return features

    def _extract_environmental_features(self, request_data: Mapping[str, Any], crime_context: Mapping[str, Any]) -> Dict[str, float]:
        weather = request_data.get("weather", {})
        timestamp = request_data.get("timestamp", datetime.now(timezone.utc))
        if isinstance(timestamp, str):
            try:
                timestamp = datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
            except ValueError:
                timestamp = datetime.now(timezone.utc)

        hour = timestamp.hour
        month = timestamp.month
        season_index = (month % 12) // 3

        features = {
            "temperature": float((weather.get("temperature", 21) + 40) / 80),
            "humidity": float(weather.get("humidity", 50) / 100),
            "precipitation": float(min(weather.get("precipitation", 0), 50) / 50),
            "wind_speed": float(min(weather.get("wind_speed", 0), 40) / 40),
            "is_daylight": float(6 <= hour <= 18),
        }

        seasons = ["season_winter", "season_spring", "season_summer", "season_fall"]
        for idx, key in enumerate(seasons):
            features[key] = float(idx == season_index)
        return features

    # ------------------------------------------------------------------
    # Vectorisation & scaling
    # ------------------------------------------------------------------
    def _vectorize_features(self, features: Mapping[str, float]) -> np.ndarray:
        vector = np.zeros(self.feature_config.max_features, dtype=self.feature_config.dtype)
        for name, value in features.items():
            slot = self._feature_slot(name)
            vector[slot] = float(value)
        return vector

    @lru_cache(maxsize=10_000)
    def _feature_slot(self, feature_name: str) -> int:
        return int(mmh3.hash(feature_name) % self.feature_config.max_features)

    def _scale_features(self, vector: np.ndarray) -> np.ndarray:
        if not self.scaling_params:
            self.scaling_params = {
                "mean": np.zeros_like(vector),
                "std": np.ones_like(vector),
            }
        mean = self.scaling_params["mean"]
        std = self.scaling_params["std"]
        scaled = (vector - mean) / (std + 1e-6)
        return np.clip(scaled, -5.0, 5.0)

    # ------------------------------------------------------------------
    # Diagnostics
    # ------------------------------------------------------------------
    def get_feature_names(self) -> List[str]:
        return list(self.feature_config.event_types)


__all__ = ["FeatureExtraction", "FeatureConfig"]
