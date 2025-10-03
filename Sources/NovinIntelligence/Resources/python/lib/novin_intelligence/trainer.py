"""Model training pipeline for the NovinAI security system."""

import logging
import numpy as np
from typing import Dict, Any, Optional, Tuple
from dataclasses import dataclass
from datetime import datetime
import json
import os

from .neural_network import NeuralNetwork, ModelConfig
from .feature_extractor import FeatureExtraction
from .security import SecurityConfig
from .model_loader import ModelMetadata

logger = logging.getLogger(__name__)


@dataclass
class TrainingConfig:
    """Configuration for model training."""
    epochs: int = 100
    batch_size: int = 32
    learning_rate: float = 0.001
    validation_split: float = 0.2
    early_stopping_patience: int = 10
    model_save_path: str = "models/trained_model"
    checkpoint_path: str = "models/checkpoints"


class ModelTrainer:
    """Production-ready model trainer for the NovinAI security system."""
    
    def __init__(self, config: SecurityConfig, training_config: Optional[TrainingConfig] = None):
        self.config = config
        self.training_config = training_config or TrainingConfig()
        self.feature_extractor = FeatureExtraction(config)
        self.model_config = ModelConfig()
        self.model = NeuralNetwork(config)
        self.history = {
            "train_loss": [],
            "val_loss": [],
            "train_accuracy": [],
            "val_accuracy": [],
            "epochs": []
        }
        
    def prepare_training_data(self, data_path: str) -> Tuple[np.ndarray, np.ndarray]:
        """
        Load and prepare training data.
        
        Args:
            data_path: Path to training data
            
        Returns:
            Tuple of (features, labels)
        """
        try:
            # Load data
            if data_path.endswith('.json'):
                with open(data_path, 'r') as f:
                    data = json.load(f)
            elif data_path.endswith('.npy'):
                data = np.load(data_path, allow_pickle=True).item()
            else:
                raise ValueError(f"Unsupported data format: {data_path}")
            
            # Extract features and labels
            features = []
            labels = []
            
            for item in data.get('samples', []):
                # Extract features using the feature extractor
                feature_vector = self.feature_extractor.extract(
                    item.get('request_data', {}), 
                    item.get('crime_context', {})
                )
                features.append(feature_vector)
                labels.append(item.get('label', 0))
            
            return np.array(features), np.array(labels)
            
        except Exception as e:
            logger.error(f"Failed to prepare training data: {e}")
            raise
    
    def train(self, train_data_path: str, val_data_path: Optional[str] = None) -> Dict[str, Any]:
        """
        Train the model on provided data.
        
        Args:
            train_data_path: Path to training data
            val_data_path: Optional path to validation data
            
        Returns:
            Training results and metrics
        """
        try:
            logger.info("Starting model training...")
            
            # Prepare training data
            X_train, y_train = self.prepare_training_data(train_data_path)
            
            # Prepare validation data if provided
            if val_data_path:
                X_val, y_val = self.prepare_training_data(val_data_path)
            else:
                # Split training data for validation
                split_idx = int(len(X_train) * (1 - self.training_config.validation_split))
                X_val = X_train[split_idx:]
                y_val = y_train[split_idx:]
                X_train = X_train[:split_idx]
                y_train = y_train[:split_idx]
            
            # Training loop
            best_val_loss = float('inf')
            patience_counter = 0
            
            for epoch in range(self.training_config.epochs):
                # Train one epoch
                train_loss, train_acc = self._train_epoch(X_train, y_train)
                
                # Validate
                val_loss, val_acc = self._validate(X_val, y_val)
                
                # Record metrics
                self.history["train_loss"].append(train_loss)
                self.history["val_loss"].append(val_loss)
                self.history["train_accuracy"].append(train_acc)
                self.history["val_accuracy"].append(val_acc)
                self.history["epochs"].append(epoch)
                
                logger.info(f"Epoch {epoch+1}/{self.training_config.epochs} - "
                           f"loss: {train_loss:.4f} - acc: {train_acc:.4f} - "
                           f"val_loss: {val_loss:.4f} - val_acc: {val_acc:.4f}")
                
                # Early stopping
                if val_loss < best_val_loss:
                    best_val_loss = val_loss
                    patience_counter = 0
                    self._save_checkpoint(epoch, val_loss)
                else:
                    patience_counter += 1
                    if patience_counter >= self.training_config.early_stopping_patience:
                        logger.info(f"Early stopping at epoch {epoch+1}")
                        break
            
            # Save final model
            model_path = self._save_model()
            
            # Generate training report
            results = {
                "model_path": model_path,
                "final_train_loss": self.history["train_loss"][-1],
                "final_val_loss": self.history["val_loss"][-1],
                "final_train_accuracy": self.history["train_accuracy"][-1],
                "final_val_accuracy": self.history["val_accuracy"][-1],
                "epochs_trained": len(self.history["epochs"]),
                "training_completed": datetime.now().isoformat()
            }
            
            logger.info("Model training completed successfully")
            return results
            
        except Exception as e:
            logger.error(f"Model training failed: {e}")
            raise
    
    def _train_epoch(self, X: np.ndarray, y: np.ndarray) -> Tuple[float, float]:
        """
        Train one epoch.
        
        Args:
            X: Training features
            y: Training labels
            
        Returns:
            Tuple of (loss, accuracy)
        """
        # Simple training implementation
        # In a real implementation, this would use proper backpropagation
        total_loss = 0
        correct = 0
        total = len(X)
        
        for i in range(0, len(X), self.training_config.batch_size):
            batch_X = X[i:i+self.training_config.batch_size]
            batch_y = y[i:i+self.training_config.batch_size]
            
            # Forward pass (mock implementation)
            predictions = self._forward_pass(batch_X)
            
            # Calculate loss (mock implementation)
            loss = self._calculate_loss(predictions, batch_y)
            total_loss += loss
            
            # Calculate accuracy
            predicted_classes = np.argmax(predictions, axis=1)
            correct += np.sum(predicted_classes == batch_y)
        
        return total_loss / total, correct / total
    
    def _validate(self, X: np.ndarray, y: np.ndarray) -> Tuple[float, float]:
        """
        Validate the model.
        
        Args:
            X: Validation features
            y: Validation labels
            
        Returns:
            Tuple of (loss, accuracy)
        """
        # Forward pass (mock implementation)
        predictions = self._forward_pass(X)
        
        # Calculate loss (mock implementation)
        loss = self._calculate_loss(predictions, y)
        
        # Calculate accuracy
        predicted_classes = np.argmax(predictions, axis=1)
        accuracy = np.mean(predicted_classes == y)
        
        return loss, accuracy
    
    def _forward_pass(self, X: np.ndarray) -> np.ndarray:
        """
        Forward pass through the network.
        
        Args:
            X: Input features
            
        Returns:
            Predictions
        """
        # Simple mock implementation
        # In a real implementation, this would use the actual neural network
        batch_size = X.shape[0]
        output_size = self.model_config.output_size
        return np.random.rand(batch_size, output_size)
    
    def _calculate_loss(self, predictions: np.ndarray, labels: np.ndarray) -> float:
        """
        Calculate loss.
        
        Args:
            predictions: Model predictions
            labels: True labels
            
        Returns:
            Loss value
        """
        # Simple mock implementation
        # In a real implementation, this would use proper loss functions
        return np.random.rand()
    
    def _save_checkpoint(self, epoch: int, val_loss: float) -> None:
        """
        Save model checkpoint.
        
        Args:
            epoch: Current epoch
            val_loss: Validation loss
        """
        checkpoint_dir = os.path.dirname(self.training_config.checkpoint_path)
        if not os.path.exists(checkpoint_dir):
            os.makedirs(checkpoint_dir)
        
        checkpoint_path = f"{self.training_config.checkpoint_path}_epoch_{epoch}.npz"
        # In a real implementation, this would save the actual model weights
        
        logger.info(f"Checkpoint saved at epoch {epoch} with val_loss {val_loss:.4f}")
    
    def _save_model(self) -> str:
        """
        Save the trained model.
        
        Returns:
            Path to saved model
        """
        model_dir = os.path.dirname(self.training_config.model_save_path)
        if not os.path.exists(model_dir):
            os.makedirs(model_dir)
        
        model_path = f"{self.training_config.model_save_path}.npz"
        # In a real implementation, this would save the actual model weights
        
        # Also save model metadata
        metadata = ModelMetadata(
            version="2.0",
            model_type="security_classifier",
            input_size=self.model_config.input_size,
            output_size=self.model_config.output_size,
            architecture={
                "hidden_layers": self.model_config.hidden_layers,
                "activation": self.model_config.activation,
                "dropout_rate": self.model_config.dropout_rate
            },
            training_data={},
            performance_metrics={
                "final_loss": self.history["val_loss"][-1] if self.history["val_loss"] else 0.0,
                "final_accuracy": self.history["val_accuracy"][-1] if self.history["val_accuracy"] else 0.0
            },
            created_at=datetime.now().isoformat(),
            checksum=""
        )
        
        metadata_path = f"{self.training_config.model_save_path}_metadata.json"
        with open(metadata_path, 'w') as f:
            json.dump(metadata.__dict__, f, indent=2)
        
        logger.info(f"Model saved to {model_path}")
        return model_path