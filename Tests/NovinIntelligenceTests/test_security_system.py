"""Unit tests for the Security System module."""

import unittest
import numpy as np
from datetime import datetime, timezone
from unittest.mock import patch, MagicMock

from novin_intelligence.security import NovinAISecuritySystem, SecurityConfig, ThreatLevel
from novin_intelligence.error_handling import ValidationError, RateLimitError


class TestNovinAISecuritySystem(unittest.TestCase):
    """Test cases for NovinAISecuritySystem class."""

    def setUp(self):
        """Set up test fixtures."""
        self.config = SecurityConfig()
        # Reduce config values for faster testing
        self.config.max_events_per_request = 5
        self.config.rate_limit_rpm = 100  # Higher rate limit for testing
        
        with patch('novin_intelligence.neural_network.NeuralNetwork.load_model'):
            self.security_system = NovinAISecuritySystem(self.config)

    def test_initialization(self):
        """Test NovinAISecuritySystem initialization."""
        self.assertIsInstance(self.security_system, NovinAISecuritySystem)
        self.assertIsInstance(self.security_system.config, SecurityConfig)
        self.assertTrue(self.security_system._initialized)

    def test_system_info(self):
        """Test system information retrieval."""
        info = self.security_system.get_system_info()
        
        self.assertIsInstance(info, dict)
        self.assertIn("version", info)
        self.assertIn("initialized", info)
        self.assertIn("uptime", info)
        self.assertIn("requests_processed", info)
        self.assertIn("model_info", info)
        self.assertIn("performance_metrics", info)
        
        self.assertTrue(info["initialized"])
        self.assertEqual(info["version"], "2.0.0")

    def test_health_check(self):
        """Test system health check."""
        health = self.security_system.health_check()
        
        self.assertIsInstance(health, dict)
        self.assertIn("status", health)
        self.assertIn("timestamp", health)
        self.assertIn("components", health)
        
        self.assertIn("neural_network", health["components"])
        self.assertIn("status", health["components"]["neural_network"])

    def test_request_validation(self):
        """Test request validation."""
        # Test with valid request
        valid_request = {
            "events": [
                {
                    "type": "motion",
                    "timestamp": datetime.now(UTC).isoformat(),
                    "confidence": 0.8
                }
            ],
            "timestamp": datetime.now(UTC).isoformat()
        }
        
        # This should not raise an exception
        try:
            self.security_system._validate_request(valid_request)
        except Exception as e:
            self.fail(f"Valid request validation failed: {e}")
        
        # Test with missing events
        invalid_request = {
            "timestamp": datetime.now(UTC).isoformat()
        }
        
        with self.assertRaises(ValidationError) as context:
            self.security_system._validate_request(invalid_request)
        
        self.assertEqual(context.exception.code, "MISSING_REQUIRED_FIELD")
        
        # Test with too many events
        invalid_request = {
            "events": [{}] * (self.config.max_events_per_request + 1),
            "timestamp": datetime.now(UTC).isoformat()
        }
        
        with self.assertRaises(ValidationError) as context:
            self.security_system._validate_request(invalid_request)
        
        self.assertEqual(context.exception.code, "TOO_MANY_EVENTS")

    def test_location_extraction(self):
        """Test location extraction from request."""
        # Test with location data
        request_with_location = {
            "events": [],
            "timestamp": datetime.now(UTC).isoformat(),
            "location": {
                "latitude": 37.7749,
                "longitude": -122.4194
            }
        }
        
        location = self.security_system._extract_location(request_with_location)
        self.assertEqual(location, (37.7749, -122.4194))
        
        # Test without location data
        request_without_location = {
            "events": [],
            "timestamp": datetime.now(UTC).isoformat()
        }
        
        location = self.security_system._extract_location(request_without_location)
        self.assertEqual(location, (0.0, 0.0))

    def test_threat_level_determination(self):
        """Test threat level determination."""
        # Mock prediction and reasoning result
        prediction = np.array([0.1, 0.2, 0.3, 0.4])  # Low threat
        
        mock_reasoning_result = MagicMock()
        mock_reasoning_result.risk_score = 0.2
        
        threat_level = self.security_system._determine_threat_level(prediction, mock_reasoning_result)
        self.assertEqual(threat_level, ThreatLevel.LOW)
        
        # Test high threat
        prediction = np.array([0.05, 0.05, 0.1, 0.8])  # High threat
        
        mock_reasoning_result.risk_score = 0.85
        
        threat_level = self.security_system._determine_threat_level(prediction, mock_reasoning_result)
        self.assertEqual(threat_level, ThreatLevel.HIGH)
        
        # Test critical threat
        prediction = np.array([0.01, 0.01, 0.01, 0.97])  # Critical threat
        
        mock_reasoning_result.risk_score = 0.98
        
        threat_level = self.security_system._determine_threat_level(prediction, mock_reasoning_result)
        self.assertEqual(threat_level, ThreatLevel.CRITICAL)

    def test_process_request_success(self):
        """Test successful request processing."""
        request_data = {
            "events": [
                {
                    "type": "motion",
                    "timestamp": datetime.now(UTC).isoformat(),
                    "confidence": 0.8,
                    "location": {
                        "latitude": 37.7749,
                        "longitude": -122.4194
                    }
                }
            ],
            "timestamp": datetime.now(UTC).isoformat(),
            "location": {
                "latitude": 37.7749,
                "longitude": -122.4194
            }
        }
        
        # Mock the internal processing methods to avoid complex dependencies
        with patch.object(self.security_system, '_get_crime_context', return_value={}):
            with patch.object(self.security_system.feature_extractor, 'extract', return_value=np.random.rand(16384)):
                with patch.object(self.security_system.neural_network, 'predict_single', return_value=np.array([0.1, 0.2, 0.3, 0.4])):
                    with patch.object(self.security_system.reasoning_engine, 'reason', return_value=MagicMock(
                        threat_assessment="low_risk",
                        confidence=0.8,
                        key_factors=["normal_activity"],
                        recommendations=["continue_monitoring"],
                        risk_score=0.2
                    )):
                        result = self.security_system.process_request(request_data, "test_client")
                        
                        self.assertIsInstance(result, dict)
                        self.assertIn("requestId", result)
                        self.assertIn("clientId", result)
                        self.assertIn("timestamp", result)
                        self.assertIn("threatLevel", result)
                        self.assertIn("threatScore", result)
                        self.assertIn("confidence", result)
                        self.assertIn("predictions", result)
                        self.assertIn("reasoning", result)
                        self.assertIn("context", result)
                        self.assertIn("processingTime", result)
                        
                        self.assertFalse(result.get("error", False))

    def test_process_request_validation_error(self):
        """Test request processing with validation error."""
        # Invalid request (missing required fields)
        invalid_request = {
            "some_field": "value"
        }
        
        result = self.security_system.process_request(invalid_request, "test_client")
        
        self.assertIsInstance(result, dict)
        self.assertTrue(result.get("error", False))
        self.assertIn("errorCode", result)
        self.assertIn("message", result)

    def test_process_request_rate_limit(self):
        """Test request processing with rate limiting."""
        # Create a request that should pass validation
        valid_request = {
            "events": [
                {
                    "type": "motion",
                    "timestamp": datetime.now(UTC).isoformat(),
                    "confidence": 0.8
                }
            ],
            "timestamp": datetime.now(UTC).isoformat()
        }
        
        # Mock rate limiter to simulate rate limit exceeded
        with patch.object(self.security_system.rate_limiter, 'check_rate_limit', side_effect=RateLimitError(60, 50)):
            result = self.security_system.process_request(valid_request, "test_client")
            
            self.assertIsInstance(result, dict)
            self.assertTrue(result.get("error", False))
            self.assertEqual(result.get("errorCode"), "RATE_LIMIT_EXCEEDED")

    def test_get_next_request_id(self):
        """Test request ID generation."""
        id1 = self.security_system._get_next_request_id()
        id2 = self.security_system._get_next_request_id()
        
        self.assertIsInstance(id1, int)
        self.assertIsInstance(id2, int)
        self.assertEqual(id2, id1 + 1)

    def test_time_context(self):
        """Test time context generation."""
        context = self.security_system._get_time_context()
        
        self.assertIsInstance(context, dict)
        self.assertIn("hour", context)
        self.assertIn("day_of_week", context)
        self.assertIn("is_weekend", context)
        self.assertIn("season", context)
        
        self.assertIsInstance(context["hour"], int)
        self.assertIsInstance(context["day_of_week"], int)
        self.assertIsInstance(context["is_weekend"], bool)
        self.assertIsInstance(context["season"], str)

    def test_system_state(self):
        """Test system state retrieval."""
        state = self.security_system._get_system_state()
        
        self.assertIsInstance(state, dict)
        self.assertIn("timestamp", state)
        self.assertIn("uptime", state)


if __name__ == '__main__':
    unittest.main()