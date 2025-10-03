"""Neural network inference utilities for the NovinAI security stack."""

from __future__ import annotations

import base64
import json
import logging
from dataclasses import dataclass, field
from hashlib import sha256
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple

import numpy as np
from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.hazmat.primitives.serialization import load_pem_public_key
from scipy.special import softmax

logger = logging.getLogger(__name__)


@dataclass(slots=True)
class ModelConfig:
    input_size: int = 16_384
    hidden_layers: Tuple[int, ...] = (512, 256, 128)
    output_size: int = 4
    activation: str = "relu"
    dropout_rate: float = 0.15
    version: str = "2.0"
    quantized: bool = False
    dtype: np.dtype = field(default=np.float32, repr=False)


class NeuralNetwork:
    """Feed-forward classifier supporting signature-verified weight loading."""

    def __init__(self, config: Any) -> None:
        self.config = config
        self.model_config = ModelConfig()
        self.weights: Dict[str, np.ndarray] = {}
        self.biases: Dict[str, np.ndarray] = {}
        self.public_key = None
        self.model_loaded = False
        self.version = self.model_config.version
        self._initialize_network()

    # ------------------------------------------------------------------
    # Initialisation & loading
    # ------------------------------------------------------------------
    def _initialize_network(self) -> None:
        layer_sizes = (self.model_config.input_size, *self.model_config.hidden_layers, self.model_config.output_size)
        for idx in range(len(layer_sizes) - 1):
            fan_in, fan_out = layer_sizes[idx], layer_sizes[idx + 1]
            limit = np.sqrt(6.0 / (fan_in + fan_out))
            self.weights[f"layer_{idx}"] = np.random.uniform(-limit, limit, (fan_in, fan_out)).astype(self.model_config.dtype)
            self.biases[f"layer_{idx}"] = np.zeros(fan_out, dtype=self.model_config.dtype)

    def load_model(self, model_path: str, signature_path: str, public_key_path: str) -> bool:
        try:
            model_bytes = Path(model_path).read_bytes()
            signature = Path(signature_path).read_bytes()
            public_key_data = Path(public_key_path).read_bytes()
            self.public_key = load_pem_public_key(public_key_data)

            if not self._verify_signature(model_bytes, signature):
                logger.error("Model signature verification failed")
                return False

            model_dict = self._parse_model_payload(model_bytes)
            self._load_weights_from_dict(model_dict)
            self.version = model_dict.get("version", self.version)
            self.model_loaded = True
            logger.info("Model %s loaded with checksum %s", self.version, model_dict.get("checksum"))
            return True
        except Exception as exc:
            logger.exception("Model loading failed: %s", exc)
            return False

    def _verify_signature(self, data: bytes, signature: bytes) -> bool:
        if not self.public_key:
            return False
        try:
            self.public_key.verify(
                signature,
                data,
                padding.PSS(mgf=padding.MGF1(hashes.SHA256()), salt_length=padding.PSS.MAX_LENGTH),
                hashes.SHA256(),
            )
            return True
        except InvalidSignature:
            return False

    @staticmethod
    def _parse_model_payload(payload: bytes) -> Dict[str, Any]:
        try:
            decoded = base64.b64decode(payload)
            model_dict = json.loads(decoded)
        except (json.JSONDecodeError, ValueError):
            model_dict = json.loads(payload.decode("utf-8"))
        model_dict.setdefault("checksum", sha256(payload).hexdigest())
        return model_dict

    def _load_weights_from_dict(self, model_dict: Dict[str, Any]) -> None:
        weights_blob = model_dict.get("weights", {})
        biases_blob = model_dict.get("biases", {})

        if not weights_blob or not biases_blob:
            raise ValueError("Model payload missing weights or biases")

        for layer, values in weights_blob.items():
            self.weights[layer] = np.asarray(values, dtype=self.model_config.dtype)
        for layer, values in biases_blob.items():
            self.biases[layer] = np.asarray(values, dtype=self.model_config.dtype)

        # Validate topology
        expected_layers = len(self.model_config.hidden_layers) + 1
        if len(self.weights) != expected_layers:
            raise ValueError("Loaded weights do not match configured architecture")

    # ------------------------------------------------------------------
    # Inference
    # ------------------------------------------------------------------
    def predict(self, features: np.ndarray) -> np.ndarray:
        if not self.model_loaded:
            logger.warning("Model not loaded – returning uniform probabilities")
            return np.full(self.model_config.output_size, 1.0 / self.model_config.output_size)

        activations = features.astype(self.model_config.dtype, copy=False)
        for idx in range(len(self.model_config.hidden_layers) + 1):
            weight = self.weights[f"layer_{idx}"]
            bias = self.biases[f"layer_{idx}"]
            activations = activations @ weight + bias
            if idx < len(self.model_config.hidden_layers):
                if self.model_config.activation == "relu":
                    activations = np.maximum(activations, 0)
                elif self.model_config.activation == "tanh":
                    activations = np.tanh(activations)
                else:
                    pass
            else:
                activations = softmax(activations)
        return activations

    def get_threat_level(self, probabilities: np.ndarray) -> str:
        levels = ["CRITICAL", "ELEVATED", "STANDARD", "IGNORE"]
        return levels[int(np.argmax(probabilities))]

    def get_confidence(self, probabilities: np.ndarray) -> float:
        return float(np.max(probabilities))

    # ------------------------------------------------------------------
    # Utility helpers
    # ------------------------------------------------------------------
    def preprocess_features(self, raw_features: Dict[str, Any]) -> np.ndarray:
        vector = np.zeros(self.model_config.input_size, dtype=self.model_config.dtype)
        for idx, (_, value) in enumerate(raw_features.items()):
            if idx >= self.model_config.input_size:
                break
            vector[idx] = float(value)
        return vector

    def save_model(self, path: str) -> bool:
        try:
            payload = {
                "version": self.version,
                "config": {
                    "input_size": self.model_config.input_size,
                    "hidden_layers": self.model_config.hidden_layers,
                    "output_size": self.model_config.output_size,
                    "activation": self.model_config.activation,
                },
                "weights": {k: v.tolist() for k, v in self.weights.items()},
                "biases": {k: v.tolist() for k, v in self.biases.items()},
            }
            Path(path).write_text(json.dumps(payload, indent=2))
            return True
        except Exception as exc:
            logger.exception("Failed to persist model: %s", exc)
            return False


__all__ = ["NeuralNetwork", "ModelConfig"]
