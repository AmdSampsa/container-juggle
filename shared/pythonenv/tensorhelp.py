import os, sys, inspect
import numpy as np
import torch
from pathlib import Path
from typing import Dict, Union, Optional

def check_nan(tensor):
    indx=torch.nonzero(torch.isnan(tensor)) # each row is an index
    nn=len(indx) # number of nans
    if (nn>0):
        print("\nnans found:", nn, "/", tensor.numel(), "=", nn/tensor.numel())
        for i in range(0, min(2, len(indx))):
            ind = indx[i]
            print(ind, "-->", tensor[*ind])
            if i>3: # show first 3 values
                break
        if len(indx) > 10:
            print("...")
            for i in range(len(indx)-2, len(indx)):
                ind = indx[i]
                print(ind, "-->", tensor[*ind])

def quick_nan_context(tensor, context=2):
    """Quick function to show NaN context"""
    nan_indices = torch.nonzero(torch.isnan(tensor))
    nn=len(nan_indices)
    if (nn>0):
        print("nans found:", nn, "/", tensor.numel(), "=", nn/tensor.numel())

    for i, idx in enumerate(nan_indices[:3]):  # Show first 3 NaNs
        print(f"NaN {i+1} at {idx.tolist()}:")
        
        # Create context slices
        slices = []
        for dim_idx, pos_tensor in enumerate(idx):
            pos = pos_tensor.item()  # Convert tensor to int
            dim_size = tensor.shape[dim_idx]
            start = max(0, pos - context)
            end = min(dim_size, pos + context + 1)
            slices.append(slice(start, end))
        
        context_data = tensor[tuple(slices)]
        print(f"  Context: {context_data.flatten()[:10]}")  # Show first 10 values


def get_context_manager_details():
    """Get details about active context managers."""
    frame = sys._getframe(1)  # Get the caller's frame
    details = []
    
    while frame:
        # Look for any objects in locals that might be context managers
        for var_name, var_value in frame.f_locals.items():
            if hasattr(var_value, '__enter__') and hasattr(var_value, '__exit__'):
                try:
                    module = inspect.getmodule(type(var_value)).__name__
                    class_name = type(var_value).__name__
                    details.append(f"{module}.{class_name} ({var_name})")
                except:
                    details.append(f"Unknown context manager: {var_name}")
        
        frame = frame.f_back
    
    return details

# Usage
#print("Active context managers:")
#for cm in get_context_manager_details():
#    print(f"- {cm}")

def save_tensor(tensor, filename):
    """Save tensor to disk in .pt format"""
    np_array = tensor.detach().cpu().numpy()
    np.save(filename, np_array)


def tensor_stat(t):
    print(f"SHAPE: {t.shape}, DTYPE: {t.dtype}, MIN: {torch.min(t)}, MAX: {torch.max(t)}, MEAN: {torch.mean(t)}, VAR: {torch.var(t)}")

def numpy_stat(arr):
    print(f"MIN: {np.min(arr)}, MAX: {np.max(arr)}, MEAN: {np.mean(arr)}, VAR: {np.var(arr)}")


def compare_np(arr1: np.array, arr2: np.array) -> dict:
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


def compare_tensor(t1: torch.tensor, t2: torch.tensor):
    return compare_np(t1.to("cpu").detach().numpy(), t2.to("cpu").detach().numpy())


def compare_torch(tensor1: torch.Tensor, tensor2: torch.Tensor) -> dict:
    if tensor1.shape != tensor2.shape:
        raise ValueError(f"Shape mismatch: {tensor1.shape} vs {tensor2.shape}")
    abs_diff = torch.abs(tensor1 - tensor2)
    max_diff = torch.max(abs_diff).item()
    mean_diff = torch.mean(abs_diff).item()
    l2_diff = torch.sqrt(torch.mean(torch.square(abs_diff))).item()
    return {
        'max_diff': max_diff,
        'mean_diff': mean_diff,
        'l2_diff': l2_diff,
        'shape': tuple(tensor1.shape),
        'arr1_mean': torch.mean(tensor1).item(),
        'arr2_mean': torch.mean(tensor2).item(),
        'arr1_std': torch.std(tensor1).item(),
        'arr2_std': torch.std(tensor2).item()
    }

def load_and_compare_tensor(file1, file2):
    """Load and compare two numpy tensors, return comparison metrics"""
    arr1 = np.load(file1)
    arr2 = np.load(file2)
    return compare_np(arr1, arr2)

class TensorComp:
    def __init__(self, directory: str, overwrite=True, verbose=False, native=False):
        """Initialize TensorComp with a directory path.
        
        Args:
            directory (str): Path to directory where tensors will be stored
            overwrite (bool): Whether to overwrite existing files
            verbose (bool): Whether to print verbose information
            native (bool): Whether to use native torch operations for comparisons instead of numpy
        """
        self.overwrite = overwrite
        self.verbose = verbose
        self.native = native
        self.directory = Path(directory)
        self.existed = self.directory.exists()
        self.directory.mkdir(parents=True, exist_ok=True)
    
    def exists(self):
        return self.existed

    def _get_filepath(self, index: int) -> Path:
        """Generate filepath for given tensor index."""
        if self.native:
            return self.directory / f"cp-{index}.pt"
        else:
            return self.directory / f"cp-{index}.npy"
    
    def save(self, tensor: torch.Tensor, index: int, show = False) -> None:
        """Save a PyTorch tensor to disk.
        
        Args:
            tensor (torch.Tensor): Tensor to save
            index (int): Index identifier for the tensor
            show (bool): Whether to print the tensor values
        """
        filepath = self._get_filepath(index)
        
        if self.overwrite==False and filepath.exists():
            print("File", filepath, "exists already - skipping")
        else:
            tensor_cpu = tensor.detach().cpu()
            
            if self.verbose:
                print("saving", index, "shape", tensor_cpu.shape)
                tensor_stat(tensor_cpu)
            
            if show:
                print(tensor_cpu)
                
            if self.native:
                # torch.save(tensor_cpu, filepath)
                torch.save(tensor, filepath)
            else:
                np_array = tensor_cpu.numpy()
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
        
        if self.native:
            tensor = torch.load(filepath)
        else:
            np_array = np.load(filepath)
            tensor = torch.from_numpy(np_array)
            
        if self.verbose:
            print("loading", index, "shape", tensor.shape)
            tensor_stat(tensor)
            
        return tensor
    
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
        
        # Get pattern based on file extension
        pattern = "cp-*.pt" if self.native else "cp-*.npy"
        
        # Get all tensor files in this directory
        for filepath in self.directory.glob(pattern):
            index = int(filepath.stem.split('-')[1])
            
            try:
                # Load tensors using the appropriate method based on native flag
                if self.native:
                    tensor1 = torch.load(filepath)
                    tensor2 = torch.load(other._get_filepath(index))
                    # Compare using torch operations
                    results[index] = compare_torch(tensor1, tensor2)
                else:
                    # Use numpy comparison (original implementation)
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
    