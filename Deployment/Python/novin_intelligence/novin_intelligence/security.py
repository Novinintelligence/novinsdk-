# NovinAI Security System
# A complete, production-ready AI security threat assessment system.

# Standard Library Imports
import base64
import collections
import dataclasses
import datetime
import enum
import hashlib
import hmac
import json
import logging
import logging.handlers
import os
import re
import threading
import time
from dataclasses import dataclass
from typing import Any, Dict, List, Tuple, Optional, Set, Callable

# Third-Party Imports (as specified in the prompt)
import numpy as np
from scipy.special import softmax

# Optional dependencies for full functionality
try:
    import psutil
except ImportError:
    psutil = None

try:
    from cryptography.hazmat.primitives import hashes
    from cryptography.hazmat.primitives.asymmetric import padding, rsa
    from cryptography.hazmat.primitives.serialization import load_pem_public_key
    from cryptography.exceptions import InvalidSignature
except ImportError:
    hashes = None
    padding = None
    rsa = None
    load_pem_public_key = None
    InvalidSignature = None

# Local Imports
from .neural_network import NeuralNetwork
from .feature_extractor import FeatureExtraction
from .crime_intelligence import CrimeIntelligence, CrimeContext
from .gemma_reasoning import GemmaReasoning, ReasoningContext, ReasoningResult
from .model_loader import ModelLoader
from .performance import PerformanceMonitor
from .rate_limiter import RateLimiter
from .production import ProductionManager
from .error_handling import NovinAIError, ValidationError, ProcessingError, RateLimitError

# --- 1. Configuration & Core Types ---

@dataclass
class SecurityConfig:
    """Single source of truth for all system parameters."""
    # Neural Network
    n_features: int = 16384
    n_classes: int = 4
    weight_init_bound: float = 0.1
    weight_security_max: float = 5.0
    prediction_timeout: float = 0.05
    
    # Feature Engineering
    max_cache_size: int = 5000
    cache_ttl_seconds: int = 1800
    max_events_per_request: int = 25
    max_metadata_bytes: int = 512
    
    # Rule Engine
    rule_priority_max: int = 10
    emergency_threshold: float = 0.95
    pet_confidence_threshold: float = 0.85
    door_open_threshold: float = 0.75
    noise_alert_db: int = 85
    face_recognition_threshold: float = 0.95
    
    # Crime Intelligence
    crime_cache_ttl: int = 3600
    crime_recency_days: int = 14
    crime_escalation_count: int = 2
    max_crime_index: float = 1.0
    
    # Event Correlation
    duplicate_event_window_seconds: int = 5
    
    # Reasoning Engine
    max_reasoning_layers: int = 8
    early_termination_confidence: float = 0.98
    reasoning_timeout: float = 0.1
    
    # Security & Performance
    rate_limit_rpm: int = 50
    cpu_max_percent: float = 70.0
    memory_max_percent: float = 75.0
    error_rate_max: float = 0.01
    max_processing_time: float = 0.1
    
    # Validation
    latitude_bounds: Tuple[float, float] = (-90.0, 90.0)
    longitude_bounds: Tuple[float, float] = (-180.0, 180.0)
    confidence_bounds: Tuple[float, float] = (0.0, 1.0)
    battery_bounds: Tuple[float, float] = (0.0, 100.0)
    decibel_max: float = 150.0
from .performance import PerformanceMonitor
from .rate_limiter import RateLimiter
from .production import ProductionManager
from .error_handling import NovinAIError, ValidationError, ProcessingError, RateLimitError

# --- 1. Configuration & Core Types ---

@dataclass
class SecurityConfig:
    """Single source of truth for all system parameters."""
    # Neural Network
    n_features: int = 16384
    n_classes: int = 4
    weight_init_bound: float = 0.1
    weight_security_max: float = 5.0
    prediction_timeout: float = 0.05
    
    # Feature Engineering
    max_cache_size: int = 5000
    cache_ttl_seconds: int = 1800
    max_events_per_request: int = 25
    max_metadata_bytes: int = 512
    
    # Rule Engine
    rule_priority_max: int = 10
    emergency_threshold: float = 0.95
    pet_confidence_threshold: float = 0.85
    door_open_threshold: float = 0.75
    noise_alert_db: int = 85
    face_recognition_threshold: float = 0.95
    
    # Crime Intelligence
    crime_cache_ttl: int = 3600
    crime_recency_days: int = 14
    crime_escalation_count: int = 2
    max_crime_index: float = 1.0
    
    # Event Correlation
    duplicate_event_window_seconds: int = 5
    
    # Reasoning Engine
    max_reasoning_layers: int = 8
    early_termination_confidence: float = 0.98
    reasoning_timeout: float = 0.1
    
    # Security & Performance
    rate_limit_rpm: int = 50
    cpu_max_percent: float = 70.0
    memory_max_percent: float = 75.0
    error_rate_max: float = 0.01
    max_processing_time: float = 0.1
    
    # Validation
    latitude_bounds: Tuple[float, float] = (-90.0, 90.0)
    longitude_bounds: Tuple[float, float] = (-180.0, 180.0)
    confidence_bounds: Tuple[float, float] = (0.0, 1.0)
    battery_bounds: Tuple[float, float] = (0.0, 100.0)
    decibel_max: float = 150.0


