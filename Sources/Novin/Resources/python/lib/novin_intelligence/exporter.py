"""Data export utilities for the NovinAI security system."""

import logging
import json
import csv
import numpy as np
from typing import Dict, Any, List, Optional, Union
from datetime import datetime
import os
import sqlite3

from .security import SecurityConfig
from .crime_intelligence import CrimeIntelligence, CrimeIncident

logger = logging.getLogger(__name__)


class DataExporter:
    """Production-ready data exporter for the NovinAI security system."""
    
    def __init__(self, config: SecurityConfig):
        self.config = config
        self.logger = logging.getLogger("NovinAI.DataExporter")
    
    def export_crime_data(self, crime_intelligence: CrimeIntelligence, 
                         export_format: str = "json", 
                         output_path: str = "exports/crime_data") -> str:
        """
        Export crime intelligence data.
        
        Args:
            crime_intelligence: Crime intelligence system
            export_format: Export format ("json", "csv", "sqlite")
            output_path: Output file path (without extension)
            
        Returns:
            Path to exported file
        """
        try:
            self.logger.info(f"Exporting crime data in {export_format} format...")
            
            # Get all crime incidents
            incidents = self._get_all_crime_incidents(crime_intelligence)
            
            # Export based on format
            if export_format.lower() == "json":
                export_path = f"{output_path}.json"
                self._export_json(incidents, export_path)
            elif export_format.lower() == "csv":
                export_path = f"{output_path}.csv"
                self._export_csv(incidents, export_path)
            elif export_format.lower() == "sqlite":
                export_path = f"{output_path}.db"
                self._export_sqlite(incidents, export_path)
            else:
                raise ValueError(f"Unsupported export format: {export_format}")
            
            self.logger.info(f"Crime data exported successfully to {export_path}")
            return export_path
            
        except Exception as e:
            self.logger.error(f"Crime data export failed: {e}")
            raise
    
    def _get_all_crime_incidents(self, crime_intelligence: CrimeIntelligence) -> List[Dict[str, Any]]:
        """
        Get all crime incidents from the database.
        
        Args:
            crime_intelligence: Crime intelligence system
            
        Returns:
            List of crime incidents as dictionaries
        """
        try:
            incidents = []
            with sqlite3.connect(crime_intelligence.db_path) as conn:
                cursor = conn.execute("""
                    SELECT id, timestamp, latitude, longitude, crime_type, 
                           severity, description, source 
                    FROM crime_incidents 
                    ORDER BY timestamp DESC
                """)
                
                for row in cursor.fetchall():
                    incident = {
                        "id": row[0],
                        "timestamp": row[1],
                        "latitude": row[2],
                        "longitude": row[3],
                        "crime_type": row[4],
                        "severity": row[5],
                        "description": row[6],
                        "source": row[7]
                    }
                    incidents.append(incident)
            
            return incidents
            
        except Exception as e:
            self.logger.error(f"Failed to retrieve crime incidents: {e}")
            raise
    
    def _export_json(self, incidents: List[Dict[str, Any]], output_path: str) -> None:
        """
        Export incidents to JSON format.
        
        Args:
            incidents: List of crime incidents
            output_path: Output file path
        """
        # Ensure output directory exists
        output_dir = os.path.dirname(output_path)
        if output_dir and not os.path.exists(output_dir):
            os.makedirs(output_dir)
        
        # Prepare export data
        export_data = {
            "export_timestamp": datetime.now().isoformat(),
            "total_incidents": len(incidents),
            "incidents": incidents,
            "export_metadata": {
                "system": "NovinAI Security System",
                "version": "2.0",
                "format": "crime_incidents"
            }
        }
        
        # Write to file
        with open(output_path, 'w') as f:
            json.dump(export_data, f, indent=2)
    
    def _export_csv(self, incidents: List[Dict[str, Any]], output_path: str) -> None:
        """
        Export incidents to CSV format.
        
        Args:
            incidents: List of crime incidents
            output_path: Output file path
        """
        # Ensure output directory exists
        output_dir = os.path.dirname(output_path)
        if output_dir and not os.path.exists(output_dir):
            os.makedirs(output_dir)
        
        if not incidents:
            # Create empty file with headers
            headers = ["id", "timestamp", "latitude", "longitude", "crime_type", 
                      "severity", "description", "source"]
            with open(output_path, 'w', newline='') as f:
                writer = csv.writer(f)
                writer.writerow(headers)
            return
        
        # Write to file
        with open(output_path, 'w', newline='') as f:
            writer = csv.writer(f)
            
            # Write header
            headers = list(incidents[0].keys())
            writer.writerow(headers)
            
            # Write data
            for incident in incidents:
                writer.writerow([incident.get(h, "") for h in headers])
    
    def _export_sqlite(self, incidents: List[Dict[str, Any]], output_path: str) -> None:
        """
        Export incidents to SQLite database.
        
        Args:
            incidents: List of crime incidents
            output_path: Output file path
        """
        # Ensure output directory exists
        output_dir = os.path.dirname(output_path)
        if output_dir and not os.path.exists(output_dir):
            os.makedirs(output_dir)
        
        # Create new database
        with sqlite3.connect(output_path) as conn:
            # Create table
            conn.execute("""
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
            """)
            
            # Insert data
            for incident in incidents:
                conn.execute("""
                    INSERT OR REPLACE INTO crime_incidents 
                    (id, timestamp, latitude, longitude, crime_type, severity, description, source)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    incident["id"],
                    incident["timestamp"],
                    incident["latitude"],
                    incident["longitude"],
                    incident["crime_type"],
                    incident["severity"],
                    incident["description"],
                    incident["source"]
                ))
            
            conn.commit()
    
    def export_model_metadata(self, model_info: Dict[str, Any], output_path: str = "exports/model_metadata.json") -> str:
        """
        Export model metadata.
        
        Args:
            model_info: Model information dictionary
            output_path: Output file path
            
        Returns:
            Path to exported file
        """
        try:
            self.logger.info("Exporting model metadata...")
            
            # Ensure output directory exists
            output_dir = os.path.dirname(output_path)
            if output_dir and not os.path.exists(output_dir):
                os.makedirs(output_dir)
            
            # Prepare export data
            export_data = {
                "export_timestamp": datetime.now().isoformat(),
                "model_info": model_info,
                "export_metadata": {
                    "system": "NovinAI Security System",
                    "version": "2.0",
                    "format": "model_metadata"
                }
            }
            
            # Write to file
            with open(output_path, 'w') as f:
                json.dump(export_data, f, indent=2)
            
            self.logger.info(f"Model metadata exported successfully to {output_path}")
            return output_path
            
        except Exception as e:
            self.logger.error(f"Model metadata export failed: {e}")
            raise
    
    def export_system_logs(self, log_path: str, output_path: str = "exports/system_logs.json") -> str:
        """
        Export system logs.
        
        Args:
            log_path: Path to log file
            output_path: Output file path
            
        Returns:
            Path to exported file
        """
        try:
            self.logger.info("Exporting system logs...")
            
            # Ensure output directory exists
            output_dir = os.path.dirname(output_path)
            if output_dir and not os.path.exists(output_dir):
                os.makedirs(output_dir)
            
            # Read log file
            if os.path.exists(log_path):
                with open(log_path, 'r') as f:
                    logs = f.readlines()
            else:
                logs = []
            
            # Prepare export data
            export_data = {
                "export_timestamp": datetime.now().isoformat(),
                "logs": logs,
                "log_source": log_path,
                "export_metadata": {
                    "system": "NovinAI Security System",
                    "version": "2.0",
                    "format": "system_logs"
                }
            }
            
            # Write to file
            with open(output_path, 'w') as f:
                json.dump(export_data, f, indent=2)
            
            self.logger.info(f"System logs exported successfully to {output_path}")
            return output_path
            
        except Exception as e:
            self.logger.error(f"System logs export failed: {e}")
            raise


# Utility functions for data export

def create_export_directory(base_path: str = "exports") -> str:
    """
    Create and return export directory path.
    
    Args:
        base_path: Base path for exports
        
    Returns:
        Export directory path
    """
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    export_dir = os.path.join(base_path, timestamp)
    
    if not os.path.exists(export_dir):
        os.makedirs(export_dir)
    
    return export_dir


def export_performance_metrics(metrics: Dict[str, Any], output_path: str) -> str:
    """
    Export performance metrics to JSON.
    
    Args:
        metrics: Performance metrics dictionary
        output_path: Output file path
        
    Returns:
        Path to exported file
    """
    # Ensure output directory exists
    output_dir = os.path.dirname(output_path)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    # Prepare export data
    export_data = {
        "export_timestamp": datetime.now().isoformat(),
        "performance_metrics": metrics,
        "export_metadata": {
            "system": "NovinAI Security System",
            "version": "2.0",
            "format": "performance_metrics"
        }
    }
    
    # Write to file
    with open(output_path, 'w') as f:
        json.dump(export_data, f, indent=2)
    
    return output_path


def export_security_report(incidents: List[Dict[str, Any]], 
                          threat_assessments: List[Dict[str, Any]], 
                          output_path: str = "exports/security_report.json") -> str:
    """
    Export comprehensive security report.
    
    Args:
        incidents: List of crime incidents
        threat_assessments: List of threat assessments
        output_path: Output file path
        
    Returns:
        Path to exported file
    """
    # Ensure output directory exists
    output_dir = os.path.dirname(output_path)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    # Prepare export data
    export_data = {
        "export_timestamp": datetime.now().isoformat(),
        "report_period": {
            "start": min([i.get("timestamp", "") for i in incidents], default=""),
            "end": max([i.get("timestamp", "") for i in incidents], default="")
        },
        "summary": {
            "total_incidents": len(incidents),
            "total_assessments": len(threat_assessments),
            "high_severity_incidents": len([i for i in incidents if i.get("severity", 0) > 0.8]),
            "critical_assessments": len([a for a in threat_assessments if a.get("risk_score", 0) > 0.9])
        },
        "incidents": incidents,
        "threat_assessments": threat_assessments,
        "export_metadata": {
            "system": "NovinAI Security System",
            "version": "2.0",
            "format": "security_report"
        }
    }
    
    # Write to file
    with open(output_path, 'w') as f:
        json.dump(export_data, f, indent=2)
    
    return output_path