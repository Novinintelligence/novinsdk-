import json
import sys
import os

# Add current directory to Python path for imports
sys.path.insert(0, os.path.dirname(__file__))

# Add Python.xcframework site-packages to path
framework_path = os.path.join(os.path.dirname(__file__), '..', 'Python.xcframework', 'ios-arm64', 'lib', 'python3.13', 'site-packages')
if os.path.exists(framework_path):
    sys.path.insert(0, framework_path)

# Try to import full AI system
try:
    from novin_intelligence.security import NovinAISecuritySystem, SecurityConfig
    from novin_intelligence.crime_intelligence import CrimeIntelligence
    
    CONFIG = SecurityConfig()
    CRIME = CrimeIntelligence(CONFIG, crime_data_path="crime_data.db")
    SYSTEM = NovinAISecuritySystem(CONFIG, crime_data_path="crime_data.db")
    
    def process_request(json_payload: str) -> dict:
        data = json.loads(json_payload)
        result = SYSTEM.process_request(data, client_id=data.get("clientId", "spm_client"))
        return result

except ImportError:
    # Fallback for missing dependencies
    def process_request(json_payload: str) -> dict:
        try:
            data = json.loads(json_payload)
            event_type = data.get('event_type', 'unknown')
            
            # Simple fallback logic
            if event_type == 'motion':
                threat_level = 'ELEVATED'
                confidence = 0.75
            elif event_type == 'sound':
                threat_level = 'STANDARD'
                confidence = 0.65
            else:
                threat_level = 'IGNORE'
                confidence = 0.3
            
            return {
                "requestId": "fallback_123",
                "clientId": data.get("clientId", "unknown"),
                "timestamp": "2024-09-27T17:30:00Z",
                "threatAssessment": {
                    "level": threat_level,
                    "confidence": confidence
                },
                "reasoning": {
                    "primaryFactors": [f"Fallback logic: {event_type} event"],
                    "ruleApplied": "fallback_mode"
                },
                "systemStatus": {
                    "healthy": True,
                    "fallbackActive": True
                },
                "error": "Full AI unavailable: missing dependencies (numpy, scipy, cryptography)"
            }
        except Exception as e:
            return {"error": f"Processing failed: {str(e)}"}
