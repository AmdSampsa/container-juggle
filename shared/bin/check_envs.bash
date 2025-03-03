#!/bin/bash

# Set up an array with the variables to check
variables=(
  "PYTHONPATH"
  "PYTORCH_TEST_WITH_ROCM"
  "TORCHINDUCTOR_COMPILE_THREADS"
  "TORCH_COMPILE_DEBUG"
  "PYTORCH_OPINFO_SAMPLE_INPUT_INDEX"
  "TRITON_INTERPRET"
  "LLVM_IR_ENABLE_DUMP"
)

# Set up colors for better readability
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "Environment Variable Status Check"
echo "================================="

# Loop through each variable and check its status
for var in "${variables[@]}"; do
  # Use parameter expansion to check if the variable is set
  if [ -n "${!var+x}" ]; then
    echo -e "${GREEN}✓${NC} $var is set to: ${YELLOW}${!var}${NC}"
  else
    echo -e "${RED}✗${NC} $var is not set"
  fi
done

echo "================================="
