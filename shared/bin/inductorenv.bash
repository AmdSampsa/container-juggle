#!/bin/bash
## run with source
export TORCH_COMPILE_DEBUG=1 # debugging / benchmarking output
## ..when that has been enabled, use also:
export TORCHINDUCTOR_BENCHMARK_KERNEL=1
export TORCHINDUCTOR_UNIQUE_KERNEL_NAMES=1
