#!/usr/bin/env python3
"""
Test runner for Novin Intelligence Security System.
"""

import unittest
import sys
import os

# Add the source directory to the path so we can import the modules
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'Sources', 'NovinIntelligence', 'Resources', 'python', 'lib'))

if __name__ == '__main__':
    # Discover and run all tests
    loader = unittest.TestLoader()
    start_dir = os.path.join(os.path.dirname(__file__), 'NovinIntelligenceTests')
    suite = loader.discover(start_dir, pattern='test_*.py')
    
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    # Exit with error code if tests failed
    sys.exit(0 if result.wasSuccessful() else 1)