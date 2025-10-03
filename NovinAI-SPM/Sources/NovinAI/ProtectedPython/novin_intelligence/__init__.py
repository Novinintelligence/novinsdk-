"""Public package surface for the NovinIntelligence security AI stack."""

from __future__ import annotations

from .crime_intelligence import CrimeContext, CrimeIncident, CrimeIntelligence
from .feature_extractor import FeatureConfig, FeatureExtraction
from .gemma_reasoning import GemmaReasoning, ReasoningContext, ReasoningResult
from .model_loader import ModelLoader, ModelMetadata, ModelWeights
from .neural_network import ModelConfig, NeuralNetwork
from .security import NovinAISecuritySystem, SecurityConfig

__version__ = "2.0.0"
__author__ = "NovinIntelligence"
__description__ = "AI Security System for Threat Assessment"


def load_config() -> SecurityConfig:
    """Factory helper for constructing a default security configuration."""

    return SecurityConfig()


__all__ = [
    "NovinAISecuritySystem",
    "SecurityConfig",
    "NeuralNetwork",
    "ModelConfig",
    "FeatureExtraction",
    "FeatureConfig",
    "CrimeIntelligence",
    "CrimeIncident",
    "CrimeContext",
    "GemmaReasoning",
    "ReasoningContext",
    "ReasoningResult",
    "ModelLoader",
    "ModelMetadata",
    "ModelWeights",
    "load_config",
]