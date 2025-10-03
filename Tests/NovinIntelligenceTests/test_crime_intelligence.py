"""Unit tests for the Crime Intelligence module."""

import unittest
import tempfile
import os
import numpy as np
from datetime import datetime, timezone, timedelta

from novin_intelligence.crime_intelligence import CrimeIntelligence, CrimeIncident, CrimeContext
from novin_intelligence.security import SecurityConfig


class TestCrimeIntelligence(unittest.TestCase):
    """Test cases for CrimeIntelligence class."""

    def setUp(self):
        """Set up test fixtures."""
        self.config = SecurityConfig()
        self.db_fd, self.db_path = tempfile.mkstemp(suffix='.db')
        self.crime_intel = CrimeIntelligence(self.config, self.db_path)

    def tearDown(self):
        """Clean up test fixtures."""
        os.close(self.db_fd)
        os.unlink(self.db_path)

    def test_initialization(self):
        """Test CrimeIntelligence initialization."""
        self.assertIsInstance(self.crime_intel, CrimeIntelligence)
        self.assertEqual(self.crime_intel.db_path, self.db_path)
        self.assertIsNotNone(self.crime_intel.cache)

    def test_database_initialization(self):
        """Test database initialization."""
        # Check if tables were created
        import sqlite3
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='crime_incidents'")
            result = cursor.fetchone()
            self.assertIsNotNone(result)
            self.assertEqual(result[0], 'crime_incidents')

    def test_sample_data_loading(self):
        """Test sample data loading."""
        # Check if sample data was loaded
        import sqlite3
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.execute("SELECT COUNT(*) FROM crime_incidents")
            count = cursor.fetchone()[0]
            self.assertGreater(count, 0)

    def test_crime_incident_creation(self):
        """Test CrimeIncident dataclass creation."""
        incident = CrimeIncident(
            id="test_001",
            timestamp=datetime.now(timezone.utc),
            latitude=37.7749,
            longitude=-122.4194,
            crime_type="theft",
            severity=0.5,
            description="Test incident",
            source="unit_test"
        )
        
        self.assertEqual(incident.id, "test_001")
        self.assertEqual(incident.latitude, 37.7749)
        self.assertEqual(incident.longitude, -122.4194)
        self.assertEqual(incident.crime_type, "theft")

    def test_add_incident(self):
        """Test adding a new incident."""
        incident = CrimeIncident(
            id="test_002",
            timestamp=datetime.now(timezone.utc),
            latitude=37.7849,
            longitude=-122.4094,
            crime_type="burglary",
            severity=0.8,
            description="Test burglary",
            source="unit_test"
        )
        
        result = self.crime_intel.add_incident(incident)
        self.assertTrue(result)
        
        # Verify incident was added
        incidents = self.crime_intel.get_incidents_by_type("burglary")
        self.assertEqual(len(incidents), 1)
        self.assertEqual(incidents[0].id, "test_002")

    def test_get_crime_context(self):
        """Test getting crime context for a location."""
        # Test with a location near our sample data
        context = self.crime_intel.get_crime_context(37.7749, -122.4194, radius_km=2.0)
        
        self.assertIsInstance(context, CrimeContext)
        self.assertEqual(context.location, (37.7749, -122.4194))
        self.assertIsInstance(context.crime_rate_24h, float)
        self.assertIsInstance(context.crime_rate_7d, float)
        self.assertIsInstance(context.crime_rate_30d, float)
        self.assertIsInstance(context.nearby_incidents, int)
        self.assertIsInstance(context.avg_severity, float)
        self.assertIsInstance(context.recent_incidents, list)
        self.assertIsInstance(context.risk_factors, list)

    def test_calculate_distance(self):
        """Test distance calculation."""
        # Test with known distance (approximately 111 km between 0,0 and 1,0)
        distance = self.crime_intel._calculate_distance(0, 0, 1, 0)
        self.assertAlmostEqual(distance, 111, delta=1)  # Approximately 111 km
        
        # Test with same point (should be 0)
        distance = self.crime_intel._calculate_distance(37.7749, -122.4194, 37.7749, -122.4194)
        self.assertEqual(distance, 0)

    def test_get_incidents_by_type(self):
        """Test getting incidents by type."""
        incidents = self.crime_intel.get_incidents_by_type("theft")
        self.assertIsInstance(incidents, list)
        
        # All returned incidents should be of type "theft"
        for incident in incidents:
            self.assertEqual(incident.crime_type, "theft")

    def test_get_incidents_by_time_range(self):
        """Test getting incidents by time range."""
        # Get all incidents
        all_incidents = self.crime_intel.get_incidents_by_type("theft")
        
        if all_incidents:
            # Test with a time range that should include all incidents
            first_incident = min(all_incidents, key=lambda x: x.timestamp)
            last_incident = max(all_incidents, key=lambda x: x.timestamp)
            
            incidents = self.crime_intel.get_incidents_by_time_range(
                first_incident.timestamp - timedelta(hours=1),
                last_incident.timestamp + timedelta(hours=1)
            )
            
            self.assertIsInstance(incidents, list)
            self.assertGreaterEqual(len(incidents), len(all_incidents))

    def test_get_statistics(self):
        """Test getting crime statistics."""
        stats = self.crime_intel.get_statistics()
        
        self.assertIsInstance(stats, dict)
        self.assertIn("total_incidents", stats)
        self.assertIn("incidents_by_type", stats)
        self.assertIn("average_severity", stats)
        self.assertIn("date_range", stats)
        
        self.assertIsInstance(stats["total_incidents"], int)
        self.assertIsInstance(stats["incidents_by_type"], dict)
        self.assertIsInstance(stats["average_severity"], float)


if __name__ == '__main__':
    unittest.main()