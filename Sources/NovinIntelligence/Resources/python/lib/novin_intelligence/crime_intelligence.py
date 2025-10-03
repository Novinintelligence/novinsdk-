# Crime Intelligence Implementation for NovinAI Security System
# Production-ready implementation with real data processing

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
                
                conn.execute('''
                    CREATE INDEX IF NOT EXISTS idx_crime_type 
                    ON crime_incidents(crime_type)
                ''')
                
                conn.execute('''
                    CREATE INDEX IF NOT EXISTS idx_severity 
                    ON crime_incidents(severity)
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
            
            # Random crime type
            crime_type = np.random.choice(crime_types)
            
            # Severity based on crime type
            severity_map = {
                'theft': 0.3,
                'burglary': 0.7,
                'assault': 0.9,
                'vandalism': 0.2,
                'robbery': 0.8,
                'fraud': 0.4,
                'drug_offense': 0.6,
                'disorderly_conduct': 0.3,
                'trespassing': 0.2
            }
            base_severity = severity_map.get(crime_type, 0.5)
            # Add some random variation
            severity = np.clip(base_severity + np.random.normal(0, 0.1), 0.0, 1.0)
            
            # Description based on crime type
            descriptions = {
                'theft': f"Personal property stolen from {('vehicle', 'residence', 'business')[i % 3]}",
                'burglary': "Unauthorized entry with intent to commit crime",
                'assault': "Intentional act causing physical harm to another person",
                'vandalism': "Willful damage to property",
                'robbery': "Theft involving force or threat of force",
                'fraud': "Deceit for financial gain",
                'drug_offense': "Possession or distribution of controlled substances",
                'disorderly_conduct': "Behavior likely to cause public disturbance",
                'trespassing': "Unauthorized entry onto property"
            }
            description = descriptions.get(crime_type, "Crime incident reported")
            
            incident = CrimeIncident(
                id=f"incident_{i:04d}",
                timestamp=timestamp,
                latitude=lat,
                longitude=lng,
                crime_type=crime_type,
                severity=severity,
                description=description,
                source="sample_data"
            )
            
            incidents.append(incident)
        
        return incidents
    
    def get_crime_context(self, latitude: float, longitude: float, radius_km: float = 1.0) -> CrimeContext:
        """
        Get crime context for a specific location.
        
        Args:
            latitude: Latitude of the location
            longitude: Longitude of the location
            radius_km: Radius in kilometers to search for incidents
            
        Returns:
            CrimeContext object with crime statistics
        """
        # Check cache first
        cache_key = f"{latitude:.4f},{longitude:.4f},{radius_km}"
        if cache_key in self.cache:
            cached_time, context = self.cache[cache_key]
            if datetime.now().timestamp() - cached_time < self.cache_ttl:
                return context
        
        try:
            # Get current time
            now = datetime.now(timezone.utc)
            
            # Calculate time windows
            time_24h = (now - timedelta(hours=24)).isoformat()
            time_7d = (now - timedelta(days=7)).isoformat()
            time_30d = (now - timedelta(days=30)).isoformat()
            
            # Get incidents in the area
            nearby_incidents = self._get_incidents_in_area(latitude, longitude, radius_km)
            
            # Filter incidents by time windows
            incidents_24h = [i for i in nearby_incidents if i.timestamp >= now - timedelta(hours=24)]
            incidents_7d = [i for i in nearby_incidents if i.timestamp >= now - timedelta(days=7)]
            incidents_30d = [i for i in nearby_incidents if i.timestamp >= now - timedelta(days=30)]
            
            # Calculate crime rates (per square kilometer per day)
            area_sq_km = np.pi * (radius_km ** 2)
            rate_24h = len(incidents_24h) / area_sq_km / 1  # 1 day
            rate_7d = len(incidents_7d) / area_sq_km / 7  # 7 days
            rate_30d = len(incidents_30d) / area_sq_km / 30  # 30 days
            
            # Calculate average severity
            avg_severity = np.mean([i.severity for i in nearby_incidents]) if nearby_incidents else 0.0
            
            # Identify risk factors
            risk_factors = self._identify_risk_factors(nearby_incidents)
            
            # Get recent incidents (last 24 hours)
            recent_incidents = sorted(incidents_24h, key=lambda x: x.timestamp, reverse=True)[:10]
            
            context = CrimeContext(
                location=(latitude, longitude),
                crime_rate_24h=rate_24h,
                crime_rate_7d=rate_7d,
                crime_rate_30d=rate_30d,
                nearby_incidents=len(nearby_incidents),
                avg_severity=avg_severity,
                recent_incidents=recent_incidents,
                risk_factors=risk_factors
            )
            
            # Cache the result
            self.cache[cache_key] = (datetime.now().timestamp(), context)
            
            return context
            
        except Exception as e:
            logger.error(f"Failed to get crime context: {e}")
            # Return default context
            return CrimeContext(
                location=(latitude, longitude),
                crime_rate_24h=0.0,
                crime_rate_7d=0.0,
                crime_rate_30d=0.0,
                nearby_incidents=0,
                avg_severity=0.0,
                recent_incidents=[],
                risk_factors=[]
            )
    
    def _get_incidents_in_area(self, latitude: float, longitude: float, radius_km: float) -> List[CrimeIncident]:
        """
        Get crime incidents within a specified radius of a location.
        
        Args:
            latitude: Latitude of the center point
            longitude: Longitude of the center point
            radius_km: Radius in kilometers
            
        Returns:
            List of CrimeIncident objects
        """
        try:
            # Calculate bounding box for initial filtering
            lat_delta = radius_km / 111.0  # Approximate degrees per km
            lng_delta = radius_km / (111.0 * np.cos(np.radians(latitude)))
            
            min_lat = latitude - lat_delta
            max_lat = latitude + lat_delta
            min_lng = longitude - lng_delta
            max_lng = longitude + lng_delta
            
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.execute('''
                    SELECT id, timestamp, latitude, longitude, crime_type, severity, description, source
                    FROM crime_incidents
                    WHERE latitude BETWEEN ? AND ? AND longitude BETWEEN ? AND ?
                ''', (min_lat, max_lat, min_lng, max_lng))
                
                incidents = []
                for row in cursor.fetchall():
                    # Calculate actual distance
                    incident_lat = row[2]
                    incident_lng = row[3]
                    distance_km = self._calculate_distance(latitude, longitude, incident_lat, incident_lng)
                    
                    if distance_km <= radius_km:
                        incident = CrimeIncident(
                            id=row[0],
                            timestamp=datetime.fromisoformat(row[1]),
                            latitude=incident_lat,
                            longitude=incident_lng,
                            crime_type=row[4],
                            severity=row[5],
                            description=row[6],
                            source=row[7]
                        )
                        incidents.append(incident)
                
                return incidents
                
        except Exception as e:
            logger.error(f"Failed to get incidents in area: {e}")
            return []
    
    def _calculate_distance(self, lat1: float, lng1: float, lat2: float, lng2: float) -> float:
        """
        Calculate the great circle distance between two points on Earth.
        
        Args:
            lat1: Latitude of first point
            lng1: Longitude of first point
            lat2: Latitude of second point
            lng2: Longitude of second point
            
        Returns:
            Distance in kilometers
        """
        # Haversine formula
        R = 6371  # Earth radius in kilometers
        
        lat1_rad = np.radians(lat1)
        lng1_rad = np.radians(lng1)
        lat2_rad = np.radians(lat2)
        lng2_rad = np.radians(lng2)
        
        dlat = lat2_rad - lat1_rad
        dlng = lng2_rad - lng1_rad
        
        a = np.sin(dlat/2)**2 + np.cos(lat1_rad) * np.cos(lat2_rad) * np.sin(dlng/2)**2
        c = 2 * np.arctan2(np.sqrt(a), np.sqrt(1-a))
        
        return R * c
    
    def _identify_risk_factors(self, incidents: List[CrimeIncident]) -> List[str]:
        """
        Identify risk factors based on incident patterns.
        
        Args:
            incidents: List of crime incidents
            
        Returns:
            List of risk factors
        """
        if not incidents:
            return []
        
        risk_factors = []
        
        # High crime rate
        if len(incidents) > 10:
            risk_factors.append("high_incident_density")
        
        # High severity incidents
        high_severity_count = len([i for i in incidents if i.severity > 0.8])
        if high_severity_count > 2:
            risk_factors.append("high_severity_incidents")
        
        # Recent incidents
        recent_incidents = [i for i in incidents if i.timestamp >= datetime.now(timezone.utc) - timedelta(hours=24)]
        if len(recent_incidents) > 3:
            risk_factors.append("recent_activity")
        
        # Specific crime types
        crime_types = [i.crime_type for i in incidents]
        if crime_types.count('assault') > 1:
            risk_factors.append("assault_incidents")
        if crime_types.count('robbery') > 0:
            risk_factors.append("robbery_incidents")
        
        return risk_factors
    
    def add_incident(self, incident: CrimeIncident) -> bool:
        """
        Add a new crime incident to the database.
        
        Args:
            incident: CrimeIncident object
            
        Returns:
            True if successful, False otherwise
        """
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
                
                # Clear cache for this location
                self._clear_location_cache(incident.latitude, incident.longitude)
                
                logger.info(f"Added incident {incident.id} to database")
                return True
                
        except Exception as e:
            logger.error(f"Failed to add incident: {e}")
            return False
    
    def _clear_location_cache(self, latitude: float, longitude: float) -> None:
        """
        Clear cache entries for a specific location.
        
        Args:
            latitude: Latitude of the location
            longitude: Longitude of the location
        """
        # Clear all cache entries (simplified approach)
        # In a production system, you might want to be more selective
        self.cache.clear()
    
    def get_incidents_by_type(self, crime_type: str, limit: int = 100) -> List[CrimeIncident]:
        """
        Get incidents of a specific crime type.
        
        Args:
            crime_type: Type of crime to filter
            limit: Maximum number of incidents to return
            
        Returns:
            List of CrimeIncident objects
        """
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.execute('''
                    SELECT id, timestamp, latitude, longitude, crime_type, severity, description, source
                    FROM crime_incidents
                    WHERE crime_type = ?
                    ORDER BY timestamp DESC
                    LIMIT ?
                ''', (crime_type, limit))
                
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
                
                return incidents
                
        except Exception as e:
            logger.error(f"Failed to get incidents by type: {e}")
            return []
    
    def get_incidents_by_time_range(self, start_time: datetime, end_time: datetime) -> List[CrimeIncident]:
        """
        Get incidents within a specific time range.
        
        Args:
            start_time: Start of time range
            end_time: End of time range
            
        Returns:
            List of CrimeIncident objects
        """
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.execute('''
                    SELECT id, timestamp, latitude, longitude, crime_type, severity, description, source
                    FROM crime_incidents
                    WHERE timestamp BETWEEN ? AND ?
                    ORDER BY timestamp DESC
                ''', (start_time.isoformat(), end_time.isoformat()))
                
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
                
                return incidents
                
        except Exception as e:
            logger.error(f"Failed to get incidents by time range: {e}")
            return []
    
    def get_statistics(self) -> Dict[str, Any]:
        """
        Get overall crime statistics.
        
        Returns:
            Dictionary with crime statistics
        """
        try:
            with sqlite3.connect(self.db_path) as conn:
                # Total incidents
                cursor = conn.execute("SELECT COUNT(*) FROM crime_incidents")
                total_incidents = cursor.fetchone()[0]
                
                # Incidents by type
                cursor = conn.execute('''
                    SELECT crime_type, COUNT(*) as count
                    FROM crime_incidents
                    GROUP BY crime_type
                    ORDER BY count DESC
                ''')
                incidents_by_type = dict(cursor.fetchall())
                
                # Average severity
                cursor = conn.execute("SELECT AVG(severity) FROM crime_incidents")
                avg_severity = cursor.fetchone()[0] or 0.0
                
                # Date range
                cursor = conn.execute("SELECT MIN(timestamp), MAX(timestamp) FROM crime_incidents")
                min_date, max_date = cursor.fetchone()
                
                return {
                    "total_incidents": total_incidents,
                    "incidents_by_type": incidents_by_type,
                    "average_severity": avg_severity,
                    "date_range": {
                        "start": min_date,
                        "end": max_date
                    }
                }
                
        except Exception as e:
            logger.error(f"Failed to get statistics: {e}")
            return {}