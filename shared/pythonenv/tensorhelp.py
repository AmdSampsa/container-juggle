"""
TensorHelp - Utilities for saving, loading, and comparing PyTorch tensors

USAGE EXAMPLES:

1. Save and load individual tensors by index:
    from tensorhelp import TensorComp
    
    tc = TensorComp('./checkpoints', overwrite=True, native=True)
    tc.save(my_tensor, index=0)
    loaded = tc.load(index=0, device='cuda:0')

2. Save and load named tensor dictionaries:
    tc = TensorComp('./debug_tensors', native=True)
    tc.save_dict({
        'query': q_tensor,
        'key': k_tensor,
        'value': v_tensor,
        'indices': block_indices
    })
    
    tensors = tc.load_dict(device='cuda:0')
    q = tensors['query']

3. Save kernel arguments for reproduction:
    # During training/inference - capture real args
    tc = TensorComp('./kernel_args', overwrite=True, native=True)
    tc.save_args(Q, K, V, LSE, kv_num_blks, kv_idx, doc_ids, positions,
                 names=['Q', 'K', 'V', 'LSE', 'kv_num_blks', 'kv_idx', 'doc_ids', 'positions'])
    
    # In repro script - load exact args
    tc = TensorComp('./kernel_args', native=True)
    args = tc.load_args(device='cuda:4')
    kernel[grid](*args)

3b. Multi-process/distributed training (auto-detects rank):
    # Saves to ./checkpoints/rank_0/, ./checkpoints/rank_1/, etc.
    tc = TensorComp('./checkpoints', native=True, use_rank_subdir=True)
    tc.save_dict({'gradients': grads, 'weights': weights})
    
    # Or manually specify rank
    tc = TensorComp('./checkpoints', native=True, rank=int(os.environ['LOCAL_RANK']))
    tc.save(my_tensor, index=0, atomic=True)  # atomic=True for safety

4. Compare tensors between two runs:
    tc1 = TensorComp('./run1', native=True)
    tc2 = TensorComp('./run2', native=True)
    
    results = tc1 == tc2
    for idx, metrics in results.items():
        print(f"Tensor {idx}: max_diff={metrics['max_diff']}, mean_diff={metrics['mean_diff']}")

5. Quick NaN debugging:
    from tensorhelp import check_nan, quick_nan_context
    
    check_nan(my_tensor)  # Print NaN locations
    quick_nan_context(my_tensor, context=3)  # Show surrounding values

6. Tensor statistics and comparisons:
    from tensorhelp import tensor_stat, compare_torch
    
    tensor_stat(my_tensor)  # Print shape, dtype, min, max, mean, var
    diff = compare_torch(tensor1, tensor2)  # Get detailed comparison metrics

7. Format kernel args for reproduction (useful for Triton debugging):
    from tensorhelp import format_args_for_repro
    
    # Just format args with stats (no dumping)
    print(format_args_for_repro(args))
    # Output:
    # (
    #     torch.randn((1, 8, 4096, 128), dtype=torch.bfloat16, device='cuda:0'),  # min=-5.12, max=5.28,
    #     torch.randint(0, 10, (1, 8, 32), dtype=torch.int32, device='cuda:0'),  # min=32, max=32,
    #     128,
    #     0.08838
    # )
    
    # Format AND dump tensors to disk for exact reproduction
    print(format_args_for_repro(args, dump_tensors=True, dump_path='/tmp/my_repro'))
    # [TensorComp] Rank 0: Saved 17 args to /tmp/my_repro/rank_0/
    # [TensorComp] To load: tc = TensorComp('/tmp/my_repro/rank_0', native=True); args = tc.load_args(device='cuda:0')
"""

import os, sys, inspect
import numpy as np
import torch
from pathlib import Path
from typing import Dict, Union, Optional
import threading
import tempfile
import fcntl  # For file locking on Unix systems

