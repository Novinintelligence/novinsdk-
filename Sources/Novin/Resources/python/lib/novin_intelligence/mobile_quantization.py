"""Model quantization utilities for the NovinAI security system."""

import logging
import numpy as np
from typing import Dict, Any, Optional, Union
from dataclasses import dataclass
import json

from .neural_network import NeuralNetwork, ModelConfig
from .security import SecurityConfig

logger = logging.getLogger(__name__)


@dataclass
class QuantizationConfig:
    """Configuration for model quantization."""
    quantization_mode: str = "int8"  # "int8", "uint8", "fp16", "mixed"
    enable_per_channel: bool = True
    enable_symmetric: bool = True
    calibration_data_size: int = 1000
    enable_quantize_bias: bool = True
    enable_fuse_bn: bool = True
    preserve_fp32_output: bool = False


class ModelQuantizer:
    """Production-ready model quantizer for the NovinAI security system."""
    
    def __init__(self, config: SecurityConfig, quantization_config: Optional[QuantizationConfig] = None):
        self.config = config
        self.quantization_config = quantization_config or QuantizationConfig()
        self.logger = logging.getLogger("NovinAI.ModelQuantizer")
        self.calibration_data = None
        
    def quantize_model(self, model: NeuralNetwork) -> NeuralNetwork:
        """
        Quantize the model for mobile deployment.
        
        Args:
            model: Neural network model to quantize
            
        Returns:
            Quantized model
        """
        try:
            self.logger.info(f"Starting model quantization ({self.quantization_config.quantization_mode})...")
            
            # Prepare calibration data if needed
            if self.calibration_data is None:
                self._generate_calibration_data(model)
            
            # Apply quantization based on mode
            if self.quantization_config.quantization_mode == "int8":
                quantized_model = self._quantize_int8(model)
            elif self.quantization_config.quantization_mode == "uint8":
                quantized_model = self._quantize_uint8(model)
            elif self.quantization_config.quantization_mode == "fp16":
                quantized_model = self._quantize_fp16(model)
            elif self.quantization_config.quantization_mode == "mixed":
                quantized_model = self._quantize_mixed(model)
            else:
                raise ValueError(f"Unsupported quantization mode: {self.quantization_config.quantization_mode}")
            
            # Update model configuration
            quantized_model.model_config.quantized = True
            quantized_model.model_config.dtype = self._get_quantized_dtype()
            
            self.logger.info("Model quantization completed successfully")
            return quantized_model
            
        except Exception as e:
            self.logger.error(f"Model quantization failed: {e}")
            raise
    
    def _quantize_int8(self, model: NeuralNetwork) -> NeuralNetwork:
        """
        Quantize model weights to int8.
        
        Args:
            model: Neural network model
            
        Returns:
            Quantized model
        """
        self.logger.info("Quantizing model to int8...")
        
        # Create a copy of the model for quantization
        quantized_model = NeuralNetwork(self.config)
        quantized_model.weights = {}
        quantized_model.biases = {}
        
        # Quantize each layer
        for layer_name, weights in model.weights.items():
            # Calculate quantization parameters
            min_val = np.min(weights)
            max_val = np.max(weights)
            
            # For symmetric quantization
            if self.quantization_config.enable_symmetric:
                max_abs = max(abs(min_val), abs(max_val))
                scale = max_abs / 127.0  # int8 range is [-128, 127]
                zero_point = 0
            else:
                # For asymmetric quantization
                scale = (max_val - min_val) / 255.0  # uint8 range is [0, 255]
                zero_point = int(-min_val / scale)
            
            # Quantize weights
            if self.quantization_config.enable_symmetric:
                quantized_weights = np.round(weights / scale).astype(np.int8)
            else:
                quantized_weights = np.round(weights / scale + zero_point).astype(np.uint8)
            
            quantized_model.weights[layer_name] = quantized_weights
            
            # Store quantization parameters
            if not hasattr(quantized_model, 'quantization_params'):
                quantized_model.quantization_params = {}
            quantized_model.quantization_params[layer_name] = {
                'scale': scale,
                'zero_point': zero_point,
                'symmetric': self.quantization_config.enable_symmetric
            }
        
        # Quantize biases if enabled
        if self.quantization_config.enable_quantize_bias:
            for layer_name, biases in model.biases.items():
                if layer_name in quantized_model.quantization_params:
                    params = quantized_model.quantization_params[layer_name]
                    if self.quantization_config.enable_symmetric:
                        quantized_biases = np.round(biases / params['scale']).astype(np.int32)
                    else:
                        quantized_biases = np.round(biases / params['scale']).astype(np.int32)
                    quantized_model.biases[layer_name] = quantized_biases
        
        self.logger.info("int8 quantization completed")
        return quantized_model
    
    def _quantize_uint8(self, model: NeuralNetwork) -> NeuralNetwork:
        """
        Quantize model weights to uint8.
        
        Args:
            model: Neural network model
            
        Returns:
            Quantized model
        """
        self.logger.info("Quantizing model to uint8...")
        
        # Similar to int8 but with different range
        quantized_model = NeuralNetwork(self.config)
        quantized_model.weights = {}
        quantized_model.biases = {}
        
        for layer_name, weights in model.weights.items():
            min_val = np.min(weights)
            max_val = np.max(weights)
            
            scale = (max_val - min_val) / 255.0
            zero_point = int(-min_val / scale)
            
            quantized_weights = np.round(weights / scale + zero_point).astype(np.uint8)
            quantized_model.weights[layer_name] = quantized_weights
            
            if not hasattr(quantized_model, 'quantization_params'):
                quantized_model.quantization_params = {}
            quantized_model.quantization_params[layer_name] = {
                'scale': scale,
                'zero_point': zero_point,
                'symmetric': False
            }
        
        self.logger.info("uint8 quantization completed")
        return quantized_model
    
    def _quantize_fp16(self, model: NeuralNetwork) -> NeuralNetwork:
        """
        Quantize model weights to fp16.
        
        Args:
            model: Neural network model
            
        Returns:
            Quantized model
        """
        self.logger.info("Quantizing model to fp16...")
        
        quantized_model = NeuralNetwork(self.config)
        quantized_model.weights = {}
        quantized_model.biases = {}
        
        for layer_name, weights in model.weights.items():
            quantized_weights = weights.astype(np.float16)
            quantized_model.weights[layer_name] = quantized_weights
        
        for layer_name, biases in model.biases.items():
            quantized_biases = biases.astype(np.float16)
            quantized_model.biases[layer_name] = quantized_biases
        
        self.logger.info("fp16 quantization completed")
        return quantized_model
    
    def _quantize_mixed(self, model: NeuralNetwork) -> NeuralNetwork:
        """
        Apply mixed precision quantization.
        
        Args:
            model: Neural network model
            
        Returns:
            Quantized model
        """
        self.logger.info("Applying mixed precision quantization...")
        
        # For mixed precision, we might keep some layers in higher precision
        # This is a simplified implementation
        return self._quantize_int8(model)
    
    def _generate_calibration_data(self, model: NeuralNetwork) -> None:
        """
        Generate calibration data for quantization.
        
        Args:
            model: Neural network model
        """
        self.logger.info("Generating calibration data...")
        
        # In a real implementation, this would use actual representative data
        # For now, we'll generate random data matching the model input size
        input_size = model.model_config.input_size
        batch_size = min(self.quantization_config.calibration_data_size, 100)
        
        self.calibration_data = np.random.rand(batch_size, input_size).astype(np.float32)
        self.logger.info(f"Generated {batch_size} calibration samples")
    
    def _get_quantized_dtype(self) -> np.dtype:
        """
        Get the appropriate dtype for quantized model.
        
        Returns:
            Quantized dtype
        """
        if self.quantization_config.quantization_mode == "int8":
            return np.int8
        elif self.quantization_config.quantization_mode == "uint8":
            return np.uint8
        elif self.quantization_config.quantization_mode == "fp16":
            return np.float16
        else:
            return np.float32
    
    def dequantize_model(self, quantized_model: NeuralNetwork) -> NeuralNetwork:
        """
        Dequantize a quantized model back to float32.
        
        Args:
            quantized_model: Quantized neural network model
            
        Returns:
            Dequantized model
        """
        try:
            self.logger.info("Dequantizing model...")
            
            # Create a copy of the model for dequantization
            dequantized_model = NeuralNetwork(self.config)
            dequantized_model.weights = {}
            dequantized_model.biases = {}
            
            # Dequantize weights
            for layer_name, quantized_weights in quantized_model.weights.items():
                if (hasattr(quantized_model, 'quantization_params') and 
                    layer_name in quantized_model.quantization_params):
                    # Apply dequantization
                    params = quantized_model.quantization_params[layer_name]
                    if params['symmetric']:
                        dequantized_weights = quantized_weights.astype(np.float32) * params['scale']
                    else:
                        dequantized_weights = (quantized_weights.astype(np.float32) - params['zero_point']) * params['scale']
                else:
                    # If no quantization params, assume no quantization was applied
                    dequantized_weights = quantized_weights.astype(np.float32)
                
                dequantized_model.weights[layer_name] = dequantized_weights
            
            # Dequantize biases
            for layer_name, quantized_biases in quantized_model.biases.items():
                if (hasattr(quantized_model, 'quantization_params') and 
                    layer_name in quantized_model.quantization_params):
                    params = quantized_model.quantization_params[layer_name]
                    if params['symmetric']:
                        dequantized_biases = quantized_biases.astype(np.float32) * params['scale']
                    else:
                        dequantized_biases = (quantized_biases.astype(np.float32) - params['zero_point']) * params['scale']
                else:
                    dequantized_biases = quantized_biases.astype(np.float32)
                
                dequantized_model.biases[layer_name] = dequantized_biases
            
            # Update model configuration
            dequantized_model.model_config.quantized = False
            dequantized_model.model_config.dtype = np.float32
            
            self.logger.info("Model dequantization completed")
            return dequantized_model
            
        except Exception as e:
            self.logger.error(f"Model dequantization failed: {e}")
            raise
    
    def set_calibration_data(self, data: np.ndarray) -> None:
        """
        Set custom calibration data for quantization.
        
        Args:
            data: Calibration data
        """
        self.calibration_data = data
        self.logger.info(f"Calibration data set with {len(data)} samples")


