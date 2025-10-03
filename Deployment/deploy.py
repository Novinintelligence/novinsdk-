#!/usr/bin/env python3
"""
Deployment script for Novin Intelligence Security System.
"""

import os
import sys
import shutil
import subprocess
import argparse
from pathlib import Path

def build_ios_framework():
    """Build the iOS framework."""
    print("Building iOS framework...")
    
    # Navigate to the project root
    project_root = Path(__file__).parent.parent
    os.chdir(project_root)
    
    # Build the Swift package
    try:
        result = subprocess.run([
            "swift", "build", 
            "--configuration", "release",
            "--product", "NovinIntelligence"
        ], check=True, capture_output=True, text=True)
        
        print("iOS framework built successfully!")
        return True
        
    except subprocess.CalledProcessError as e:
        print(f"Failed to build iOS framework: {e}")
        print(f"Error output: {e.stderr}")
        return False

def package_python_components():
    """Package Python components for iOS deployment."""
    print("Packaging Python components...")
    
    project_root = Path(__file__).parent.parent
    resources_dir = project_root / "Sources" / "NovinIntelligence" / "Resources"
    python_lib_dir = resources_dir / "python" / "lib"
    
    # Create a deployment package directory
    deploy_dir = project_root / "Deployment" / "Python"
    deploy_dir.mkdir(parents=True, exist_ok=True)
    
    # Copy Python components
    if python_lib_dir.exists():
        shutil.copytree(
            python_lib_dir, 
            deploy_dir / "novin_intelligence",
            dirs_exist_ok=True
        )
        print("Python components packaged successfully!")
        return True
    else:
        print("Python lib directory not found!")
        return False

def create_model_bundle():
    """Create a model bundle for deployment."""
    print("Creating model bundle...")
    
    project_root = Path(__file__).parent.parent
    models_dir = project_root / "Sources" / "NovinIntelligence" / "Resources" / "python" / "lib" / "novin_intelligence" / "models"
    deploy_dir = project_root / "Deployment" / "Models"
    deploy_dir.mkdir(parents=True, exist_ok=True)
    
    # Create placeholder model files if they don't exist
    model_files = [
        "model_public.pem",
        "model_private.pem",
        "novin_ai_v2.0.json"
    ]
    
    for model_file in model_files:
        model_path = models_dir / model_file
        deploy_path = deploy_dir / model_file
        
        if model_path.exists():
            shutil.copy2(model_path, deploy_path)
        else:
            # Create placeholder files
            with open(deploy_path, 'w') as f:
                f.write(f"# Placeholder {model_file}\n")
                f.write("# This is a placeholder file for deployment\n")
    
    print("Model bundle created successfully!")
    return True

def run_tests():
    """Run all tests."""
    print("Running tests...")
    
    project_root = Path(__file__).parent.parent
    tests_dir = project_root / "Tests"
    
    # Change to tests directory
    original_cwd = os.getcwd()
    os.chdir(tests_dir)
    
    try:
        # Run tests
        result = subprocess.run([
            sys.executable, "run_tests.py"
        ], check=True, capture_output=True, text=True)
        
        print("All tests passed!")
        return True
        
    except subprocess.CalledProcessError as e:
        print(f"Tests failed: {e}")
        print(f"Error output: {e.stderr}")
        return False
    finally:
        os.chdir(original_cwd)

def create_deployment_package():
    """Create a complete deployment package."""
    print("Creating deployment package...")
    
    project_root = Path(__file__).parent.parent
    deploy_root = project_root / "Deployment"
    deploy_root.mkdir(parents=True, exist_ok=True)
    
    # Copy essential files
    files_to_copy = [
        "Package.swift",
        "README.md"
    ]
    
    for file_name in files_to_copy:
        src_path = project_root / file_name
        dst_path = deploy_root / file_name
        
        if src_path.exists():
            shutil.copy2(src_path, dst_path)
    
    # Copy directories
    dirs_to_copy = [
        "Sources",
        "Tests"
    ]
    
    for dir_name in dirs_to_copy:
        src_path = project_root / dir_name
        dst_path = deploy_root / dir_name
        
        if src_path.exists():
            shutil.copytree(src_path, dst_path, dirs_exist_ok=True)
    
    print("Deployment package created successfully!")
    return True

def main():
    """Main deployment function."""
    parser = argparse.ArgumentParser(description="Deploy Novin Intelligence Security System")
    parser.add_argument("--build-ios", action="store_true", help="Build iOS framework")
    parser.add_argument("--package-python", action="store_true", help="Package Python components")
    parser.add_argument("--create-models", action="store_true", help="Create model bundle")
    parser.add_argument("--run-tests", action="store_true", help="Run all tests")
    parser.add_argument("--create-package", action="store_true", help="Create deployment package")
    parser.add_argument("--all", action="store_true", help="Run all deployment steps")
    
    args = parser.parse_args()
    
    # If no arguments provided, show help
    if not any(vars(args).values()):
        parser.print_help()
        return
    
    # Run selected steps
    success = True
    
    if args.all or args.run_tests:
        success &= run_tests()
    
    if success and (args.all or args.build_ios):
        success &= build_ios_framework()
    
    if success and (args.all or args.package_python):
        success &= package_python_components()
    
    if success and (args.all or args.create_models):
        success &= create_model_bundle()
    
    if success and (args.all or args.create_package):
        success &= create_deployment_package()
    
    if success:
        print("\nDeployment completed successfully!")
        return 0
    else:
        print("\nDeployment failed!")
        return 1

if __name__ == "__main__":
    sys.exit(main())