class ThreatLevel(enum.Enum):
    """Defines the four threat levels for classification."""
    CRITICAL = 3
    HIGH = 2
    MEDIUM = 1
    LOW = 0


# --- 2. Main Security System Class ---

class NovinAISecuritySystem:
    """Production-ready AI security threat assessment system."""
    
    def __init__(self, config: SecurityConfig) -> None:
        self.config = config
        self.logger = logging.getLogger("NovinAI.SecuritySystem")
        
        # Initialize core components
        self.feature_extractor = FeatureExtraction(config)
        self.crime_intelligence = CrimeIntelligence(config)
        self.reasoning_engine = GemmaReasoning(config)
        self.model_loader = ModelLoader(config)
        self.neural_network = NeuralNetwork(config)
        self.performance_monitor = PerformanceMonitor(config)
        self.rate_limiter = RateLimiter(config)
        self.production_manager = ProductionManager(config)
        
        # State management
        self._lock = threading.RLock()
        self._request_counter = 0
        self._initialized = False
        self._startup_time = time.time()
        
        # Initialize system
        self._initialize_system()
    
    def _initialize_system(self) -> None:
        """Initialize all system components."""
        try:
            self.logger.info("Initializing NovinAI Security System...")
            
            # Load security model (if available)
            model_path = os.environ.get("NOVIN_AI_MODEL_PATH", "models/novin_ai_v2.0.json")
            signature_path = f"{model_path}.sig"
            public_key_path = os.environ.get("NOVIN_AI_PUBLIC_KEY_PATH", "models/model_public.pem")
            
            if os.path.exists(model_path) and os.path.exists(signature_path) and os.path.exists(public_key_path):
                if self.neural_network.load_model(model_path, signature_path, public_key_path):
                    self.logger.info("Security model loaded successfully")
                else:
                    self.logger.warning("Failed to load security model, using random predictions")
            else:
                self.logger.info("No pre-trained model found, using initialized random weights")
            
            # Initialize performance monitoring
            init_time = time.time() - self._startup_time
            self.performance_monitor.metrics["initialization_time"] = init_time
            
            self._initialized = True
            self.logger.info(f"NovinAI Security System initialized in {init_time:.3f}s")
            
        except Exception as e:
            self.logger.error(f"System initialization failed: {e}")
            raise
    
    def process_request(self, request_data: Dict[str, Any], client_id: str = "default_client") -> Dict[str, Any]:
        """
        Process a security assessment request.
        
        Args:
            request_data: Request data containing sensor events and metadata
            client_id: Identifier for the client making the request
            
        Returns:
            Security assessment result
        """
        request_id = f"{client_id}_{int(time.time() * 1000000)}_{self._get_next_request_id()}"
        
        try:
            # Start performance monitoring
            self.performance_monitor.start_request(request_id)
            
            # Rate limiting
            self.rate_limiter.check_rate_limit(client_id, request_id)
            
            # Validate request
            self._validate_request(request_data)
            
            # Process request
            result = self._process_request_internal(request_data, client_id, request_id)
            
            # Complete performance monitoring
            self.performance_monitor.end_request(request_id, success=True)
            
            # Complete rate limiting
            self.rate_limiter.complete_request(client_id, request_id)
            
            return result
            
        except RateLimitError:
            self.performance_monitor.end_request(request_id, success=False)
            return {
                "error": True,
                "errorCode": "RATE_LIMIT_EXCEEDED",
                "message": "Request rate limit exceeded",
                "details": {
                    "max_requests": self.config.rate_limit_rpm,
                    "window_seconds": 60
                }
            }
        except ValidationError as e:
            self.performance_monitor.end_request(request_id, success=False)
            self.rate_limiter.complete_request(client_id, request_id)
            return e.to_dict()
        except Exception as e:
            self.logger.exception(f"Request processing failed: {e}")
            self.performance_monitor.end_request(request_id, success=False)
            self.rate_limiter.complete_request(client_id, request_id)
            return {
                "error": True,
                "errorCode": "PROCESSING_ERROR",
                "message": "An error occurred while processing the request",
                "details": {
                    "error_type": type(e).__name__
                }
            }
    
    def _process_request_internal(self, request_data: Dict[str, Any], client_id: str, request_id: str) -> Dict[str, Any]:
        """Internal request processing logic."""
        start_time = time.time()
        
        # Extract location information
        location = self._extract_location(request_data)
        
        # Get crime context
        crime_context = self._get_crime_context(location)
        
        # Extract features
        features = self.feature_extractor.extract(request_data, crime_context)
        
        # Get neural network prediction
        prediction = self.neural_network.predict_single(features)
        
        # Apply reasoning
        reasoning_context = ReasoningContext(
            event_data=request_data,
            crime_context=crime_context,
            user_history=[],  # In a real implementation, this would be populated
            system_state=self._get_system_state(),
            time_context=self._get_time_context()
        )
        reasoning_result = self.reasoning_engine.reason(reasoning_context)
        
        # Determine threat level
        threat_level = self._determine_threat_level(prediction, reasoning_result)
        
        # Prepare response
        response = {
            "requestId": request_id,
            "clientId": client_id,
            "timestamp": datetime.datetime.now(UTC).isoformat(),
            "threatLevel": threat_level.name,
            "threatScore": float(np.max(prediction)),
            "confidence": float(reasoning_result.confidence),
            "predictions": {
                "critical": float(prediction[3]) if len(prediction) > 3 else 0.0,
                "high": float(prediction[2]) if len(prediction) > 2 else 0.0,
                "medium": float(prediction[1]) if len(prediction) > 1 else 0.0,
                "low": float(prediction[0]) if len(prediction) > 0 else 0.0
            },
            "reasoning": {
                "assessment": reasoning_result.threat_assessment,
                "keyFactors": reasoning_result.key_factors,
                "recommendations": reasoning_result.recommendations,
                "riskScore": float(reasoning_result.risk_score)
            },
            "context": {
                "crimeRate24h": crime_context.crime_rate_24h,
                "crimeRate7d": crime_context.crime_rate_7d,
                "nearbyIncidents": crime_context.nearby_incidents,
                "riskFactors": crime_context.risk_factors
            },
            "processingTime": time.time() - start_time
        }
        
        return response
    
    def _validate_request(self, request_data: Dict[str, Any]) -> None:
        """Validate incoming request data."""
        if not isinstance(request_data, dict):
            raise ValidationError("INVALID_REQUEST_FORMAT", "Request data must be a dictionary")
        
        # Check for required fields
        required_fields = ["events", "timestamp"]
        for field in required_fields:
            if field not in request_data:
                raise ValidationError("MISSING_REQUIRED_FIELD", f"Missing required field: {field}")
        
        # Validate events
        events = request_data.get("events", [])
        if not isinstance(events, list):
            raise ValidationError("INVALID_EVENTS_FORMAT", "Events must be a list")
        
        if len(events) == 0:
            raise ValidationError("NO_EVENTS", "At least one event is required")
        
        if len(events) > self.config.max_events_per_request:
            raise ValidationError("TOO_MANY_EVENTS", f"Too many events, maximum is {self.config.max_events_per_request}")
        
        # Validate timestamp
        timestamp = request_data.get("timestamp")
        if not timestamp:
            raise ValidationError("MISSING_TIMESTAMP", "Timestamp is required")
        
        # Validate location if present
        location = request_data.get("location")
        if location:
            if not isinstance(location, dict):
                raise ValidationError("INVALID_LOCATION_FORMAT", "Location must be a dictionary")
            
            lat = location.get("latitude")
            lng = location.get("longitude")
            
            if lat is not None and not (self.config.latitude_bounds[0] <= lat <= self.config.latitude_bounds[1]):
                raise ValidationError("INVALID_LATITUDE", f"Latitude must be between {self.config.latitude_bounds[0]} and {self.config.latitude_bounds[1]}")
            
            if lng is not None and not (self.config.longitude_bounds[0] <= lng <= self.config.longitude_bounds[1]):
                raise ValidationError("INVALID_LONGITUDE", f"Longitude must be between {self.config.longitude_bounds[0]} and {self.config.longitude_bounds[1]}")
    
    def _extract_location(self, request_data: Dict[str, Any]) -> Tuple[float, float]:
        """Extract location from request data."""
        location = request_data.get("location", {})
        lat = location.get("latitude", 0.0)
        lng = location.get("longitude", 0.0)
        return (float(lat), float(lng))
    
    def _get_crime_context(self, location: Tuple[float, float]) -> Dict[str, Any]:
        """Get crime context for the location."""
        try:
            lat, lng = location
            context = self.crime_intelligence.get_crime_context(lat, lng)
            return {
                "crime_rate_24h": context.crime_rate_24h,
                "crime_rate_7d": context.crime_rate_7d,
                "crime_rate_30d": context.crime_rate_30d,
                "nearby_incidents": context.nearby_incidents,
                "avg_severity": context.avg_severity,
                "recent_incidents": [dataclasses.asdict(i) for i in context.recent_incidents],
                "risk_factors": context.risk_factors
            }
        except Exception as e:
            self.logger.warning(f"Failed to get crime context: {e}")
            return {
                "crime_rate_24h": 0.0,
                "crime_rate_7d": 0.0,
                "crime_rate_30d": 0.0,
                "nearby_incidents": 0,
                "avg_severity": 0.0,
                "recent_incidents": [],
                "risk_factors": []
            }
    
    def _get_system_state(self) -> Dict[str, Any]:
        """Get current system state."""
        state = {
            "timestamp": datetime.datetime.now(UTC).isoformat(),
            "uptime": time.time() - self._startup_time
        }
        
        # Add performance metrics if available
        if psutil:
            try:
                state["cpu_percent"] = psutil.cpu_percent()
                state["memory_percent"] = psutil.virtual_memory().percent
            except Exception:
                pass
        
        return state
    
    def _get_time_context(self) -> Dict[str, Any]:
        """Get time-based context."""
        now = datetime.datetime.now(UTC)
        return {
            "hour": now.hour,
            "day_of_week": now.weekday(),
            "is_weekend": now.weekday() >= 5,
            "season": self._get_season(now)
        }
    
    def _get_season(self, date: datetime.datetime) -> str:
        """Get season based on date."""
        month = date.month
        if month in [12, 1, 2]:
            return "winter"
        elif month in [3, 4, 5]:
            return "spring"
        elif month in [6, 7, 8]:
            return "summer"
        else:
            return "fall"
    
    def _determine_threat_level(self, prediction: np.ndarray, reasoning_result: ReasoningResult) -> ThreatLevel:
        """Determine threat level based on prediction and reasoning."""
        max_prob = np.max(prediction)
        risk_score = reasoning_result.risk_score
        
        # Combine neural network prediction with reasoning result
        combined_score = (max_prob + risk_score) / 2.0
        
        if combined_score >= self.config.emergency_threshold:
            return ThreatLevel.CRITICAL
        elif combined_score >= 0.8:
            return ThreatLevel.HIGH
        elif combined_score >= 0.6:
            return ThreatLevel.MEDIUM
        else:
            return ThreatLevel.LOW
    
    def _get_next_request_id(self) -> int:
        """Get next request ID."""
        with self._lock:
            self._request_counter += 1
            return self._request_counter
    
    def get_system_info(self) -> Dict[str, Any]:
        """Get system information."""
        return {
            "version": "2.0.0",
            "initialized": self._initialized,
            "uptime": time.time() - self._startup_time,
            "requests_processed": self.performance_monitor.metrics.get("requests_processed", 0),
            "model_info": self.neural_network.get_model_info(),
            "performance_metrics": self.performance_monitor.metrics
        }
    
    def health_check(self) -> Dict[str, Any]:
        """Perform system health check."""
        health = {
            "status": "healthy",
            "timestamp": datetime.datetime.now(UTC).isoformat(),
            "components": {}
        }
        
        # Check neural network
        health["components"]["neural_network"] = {
            "status": "healthy" if self.neural_network.model_loaded else "degraded",
            "model_loaded": self.neural_network.model_loaded
        }
        
        # Check system resources if available
        if psutil:
            cpu_percent = psutil.cpu_percent()
            memory_percent = psutil.virtual_memory().percent
            
            health["components"]["system_resources"] = {
                "status": "healthy" if cpu_percent < self.config.cpu_max_percent and memory_percent < self.config.memory_max_percent else "degraded",
                "cpu_percent": cpu_percent,
                "memory_percent": memory_percent
            }
        
        # Overall status
        unhealthy_components = [name for name, component in health["components"].items() if component["status"] != "healthy"]
        if unhealthy_components:
            health["status"] = "degraded"
            health["unhealthy_components"] = unhealthy_components
        
        return health


# Factory function for embedded systems
def get_embedded_system_instance(brand_config: Optional[Dict[str, Any]] = None) -> NovinAISecuritySystem:
    """
    Factory function to get an embedded system instance.
    
    Args:
        brand_config: Optional brand-specific configuration
        
    Returns:
        NovinAISecuritySystem instance
    """
    config = SecurityConfig()
    
    # Apply brand-specific configuration if provided
    if brand_config:
        for key, value in brand_config.items():
            if hasattr(config, key):
                setattr(config, key, value)
    
    return NovinAISecuritySystem(config)