# Utility functions for quantization

def create_quantization_config(mode: str = "int8") -> QuantizationConfig:
    """
    Create a quantization configuration.
    
    Args:
        mode: Quantization mode ("int8", "uint8", "fp16", "mixed")
        
    Returns:
        Quantization configuration
    """
    return QuantizationConfig(
        quantization_mode=mode,
        enable_per_channel=True,
        enable_symmetric=True,
        calibration_data_size=1000,
        enable_quantize_bias=True,
        enable_fuse_bn=True,
        preserve_fp32_output=False
    )


def get_model_size(model: NeuralNetwork) -> Dict[str, float]:
    """
    Get the size of the model in different formats.
    
    Args:
        model: Neural network model
        
    Returns:
        Dictionary with model sizes in MB
    """
    fp32_size = 0
    int8_size = 0
    fp16_size = 0
    
    # Calculate sizes for weights
    for weights in model.weights.values():
        fp32_size += weights.size * 4  # float32 = 4 bytes
        int8_size += weights.size * 1  # int8 = 1 byte
        fp16_size += weights.size * 2  # float16 = 2 bytes
    
    # Calculate sizes for biases
    for biases in model.biases.values():
        fp32_size += biases.size * 4
        int8_size += biases.size * 1
        fp16_size += biases.size * 2
    
    return {
        "fp32_mb": fp32_size / (1024 * 1024),
        "int8_mb": int8_size / (1024 * 1024),
        "fp16_mb": fp16_size / (1024 * 1024),
        "compression_ratio_int8": fp32_size / int8_size if int8_size > 0 else 1.0,
        "compression_ratio_fp16": fp32_size / fp16_size if fp16_size > 0 else 1.0
    }