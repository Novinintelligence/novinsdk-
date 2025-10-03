# Novin Intelligence Security System - Deployment

This directory contains scripts and configurations for deploying the Novin Intelligence Security System.

## Deployment Steps

1. **Run Tests**: Ensure all tests pass before deployment
2. **Build iOS Framework**: Compile the Swift components
3. **Package Python Components**: Bundle Python libraries for iOS
4. **Create Model Bundle**: Package trained models
5. **Create Deployment Package**: Generate complete deployment bundle

## Prerequisites

- Python 3.8+
- Swift 5.0+
- Xcode (for iOS deployment)
- Required Python packages (see requirements.txt)

## Usage

### Run All Deployment Steps

```bash
python deploy.py --all
```

### Individual Steps

```bash
# Run tests only
python deploy.py --run-tests

# Build iOS framework only
python deploy.py --build-ios

# Package Python components only
python deploy.py --package-python

# Create model bundle only
python deploy.py --create-models

# Create deployment package only
python deploy.py --create-package
```

## Directory Structure

```
Deployment/
├── Python/          # Packaged Python components
├── Models/          # Model bundle
├── deploy.py        # Deployment script
└── requirements.txt # Deployment requirements
```

## Testing

Run the test suite before deployment:

```bash
cd ../Tests
python run_tests.py
```

## Requirements

Install deployment requirements:

```bash
pip install -r requirements.txt
```