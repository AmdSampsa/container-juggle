#!/usr/bin/env python3
import sys
import argparse
from typing import Dict
import json
from pathlib import Path
from tensorhelp import TensorComp

def format_comparison(comparison_results: Dict) -> str:
    """Format comparison results into a readable string."""
    output = []
    
    for index, metrics in sorted(comparison_results.items()):
        output.append(f"\nTensor {index}:")
        output.append("-" * 40)
        
        # Format shape specially
        shape = metrics.pop('shape')
        output.append(f"Shape: {shape}")
        
        # Format all numerical metrics with consistent precision
        for metric_name, value in sorted(metrics.items()):
            output.append(f"{metric_name}: {value:.6e}")
    
    return "\n".join(output)

def main():
    parser = argparse.ArgumentParser(description='Compare PyTorch tensors stored in two directories.')
    parser.add_argument('dir1', type=str, help='First directory containing tensors')
    parser.add_argument('dir2', type=str, help='Second directory containing tensors')
    parser.add_argument('--json', action='store_true', help='Output in JSON format')
    parser.add_argument('--threshold', type=float, default=None,
                       help='Threshold for max_diff to consider tensors different')
    
    args = parser.parse_args()

    try:
        tc1 = TensorComp(args.dir1)
        tc2 = TensorComp(args.dir2)
        
        comparison_results = tc1 == tc2
        
        if args.threshold is not None:
            any_different = False
            for metrics in comparison_results.values():
                if metrics['max_diff'] > args.threshold:
                    any_different = True
                    break
            if any_different:
                print(f"⚠️  Some tensors differ by more than {args.threshold}")
            else:
                print(f"✓ All tensors are within threshold {args.threshold}")
            print()

        if args.json:
            # Convert numpy types to Python types for JSON serialization
            serializable_results = {}
            for idx, metrics in comparison_results.items():
                serializable_results[str(idx)] = {
                    k: list(v) if isinstance(v, tuple) else v 
                    for k, v in metrics.items()
                }
            print(json.dumps(serializable_results, indent=2))
        else:
            print(format_comparison(comparison_results))

    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
