#!/usr/bin/env python3
"""
Example usage of the NovinIntelligence AI Security System
This demonstrates how to use the complete system with all components
"""

import json
import logging
from datetime import datetime, timezone
from novin_intelligence import (
    NovinAISecuritySystem, SecurityConfig,
    CrimeIncident, ReasoningContext
)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def main():
    """Main example function"""
    
    # 1. Initialize the security system
    config = SecurityConfig()
    security_system = NovinAISecuritySystem(config)
    
    # 2. Load the AI model
    model_path = "models/novin_ai_v2.0.json"
    signature_path = "models/novin_ai_v2.0.json.sig"
    public_key_path = "models/model_public.pem"
    
    try:
        success = security_system.load_dependencies(
            model_path=model_path,
            signature_path=signature_path,
            public_key_path=public_key_path
        )
        
        if not success:
            logger.error("Failed to load AI model dependencies")
            return
        
        logger.info("AI model loaded successfully")
        
    except Exception as e:
        logger.error(f"Error loading model: {e}")
        return
    
    # 3. Example security events to analyze
    
    # Example 1: Motion detection during night
    motion_event = {
        "event_type": "motion",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "location": {
            "latitude": 37.7749,
            "longitude": -122.4194
        },
        "event_data": {
            "confidence": 0.85,
            "duration": 45,
            "intensity": 0.7,
            "sensors_triggered": ["camera_1", "motion_1"]
        },
        "user_id": "user_123",
        "activity_history": [
            {"event_type": "motion", "hour": 14, "confidence": 0.6},
            {"event_type": "door", "hour": 16, "confidence": 0.8}
        ],
        "user_risk_profile": {
            "risk_score": 0.3,
            "trust_level": 0.8
        },
        "weather": {
            "temperature": 18,
            "humidity": 65,
            "precipitation": 0,
            "wind_speed": 5
        }
    }
    
    # Example 2: Face recognition event
    face_event = {
        "event_type": "face",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "location": {
            "latitude": 37.7849,
            "longitude": -122.4094
        },
        "event_data": {
            "confidence": 0.92,
            "known_face": False,
            "face_confidence": 0.88,
            "sensors_triggered": ["camera_2"]
        },
        "user_id": "user_123",
        "activity_history": [
            {"event_type": "motion", "hour": 2, "confidence": 0.7},
            {"event_type": "face", "hour": 2, "confidence": 0.9}
        ],
        "user_risk_profile": {
            "risk_score": 0.2,
            "trust_level": 0.9
        },
        "weather": {
            "temperature": 15,
            "humidity": 70,
            "precipitation": 0,
            "wind_speed": 3
        }
    }
    
    # Example 3: Sound detection event
    sound_event = {
        "event_type": "sound",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "location": {
            "latitude": 37.7649,
            "longitude": -122.4294
        },
        "event_data": {
            "confidence": 0.95,
            "sound_type": "glass_breaking",
            "sound_level": 85,
            "sensors_triggered": ["audio_1", "vibration_1"]
        },
        "user_id": "user_123",
        "activity_history": [
            {"event_type": "motion", "hour": 23, "confidence": 0.8},
            {"event_type": "sound", "hour": 23, "confidence": 0.9}
        ],
        "user_risk_profile": {
            "risk_score": 0.1,
            "trust_level": 0.95
        },
        "weather": {
            "temperature": 12,
            "humidity": 80,
            "precipitation": 0,
            "wind_speed": 8
        }
    }
    
    # 4. Process each event
    events = [
        ("Motion Detection", motion_event),
        ("Face Recognition", face_event),
        ("Sound Detection", sound_event)
    ]
    
    for event_name, event_data in events:
        logger.info(f"\n{'='*50}")
        logger.info(f"Processing: {event_name}")
        logger.info(f"{'='*50}")
        
        try:
            # Process the security event
            result = security_system.process_request(event_data, "client_123")
            
            # Display results
            print(f"\nEvent: {event_name}")
            print(f"Threat Level: {result['threatLevel']}")
            print(f"Confidence: {result['confidence']:.2f}")
            print(f"Reasoning: {result['reasoning']}")
            
            if 'recommendations' in result:
                print("Recommendations:")
                for rec in result['recommendations']:
                    print(f"  - {rec}")
            
            if 'keyFactors' in result:
                print("Key Factors:")
                for factor in result['keyFactors']:
                    print(f"  - {factor}")
            
            print(f"\nFull Result: {json.dumps(result, indent=2)}")
            
        except Exception as e:
            logger.error(f"Error processing {event_name}: {e}")
    
    # 5. Example of adding a crime incident
    logger.info(f"\n{'='*50}")
    logger.info("Adding Crime Incident")
    logger.info(f"{'='*50}")
    
    new_incident = CrimeIncident(
        id="incident_9999",
        timestamp=datetime.now(timezone.utc),
        latitude=37.7749,
        longitude=-122.4194,
        crime_type="theft",
        severity=0.6,
        description="Package theft from front porch",
        source="user_report"
    )
    
    try:
        success = security_system.crime_intelligence.add_incident(new_incident)
        if success:
            logger.info("Crime incident added successfully")
        else:
            logger.error("Failed to add crime incident")
    except Exception as e:
        logger.error(f"Error adding crime incident: {e}")
    
    # 6. Example of getting crime statistics
    logger.info(f"\n{'='*50}")
    logger.info("Crime Statistics")
    logger.info(f"{'='*50}")
    
    try:
        stats = security_system.crime_intelligence.get_crime_statistics(
            {"latitude": 37.7749, "longitude": -122.4194},
            days=30
        )
        
        print(f"Crime Statistics (30 days):")
        print(f"  Total Incidents: {stats['total_incidents']}")
        print(f"  Average Severity: {stats['avg_severity']:.2f}")
        print(f"  Max Severity: {stats['max_severity']:.2f}")
        print(f"  Crime Types: {stats['crime_types']}")
        
    except Exception as e:
        logger.error(f"Error getting crime statistics: {e}")
    
    logger.info(f"\n{'='*50}")
    logger.info("Example completed successfully!")
    logger.info(f"{'='*50}")

if __name__ == "__main__":
    main()

