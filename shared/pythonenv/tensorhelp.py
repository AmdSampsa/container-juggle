import os
import numpy as np
import torch
from pathlib import Path
from typing import Dict, Union, Optional


def save_tensor(tensor, filename):
    """Save tensor to disk in .pt format"""
    np_array = tensor.detach().cpu().numpy()
    np.save(filename, np_array)


def tensor_stat(t):
    print(f"MIN: {torch.min(t)}, MAX: {torch.max(t)}, MEAN: {torch.mean(t)}, VAR: {torch.var(t)}")

def numpy_stat(arr):
    print(f"MIN: {np.min(arr)}, MAX: {np.max(arr)}, MEAN: {np.mean(arr)}, VAR: {np.var(arr)}")

def load_and_compare_tensor(file1, file2):
    """Load and compare two numpy tensors, return comparison metrics"""
    arr1 = np.load(file1)
    arr2 = np.load(file2)
    
    if arr1.shape != arr2.shape:
        raise ValueError(f"Shape mismatch: {arr1.shape} vs {arr2.shape}")
    
    abs_diff = np.abs(arr1 - arr2)
    max_diff = np.max(abs_diff)
    mean_diff = np.mean(abs_diff)
    l2_diff = np.sqrt(np.mean(np.square(abs_diff)))
    
    return {
        'max_diff': max_diff,
        'mean_diff': mean_diff,
        'l2_diff': l2_diff,
        'shape': arr1.shape,
        'arr1_mean': np.mean(arr1),
        'arr2_mean': np.mean(arr2),
        'arr1_std': np.std(arr1),
        'arr2_std': np.std(arr2)
    }


class TensorComp:
    def __init__(self, directory: str, overwrite=True, verbose=False):
        """Initialize TensorComp with a directory path.
        
        Args:
            directory (str): Path to directory where tensors will be stored
        """
        self.overwrite=overwrite
        self.verbose=verbose
        self.directory = Path(directory)
        self.existed = self.directory.exists()
        self.directory.mkdir(parents=True, exist_ok=True)
    
    def exists(self):
        return self.existed

    def _get_filepath(self, index: int) -> Path:
        """Generate filepath for given tensor index."""
        return self.directory / f"cp-{index}.npy"
    
    def save(self, tensor: torch.Tensor, index: int, show = False) -> None:
        """Save a PyTorch tensor to disk as numpy array.
        
        Args:
            tensor (torch.Tensor): Tensor to save
            index (int): Index identifier for the tensor
        """
        filepath = self._get_filepath(index)
        np_array = tensor.detach().cpu().numpy()
        if self.overwrite==False and filepath.exists():
            print("File", filepath, "exists already - skipping")
        else:
            if self.verbose:
                print("saving", index, "shape", np_array.shape)
                numpy_stat(np_array)
            if show:
                print(np_array)
            np.save(filepath, np_array)
    
    def load(self, index: int) -> torch.Tensor:
        """Load a tensor from disk.
        
        Args:
            index (int): Index identifier of the tensor to load
            
        Returns:
            torch.Tensor: Loaded tensor
            
        Raises:
            FileNotFoundError: If tensor file doesn't exist
        """
        filepath = self._get_filepath(index)
        if not filepath.exists():
            raise FileNotFoundError(f"No tensor found at index {index}")
        np_array = np.load(filepath)
        if self.verbose:
                print("loading", index, "shape", np_array.shape)
                numpy_stat(np_array)
        return torch.from_numpy(np_array)
    
    def __eq__(self, other: 'TensorComp') -> Dict[int, Dict]:
        """Compare all tensors in this directory with another TensorComp instance.
        
        Args:
            other (TensorComp): Another TensorComp instance to compare with
            
        Returns:
            Dict[int, Dict]: Dictionary mapping tensor indices to comparison metrics
            
        Raises:
            FileNotFoundError: If a corresponding tensor is not found in other directory
        """
        results = {}
        
        # Get all tensor files in this directory
        for filepath in self.directory.glob("cp-*.npy"):
            index = int(filepath.stem.split('-')[1])
            
            try:
                arr1 = np.load(filepath)
                arr2 = np.load(other._get_filepath(index))
                
                if arr1.shape != arr2.shape:
                    raise ValueError(f"Shape mismatch for index {index}: {arr1.shape} vs {arr2.shape}")
                
                abs_diff = np.abs(arr1 - arr2)
                results[index] = {
                    'max_diff': float(np.max(abs_diff)),
                    'mean_diff': float(np.mean(abs_diff)),
                    'l2_diff': float(np.sqrt(np.mean(np.square(abs_diff)))),
                    'shape': arr1.shape,
                    'arr1_mean': float(np.mean(arr1)),
                    'arr2_mean': float(np.mean(arr2)),
                    'arr1_std': float(np.std(arr1)),
                    'arr2_std': float(np.std(arr2))
                }
                
            except FileNotFoundError:
                raise FileNotFoundError(f"No corresponding tensor found at index {index} in comparison directory")
        
        return results