def format_args_for_repro(args, pretty=True, dump_tensors=False, dump_path="/tmp/triton_repro_tensors"):
    """Format args into copy-pasteable torch.randn()/torch.randint() calls.
    
    Useful for debugging Triton kernels - generates reproducible code snippets
    and optionally dumps actual tensor data for exact reproduction.
    
    NOTE: During autotuning, rand_strided() is used which:
    - For float types: torch.randn() (random Gaussian)
    - For int/bool types: torch.zeros() (ALL ZEROS!)
    This can cause issues if kernels expect valid non-zero integer inputs.
    
    Args:
        args: The arguments to format (tensors, scalars, etc.)
        pretty: If True, format with newlines for readability
        dump_tensors: If True, also save actual tensor data to disk via TensorComp
        dump_path: Base directory path where tensors will be saved (if dump_tensors=True).
                   Actual path will be {dump_path}/rank_{rank}/ (TensorComp handles rank auto-detection)
    
    Returns:
        str: Formatted string representation of the args
    
    Example:
        >>> args = (torch.randn(2, 3), torch.randint(0, 10, (4,)), 42, 3.14)
        >>> print(format_args_for_repro(args))
        (
            torch.randn((2, 3), dtype=torch.float32, device='cpu'),  # min=-1.23, max=0.98,
            torch.randint(0, 10, (4,), dtype=torch.int64, device='cpu'),  # min=2, max=8,
            42,
            3.14
        )
        
        >>> # With tensor dumping for exact reproduction:
        >>> print(format_args_for_repro(args, dump_tensors=True, dump_path='/tmp/my_repro'))
        [TensorComp] Saved 4 args to /tmp/my_repro/rank_0/
        [TensorComp] To load: tc = TensorComp('/tmp/my_repro/rank_0', native=True); args = tc.load_args(device='cuda:0')
        ...
    """
    formatted = []
    
    # Optionally dump tensors to disk for exact repro
    # TensorComp handles rank-specific subdirectories automatically via use_rank_subdir=True
    if dump_tensors:
        try:
            tc = TensorComp(dump_path, overwrite=True, native=True, use_rank_subdir=True)
            tc.save_args(*args)
            # tc.directory includes the rank subdirectory
            print(f"[TensorComp] Saved {len(args)} args to {tc.directory}/")
            print(f"[TensorComp] To load: tc = TensorComp('{tc.directory}', native=True, use_rank_subdir=False); args = tc.load_args(device='cuda:0')")
        except Exception as e:
            print(f"[TensorComp] Failed to save args: {e}")
    
    for i, arg in enumerate(args):
        if isinstance(arg, torch.Tensor):
            shape = tuple(arg.shape)
            dtype = str(arg.dtype).replace("torch.", "")
            device = str(arg.device)
            
            # Gather tensor statistics for debugging
            stats = ""
            try:
                has_nan = arg.isnan().any().item() if arg.dtype.is_floating_point else False
                has_inf = arg.isinf().any().item() if arg.dtype.is_floating_point else False
                is_all_zeros = (arg == 0).all().item()
                
                if arg.numel() > 0:
                    if arg.dtype.is_floating_point:
                        min_val = arg[~arg.isnan()].min().item() if not arg.isnan().all() else float('nan')
                        max_val = arg[~arg.isnan()].max().item() if not arg.isnan().all() else float('nan')
                    else:
                        min_val = arg.min().item()
                        max_val = arg.max().item()
                else:
                    min_val = max_val = 0
                
                # Build warning string
                warnings = []
                if has_nan:
                    warnings.append("HAS_NaN!")
                if has_inf:
                    warnings.append("HAS_Inf!")
                if is_all_zeros:
                    warnings.append("ALL_ZEROS!")
                
                stats = f"  # min={min_val}, max={max_val}"
                if warnings:
                    stats += f" ⚠️ {', '.join(warnings)}"
            except Exception as e:
                stats = f"  # stats error: {e}"
            
            # Use appropriate creation function based on dtype
            if dtype in ('int32', 'int64', 'int16', 'int8', 'uint8'):
                formatted.append(f"torch.randint(0, 10, {shape}, dtype=torch.{dtype}, device='{device}'),{stats}")
            elif dtype in ('bool',):
                formatted.append(f"torch.randint(0, 2, {shape}, dtype=torch.{dtype}, device='{device}'),{stats}")
            else:
                # For float types - rand_strided uses randn
                formatted.append(f"torch.randn({shape}, dtype=torch.{dtype}, device='{device}'),{stats}")
        elif isinstance(arg, (int, float, bool)):
            formatted.append(repr(arg))
        else:
            formatted.append(f"<{type(arg).__name__}>")
    
    if pretty and len(formatted) > 1:
        # Pretty print: one arg per line
        return "(\n    " + ",\n    ".join(formatted) + "\n)"
    else:
        return ", ".join(formatted)


