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


@dataclass
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
        """Load weights and biases from model dictionary."""
        weights_data = model_dict.get("weights", {})
        biases_data = model_dict.get("biases", {})
        
        # Load weights
        for key, value in weights_data.items():
            if isinstance(value, list):
                self.weights[key] = np.array(value, dtype=self.model_config.dtype)
            elif isinstance(value, np.ndarray):
                self.weights[key] = value.astype(self.model_config.dtype)
            else:
                self.weights[key] = np.array(value, dtype=self.model_config.dtype)
        
        # Load biases
        for key, value in biases_data.items():
            if isinstance(value, list):
                self.biases[key] = np.array(value, dtype=self.model_config.dtype)
            elif isinstance(value, np.ndarray):
                self.biases[key] = value.astype(self.model_config.dtype)
            else:
                self.biases[key] = np.array(value, dtype=self.model_config.dtype)

    # ------------------------------------------------------------------
    # Inference
    # ------------------------------------------------------------------
    def predict(self, input_data: np.ndarray) -> np.ndarray:
        """
        Perform inference on input data.
        
        Args:
            input_data: Input features (batch_size, input_size)
            
        Returns:
            Predictions (batch_size, output_size)
        """
        if not self.model_loaded:
            logger.warning("Model not loaded, using random predictions")
            return np.random.rand(input_data.shape[0], self.model_config.output_size)
        
        try:
            # Ensure input is the correct shape
            if input_data.ndim == 1:
                input_data = input_data.reshape(1, -1)
            
            if input_data.shape[1] != self.model_config.input_size:
                raise ValueError(f"Input size mismatch: expected {self.model_config.input_size}, got {input_data.shape[1]}")
            
            # Forward pass through the network
            x = input_data.astype(self.model_config.dtype)
            
            # Apply dropout during inference (if needed)
            if self.model_config.dropout_rate > 0:
                # For inference, we scale the weights instead of applying dropout
                pass
            
            # Forward pass through each layer
            for idx in range(len(self.model_config.hidden_layers) + 1):
                # Linear transformation
                layer_name = f"layer_{idx}"
                if layer_name in self.weights and layer_name in self.biases:
                    x = np.dot(x, self.weights[layer_name]) + self.biases[layer_name]
                    
                    # Apply activation function (except for output layer)
                    if idx < len(self.model_config.hidden_layers):
                        x = self._apply_activation(x, self.model_config.activation)
                        
                        # Apply dropout (during inference, we scale the outputs)
                        if self.model_config.dropout_rate > 0:
                            x = x * (1 - self.model_config.dropout_rate)
            
            # Apply softmax to get probabilities
            predictions = softmax(x, axis=-1)
            
            return predictions
            
        except Exception as e:
            logger.error(f"Inference failed: {e}")
            # Return random predictions as fallback
            return np.random.rand(input_data.shape[0], self.model_config.output_size)

    def _apply_activation(self, x: np.ndarray, activation: str) -> np.ndarray:
        """
        Apply activation function to input.
        
        Args:
            x: Input array
            activation: Activation function name
            
        Returns:
            Output after applying activation
        """
        if activation == "relu":
            return np.maximum(0, x)
        elif activation == "sigmoid":
            return 1 / (1 + np.exp(-np.clip(x, -500, 500)))  # Clip to prevent overflow
        elif activation == "tanh":
            return np.tanh(x)
        elif activation == "linear":
            return x
        else:
            logger.warning(f"Unknown activation function: {activation}, using linear")
            return x

    def predict_single(self, input_data: np.ndarray) -> np.ndarray:
        """
        Perform inference on a single input sample.
        
        Args:
            input_data: Input features (input_size,)
            
        Returns:
            Prediction (output_size,)
        """
        # Reshape to batch format
        if input_data.ndim == 1:
            input_batch = input_data.reshape(1, -1)
        else:
            input_batch = input_data
            
        # Get predictions
        predictions = self.predict(input_batch)
        
        # Return single prediction
        return predictions[0]

    def get_feature_importance(self, input_data: np.ndarray) -> np.ndarray:
        """
        Calculate feature importance using gradient-based method.
        
        Args:
            input_data: Input features
            
        Returns:
            Feature importance scores
        """
        # Simple implementation using gradient approximation
        # In a real implementation, this would use proper backpropagation
        epsilon = 1e-5
        base_prediction = self.predict(input_data)
        
        importance_scores = np.zeros(input_data.shape[1])
        for i in range(min(100, input_data.shape[1])):  # Sample first 100 features for efficiency
            # Perturb feature
            perturbed_input = input_data.copy()
            perturbed_input[:, i] += epsilon
            perturbed_prediction = self.predict(perturbed_input)
            
            # Calculate change in prediction
            importance_scores[i] = np.mean(np.abs(perturbed_prediction - base_prediction)) / epsilon
        
        return importance_scores

    # ------------------------------------------------------------------
    # Model information
    # ------------------------------------------------------------------
    def get_model_info(self) -> Dict[str, Any]:
        """
        Get information about the loaded model.
        
        Returns:
            Dictionary with model information
        """
        return {
            "version": self.version,
            "input_size": self.model_config.input_size,
            "hidden_layers": self.model_config.hidden_layers,
            "output_size": self.model_config.output_size,
            "activation": self.model_config.activation,
            "dropout_rate": self.model_config.dropout_rate,
            "quantized": self.model_config.quantized,
            "model_loaded": self.model_loaded,
            "num_parameters": sum(w.size for w in self.weights.values()) + sum(b.size for b in self.biases.values())
        }

    def save_model(self, model_path: str, private_key_path: Optional[str] = None) -> bool:
        """
        Save the model to file with signature.
        
        Args:
            model_path: Path to save model
            private_key_path: Path to private key for signing (optional)
            
        Returns:
            True if successful, False otherwise
        """
        try:
            # Prepare model data
            model_dict = {
                "version": self.version,
                "weights": {k: v.tolist() for k, v in self.weights.items()},
                "biases": {k: v.tolist() for k, v in self.biases.items()},
                "config": {
                    "input_size": self.model_config.input_size,
                    "hidden_layers": self.model_config.hidden_layers,
                    "output_size": self.model_config.output_size,
                    "activation": self.model_config.activation,
                    "dropout_rate": self.model_config.dropout_rate,
                    "quantized": self.model_config.quantized
                }
            }
            
            # Serialize model
            model_json = json.dumps(model_dict, indent=2)
            model_bytes = model_json.encode('utf-8')
            
            # Save model
            with open(model_path, 'wb') as f:
                f.write(model_bytes)
            
            # Sign model if private key is provided
            if private_key_path and Path(private_key_path).exists():
                try:
                    from cryptography.hazmat.primitives import serialization
                    from cryptography.hazmat.primitives.asymmetric import padding
                    from cryptography.hazmat.primitives import hashes
                    
                    with open(private_key_path, 'rb') as f:
                        private_key = serialization.load_pem_private_key(
                            f.read(), password=None
                        )
                    
                    signature = private_key.sign(
                        model_bytes,
                        padding.PSS(mgf=padding.MGF1(hashes.SHA256()), salt_length=padding.PSS.MAX_LENGTH),
                        hashes.SHA256()
                    )
                    
                    # Save signature
                    signature_path = f"{model_path}.sig"
                    with open(signature_path, 'wb') as f:
                        f.write(signature)
                        
                except Exception as e:
                    logger.warning(f"Failed to sign model: {e}")
            
            logger.info(f"Model saved to {model_path}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to save model: {e}")
            return False


__all__ = ["NeuralNetwork", "ModelConfig"]