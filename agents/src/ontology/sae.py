import copy
import torch
import torch.nn as nn
import torch.optim as optim
import pandas as pd
import numpy as np
from torch.utils.data import DataLoader, TensorDataset
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from dataclasses import dataclass, field
from pydantic import BaseModel, field_validator

class HyperParams(BaseModel):
    latent_dim: int
    learning_rate: float
    batch_size: int
    max_epochs: int
    l1_lambda: float
    val_size: float
    patience: int

    @field_validator("latent_dim")
    @classmethod
    def validate_latent_dim(cls, v):
        if v < 1:
            raise ValueError("Latent dim must be at least 1")
        return v
    
    @field_validator("learning_rate")
    @classmethod
    def validate_learning_rate(cls, v):
        if v < 0.0 or v > 1.0:
            raise ValueError("Learning rate must be between 0 and 1")
        return v
    
    @field_validator("batch_size")
    @classmethod
    def validate_batch_size(cls, v):
        if v < 1:
            raise ValueError("Batch size must be at least 1")
        return v
    
    @field_validator("max_epochs")
    @classmethod
    def validate_max_epochs(cls, v):
        if v < 1:
            raise ValueError("Max epochs must be at least 1")
        return v
    
    @field_validator("l1_lambda")
    @classmethod
    def validate_l1_lambda(cls, v):
        if v < 0.0:
            raise ValueError("L1 lambda must be non-negative")
        return v
    
    @field_validator("val_size")
    @classmethod
    def validate_val_size(cls, v):
        if v <= 0.0 or v >= 1.0:
            raise ValueError("Validation size must be between 0 and 1")
        return v
    
    @field_validator("patience")
    @classmethod
    def validate_patience(cls, v):
        if v < 1:
            raise ValueError("Patience must be at least 1")
        return v

@dataclass
class TrainingResults:
    train_loss_history: list[float] = field(default_factory = list)
    val_loss_history: list[float] = field(default_factory = list)
    train_sparsity_history: list[float] = field(default_factory = list)
    val_sparsity_history: list[float] = field(default_factory = list)

class SparseAutoencoder(nn.Module):
    def __init__(self, input_dim: int, hyper_params: HyperParams):
        super().__init__()
        
        self.input_dim = input_dim
        self.hyper_params = hyper_params

        self.scaler = StandardScaler()
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

        latent_dim = hyper_params.latent_dim

        self.encoder = nn.Sequential(
            nn.Linear(self.input_dim, latent_dim),
            nn.ReLU() 
        )
        
        self.decoder = nn.Sequential(
            nn.Linear(latent_dim, self.input_dim),
        )
        self.to(self.device)

    def forward(self, x) -> tuple[torch.Tensor, torch.Tensor]:
        latent = self.encoder(x)
        reconstructed = self.decoder(latent)
        return reconstructed, latent

    def sparse_loss(self, reconstructed, original, latent) -> torch.Tensor:

        mse = nn.functional.mse_loss(reconstructed, original)
        
        latent_abs = torch.abs(latent)
        latent_mean = torch.mean(latent_abs)

        l1_penalty = self.hyper_params.l1_lambda * latent_mean
        
        return mse + l1_penalty
    
    def preprocess_data(self, data: pd.DataFrame) -> tuple[DataLoader, DataLoader]:
        hyper_params = self.hyper_params
        batch_size = hyper_params.batch_size

        train, val = train_test_split(data.values, test_size = hyper_params.val_size)

        scaler = self.scaler
        train = scaler.fit_transform(train)
        val = scaler.transform(val)

        train_tensor = torch.FloatTensor(train)
        val_tensor = torch.FloatTensor(val)

        train_dataset = TensorDataset(train_tensor)
        val_dataset = TensorDataset(val_tensor)
        
        train_loader = DataLoader(train_dataset, batch_size = batch_size, shuffle = True)
        val_loader = DataLoader(val_dataset, batch_size = batch_size, shuffle = False)
        
        return train_loader, val_loader

    def train_epoch(self, train_loader: DataLoader, opt: optim.Optimizer) -> tuple[float, float]:
        train_loss = 0.0
        train_sparsity = 0.0
        self.train()

        for batch_list in train_loader:
            batch = batch_list[0].to(self.device)

            reconstructed, latent = self(batch)
            
            loss = self.sparse_loss(reconstructed, batch, latent)

            opt.zero_grad()

            loss.backward()
            opt.step()
            
            train_loss += loss.item()
            train_sparsity += (latent == 0).float().mean().item()
        
        n_batches = len(train_loader)
        return train_loss / n_batches, train_sparsity / n_batches

    def validate_epoch(self, val_loader: DataLoader) -> tuple[float, float]:
        val_loss = 0.0
        val_sparsity = 0.0
        self.eval()
        
        with torch.no_grad():
            for batch_list in val_loader:
                batch = batch_list[0].to(self.device)

                reconstructed, latent = self(batch)
                loss = self.sparse_loss(reconstructed, batch, latent)
                val_loss += loss.item()
                val_sparsity += (latent == 0).float().mean().item()
        
        n_batches = len(val_loader)
        return val_loss / n_batches, val_sparsity / n_batches

    def fit(self, data: pd.DataFrame) -> TrainingResults:
        results = TrainingResults()
        hyper_params = self.hyper_params
        
        train_loader, val_loader = self.preprocess_data(data)

        model_params = self.parameters()
        opt = optim.Adam(model_params, lr = hyper_params.learning_rate)

        best_val_loss = float('inf')
        patience_counter = 0
        best_model_state = None

        for epoch in range(hyper_params.max_epochs):
            
            train_loss, train_sparsity = self.train_epoch(train_loader, opt)
            val_loss, val_sparsity = self.validate_epoch(val_loader)

            results.train_loss_history.append(train_loss)
            results.val_loss_history.append(val_loss)
            results.train_sparsity_history.append(train_sparsity)
            results.val_sparsity_history.append(val_sparsity)

            print(f"Epoch {epoch + 1}/{hyper_params.max_epochs} - Train Loss: {train_loss:.4f} - Val Loss: {val_loss:.4f} - Sparsity: {val_sparsity:.4f}")

            if val_loss < best_val_loss:
                best_val_loss = val_loss
                patience_counter = 0

                state_dict = self.state_dict()
                best_model_state = copy.deepcopy(state_dict)
            else:
                patience_counter += 1
                if patience_counter >= hyper_params.patience:
                    print(f"Early stopping triggered at epoch {epoch + 1}")
                    if best_model_state is not None:
                        self.load_state_dict(best_model_state)
                    break
        
        return results
    
    def predict(self, data: pd.DataFrame) -> np.ndarray:
        X = self.scaler.transform(data.values)
        X = torch.FloatTensor(X).to(self.device)
        
        with torch.no_grad():
            self.eval()
            _, latent = self(X)
        
        latent_cpu = latent.cpu()
        return latent_cpu.numpy()
    

        
        