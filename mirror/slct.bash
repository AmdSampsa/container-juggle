#!/bin/bash

# Check if dialog is installed
if ! command -v dialog &> /dev/null; then
    echo "dialog is not installed. Installing..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get install -y dialog
    elif command -v yum &> /dev/null; then
        sudo yum install -y dialog
    else
        echo "Could not install dialog. Please install it manually."
        exit 1
    fi
fi

# Function to create a temporary file for dialog output
create_temp() {
    TEMP_FILE=$(mktemp /tmp/script-selector.XXXXXX)
    trap 'rm -f $TEMP_FILE' EXIT
}

# Get all bash scripts in the directory
SCRIPT_DIR="$HOME/mirror/context"
SCRIPTS=($(find "$SCRIPT_DIR" -maxdepth 1 -name "*.bash" -not -name "*scaffold*" -type f))

if [ ${#SCRIPTS[@]} -eq 0 ]; then
    dialog --msgbox "No bash scripts found in $SCRIPT_DIR" 8 40
    exit 1
fi

# Create menu items
MENU_ITEMS=()
for ((i=0; i<${#SCRIPTS[@]}; i++)); do
    SCRIPT_NAME=$(basename "${SCRIPTS[$i]}")
    MENU_ITEMS+=("$i" "$SCRIPT_NAME")
done

# Create temporary file for dialog output
create_temp

# Display menu
dialog --clear --title "Script Selector" \
       --menu "Choose a script to source:" 15 50 10 \
       "${MENU_ITEMS[@]}" 2> "$TEMP_FILE"

# Check if user cancelled
if [ $? -ne 0 ]; then
    clear
    echo "Selection cancelled."
else
    # Get selected script
    SELECTION=$(cat "$TEMP_FILE")
    SELECTED_SCRIPT="${SCRIPTS[$SELECTION]}"

    # Clear screen and show selected script
    clear
    echo "Sourcing: $SELECTED_SCRIPT"
    echo "----------------------------------------"

    rm -f $HOME/.latest_ctx.bash
    ln -s $SELECTED_SCRIPT $HOME/.latest_ctx.bash

    # Source the selected script
    source "$SELECTED_SCRIPT"
    ctx.bash
fi
