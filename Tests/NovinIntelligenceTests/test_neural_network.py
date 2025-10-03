"""Unit tests for the Neural Network module."""

import unittest
import numpy as np
import tempfile
import os

from novin_intelligence.neural_network import NeuralNetwork, ModelConfig
from novin_intelligence.security import SecurityConfig


class TestNeuralNetwork(unittest.TestCase):
    """Test cases for NeuralNetwork class."""

    def setUp(self):
        """Set up test fixtures."""
        self.config = SecurityConfig()
        self.neural_net = NeuralNetwork(self.config)

    def test_initialization(self):
        """Test NeuralNetwork initialization."""
        self.assertIsInstance(self.neural_net, NeuralNetwork)
        self.assertIsInstance(self.neural_net.model_config, ModelConfig)
        self.assertIsInstance(self.neural_net.weights, dict)
        self.assertIsInstance(self.neural_net.biases, dict)
        self.assertFalse(self.neural_net.model_loaded)

    def test_model_configuration(self):
        """Test model configuration."""
        config = self.neural_net.model_config
        self.assertEqual(config.input_size, 16384)
        self.assertEqual(config.hidden_layers, (512, 256, 128))
        self.assertEqual(config.output_size, 4)
        self.assertEqual(config.activation, "relu")
        self.assertEqual(config.dropout_rate, 0.15)

    def test_weight_initialization(self):
        """Test weight initialization."""
        # Check that weights and biases were initialized for each layer
        expected_layers = len(self.neural_net.model_config.hidden_layers) + 1
        
        self.assertEqual(len(self.neural_net.weights), expected_layers)
        self.assertEqual(len(self.neural_net.biases), expected_layers)
        
        # Check weight shapes
        layer_sizes = (self.neural_net.model_config.input_size, 
                      *self.neural_net.model_config.hidden_layers, 
                      self.neural_net.model_config.output_size)
        
        for i in range(expected_layers):
            layer_name = f"layer_{i}"
            self.assertIn(layer_name, self.neural_net.weights)
            self.assertIn(layer_name, self.neural_net.biases)
            
            expected_weight_shape = (layer_sizes[i], layer_sizes[i + 1])
            expected_bias_shape = (layer_sizes[i + 1],)
            
            self.assertEqual(self.neural_net.weights[layer_name].shape, expected_weight_shape)
            self.assertEqual(self.neural_net.biases[layer_name].shape, expected_bias_shape)

    def test_activation_functions(self):
        """Test activation functions."""
        x = np.array([-2, -1, 0, 1, 2])
        
        # Test ReLU
        result = self.neural_net._apply_activation(x, "relu")
        expected = np.maximum(0, x)
        np.testing.assert_array_equal(result, expected)
        
        # Test sigmoid
        result = self.neural_net._apply_activation(x, "sigmoid")
        expected = 1 / (1 + np.exp(-np.clip(x, -500, 500)))
        np.testing.assert_array_almost_equal(result, expected)
        
        # Test tanh
        result = self.neural_net._apply_activation(x, "tanh")
        expected = np.tanh(x)
        np.testing.assert_array_almost_equal(result, expected)
        
        # Test linear
        result = self.neural_net._apply_activation(x, "linear")
        np.testing.assert_array_equal(result, x)
        
        # Test unknown activation (should default to linear)
        result = self.neural_net._apply_activation(x, "unknown")
        np.testing.assert_array_equal(result, x)

    def test_prediction_single(self):
        """Test single prediction."""
        # Create test input
        input_data = np.random.rand(self.neural_net.model_config.input_size)
        
        # Test prediction
        prediction = self.neural_net.predict_single(input_data)
        
        self.assertIsInstance(prediction, np.ndarray)
        self.assertEqual(prediction.shape, (self.neural_net.model_config.output_size,))
        
        # Predictions should be probabilities (sum to 1)
        self.assertAlmostEqual(np.sum(prediction), 1.0, places=5)
        
        # All values should be between 0 and 1
        self.assertTrue(np.all(prediction >= 0))
        self.assertTrue(np.all(prediction <= 1))

    def test_prediction_batch(self):
        """Test batch prediction."""
        # Create test input batch
        batch_size = 5
        input_data = np.random.rand(batch_size, self.neural_net.model_config.input_size)
        
        # Test prediction
        predictions = self.neural_net.predict(input_data)
        
        self.assertIsInstance(predictions, np.ndarray)
        self.assertEqual(predictions.shape, (batch_size, self.neural_net.model_config.output_size))
        
        # Each prediction should be probabilities (sum to 1)
        for i in range(batch_size):
            self.assertAlmostEqual(np.sum(predictions[i]), 1.0, places=5)
            self.assertTrue(np.all(predictions[i] >= 0))
            self.assertTrue(np.all(predictions[i] <= 1))

    def test_input_shape_validation(self):
        """Test input shape validation."""
        # Test with correct input size
        correct_input = np.random.rand(self.neural_net.model_config.input_size)
        try:
            prediction = self.neural_net.predict_single(correct_input)
            self.assertIsInstance(prediction, np.ndarray)
        except Exception as e:
            self.fail(f"Prediction with correct input size failed: {e}")
        
        # Test with incorrect input size
        incorrect_input = np.random.rand(self.neural_net.model_config.input_size + 1)
        with self.assertRaises(ValueError):
            self.neural_net.predict_single(incorrect_input)

    def test_model_info(self):
        """Test model information retrieval."""
        info = self.neural_net.get_model_info()
        
        self.assertIsInstance(info, dict)
        self.assertIn("version", info)
        self.assertIn("input_size", info)
        self.assertIn("hidden_layers", info)
        self.assertIn("output_size", info)
        self.assertIn("activation", info)
        self.assertIn("dropout_rate", info)
        self.assertIn("quantized", info)
        self.assertIn("model_loaded", info)
        self.assertIn("num_parameters", info)
        
        self.assertEqual(info["input_size"], self.neural_net.model_config.input_size)
        self.assertEqual(info["output_size"], self.neural_net.model_config.output_size)
        self.assertEqual(info["model_loaded"], self.neural_net.model_loaded)

    def test_save_model(self):
        """Test model saving."""
        # Create temporary file for testing
        fd, path = tempfile.mkstemp(suffix='.json')
        
        try:
            # Test saving model
            result = self.neural_net.save_model(path)
            self.assertTrue(result)
            
            # Check if file was created
            self.assertTrue(os.path.exists(path))
            
        finally:
            # Clean up
            os.close(fd)
            if os.path.exists(path):
                os.unlink(path)
            # Also clean up signature file if it was created
            sig_path = f"{path}.sig"
            if os.path.exists(sig_path):
                os.unlink(sig_path)

    def test_model_loading_mock(self):
        """Test model loading with mock data."""
        # This test would require actual model files to be more meaningful
        # For now, we'll just test that the method exists and handles errors gracefully
        
        # Test with non-existent files
        result = self.neural_net.load_model("nonexistent_model.json", 
                                          "nonexistent_model.json.sig", 
                                          "nonexistent_public_key.pem")
        self.assertFalse(result)


if __name__ == '__main__':
    unittest.main()