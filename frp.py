import os
import subprocess
import glob
import re
import random
import string
import tarfile
import tempfile
import requests
import shutil
from typing import Optional, List, Dict
from rich import print as rich_print
from rich.console import Console
from rich.prompt import Prompt, Confirm
from rich.panel import Panel
from rich.table import Table


class FRP:
    def __init__(self):
        """Initialize FRP class"""
        self.console = Console()
        # Use user's home directory for more accessibility
        self.home_dir = os.path.expanduser("~")
        self.base_dir = os.path.join(self.home_dir, ".gamingtunnel")
        
        # Update paths to be user-accessible
        self.bin_dir = os.path.join(self.base_dir, "bin")
        self.configs_dir = os.path.join(self.base_dir, "frp_configs")
        self.log_dir = os.path.join(self.base_dir, "logs")
        
        # Update binary paths
        self.frps_binary = os.path.join(self.bin_dir, "frps")
        self.frpc_binary = os.path.join(self.bin_dir, "frpc")
        
        self.github_release_url = "https://github.com/fatedier/frp/releases/latest"
        self.github_download_url = "https://github.com/fatedier/frp/releases/download"
        self.version_url = "https://api.github.com/repos/fatedier/frp/releases/latest"
        self.default_frp_port = 7000
        
        # Create necessary directories
        os.makedirs(self.configs_dir, exist_ok=True)
        os.makedirs(self.log_dir, exist_ok=True)
        os.makedirs(self.bin_dir, exist_ok=True)

    def colorize(self, color, text, bold=False):
        """Print colored text using rich"""
        style = color
        if bold:
            style = f"{color} bold"
        rich_print(f"[{style}]{text}[/{style}]")

    def is_installed(self) -> bool:
        """Check if FRP is installed"""
        return os.path.isfile(self.frps_binary) and os.path.isfile(self.frpc_binary)
        
    def get_latest_version(self) -> str:
        """Get the latest FRP version from GitHub releases"""
        try:
            response = requests.get(self.version_url, allow_redirects=True)
            # Extract version from URL redirect (e.g., .../tag/v0.62.0)
            version = response.url.split('/')[-1]
            if version.startswith('v'):
                version = version[1:]  # Remove 'v' prefix
            return version
        except Exception as e:
            self.colorize("red", f"Failed to get latest version: {str(e)}", bold=True)
            # Fallback to a hardcoded recent version
            return "0.62.0"
    
    def get_download_url(self, version: str, arch: str) -> str:
        """Generate the download URL for a specific version and architecture"""
        if arch == "x86_64":
            arch_suffix = "linux_amd64"
        elif arch in ["armv7l", "armv7"]:
            arch_suffix = "linux_arm"
        elif arch in ["aarch64", "arm64"]:
            arch_suffix = "linux_arm64"
        else:
            self.colorize("red", f"Unsupported architecture: {arch}", bold=True)
            return None
        
        return f"{self.github_download_url}/v{version}/frp_{version}_{arch_suffix}.tar.gz"
    
    def install(self, version: str = None, arch: str = None) -> bool:
        """Install FRP binaries"""
        if version is None:
            version = self.get_latest_version()
            
        if arch is None:
            arch = platform.machine()
            if arch == "x86_64":
                arch = "amd64"
            elif arch in ["armv7l", "aarch64"]:
                arch = "arm64"  # Most common ARM architecture
            else:
                self.colorize("red", f"Unsupported architecture: {arch}", bold=True)
                return False
                
        # Get download URL for the specific version and architecture
        download_url = self.get_download_url(version, arch)
        if not download_url:
            return False
            
        # Create a temporary directory for downloading
        with tempfile.TemporaryDirectory() as temp_dir:
            try:
                # Download the tar.gz file
                self.colorize("cyan", f"Downloading FRP {version} for {arch}...", bold=True)
                tarball_path = os.path.join(temp_dir, "frp.tar.gz")
                
                response = requests.get(download_url, stream=True)
                with open(tarball_path, 'wb') as f:
                    for chunk in response.iter_content(chunk_size=8192):
                        f.write(chunk)
                        
                # Extract the tarball
                self.colorize("cyan", "Extracting FRP...", bold=True)
                with tarfile.open(tarball_path, 'r:gz') as tar:
                    tar.extractall(path=temp_dir)
                    
                # Find the extracted directory
                extracted_dir = None
                for item in os.listdir(temp_dir):
                    item_path = os.path.join(temp_dir, item)
                    if os.path.isdir(item_path) and item.startswith("frp_"):
                        extracted_dir = item_path
                        break
                        
                if not extracted_dir:
                    self.colorize("red", "Could not find extracted FRP directory", bold=True)
                    return False
                    
                # Install the binaries
                self.colorize("cyan", "Installing FRP binaries...", bold=True)
                
                # Copy the executables to the user-accessible bin directory
                shutil.copy2(os.path.join(extracted_dir, "frps"), self.frps_binary)
                shutil.copy2(os.path.join(extracted_dir, "frpc"), self.frpc_binary)
                
                # Set executable permissions
                os.chmod(self.frps_binary, 0o755)
                os.chmod(self.frpc_binary, 0o755)
                
                # Create the configs directory and copy example configs
                os.makedirs(self.configs_dir, exist_ok=True)
                subprocess.run(["cp", os.path.join(extracted_dir, "frps.toml"), f"{self.configs_dir}/frps.toml.example"])
                subprocess.run(["cp", os.path.join(extracted_dir, "frpc.toml"), f"{self.configs_dir}/frpc.toml.example"])
                
                self.colorize("green", f"FRP {version} installed successfully", bold=True)
                return True
                
            except Exception as e:
                self.colorize("red", f"Error installing FRP: {str(e)}", bold=True)
                return False
            
    def get_available_configs(self) -> List[dict]:
        """Get a list of available FRP configurations"""
        configs = []
        
        # Look for server configs
        server_configs = glob.glob(f"{self.configs_dir}/frps-*.toml")
        for config in server_configs:
            config_name = os.path.basename(config).replace('frps-', '').replace('.toml', '')
            configs.append({
                'name': config_name,
                'type': 'server',
                'path': config
            })
            
        # Look for client configs
        client_configs = glob.glob(f"{self.configs_dir}/frpc-*.toml")
        for config in client_configs:
            config_name = os.path.basename(config).replace('frpc-', '').replace('.toml', '')
            configs.append({
                'name': config_name,
                'type': 'client',
                'path': config
            })
            
        return configs
        
    def load_config(self, config_name: str) -> Dict[str, str]:
        """Load a configuration file and parse its settings"""
        # Try to find the config file (either server or client)
        server_config = f"{self.configs_dir}/frps-{config_name}.toml"
        client_config = f"{self.configs_dir}/frpc-{config_name}.toml"
        
        config_path = None
        config_type = None
        
        if os.path.isfile(server_config):
            config_path = server_config
            config_type = "server"
        elif os.path.isfile(client_config):
            config_path = client_config
            config_type = "client"
        else:
            self.colorize("red", f"Configuration '{config_name}' not found", bold=True)
            return None
            
        # Parse the TOML file (simple version, not handling nested sections)
        config_data = {
            "NAME": config_name,
            "TYPE": config_type,
            "PATH": config_path
        }
        
        try:
            with open(config_path, 'r') as f:
                current_section = ""
                for line in f:
                    line = line.strip()
                    if not line or line.startswith('#'):
                        continue
                        
                    # Check if this is a section header
                    if line.startswith('[') and line.endswith(']'):
                        current_section = line[1:-1]  # Remove brackets
                        continue
                        
                    # Parse key-value pairs
                    if '=' in line:
                        key, value = line.split('=', 1)
                        key = key.strip()
                        value = value.strip()
                        
                        # Remove quotes if present
                        if value.startswith('"') and value.endswith('"'):
                            value = value[1:-1]
                            
                        # Add section prefix if in a section
                        if current_section:
                            key = f"{current_section}.{key}"
                            
                        config_data[key] = value
                        
            return config_data
            
        except Exception as e:
            self.colorize("red", f"Failed to load configuration: {str(e)}", bold=True)
            return None
            
    def generate_random_token(self, length=12):
        """Generate a random token for FRP authentication"""
        chars = string.ascii_letters + string.digits + "!@#$%^&*"
        return ''.join(random.choice(chars) for _ in range(length))
        
    def create_server_config(self, config_name: str) -> bool:
        """Create a new FRP server configuration"""
        # Check if configuration already exists
        config_path = f"{self.configs_dir}/frps-{config_name}.toml"
        if os.path.exists(config_path):
            self.colorize("yellow", f"Configuration '{config_name}' already exists", bold=True)
            return False
            
        # Prompt for configuration parameters
        print("\nConfiguring FRP Server:")
        print("------------------------")
        
        # Bind address
        bind_addr = Prompt.ask("Bind address", default="0.0.0.0")
        
        # Bind port
        while True:
            try:
                bind_port = int(Prompt.ask("Bind port", default=str(self.default_frp_port)))
                if 1 <= bind_port <= 65535:
                    break
                else:
                    self.colorize("red", "Port must be between 1 and 65535", bold=True)
            except ValueError:
                self.colorize("red", "Port must be a number", bold=True)
                
        # Authentication token
        use_default_token = Confirm.ask("Generate a random authentication token?", default=True)
        if use_default_token:
            auth_token = self.generate_random_token()
            self.colorize("green", f"Generated authentication token: {auth_token}", bold=True)
        else:
            auth_token = Prompt.ask("Authentication token")
            
        # Create the configuration
        try:
            with open(config_path, 'w') as f:
                f.write(f"# FRP Server Configuration for {config_name}\n\n")
                f.write(f"bindAddr = \"{bind_addr}\"\n")
                f.write(f"bindPort = {bind_port}\n")
                f.write(f"kcpBindPort = {bind_port}\n\n")
                
                f.write("transport.maxPoolCount = 5\n")
                f.write("transport.tcpMux = true\n")
                f.write("transport.tcpMuxKeepaliveInterval = 30\n")
                f.write("transport.tcpKeepalive = 7200\n\n")
                
                f.write("auth.method = \"token\"\n")
                f.write(f"auth.token = \"{auth_token}\"\n")
                
            self.colorize("green", f"Server configuration '{config_name}' created successfully", bold=True)
            
            # Create system service
            service_file = f"/etc/systemd/system/frps-{config_name}.service"
            
            with open(service_file, 'w') as f:
                f.write("[Unit]\n")
                f.write("Description=FRP Server Service\n")
                f.write("After=network.target\n\n")
                
                f.write("[Service]\n")
                f.write("Type=simple\n")
                f.write(f"ExecStart={self.frps_binary} -c {config_path}\n")
                f.write("Restart=always\n")
                f.write("RestartSec=5\n")
                f.write("LimitNOFILE=1048576\n\n")
                
                f.write("[Install]\n")
                f.write("WantedBy=multi-user.target\n")
                
            # Install the service
            self.install_service(config_name, "server")
            
            return True
            
        except Exception as e:
            self.colorize("red", f"Failed to create server configuration: {str(e)}", bold=True)
            return False
            
    def create_client_config(self, config_name: str) -> bool:
        """Create a new FRP client configuration"""
        # Check if configuration already exists
        config_path = f"{self.configs_dir}/frpc-{config_name}.toml"
        if os.path.exists(config_path):
            self.colorize("yellow", f"Configuration '{config_name}' already exists", bold=True)
            return False
            
        # Prompt for configuration parameters
        print("\nConfiguring FRP Client:")
        print("------------------------")
        
        # Server address
        server_addr = Prompt.ask("Server address (IP or domain)")
        
        # Server port
        while True:
            try:
                server_port = int(Prompt.ask("Server port", default=str(self.default_frp_port)))
                if 1 <= server_port <= 65535:
                    break
                else:
                    self.colorize("red", "Port must be between 1 and 65535", bold=True)
            except ValueError:
                self.colorize("red", "Port must be a number", bold=True)
                
        # Authentication token
        auth_token = Prompt.ask("Authentication token")
        
        # Transport protocol
        transport_protocol = Prompt.ask(
            "Transport protocol",
            choices=["quic", "kcp", "tcp", "wss"],
            default="quic"
        )
        
        # Prompt for proxy configuration
        print("\nConfiguring proxy:")
        proxy_name = Prompt.ask("Proxy name", default=f"{config_name}-proxy")
        
        proxy_type = Prompt.ask(
            "Proxy type",
            choices=["tcp", "udp"],
            default="udp"
        )
        
        local_ip = Prompt.ask("Local IP", default="127.0.0.1")
        
        while True:
            try:
                local_port = int(Prompt.ask("Local port"))
                if 1 <= local_port <= 65535:
                    break
                else:
                    self.colorize("red", "Port must be between 1 and 65535", bold=True)
            except ValueError:
                self.colorize("red", "Port must be a number", bold=True)
                
        remote_port = Prompt.ask("Remote port", default=str(local_port))
        
        # Create the configuration
        try:
            with open(config_path, 'w') as f:
                f.write(f"# FRP Client Configuration for {config_name}\n\n")
                f.write(f"serverAddr = \"{server_addr}\"\n")
                f.write(f"serverPort = {server_port}\n\n")
                
                f.write("auth.method = \"token\"\n")
                f.write(f"auth.token = \"{auth_token}\"\n\n")
                
                f.write(f"transport.protocol = \"{transport_protocol}\"\n")
                f.write("transport.tcpMux = true\n")
                f.write("transport.tcpMuxKeepaliveInterval = 30\n\n")
                
                f.write("[[proxies]]\n")
                f.write(f"name = \"{proxy_name}\"\n")
                f.write(f"type = \"{proxy_type}\"\n")
                f.write(f"localIP = \"{local_ip}\"\n")
                f.write(f"localPort = {local_port}\n")
                f.write(f"remotePort = {remote_port}\n")
                
            self.colorize("green", f"Client configuration '{config_name}' created successfully", bold=True)
            
            # Create system service
            service_file = f"/etc/systemd/system/frpc-{config_name}.service"
            
            with open(service_file, 'w') as f:
                f.write("[Unit]\n")
                f.write("Description=FRP Client Service\n")
                f.write("After=network.target\n\n")
                
                f.write("[Service]\n")
                f.write("Type=simple\n")
                f.write(f"ExecStart={self.frpc_binary} -c {config_path}\n")
                f.write("Restart=always\n")
                f.write("RestartSec=5\n")
                f.write("LimitNOFILE=1048576\n\n")
                
                f.write("[Install]\n")
                f.write("WantedBy=multi-user.target\n")
                
            # Install the service
            self.install_service(config_name, "client")
            
            return True
            
        except Exception as e:
            self.colorize("red", f"Failed to create client configuration: {str(e)}", bold=True)
            return False
    
    def install_service(self, config_name: str, config_type: str) -> bool:
        """Install and start the FRP service"""
        try:
            # Determine the binary and config file paths
            binary = self.frps_binary if config_type == "server" else self.frpc_binary
            config_file = f"{self.configs_dir}/frp{'s' if config_type == 'server' else 'c'}-{config_name}.toml"
            service_suffix = "s" if config_type == "server" else "c"
            
            # Create the service file in the user's home directory
            service_dir = os.path.join(self.base_dir, "services")
            os.makedirs(service_dir, exist_ok=True)
            
            service_file = os.path.join(service_dir, f"frp{service_suffix}-{config_name}.service")
            
            # Write the service file
            with open(service_file, 'w') as f:
                f.write(f"""[Unit]
Description=FRP {'Server' if config_type == 'server' else 'Client'} Service for {config_name}
After=network.target

[Service]
Type=simple
ExecStart={binary} -c {config_file}
Restart=always
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
""")
            
            self.colorize("green", f"Created service file: {service_file}", bold=True)
            
            # Try to install the service file using systemd if running as root
            try:
                systemd_dir = "/etc/systemd/system"
                if os.access(systemd_dir, os.W_OK):
                    systemd_service_file = f"/etc/systemd/system/frp{service_suffix}-{config_name}.service"
                    shutil.copy2(service_file, systemd_service_file)
                    
                    # Enable and start the service
                    subprocess.run(["systemctl", "daemon-reload"], check=True)
                    subprocess.run(["systemctl", "enable", f"frp{service_suffix}-{config_name}.service"], check=True)
                    subprocess.run(["systemctl", "start", f"frp{service_suffix}-{config_name}.service"], check=True)
                    
                    self.colorize("green", f"FRP {config_type} service installed and started", bold=True)
                else:
                    self.colorize("yellow", "No permission to install system service. Manual installation required:", bold=True)
                    print(f"To install the service, run these commands as root:")
                    print(f"  sudo cp {service_file} /etc/systemd/system/")
                    print(f"  sudo systemctl daemon-reload")
                    print(f"  sudo systemctl enable frp{service_suffix}-{config_name}.service")
                    print(f"  sudo systemctl start frp{service_suffix}-{config_name}.service")
            except Exception as e:
                self.colorize("yellow", f"Could not install system service: {str(e)}", bold=True)
                print(f"To install the service, run these commands as root:")
                print(f"  sudo cp {service_file} /etc/systemd/system/")
                print(f"  sudo systemctl daemon-reload")
                print(f"  sudo systemctl enable frp{service_suffix}-{config_name}.service")
                print(f"  sudo systemctl start frp{service_suffix}-{config_name}.service")
            
            return True
        except Exception as e:
            self.colorize("red", f"Failed to install service: {str(e)}", bold=True)
            return False
    
    def configure_server(self):
        """Configure a new FRP server"""
        if not self.is_installed():
            self.colorize("yellow", "FRP is not installed. Installing...", bold=True)
            if not self.install():
                self.colorize("red", "Failed to install FRP", bold=True)
                return False
        
        print("\nCreating a new FRP server configuration")
        config_name = Prompt.ask("Configuration name")
        
        # Create server configuration
        return self.create_server_config(config_name)
    
    def configure_client(self):
        """Configure a new FRP client"""
        if not self.is_installed():
            self.colorize("yellow", "FRP is not installed. Installing...", bold=True)
            if not self.install():
                self.colorize("red", "Failed to install FRP", bold=True)
                return False
        
        print("\nCreating a new FRP client configuration")
        config_name = Prompt.ask("Configuration name")
        
        # Create client configuration
        return self.create_client_config(config_name)
    
    def check_service_status(self):
        """Check the status of FRP services"""
        # Get all available configurations
        configs = self.get_available_configs()
        
        if not configs:
            self.colorize("yellow", "No FRP configurations found", bold=True)
            return
            
        # Create a selection menu
        self.colorize("cyan", "Available FRP configurations:", bold=True)
        for i, config in enumerate(configs, 1):
            config_type = "Server" if config['type'] == 'server' else "Client"
            print(f"{i}. {config['name']} ({config_type})")
            
        # Get user selection
        selection = Prompt.ask("Select a configuration (or 'all' to check all)", default="all")
        
        if selection.lower() == 'all':
            # Check all configurations
            for config in configs:
                self.check_specific_service(config['name'], config['type'])
        else:
            try:
                index = int(selection) - 1
                if 0 <= index < len(configs):
                    selected_config = configs[index]
                    self.check_specific_service(selected_config['name'], selected_config['type'])
                else:
                    self.colorize("red", "Invalid selection", bold=True)
            except ValueError:
                self.colorize("red", "Invalid selection", bold=True)
                
        input("\nPress Enter to continue...")
    
    def check_specific_service(self, config_name: str, config_type: str):
        """Check the status of a specific service"""
        service_name = f"frp{'s' if config_type == 'server' else 'c'}-{config_name}.service"
        
        self.colorize("cyan", f"Checking status of {service_name}...", bold=True)
        
        try:
            result = subprocess.run(
                ["systemctl", "status", service_name],
                capture_output=True,
                text=True
            )
            print(result.stdout)
            
            if result.returncode != 0:
                print(result.stderr)
                
        except Exception as e:
            self.colorize("red", f"Error checking service status: {str(e)}", bold=True)
    
    def view_logs(self):
        """View logs for FRP services"""
        # Get all available configurations
        configs = self.get_available_configs()
        
        if not configs:
            self.colorize("yellow", "No FRP configurations found", bold=True)
            return
            
        # Create a selection menu
        self.colorize("cyan", "Available FRP configurations:", bold=True)
        for i, config in enumerate(configs, 1):
            config_type = "Server" if config['type'] == 'server' else "Client"
            print(f"{i}. {config['name']} ({config_type})")
            
        # Get user selection
        try:
            index = int(Prompt.ask("Select a configuration")) - 1
            if 0 <= index < len(configs):
                selected_config = configs[index]
                service_name = f"frp{'s' if selected_config['type'] == 'server' else 'c'}-{selected_config['name']}"
                
                # Use journalctl to view logs
                self.colorize("cyan", f"Viewing logs for {service_name}...", bold=True)
                
                try:
                    # Use popen to allow paging through results
                    process = subprocess.Popen(
                        ["journalctl", "-u", f"{service_name}.service", "--no-pager", "-n", "100"],
                        stdout=subprocess.PIPE
                    )
                    
                    for line in process.stdout:
                        print(line.decode('utf-8'), end='')
                        
                except Exception as e:
                    self.colorize("red", f"Error viewing logs: {str(e)}", bold=True)
            else:
                self.colorize("red", "Invalid selection", bold=True)
        except ValueError:
            self.colorize("red", "Invalid selection", bold=True)
                
        input("\nPress Enter to continue...")
    
    def restart_service(self):
        """Restart FRP services"""
        # Get all available configurations
        configs = self.get_available_configs()
        
        if not configs:
            self.colorize("yellow", "No FRP configurations found", bold=True)
            return
            
        # Create a selection menu
        self.colorize("cyan", "Available FRP configurations:", bold=True)
        for i, config in enumerate(configs, 1):
            config_type = "Server" if config['type'] == 'server' else "Client"
            print(f"{i}. {config['name']} ({config_type})")
            
        print(f"{len(configs) + 1}. Restart all services")
        
        # Get user selection
        try:
            selection = int(Prompt.ask("Select a configuration to restart", default=str(len(configs) + 1)))
            
            if selection == len(configs) + 1:
                # Restart all services
                self.colorize("yellow", "Restarting all FRP services...", bold=True)
                for config in configs:
                    service_name = f"frp{'s' if config['type'] == 'server' else 'c'}-{config['name']}.service"
                    try:
                        subprocess.run(["systemctl", "restart", service_name], check=True)
                        self.colorize("green", f"Service {service_name} restarted successfully", bold=True)
                    except subprocess.CalledProcessError as e:
                        self.colorize("red", f"Failed to restart {service_name}: {str(e)}", bold=True)
            elif 1 <= selection <= len(configs):
                selected_config = configs[selection - 1]
                service_name = f"frp{'s' if selected_config['type'] == 'server' else 'c'}-{selected_config['name']}.service"
                
                try:
                    self.colorize("yellow", f"Restarting {service_name}...", bold=True)
                    subprocess.run(["systemctl", "restart", service_name], check=True)
                    self.colorize("green", f"Service {service_name} restarted successfully", bold=True)
                except subprocess.CalledProcessError as e:
                    self.colorize("red", f"Failed to restart service: {str(e)}", bold=True)
            else:
                self.colorize("red", "Invalid selection", bold=True)
        except ValueError:
            self.colorize("red", "Invalid selection", bold=True)
                
        input("\nPress Enter to continue...")
    
    def remove_service(self, config_name=None, config_type=None):
        """Remove FRP services and configurations"""
        # If specific config is provided, remove it
        if config_name and config_type:
            return self._remove_specific_service(config_name, config_type)
            
        # Get all available configurations
        configs = self.get_available_configs()
        
        if not configs:
            self.colorize("yellow", "No FRP configurations found", bold=True)
            return
            
        # Create a selection menu
        self.colorize("cyan", "Available FRP configurations:", bold=True)
        for i, config in enumerate(configs, 1):
            config_type = "Server" if config['type'] == 'server' else "Client"
            print(f"{i}. {config['name']} ({config_type})")
            
        # Get user selection
        try:
            index = int(Prompt.ask("Select a configuration to remove")) - 1
            if 0 <= index < len(configs):
                selected_config = configs[index]
                
                if Confirm.ask(f"Are you sure you want to remove {selected_config['name']}?"):
                    self._remove_specific_service(selected_config['name'], selected_config['type'])
            else:
                self.colorize("red", "Invalid selection", bold=True)
        except ValueError:
            self.colorize("red", "Invalid selection", bold=True)
                
        input("\nPress Enter to continue...")
    
    def _remove_specific_service(self, config_name: str, config_type: str) -> bool:
        """Remove a specific FRP service and configuration"""
        service_name = f"frp{'s' if config_type == 'server' else 'c'}-{config_name}.service"
        config_file = f"{self.configs_dir}/frp{'s' if config_type == 'server' else 'c'}-{config_name}.toml"
        
        # Stop the service
        try:
            subprocess.run(["systemctl", "stop", service_name], check=True)
            self.colorize("green", f"Service {service_name} stopped", bold=True)
        except subprocess.CalledProcessError:
            self.colorize("yellow", f"Failed to stop service {service_name}", bold=True)
            
        # Disable the service
        try:
            subprocess.run(["systemctl", "disable", service_name], check=True)
            self.colorize("green", f"Service {service_name} disabled", bold=True)
        except subprocess.CalledProcessError:
            self.colorize("yellow", f"Failed to disable service {service_name}", bold=True)
            
        # Remove the service file
        service_file = f"/etc/systemd/system/{service_name}"
        if os.path.exists(service_file):
            try:
                os.remove(service_file)
                self.colorize("green", f"Service file {service_file} removed", bold=True)
            except Exception as e:
                self.colorize("red", f"Failed to remove service file: {str(e)}", bold=True)
                
        # Remove the configuration file
        if os.path.exists(config_file):
            try:
                os.remove(config_file)
                self.colorize("green", f"Configuration file {config_file} removed", bold=True)
            except Exception as e:
                self.colorize("red", f"Failed to remove configuration file: {str(e)}", bold=True)
                
        # Reload systemd daemon
        try:
            subprocess.run(["systemctl", "daemon-reload"], check=True)
        except subprocess.CalledProcessError:
            self.colorize("yellow", "Failed to reload systemd daemon", bold=True)
            
        self.colorize("green", f"FRP {config_type} '{config_name}' removed successfully", bold=True)
        return True 