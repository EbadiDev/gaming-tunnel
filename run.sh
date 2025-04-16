#!/bin/bash
set -e

# Function to display colored messages
print_colored() {
  local color=$1
  local message=$2
  case $color in
    "green") echo -e "\033[0;32m$message\033[0m" ;;
    "red") echo -e "\033[0;31m$message\033[0m" ;;
    "yellow") echo -e "\033[0;33m$message\033[0m" ;;
    "blue") echo -e "\033[0;34m$message\033[0m" ;;
    *) echo "$message" ;;
  esac
}

# Repository info
REPO_URL="https://github.com/EbadiDev/gaming-tunnel.git"
REPO_DIR="gaming-tunnel"

# Clone the repository if it doesn't exist
if [ ! -d "$REPO_DIR" ]; then
  print_colored "blue" "Cloning Gaming Tunnel repository..."
  git clone $REPO_URL $REPO_DIR
  print_colored "green" "Repository cloned successfully!"
else
  print_colored "yellow" "Gaming Tunnel repository already exists, using existing directory"
fi

# Change to repository directory
cd $REPO_DIR

# Check if we're in the right directory (should have main.py in test_phase)
if [ ! -f "test_phase/main.py" ]; then
  print_colored "red" "Error: main.py not found in the test_phase directory."
  print_colored "yellow" "The repository structure may have changed or the clone was incomplete."
  exit 1
fi

# Install uv if it's not already installed
if ! command -v uv &> /dev/null; then
  print_colored "blue" "Installing uv package manager..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  
  # Add uv to PATH for this session if it's not already there
  export PATH="$HOME/.cargo/bin:$PATH"
fi

# Create and activate virtual environment
print_colored "blue" "Creating Python virtual environment..."
if [ ! -d ".venv" ]; then
  uv venv --python 3.13
else
  print_colored "yellow" "Virtual environment already exists, using existing .venv"
fi

# Activate the virtual environment
print_colored "blue" "Activating virtual environment..."
source .venv/bin/activate

# Check if requirements.txt exists, create a basic one if not
if [ ! -f "requirements.txt" ]; then
  print_colored "yellow" "requirements.txt not found, creating a basic one..."
  cat > requirements.txt << EOF
typer>=0.9.0
rich>=13.4.2
requests>=2.31.0
EOF
fi

# Install dependencies
print_colored "blue" "Installing dependencies..."
uv pip install -r requirements.txt

# Run the application
print_colored "green" "Starting Gaming Tunnel..."
cd test_phase
python ./main.py

# Deactivate virtual environment on exit
deactivate 