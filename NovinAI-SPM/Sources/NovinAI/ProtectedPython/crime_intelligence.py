# Crime Intelligence Implementation for NovinAI Security System
# Mock implementation with proper structure for production use

import json
import logging
import sqlite3
import numpy as np
from typing import Dict, List, Optional, Any, Tuple
from dataclasses import dataclass
from datetime import datetime, timezone, timedelta
import os
import requests
from collections import defaultdict

logger = logging.getLogger(__name__)

@dataclass
class CrimeIncident:
    """Crime incident data structure"""
    id: str
    timestamp: datetime
    latitude: float
    longitude: float
    crime_type: str
    severity: float  # 0.0 to 1.0
    description: str
    source: str

@dataclass
class CrimeContext:
    """Crime context for a location"""
    location: Tuple[float, float]
    crime_rate_24h: float
    crime_rate_7d: float
    crime_rate_30d: float
    nearby_incidents: int
    avg_severity: float
    recent_incidents: List[CrimeIncident]
    risk_factors: List[str]

class CrimeIntelligence:
    """Crime intelligence and context provider"""
    
    def __init__(self, config, crime_data_path: Optional[str] = None):
        self.config = config
        self.crime_data_path = crime_data_path
        self.db_path = crime_data_path or "crime_data.db"
        self.cache = {}
        self.cache_ttl = 3600  # 1 hour cache
        
        # Initialize database
        self._init_database()
        
        # Load sample data if database is empty
        self._load_sample_data()
    
    def _init_database(self):
        """Initialize SQLite database for crime data"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                conn.execute('''
                    CREATE TABLE IF NOT EXISTS crime_incidents (
                        id TEXT PRIMARY KEY,
                        timestamp TEXT NOT NULL,
                        latitude REAL NOT NULL,
                        longitude REAL NOT NULL,
                        crime_type TEXT NOT NULL,
                        severity REAL NOT NULL,
                        description TEXT,
                        source TEXT
                    )
                ''')
                
                conn.execute('''
                    CREATE INDEX IF NOT EXISTS idx_location 
                    ON crime_incidents(latitude, longitude)
                ''')
                
                conn.execute('''
                    CREATE INDEX IF NOT EXISTS idx_timestamp 
                    ON crime_incidents(timestamp)
                ''')
                
                conn.commit()
                
        except Exception as e:
            logger.error(f"Failed to initialize database: {e}")
    
    def _load_sample_data(self):
        """Load sample crime data for testing"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.execute("SELECT COUNT(*) FROM crime_incidents")
                count = cursor.fetchone()[0]
                
                if count == 0:
                    # Load sample data
                    sample_incidents = self._generate_sample_incidents()
                    
                    for incident in sample_incidents:
                        conn.execute('''
                            INSERT OR REPLACE INTO crime_incidents 
                            (id, timestamp, latitude, longitude, crime_type, severity, description, source)
                            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                        ''', (
                            incident.id,
                            incident.timestamp.isoformat(),
                            incident.latitude,
                            incident.longitude,
                            incident.crime_type,
                            incident.severity,
                            incident.description,
                            incident.source
                        ))
                    
                    conn.commit()
                    logger.info(f"Loaded {len(sample_incidents)} sample incidents")
                    
        except Exception as e:
            logger.error(f"Failed to load sample data: {e}")
    
    def _generate_sample_incidents(self) -> List[CrimeIncident]:
        """Generate sample crime incidents for testing"""
        incidents = []
        
        # Sample locations (San Francisco area)
        locations = [
            (37.7749, -122.4194),  # Downtown SF
            (37.7849, -122.4094),  # North of downtown
            (37.7649, -122.4294),  # South of downtown
            (37.7849, -122.4394),  # West of downtown
            (37.7549, -122.3994),  # East of downtown
        ]
        
        crime_types = [
            'theft', 'burglary', 'assault', 'vandalism', 'robbery',
            'fraud', 'drug_offense', 'disorderly_conduct', 'trespassing'
        ]
        
        # Generate incidents for the last 30 days
        base_time = datetime.now(timezone.utc) - timedelta(days=30)
        
        for i in range(100):  # Generate 100 sample incidents
            # Random location
            lat, lng = locations[i % len(locations)]
            # Add some random variation
            lat += np.random.normal(0, 0.01)
            lng += np.random.normal(0, 0.01)
            
            # Random time in the last 30 days
            time_offset = timedelta(
                days=np.random.randint(0, 30),
                hours=np.random.randint(0, 24),
                minutes=np.random.randint(0, 60)
            )
            timestamp = base_time + time_offset
            
            # Random crime type and severity
            crime_type = np.random.choice(crime_types)
            severity = np.random.beta(2, 5)  # Skewed towards lower severity
            
            incident = CrimeIncident(
                id=f"incident_{i:04d}",
                timestamp=timestamp,
                latitude=lat,
                longitude=lng,
                crime_type=crime_type,
                severity=severity,
                description=f"Sample {crime_type} incident",
                source="sample_data"
            )
            
            incidents.append(incident)
        
        return incidents
    
    def get_context(self, location: Dict[str, float]) -> Dict[str, Any]:
        """Get crime context for a location"""
        try:
            lat = location.get('latitude', 0.0)
            lng = location.get('longitude', 0.0)
            
            # Check cache first
            cache_key = f"{lat:.3f},{lng:.3f}"
            if cache_key in self.cache:
                cached_data, timestamp = self.cache[cache_key]
                if datetime.now(timezone.utc).timestamp() - timestamp < self.cache_ttl:
                    return cached_data
            
            # Query database for nearby incidents
            context = self._query_crime_context(lat, lng)
            
            # Cache the result
            self.cache[cache_key] = (context, datetime.now(timezone.utc).timestamp())
            
            return context
            
        except Exception as e:
            logger.error(f"Failed to get crime context: {e}")
            return self._get_default_context()
    
    def _query_crime_context(self, lat: float, lng: float, radius_km: float = 5.0) -> Dict[str, Any]:
        """Query crime incidents within radius of location"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                # Calculate bounding box for the radius
                lat_range = radius_km / 111.0  # Approximate km per degree latitude
                lng_range = radius_km / (111.0 * np.cos(np.radians(lat)))
                
                # Query incidents within bounding box
                cursor = conn.execute('''
                    SELECT id, timestamp, latitude, longitude, crime_type, severity, description, source
                    FROM crime_incidents
                    WHERE latitude BETWEEN ? AND ?
                    AND longitude BETWEEN ? AND ?
                    ORDER BY timestamp DESC
                ''', (
                    lat - lat_range, lat + lat_range,
                    lng - lng_range, lng + lng_range
                ))
                
                incidents = []
                for row in cursor.fetchall():
                    incident = CrimeIncident(
                        id=row[0],
                        timestamp=datetime.fromisoformat(row[1]),
                        latitude=row[2],
                        longitude=row[3],
                        crime_type=row[4],
                        severity=row[5],
                        description=row[6],
                        source=row[7]
                    )
                    incidents.append(incident)
                
                # Calculate statistics
                now = datetime.now(timezone.utc)
                
                # Filter by time periods
                incidents_24h = [i for i in incidents if (now - i.timestamp).total_seconds() < 86400]
                incidents_7d = [i for i in incidents if (now - i.timestamp).total_seconds() < 604800]
                incidents_30d = [i for i in incidents if (now - i.timestamp).total_seconds() < 2592000]
                
                # Calculate rates (incidents per day)
                crime_rate_24h = len(incidents_24h)
                crime_rate_7d = len(incidents_7d) / 7.0
                crime_rate_30d = len(incidents_30d) / 30.0
                
                # Calculate average severity
                if incidents_30d:
                    avg_severity = np.mean([i.severity for i in incidents_30d])
                else:
                    avg_severity = 0.0
                
                # Identify risk factors
                risk_factors = self._identify_risk_factors(incidents_30d)
                
                return {
                    'crime_rate_24h': crime_rate_24h,
                    'crime_rate_7d': crime_rate_7d,
                    'crime_rate_30d': crime_rate_30d,
                    'nearby_incidents': len(incidents_30d),
                    'avg_severity': avg_severity,
                    'recent_incidents': incidents_24h[:10],  # Last 10 incidents
                    'risk_factors': risk_factors
                }
                
        except Exception as e:
            logger.error(f"Failed to query crime context: {e}")
            return self._get_default_context()
    
    def _identify_risk_factors(self, incidents: List[CrimeIncident]) -> List[str]:
        """Identify risk factors from recent incidents"""
        risk_factors = []
        
        if not incidents:
            return risk_factors
        
        # Count crime types
        crime_counts = defaultdict(int)
        for incident in incidents:
            crime_counts[incident.crime_type] += 1
        
        # Identify patterns
        total_incidents = len(incidents)
        
        # High severity crimes
        high_severity = [i for i in incidents if i.severity > 0.7]
        if len(high_severity) > total_incidents * 0.3:
            risk_factors.append("high_severity_crimes")
        
        # Violent crimes
        violent_crimes = ['assault', 'robbery', 'burglary']
        violent_count = sum(crime_counts[crime] for crime in violent_crimes)
        if violent_count > total_incidents * 0.4:
            risk_factors.append("violent_crime_pattern")
        
        # Recent spike
        if total_incidents > 10:  # Only if we have enough data
            risk_factors.append("elevated_activity")
        
        # Specific crime types
        for crime_type, count in crime_counts.items():
            if count > total_incidents * 0.3:
                risk_factors.append(f"frequent_{crime_type}")
        
        return risk_factors
    
    def _get_default_context(self) -> Dict[str, Any]:
        """Get default context when no data is available"""
        return {
            'crime_rate_24h': 0.0,
            'crime_rate_7d': 0.0,
            'crime_rate_30d': 0.0,
            'nearby_incidents': 0,
            'avg_severity': 0.0,
            'recent_incidents': [],
            'risk_factors': []
        }
    
    def add_incident(self, incident: CrimeIncident) -> bool:
        """Add a new crime incident to the database"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                conn.execute('''
                    INSERT OR REPLACE INTO crime_incidents 
                    (id, timestamp, latitude, longitude, crime_type, severity, description, source)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    incident.id,
                    incident.timestamp.isoformat(),
                    incident.latitude,
                    incident.longitude,
                    incident.crime_type,
                    incident.severity,
                    incident.description,
                    incident.source
                ))
                
                conn.commit()
                
                # Clear cache for affected area
                self._clear_cache_for_location(incident.latitude, incident.longitude)
                
                return True
                
        except Exception as e:
            logger.error(f"Failed to add incident: {e}")
            return False
    
    def _clear_cache_for_location(self, lat: float, lng: float):
        """Clear cache entries for a location"""
        # Simple implementation - clear all cache
        # In production, you'd want to be more selective
        self.cache.clear()
    
    def get_crime_statistics(self, location: Dict[str, float], days: int = 30) -> Dict[str, Any]:
        """Get detailed crime statistics for a location"""
        try:
            lat = location.get('latitude', 0.0)
            lng = location.get('longitude', 0.0)
            
            with sqlite3.connect(self.db_path) as conn:
                # Calculate bounding box
                lat_range = 5.0 / 111.0  # 5km radius
                lng_range = 5.0 / (111.0 * np.cos(np.radians(lat)))
                
                # Query incidents
                cursor = conn.execute('''
                    SELECT crime_type, severity, timestamp
                    FROM crime_incidents
                    WHERE latitude BETWEEN ? AND ?
                    AND longitude BETWEEN ? AND ?
                    AND timestamp >= ?
                    ORDER BY timestamp DESC
                ''', (
                    lat - lat_range, lat + lat_range,
                    lng - lng_range, lng + lng_range,
                    (datetime.now(timezone.utc) - timedelta(days=days)).isoformat()
                ))
                
                incidents = cursor.fetchall()
                
                # Calculate statistics
                crime_types = defaultdict(int)
                severities = []
                
                for crime_type, severity, timestamp in incidents:
                    crime_types[crime_type] += 1
                    severities.append(severity)
                
                return {
                    'total_incidents': len(incidents),
                    'crime_types': dict(crime_types),
                    'avg_severity': np.mean(severities) if severities else 0.0,
                    'max_severity': np.max(severities) if severities else 0.0,
                    'days_analyzed': days
                }
                
        except Exception as e:
            logger.error(f"Failed to get crime statistics: {e}")
            return {'total_incidents': 0, 'crime_types': {}, 'avg_severity': 0.0, 'max_severity': 0.0, 'days_analyzed': days}
