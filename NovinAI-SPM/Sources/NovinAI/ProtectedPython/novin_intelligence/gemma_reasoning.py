"""Adaptive reasoning engine for the NovinAI security system."""

from __future__ import annotations

import asyncio
import logging
from dataclasses import dataclass
from datetime import datetime, timezone
from functools import lru_cache
from typing import Any, Dict, Iterable, List, Optional

import numpy as np

logger = logging.getLogger(__name__)


@dataclass
class ReasoningContext:
    event_data: Dict[str, Any]
    crime_context: Dict[str, Any]
    user_history: List[Dict[str, Any]]
    system_state: Dict[str, Any]
    time_context: Dict[str, Any]


@dataclass
class ReasoningResult:
    threat_assessment: str
    confidence: float
    reasoning_chain: List[str]
    key_factors: List[str]
    recommendations: List[str]
    risk_score: float


class GemmaReasoning:
    """Production-grade reasoning engine combining rules and adaptive scoring."""

    def __init__(self, config: Any) -> None:
        self.config = config
        self._rules = self._load_reasoning_rules()
        self._patterns = self._load_patterns()

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------
    def reason(self, context: ReasoningContext) -> ReasoningResult:
        try:
            return self._reason_internal(context)
        except Exception as exc:  # Defensive: never allow reasoning to crash pipeline.
            logger.exception("Reasoning failure: %s", exc)
            return self._get_default_result()

    async def reason_async(self, context: ReasoningContext) -> ReasoningResult:
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(None, self.reason, context)

    def update_reasoning_rules(self, new_rules: Dict[str, List[Dict[str, Any]]]) -> None:
        self._rules.update(new_rules)
        logger.info("Reasoning rules updated. Active rule groups: %s", list(self._rules))

    def get_reasoning_explanation(self, result: ReasoningResult) -> str:
        lines = [
            f"Threat Assessment: {result.threat_assessment}",
            f"Risk Score: {result.risk_score:.2f}",
            f"Confidence: {result.confidence:.2f}",
            "",
            "Reasoning Chain:",
        ]
        lines.extend(f"{idx + 1}. {step}" for idx, step in enumerate(result.reasoning_chain))
        lines.append("")
        lines.append("Key Factors:")
        lines.extend(f"- {factor}" for factor in result.key_factors)
        lines.append("")
        lines.append("Recommendations:")
        lines.extend(f"- {rec}" for rec in result.recommendations)
        return "\n".join(lines)

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------
    def _reason_internal(self, context: ReasoningContext) -> ReasoningResult:
        event_type = context.event_data.get("event_type", "unknown")
        reasoning_chain: List[str] = []

        base_risk = self._calculate_base_risk(context)
        reasoning_chain.append(f"Base risk: {base_risk:.2f}")

        event_multiplier = self._apply_event_reasoning(context, event_type, reasoning_chain)
        pattern_multiplier = self._apply_pattern_reasoning(context, reasoning_chain)
        context_multiplier = self._apply_contextual_reasoning(context, reasoning_chain)

        total_risk = np.clip(base_risk * event_multiplier * pattern_multiplier * context_multiplier, 0.0, 1.0)

        threat_level = self._determine_threat_level(total_risk)
        recommendations = self._generate_recommendations(context, threat_level, total_risk)
        key_factors = self._extract_key_factors(context, reasoning_chain)

        confidence = float(np.clip(total_risk * 1.15, 0.0, 1.0))

        return ReasoningResult(
            threat_assessment=threat_level,
            confidence=confidence,
            reasoning_chain=reasoning_chain,
            key_factors=key_factors,
            recommendations=recommendations,
            risk_score=float(total_risk),
        )

    @lru_cache(maxsize=32)
    def _load_reasoning_rules(self) -> Dict[str, List[Dict[str, Any]]]:
        return {
            "motion": [
                {
                    "condition": lambda ctx: ctx.time_context.get("hour", 12) not in range(6, 23),
                    "reason": "Motion detected during guard hours",
                    "multiplier": 1.4,
                },
                {
                    "condition": lambda ctx: ctx.crime_context.get("crime_rate_24h", 0) > 3,
                    "reason": "Elevated local crime rate",
                    "multiplier": 1.3,
                },
                {
                    "condition": lambda ctx: ctx.user_history and ctx.user_history[-1].get("event_type") == "motion",
                    "reason": "Back-to-back motion events",
                    "multiplier": 1.35,
                },
            ],
            "door": [
                {
                    "condition": lambda ctx: ctx.time_context.get("hour", 12) not in range(6, 23),
                    "reason": "Door activity during night routine",
                    "multiplier": 1.55,
                },
                {
                    "condition": lambda ctx: ctx.event_data.get("confidence", 0.0) >= 0.8,
                    "reason": "High-confidence door event",
                    "multiplier": 1.15,
                },
            ],
            "window": [
                {
                    "condition": lambda ctx: ctx.event_data.get("confidence", 0.0) >= 0.7,
                    "reason": "High-confidence window disturbance",
                    "multiplier": 1.2,
                }
            ],
            "face": [
                {
                    "condition": lambda ctx: not ctx.event_data.get("known_face", True),
                    "reason": "Unknown face detected",
                    "multiplier": 1.75,
                },
                {
                    "condition": lambda ctx: ctx.event_data.get("face_confidence", 1.0) < 0.65,
                    "reason": "Face partial match – possible disguise",
                    "multiplier": 1.25,
                },
            ],
            "sound": [
                {
                    "condition": lambda ctx: ctx.event_data.get("sound_type") in {"glass_breaking", "alarm", "scream"},
                    "reason": "Critical sound signature",
                    "multiplier": 1.9,
                },
                {
                    "condition": lambda ctx: ctx.event_data.get("sound_level", 0) > 85,
                    "reason": "Acoustic intensity spike",
                    "multiplier": 1.35,
                },
            ],
        }

    @staticmethod
    def _load_patterns() -> Dict[str, List[str]]:
        return {
            "intrusion": ["motion", "door", "motion", "sound"],
            "emergency": ["smoke", "fire", "alarm"],
            "false_alarm": ["pet", "motion", "motion"],
        }

    def _calculate_base_risk(self, context: ReasoningContext) -> float:
        risk = 0.15
        hour = context.time_context.get("hour", 12)
        if hour not in range(6, 23):
            risk += 0.18

        crime_rate = context.crime_context.get("crime_rate_24h", 0.0)
        if crime_rate > 3:
            risk += 0.25
        elif crime_rate > 1:
            risk += 0.1

        recent_events = context.user_history[-5:]
        if any(evt.get("threat_level") == "ELEVATED" for evt in recent_events):
            risk += 0.15

        return float(np.clip(risk, 0.0, 0.55))

    def _apply_event_reasoning(self, context: ReasoningContext, event_type: str, reasoning_chain: List[str]) -> float:
        rules = self._rules.get(event_type, [])
        multiplier = 1.0
        for rule in rules:
            try:
                if rule["condition"](context):
                    multiplier *= rule["multiplier"]
                    reasoning_chain.append(rule["reason"])
            except Exception as exc:
                logger.debug("Rule evaluation failure: %s", exc)
        return float(np.clip(multiplier, 0.5, 3.0))

    def _apply_pattern_reasoning(self, context: ReasoningContext, reasoning_chain: List[str]) -> float:
        recent = [evt.get("event_type", "unknown") for evt in context.user_history[-4:]]
        recent.append(context.event_data.get("event_type", "unknown"))
        multiplier = 1.0

        if self._matches_pattern(recent, self._patterns["intrusion"]):
            reasoning_chain.append("Intrusion pattern recognised")
            multiplier *= 1.6
        if self._matches_pattern(recent, self._patterns["emergency"]):
            reasoning_chain.append("Emergency escalation pattern recognised")
            multiplier *= 1.8
        if self._matches_pattern(recent, self._patterns["false_alarm"]):
            reasoning_chain.append("False-alarm pattern detected")
            multiplier *= 0.7

        return float(np.clip(multiplier, 0.4, 3.0))

    def _apply_contextual_reasoning(self, context: ReasoningContext, reasoning_chain: List[str]) -> float:
        multiplier = 1.0
        weather = context.system_state.get("weather", {})
        if weather.get("precipitation", 0.0) > 0.6:
            reasoning_chain.append("Severe weather degrading sensors")
            multiplier *= 0.85

        battery = context.system_state.get("system_health", {}).get("battery_level", 100)
        if battery < 20:
            reasoning_chain.append("System battery critically low")
            multiplier *= 1.1

        if not context.system_state.get("user_presence", True):
            reasoning_chain.append("Premises unattended")
            multiplier *= 1.25

        if context.user_history:
            last_event = context.user_history[-1]
            last_ts = last_event.get("timestamp")
            if last_ts:
                try:
                    delta = datetime.now(timezone.utc) - datetime.fromisoformat(last_ts.replace("Z", "+00:00"))
                    if delta.total_seconds() < 600:
                        reasoning_chain.append("Clustered activity window")
                        multiplier *= 1.2
                except ValueError:
                    logger.debug("Timestamp parsing failed for %s", last_ts)

        return float(np.clip(multiplier, 0.5, 2.5))

    @staticmethod
    def _determine_threat_level(risk_score: float) -> str:
        if risk_score >= 0.8:
            return "CRITICAL"
        if risk_score >= 0.6:
            return "ELEVATED"
        if risk_score >= 0.35:
            return "STANDARD"
        return "IGNORE"

    def _generate_recommendations(self, context: ReasoningContext, threat_level: str, risk_score: float) -> List[str]:
        recommendations: List[str] = []
        if threat_level == "CRITICAL":
            recommendations.extend([
                "Dispatch emergency response",
                "Trigger fail-safe lockdown",
                "Notify all on-call responders",
            ])
        elif threat_level == "ELEVATED":
            recommendations.extend([
                "Escalate to security team",
                "Activate secondary verification sensors",
                "Issue push notification to homeowner",
            ])
        elif threat_level == "STANDARD":
            recommendations.extend([
                "Log incident for review",
                "Maintain monitoring cadence",
            ])
        else:
            recommendations.append("Auto-resolve event – low risk")

        event_type = context.event_data.get("event_type", "")
        if event_type == "face" and not context.event_data.get("known_face", True):
            recommendations.append("Cross-check against authorised visitor list")
        if event_type == "sound" and context.event_data.get("sound_type") == "glass_breaking":
            recommendations.append("Dispatch drone for perimeter sweep")
        if event_type == "motion" and risk_score > 0.45:
            recommendations.append("Enable AI spotlight deterrent")
        return recommendations

    def _extract_key_factors(self, context: ReasoningContext, reasoning_chain: Iterable[str]) -> List[str]:
        factors: List[str] = []
        hour = context.time_context.get("hour", 12)
        if hour not in range(6, 23):
            factors.append("Event during protected hours")

        if context.crime_context.get("crime_rate_24h", 0) > 2:
            factors.append("High local crime frequency")

        if context.event_data.get("event_type") in {"face", "sound", "door", "window"}:
            factors.append(f"High-priority sensor: {context.event_data['event_type']}")

        confidence = context.event_data.get("confidence", 0.5)
        if confidence >= 0.8:
            factors.append("Detector confidence strong")
        elif confidence <= 0.3:
            factors.append("Detector confidence weak")

        unique_events = {evt.get("event_type") for evt in context.user_history[-5:]}
        if len(unique_events) > 2:
            factors.append("Multi-sensor correlation active")

        factors.extend(step for step in reasoning_chain if "pattern" in step.lower())
        return factors

    @staticmethod
    def _matches_pattern(sequence: List[str], pattern: List[str]) -> bool:
        if len(sequence) < len(pattern):
            return False
        return sequence[-len(pattern) :] == pattern

    @staticmethod
    def _get_default_result() -> ReasoningResult:
        return ReasoningResult(
            threat_assessment="STANDARD",
            confidence=0.5,
            reasoning_chain=["Fallback reasoning pathway invoked"],
            key_factors=["Reasoning engine fallback"],
            recommendations=["Audit system health"],
            risk_score=0.35,
        )
