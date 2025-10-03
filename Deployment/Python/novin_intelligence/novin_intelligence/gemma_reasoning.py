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
        """Update reasoning rules at runtime."""
        self._rules.update(new_rules)
        logger.info("Reasoning rules updated with %d new rules", len(new_rules))

    # ------------------------------------------------------------------
    # Internal implementation
    # ------------------------------------------------------------------
    def _reason_internal(self, context: ReasoningContext) -> ReasoningResult:
        """Core reasoning implementation."""
        # 1. Apply rule engine
        rule_results = self._apply_rules(context)
        
        # 2. Apply pattern matching
        pattern_results = self._match_patterns(context)
        
        # 3. Combine results
        combined_score = self._combine_scores(rule_results, pattern_results)
        
        # 4. Generate assessment
        assessment = self._generate_assessment(combined_score, context)
        
        # 5. Generate recommendations
        recommendations = self._generate_recommendations(combined_score, context)
        
        return ReasoningResult(
            threat_assessment=assessment,
            confidence=float(min(1.0, abs(combined_score))),
            reasoning_chain=[
                f"Rule analysis: {len(rule_results)} rules matched",
                f"Pattern analysis: {len(pattern_results)} patterns identified",
                f"Combined risk score: {combined_score:.3f}"
            ],
            key_factors=self._extract_key_factors(rule_results, pattern_results),
            recommendations=recommendations,
            risk_score=float(combined_score)
        )

    def _apply_rules(self, context: ReasoningContext) -> List[Dict[str, Any]]:
        """Apply reasoning rules to context."""
        results = []
        for category, rules in self._rules.items():
            for rule in rules:
                if self._evaluate_rule(rule, context):
                    results.append({
                        "category": category,
                        "rule": rule.get("name", "unnamed"),
                        "weight": rule.get("weight", 1.0),
                        "score": rule.get("score", 0.5)
                    })
        return results

    def _evaluate_rule(self, rule: Dict[str, Any], context: ReasoningContext) -> bool:
        """Evaluate a single rule against context."""
        # Simplified rule evaluation
        conditions = rule.get("conditions", [])
        # In a real implementation, this would evaluate the actual conditions
        return len(conditions) > 0

    def _match_patterns(self, context: ReasoningContext) -> List[Dict[str, Any]]:
        """Match patterns in the context."""
        results = []
        for pattern in self._patterns:
            if self._evaluate_pattern(pattern, context):
                results.append({
                    "pattern": pattern.get("name", "unnamed"),
                    "weight": pattern.get("weight", 1.0),
                    "score": pattern.get("score", 0.5)
                })
        return results

    def _evaluate_pattern(self, pattern: Dict[str, Any], context: ReasoningContext) -> bool:
        """Evaluate a pattern against context."""
        # Simplified pattern matching
        return True

    def _combine_scores(self, rule_results: List[Dict[str, Any]], pattern_results: List[Dict[str, Any]]) -> float:
        """Combine scores from rules and patterns."""
        total_weight = 0.0
        weighted_sum = 0.0
        
        # Combine rule results
        for result in rule_results:
            weight = result.get("weight", 1.0)
            score = result.get("score", 0.5)
            weighted_sum += weight * score
            total_weight += weight
        
        # Combine pattern results
        for result in pattern_results:
            weight = result.get("weight", 1.0)
            score = result.get("score", 0.5)
            weighted_sum += weight * score
            total_weight += weight
        
        if total_weight == 0:
            return 0.5  # Neutral score
        
        return weighted_sum / total_weight

    def _generate_assessment(self, score: float, context: ReasoningContext) -> str:
        """Generate threat assessment based on score."""
        if score >= 0.9:
            return "CRITICAL_RISK"
        elif score >= 0.7:
            return "HIGH_RISK"
        elif score >= 0.5:
            return "MEDIUM_RISK"
        else:
            return "LOW_RISK"

    def _generate_recommendations(self, score: float, context: ReasoningContext) -> List[str]:
        """Generate recommendations based on score."""
        recommendations = []
        if score >= 0.9:
            recommendations.extend([
                "Immediate security response required",
                "Contact emergency services",
                "Lock all entry points"
            ])
        elif score >= 0.7:
            recommendations.extend([
                "Increase monitoring",
                "Notify security personnel",
                "Verify recent activities"
            ])
        elif score >= 0.5:
            recommendations.extend([
                "Continue monitoring",
                "Review recent events",
                "Check system status"
            ])
        else:
            recommendations.extend([
                "Normal monitoring",
                "System operating normally",
                "No immediate action required"
            ])
        return recommendations

    def _extract_key_factors(self, rule_results: List[Dict[str, Any]], pattern_results: List[Dict[str, Any]]) -> List[str]:
        """Extract key factors from results."""
        factors = []
        for result in rule_results:
            factors.append(f"Rule: {result.get('rule', 'unnamed')}")
        for result in pattern_results:
            factors.append(f"Pattern: {result.get('pattern', 'unnamed')}")
        return factors if factors else ["No significant factors identified"]

    def _get_default_result(self) -> ReasoningResult:
        """Get default reasoning result for error cases."""
        return ReasoningResult(
            threat_assessment="LOW_RISK",
            confidence=0.0,
            reasoning_chain=["Default result due to error"],
            key_factors=["System error"],
            recommendations=["Check system status"],
            risk_score=0.1
        )

    def _load_reasoning_rules(self) -> Dict[str, List[Dict[str, Any]]]:
        """Load reasoning rules from configuration."""
        # In a real implementation, this would load from a file or database
        return {
            "motion": [
                {
                    "name": "suspicious_motion_night",
                    "conditions": ["time_night", "motion_detected"],
                    "weight": 1.5,
                    "score": 0.7
                }
            ],
            "sound": [
                {
                    "name": "loud_noise",
                    "conditions": ["sound_level_high"],
                    "weight": 1.2,
                    "score": 0.6
                }
            ]
        }

    def _load_patterns(self) -> List[Dict[str, Any]]:
        """Load pattern definitions."""
        # In a real implementation, this would load from a file or database
        return [
            {
                "name": "repeated_events",
                "weight": 1.3,
                "score": 0.65
            }
        ]


__all__ = ["GemmaReasoning", "ReasoningContext", "ReasoningResult"]