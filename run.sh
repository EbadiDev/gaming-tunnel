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

# Repository info and paths
REPO_URL="https://github.com/EbadiDev/gaming-tunnel.git"
INSTALL_DIR="/root/gamingtunnel"

# Make sure we have permission to create the directory
if [ "$EUID" -ne 0 ]; then
  print_colored "red" "This script must be run as root to install to /root/gamingtunnel"
  print_colored "yellow" "Please run with sudo or as root"
  exit 1
fi

# Create the target installation directory if it doesn't exist
if [ ! -d "$INSTALL_DIR" ]; then
  print_colored "blue" "Creating installation directory $INSTALL_DIR..."
  mkdir -p "$INSTALL_DIR"
fi

# Clone the repository if it doesn't exist
if [ ! -d "$INSTALL_DIR/src" ]; then
  print_colored "blue" "Cloning Gaming Tunnel repository..."
  git clone $REPO_URL "$INSTALL_DIR/src"
  print_colored "green" "Repository cloned successfully!"
else
  print_colored "yellow" "Gaming Tunnel repository already exists at $INSTALL_DIR/src"
fi

# Change to repository directory
cd "$INSTALL_DIR/src"

# Check if main.py exists
if [ ! -f "main.py" ]; then
  print_colored "red" "Error: main.py not found in the repository."
  print_colored "yellow" "The repository structure may have changed or the clone was incomplete."
  exit 1
fi

# Install uv if it's not already installed
if command -v uv &> /dev/null; then
  print_colored "green" "uv is already installed at $(which uv)"
  # Make sure we know where the binary is for later use
  UV_PATH=$(which uv)
else
  print_colored "blue" "Installing uv package manager..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  
  # Add standard uv installation paths to PATH for this session
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
  
  # Check if uv is now in PATH
  if command -v uv &> /dev/null; then
    UV_PATH=$(which uv)
    print_colored "green" "uv installed successfully at $UV_PATH"
  else
    print_colored "yellow" "uv command not found in PATH. Trying common installation locations..."
    
    # Check common installation locations
    for possible_path in "$HOME/.local/bin/uv" "$HOME/.cargo/bin/uv" "/usr/local/bin/uv"; do
      if [ -f "$possible_path" ]; then
        UV_PATH="$possible_path"
        print_colored "green" "Found uv at $UV_PATH"
        export PATH="$(dirname $UV_PATH):$PATH"
        break
      fi
    done
    
    if [ -z "$UV_PATH" ]; then
      print_colored "red" "Could not find uv executable after installation."
      print_colored "yellow" "Please add the installation directory to your PATH manually."
      exit 1
    fi
  fi
fi

# Create and activate virtual environment
print_colored "blue" "Creating Python virtual environment..."
if [ ! -d ".venv" ]; then
  # Use the UV_PATH variable we set earlier
  "$UV_PATH" venv --python 3.13 || "$UV_PATH" venv
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
# Use the UV_PATH variable for pip commands
"$UV_PATH" pip install -r requirements.txt

# Run the application
print_colored "green" "Starting Gaming Tunnel..."
python ./main.py

# Deactivate virtual environment on exit
deactivate 