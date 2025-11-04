#!/bin/bash

# long-story-short:
# we need this crap because vscode's debugpy is buggy: 
# it seems to hardcode /bin/python inside its code
# we could create a simple symlink from /bin/python into the correct python interpreter,
# but even that is not enough: the correct env variables from that python intepreter setup are
# not inherited (why? - maybe because of process spawning)
# so we need to create a wrapper script that runs the environment first
#
# Smart /bin/python setup script
setup_bin_python() {
    echo "Setting up /bin/python for VSCode debugpy compatibility..."
    
    # Get current Python interpreter
    CURRENT_PYTHON=$(which python)
    echo "Current Python interpreter: $CURRENT_PYTHON"
    
    # Check if current Python is in a virtual environment
    VENV_PATH=""
    if [[ "$CURRENT_PYTHON" == */venv/bin/python ]] || [[ "$CURRENT_PYTHON" == */env/bin/python ]] || [[ -n "$VIRTUAL_ENV" ]]; then
        # Extract venv path
        if [[ -n "$VIRTUAL_ENV" ]]; then
            VENV_PATH="$VIRTUAL_ENV"
        else
            VENV_PATH=$(dirname $(dirname "$CURRENT_PYTHON"))
        fi
        echo "Detected virtual environment: $VENV_PATH"
        
        # Remove existing /bin/python
        sudo rm -f /bin/python
        
        # Create wrapper script that activates venv
        sudo tee /bin/python << EOF
#!/bin/bash
source "$VENV_PATH/bin/activate"
exec "$VENV_PATH/bin/python" "\$@"
EOF
        
        sudo chmod +x /bin/python
        echo "Created /bin/python wrapper script for virtual environment"
        
    elif [[ "$CURRENT_PYTHON" == */conda*/bin/python ]] || [[ -n "$CONDA_DEFAULT_ENV" ]]; then
        # Handle conda environment
        if [[ -n "$CONDA_DEFAULT_ENV" ]]; then
            ENV_NAME="$CONDA_DEFAULT_ENV"
        else
            # Extract env name from path
            ENV_NAME=$(echo "$CURRENT_PYTHON" | sed 's|.*/envs/\([^/]*\)/bin/python|\1|')
        fi
        echo "Detected conda environment: $ENV_NAME"
        
        # Remove existing /bin/python
        sudo rm -f /bin/python
        
        # Create wrapper script that activates conda env
        sudo tee /bin/python << EOF
#!/bin/bash
source \$(conda info --base)/etc/profile.d/conda.sh
conda activate "$ENV_NAME"
exec python "\$@"
EOF
        
        sudo chmod +x /bin/python
        echo "Created /bin/python wrapper script for conda environment"
        
    else
        # No virtual environment detected, create simple symlink
        echo "No virtual environment detected, creating simple symlink"
        sudo rm -f /bin/python
        sudo ln -s "$CURRENT_PYTHON" /bin/python
        echo "Created symlink: /bin/python -> $CURRENT_PYTHON"
    fi
    
    # Test the setup
    echo "Testing /bin/python setup..."
    if /bin/python -c "import sys; print(f'Python: {sys.executable}')"; then
        echo "✅ /bin/python setup successful!"
    else
        echo "❌ /bin/python setup failed!"
        return 1
    fi
}

# Run the setup
setup_bin_python

