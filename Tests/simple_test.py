#!/usr/bin/env python3
"""
Simple test script to verify core functionality.
"""

import sys
import os

# Add the source directory to the path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'Sources', 'NovinIntelligence', 'Resources', 'python', 'lib'))

def test_imports():
    """Test that we can import the core modules."""
    try:
        import novin_intelligence
        print("✓ Successfully imported novin_intelligence package")
        
        # Test importing specific modules
        from novin_intelligence import crime_intelligence
        print("✓ Successfully imported crime_intelligence module")
        
        from novin_intelligence import neural_network
        print("✓ Successfully imported neural_network module")
        
        from novin_intelligence import security
        print("✓ Successfully imported security module")
        
        from novin_intelligence import trainer
        print("✓ Successfully imported trainer module")
        
        from novin_intelligence import mobile_optimizations
        print("✓ Successfully imported mobile_optimizations module")
        
        from novin_intelligence import mobile_quantization
        print("✓ Successfully imported mobile_quantization module")
        
        from novin_intelligence import exporter
        print("✓ Successfully imported exporter module")
        
        return True
        
    except Exception as e:
        print(f"✗ Failed to import modules: {e}")
        return False

def test_basic_functionality():
    """Test basic functionality."""
    try:
        from novin_intelligence.security import SecurityConfig
        from novin_intelligence.crime_intelligence import CrimeIncident
        
        # Test creating a security config
        config = SecurityConfig()
        print("✓ Successfully created SecurityConfig")
        
        # Test creating a crime incident (without slots parameter)
        incident = CrimeIncident(
            id="test_001",
            timestamp="2023-01-01T00:00:00Z",
            latitude=0.0,
            longitude=0.0,
            crime_type="test",
            severity=0.5,
            description="Test incident",
            source="test"
        )
        print("✓ Successfully created CrimeIncident")
        
        return True
        
    except Exception as e:
        print(f"✗ Failed basic functionality test: {e}")
        return False

def main():
    """Main test function."""
    print("Testing Novin Intelligence Security System...")
    print()
    
    success = True
    success &= test_imports()
    print()
    success &= test_basic_functionality()
    print()
    
    if success:
        print("All tests passed! ✓")
        return 0
    else:
        print("Some tests failed! ✗")
        return 1

if __name__ == "__main__":
    sys.exit(main())