def check_nan(tensor):
    indx=torch.nonzero(torch.isnan(tensor)) # each row is an index
    nn=len(indx) # number of nans
    if (nn>0):
        print("\nnans found:", nn, "/", tensor.numel(), "=", nn/tensor.numel())
        for i in range(0, min(2, len(indx))):
            ind = indx[i]
            print(ind, "-->", tensor[tuple(ind)])
            if i>3: # show first 3 values
                break
        if len(indx) > 10:
            print("...")
            for i in range(len(indx)-2, len(indx)):
                ind = indx[i]
                print(ind, "-->", tensor[tuple(ind)])

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
    min_v = torch.min(t).item()
    max_v = torch.max(t).item()
    dev = str(t.device)
    # Format values compactly
    def fmt(v):
        if isinstance(v, float):
            return f"{v:.4g}"
        return str(v)
    # Only compute mean/var for floating point types
    if t.dtype.is_floating_point or t.dtype.is_complex:
        mean_v = torch.mean(t).item()
        var_v = torch.var(t).item()
        print(f"{t.shape} {t.dtype} {dev} min={fmt(min_v)} max={fmt(max_v)} mean={fmt(mean_v)} var={fmt(var_v)}")
    else:
        print(f"{t.shape} {t.dtype} {dev} min={min_v} max={max_v}")

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
    def __init__(self, directory: str, overwrite=True, verbose=False, native=False, 
                 rank: Optional[int] = None, use_rank_subdir=True):
        """Initialize TensorComp with a directory path.
        
        Args:
            directory (str): Path to directory where tensors will be stored
            overwrite (bool): Whether to overwrite existing files
            verbose (bool): Whether to print verbose information
            native (bool): Whether to use native torch operations for comparisons instead of numpy
            rank (int, optional): Process rank for distributed training (auto-detected from env if None)
            use_rank_subdir (bool): Whether to create rank-specific subdirectories for process safety
        """
        self.overwrite = overwrite
        self.verbose = verbose
        self.native = native
        self._lock = threading.Lock()  # Thread safety within process
        
        # Auto-detect rank from common distributed training env vars
        if rank is None and use_rank_subdir:
            rank = int(os.environ.get('RANK', 
                       os.environ.get('LOCAL_RANK',
                       os.environ.get('SLURM_PROCID', -1))))
        
        self.rank = rank if (rank is not None and rank >= 0) else None
        
        # Use rank-specific subdirectory for process safety
        base_dir = Path(directory)
        if self.rank is not None and use_rank_subdir:
            self.directory = base_dir / f"rank_{self.rank}"
        else:
            self.directory = base_dir
            
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
    
    def _atomic_save(self, data, filepath: Path, save_fn):
        """Atomically save data to filepath using write-then-rename pattern.
        
        Args:
            data: Data to save
            filepath: Target filepath
            save_fn: Function to call with (data, temp_filepath) to save
        """
        # Create temp file in same directory (ensures same filesystem for atomic rename)
        temp_fd, temp_path = tempfile.mkstemp(dir=filepath.parent, suffix=filepath.suffix)
        temp_path = Path(temp_path)
        
        try:
            # Close the fd, we'll use the path
            os.close(temp_fd)
            
            # Save to temp file
            save_fn(data, temp_path)
            
            # Atomic rename (only works if src and dst on same filesystem)
            temp_path.replace(filepath)
            
        except Exception as e:
            # Clean up temp file on error
            if temp_path.exists():
                temp_path.unlink()
            raise e
    
    def save(self, tensor: torch.Tensor, index: int, show = False, atomic=True) -> None:
        """Save a PyTorch tensor to disk (thread/process safe).
        
        Args:
            tensor (torch.Tensor): Tensor to save
            index (int): Index identifier for the tensor
            show (bool): Whether to print the tensor values
            atomic (bool): Whether to use atomic write (safer but slightly slower)
        """
        with self._lock:  # Thread safety
            filepath = self._get_filepath(index)
            
            if self.overwrite==False and filepath.exists():
                print("File", filepath, "exists already - skipping")
                return
                
            tensor_cpu = tensor.detach().cpu()
            
            if self.verbose:
                print(f"[Rank {self.rank}] saving", index, "shape", tensor_cpu.shape)
                tensor_stat(tensor_cpu)
            
            if show:
                print(tensor_cpu)
            
            if atomic:
                # Atomic write using temp file + rename
                if self.native:
                    self._atomic_save(tensor, filepath, lambda t, p: torch.save(t, p))
                else:
                    np_array = tensor_cpu.numpy()
                    self._atomic_save(np_array, filepath, lambda arr, p: np.save(p, arr))
            else:
                # Direct write (faster but not atomic)
                if self.native:
                    torch.save(tensor, filepath)
                else:
                    np_array = tensor_cpu.numpy()
                    np.save(filepath, np_array)
    
    def load(self, index: int, device: Optional[str] = None) -> torch.Tensor:
        """Load a tensor from disk.
        
        Args:
            index (int): Index identifier of the tensor to load
            device (str, optional): Device to load tensor to (e.g., 'cuda:0', 'cpu')
            
        Returns:
            torch.Tensor: Loaded tensor
            
        Raises:
            FileNotFoundError: If tensor file doesn't exist
        """
        filepath = self._get_filepath(index)
        if not filepath.exists():
            raise FileNotFoundError(f"No tensor found at index {index}")
        
        if self.native:
            tensor = torch.load(filepath, map_location=device if device else 'cpu')
        else:
            np_array = np.load(filepath)
            tensor = torch.from_numpy(np_array)
            if device:
                tensor = tensor.to(device)
            
        if self.verbose:
            print("loading", index, "shape", tensor.shape, "device", tensor.device)
            tensor_stat(tensor)
            
        return tensor
    
    def save_dict(self, tensor_dict: Dict[str, torch.Tensor], atomic=True) -> None:
        """Save a dictionary of named tensors (thread/process safe).
        
        Args:
            tensor_dict (Dict[str, torch.Tensor]): Dictionary mapping names to tensors
            atomic (bool): Whether to use atomic write
        """
        with self._lock:  # Thread safety
            filepath = self.directory / "tensor_dict.pt"
            
            if self.overwrite == False and filepath.exists():
                print(f"File {filepath} exists already - skipping")
                return
            
            # Convert all tensors to CPU before saving
            cpu_dict = {k: v.detach().cpu() for k, v in tensor_dict.items()}
            
            if atomic:
                self._atomic_save(cpu_dict, filepath, lambda d, p: torch.save(d, p))
            else:
                torch.save(cpu_dict, filepath)
            
            if self.verbose:
                print(f"[Rank {self.rank}] Saved {len(cpu_dict)} tensors to {filepath}")
                for name, tensor in cpu_dict.items():
                    print(f"  {name}: {tensor.shape}, {tensor.dtype}")
    
    def load_dict(self, device: Optional[str] = None) -> Dict[str, torch.Tensor]:
        """Load a dictionary of named tensors.
        
        Args:
            device (str, optional): Device to load tensors to
            
        Returns:
            Dict[str, torch.Tensor]: Dictionary of loaded tensors
        """
        filepath = self.directory / "tensor_dict.pt"
        
        if not filepath.exists():
            raise FileNotFoundError(f"No tensor dictionary found at {filepath}")
        
        tensor_dict = torch.load(filepath, map_location=device if device else 'cpu')
        
        if self.verbose:
            print(f"Loaded {len(tensor_dict)} tensors from {filepath}")
            for name, tensor in tensor_dict.items():
                print(f"  {name}: {tensor.shape}, {tensor.dtype}, {tensor.device}")
        
        return tensor_dict
    
    def save_args(self, *args, names: Optional[list] = None, atomic=True) -> None:
        """Save multiple tensors as args (for kernel repro, thread/process safe).
        
        Args:
            *args: Tensors or other values to save
            names (list, optional): Names for each arg (auto-generated if not provided)
            atomic (bool): Whether to use atomic write
        """
        with self._lock:  # Thread safety
            filepath = self.directory / "args.pt"
            
            if self.overwrite == False and filepath.exists():
                print(f"File {filepath} exists already - skipping")
                return
            
            # Prepare data to save
            saved_args = []
            for i, arg in enumerate(args):
                if isinstance(arg, torch.Tensor):
                    saved_args.append(('tensor', arg.detach().cpu()))
                elif isinstance(arg, (int, float, bool, str)):
                    saved_args.append(('scalar', arg))
                else:
                    saved_args.append(('other', str(type(arg))))
            
            data = {'args': saved_args, 'names': names}
            
            if atomic:
                self._atomic_save(data, filepath, lambda d, p: torch.save(d, p))
            else:
                torch.save(data, filepath)
            
            if self.verbose:
                print(f"[Rank {self.rank}] Saved {len(saved_args)} args to {filepath}")
                for i, (dtype, val) in enumerate(saved_args):
                    name = names[i] if names and i < len(names) else f"arg_{i}"
                    if dtype == 'tensor':
                        print(f"  {name}: {val.shape}, {val.dtype}")
                    else:
                        print(f"  {name}: {dtype} = {val}")
    
    def load_args(self, device: Optional[str] = None) -> tuple:
        """Load saved args.
        
        Args:
            device (str, optional): Device to load tensors to
            
        Returns:
            tuple: Loaded arguments
        """
        filepath = self.directory / "args.pt"
        
        if not filepath.exists():
            raise FileNotFoundError(f"No args found at {filepath}")
        
        data = torch.load(filepath, map_location='cpu')
        saved_args = data['args']
        names = data.get('names', None)
        
        # Reconstruct args
        loaded_args = []
        for i, (dtype, val) in enumerate(saved_args):
            if dtype == 'tensor':
                tensor = val.to(device) if device else val
                loaded_args.append(tensor)
            elif dtype == 'scalar':
                loaded_args.append(val)
            else:
                loaded_args.append(None)  # Can't reconstruct other types
        
        if self.verbose:
            print(f"Loaded {len(loaded_args)} args from {filepath}")
            for i, arg in enumerate(loaded_args):
                name = names[i] if names and i < len(names) else f"arg_{i}"
                if isinstance(arg, torch.Tensor):
                    print(f"  {name}: {arg.shape}, {arg.dtype}, {arg.device}")
                else:
                    print(f"  {name}: {type(arg)} = {arg}")
        
        return tuple(loaded_args)
    
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
    