"""
Redirect stdout/stderr per rank for distributed training.

Usage:
    # At the very top of your training script:
    import rank_redirect
    rank_redirect.setup('/tmp/logs')
    
    # Now all prints go to /tmp/logs/rank_0.log, /tmp/logs/rank_1.log, etc.
"""

import sys
import os
from pathlib import Path

def setup(log_dir='/tmp/rank_logs', prefix='rank', also_print=False):
    """Setup per-rank logging.
    
    Args:
        log_dir: Directory to save rank logs
        prefix: Filename prefix (e.g., 'rank' -> rank_0.log)
        also_print: If True, also print to original stdout (uses tee-like behavior)
    """
    # Get rank from environment
    rank = int(os.environ.get('RANK', os.environ.get('LOCAL_RANK', 0)))
    
    # Create log directory
    Path(log_dir).mkdir(parents=True, exist_ok=True)
    
    # Create log file
    log_file = Path(log_dir) / f"{prefix}_{rank}.log"
    
    if also_print:
        # Tee-like: write to both file and original stdout
        class TeeFile:
            def __init__(self, file1, file2):
                self.file1 = file1
                self.file2 = file2
            
            def write(self, data):
                self.file1.write(data)
                self.file2.write(data)
            
            def flush(self):
                self.file1.flush()
                self.file2.flush()
        
        original_stdout = sys.stdout
        file_handle = open(log_file, 'w', buffering=1)
        sys.stdout = TeeFile(file_handle, original_stdout)
        sys.stderr = sys.stdout
    else:
        # Just redirect to file
        file_handle = open(log_file, 'w', buffering=1)  # Line buffered
        sys.stdout = file_handle
        sys.stderr = file_handle
    
    print(f"[Rank {rank}] Logging to {log_file}")
    
    return log_file

if __name__ == "__main__":
    # Test
    setup('/tmp/test_logs')
    print("This should go to the rank-specific log file!")
    import time
    time.sleep(1)
    print("Second message!")

