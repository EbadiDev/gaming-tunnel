import os
import subprocess
import socket
import re
import shutil
from typing import Dict, Optional, List, Tuple

from rich.console import Console
from rich.prompt import Prompt, IntPrompt, Confirm
from rich import print as rich_print


class TinyVPN:
    def __init__(self):
        self.console = Console()
        self.base_dir = "/root/gamingtunnel"
        self.binary_path = os.path.join(self.base_dir, "tinyvpn")
        self.configs_dir = os.path.join(self.base_dir, "configs")
        
        # Create configs directory if it doesn't exist
        if not os.path.isdir(self.configs_dir):
            os.makedirs(self.configs_dir, exist_ok=True)
    
    def colorize(self, color, text, bold=False):
        """Print colored text using rich"""
        style = color
        if bold:
            style = f"{color} bold"
        rich_print(f"[{style}]{text}[/{style}]")
    
    def is_port_open(self, port: int) -> bool:
        """Check if a port is available"""
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            return s.connect_ex(('localhost', port)) != 0
    
    def get_available_configs(self) -> List[dict]:
        """Get a list of available configurations with their types"""
        if not os.path.exists(self.configs_dir):
            return []
        
        configs = []
        for item in os.listdir(self.configs_dir):
            item_path = os.path.join(self.configs_dir, item)
            if os.path.isdir(item_path):
                # Check for server configuration
                server_config_path = os.path.join(item_path, f"server_config_{item}.conf")
                client_config_path = os.path.join(item_path, f"client_config_{item}.conf")
                
                # If both server and client configs exist with the same name
                if os.path.exists(server_config_path):
                    configs.append({"name": item, "type": "server"})
                
                if os.path.exists(client_config_path):
                    configs.append({"name": item, "type": "client"})
        
        return configs
    
    def load_config(self, config_name: str) -> Dict[str, str]:
        """Load a configuration from a file"""
        config_path = os.path.join(self.configs_dir, config_name)
        server_config_path = os.path.join(config_path, f"server_config_{config_name}.conf")
        client_config_path = os.path.join(config_path, f"client_config_{config_name}.conf")
        
        config = {}
        
        # Try server config first
        if os.path.exists(server_config_path):
            with open(server_config_path, 'r') as f:
                for line in f:
                    if '=' in line:
                        key, value = line.strip().split('=', 1)
                        config[key] = value
            
            # Ensure CONFIG_TYPE is set even if not in file
            if 'CONFIG_TYPE' not in config:
                config['CONFIG_TYPE'] = 'server'
            
            return config
            
        # Then try client config
        elif os.path.exists(client_config_path):
            with open(client_config_path, 'r') as f:
                for line in f:
                    if '=' in line:
                        key, value = line.strip().split('=', 1)
                        config[key] = value
            
            # Ensure CONFIG_TYPE is set even if not in file
            if 'CONFIG_TYPE' not in config:
                config['CONFIG_TYPE'] = 'client'
                
            return config
            
        return {}
    
    def create_server_config(self, config_name: str) -> bool:
        """Create a new TinyVPN server configuration"""
        # Check if configuration already exists
        config_path = os.path.join(self.configs_dir, config_name)
        if os.path.exists(config_path):
            self.colorize("red", f"Configuration '{config_name}' already exists!", bold=True)
            return False
        
        # Create configuration directory
        os.makedirs(config_path, exist_ok=True)
        
        # Collect server configuration parameters
        self.colorize("cyan", "TinyVPN Server Configuration", bold=True)
        print()
        
        # Get server port
        while True:
            port = IntPrompt.ask("Enter tunnel port (1024-65535)", default=20002)
            if 1024 <= port <= 65535:
                if self.is_port_open(port):
                    break
                else:
                    self.colorize("red", f"Port {port} is already in use. Please choose another port.", bold=True)
            else:
                self.colorize("red", "Port must be between 1024 and 65535", bold=True)
        
        # Get FEC value
        while True:
            fec_input = Prompt.ask("Enter FEC value (x:y format, 0 to disable)", default="2:4")
            if fec_input == "0":
                fec = "--disable-fec"
                break
            elif re.match(r'^\d+:\d+$', fec_input):
                fec = f"-f{fec_input}"
                break
            else:
                self.colorize("red", "Invalid FEC format. Use x:y format or 0 to disable.", bold=True)
        
        # Get subnet
        subnet = Prompt.ask("Enter subnet address", default="10.22.23.0")
        
        # Get mode
        mode_choice = Prompt.ask(
            "Select mode", 
            choices=["0", "1"], 
            default="1"
        )
        
        if mode_choice == "0":
            mode = "--mode 0 --timeout 4"
            self.colorize("yellow", "Selected non-gaming mode with timeout 4", bold=False)
        else:
            mode = "--mode 1 --timeout 0"
            self.colorize("green", "Selected gaming mode with timeout 0", bold=False)
        
        # Get MTU
        mtu = IntPrompt.ask("Enter MTU value", default=1450)
        
        # Prepare the configuration
        server_cmd = (
            f"-s \"-l[::]:{port}\" {fec} --sub-net {subnet} --mtu {mtu} "
            f"{mode} --tun-dev {config_name} --disable-obscure"
        )
        
        # Save configuration
        config_file = os.path.join(config_path, f"server_config_{config_name}.conf")
        with open(config_file, "w") as f:
            f.write(f"PORT={port}\n")
            f.write(f"FEC={fec}\n")
            f.write(f"SUBNET={subnet}\n")
            f.write(f"MODE={mode}\n")
            f.write(f"MTU=--mtu {mtu}\n")
            f.write(f"COMMAND={server_cmd}\n")
            f.write(f"CONFIG_TYPE=server\n")
        
        # Create systemd service file
        service_file = os.path.join(config_path, f"tinyvpn-{config_name}-server.service")
        with open(service_file, "w") as f:
            f.write(f"""[Unit]
Description=GamingVPN Server {config_name}
After=network.target
Wants=network.target

[Service]
Type=simple
WorkingDirectory={self.base_dir}
ExecStart={self.binary_path} {server_cmd}
Restart=always
RestartSec=1
LimitNOFILE=infinity

# Logging configuration
StandardOutput=append:/var/log/tunnel{config_name}.log
StandardError=append:/var/log/tunnel{config_name}.error.log

# Optional: log rotation to prevent huge log files
LogRateLimitIntervalSec=0
LogRateLimitBurst=0

[Install]
WantedBy=multi-user.target
""")
        
        # Create client config info for reference
        client_info_file = os.path.join(config_path, "client_info.txt")
        server_ip = self.get_server_ip()
        with open(client_info_file, "w") as f:
            f.write(f"# Client configuration information for {config_name}\n")
            f.write(f"Server IP: {server_ip}\n")
            f.write(f"Server Port: {port}\n")
            f.write(f"Subnet: {subnet}\n")
            f.write(f"Server VPN IP: {subnet.rsplit('.', 1)[0]}.1\n")
            f.write(f"Client VPN IP: {subnet.rsplit('.', 1)[0]}.2\n")
            f.write(f"FEC: {fec}\n")
            f.write(f"MTU: {mtu}\n")
            
        self.colorize("green", f"TinyVPN server configuration '{config_name}' created successfully!", bold=True)
        
        # Automatically install and start the service
        self.install_service(config_name, service_file)
        
        return True
    
    def install_service(self, config_name: str, service_file: str) -> bool:
        """Install and start a systemd service"""
        self.colorize("yellow", "Installing and starting service...", bold=True)
        
        # Determine if this is a server or client service based on the service filename
        is_server = "-server.service" in service_file
        is_client = "-client.service" in service_file
        service_type = "server" if is_server else "client" if is_client else ""
        service_name = f"tinyvpn-{config_name}-{service_type}"
        
        # Copy service file to systemd directory
        try:
            # Copy service file
            result = subprocess.run(
                ["sudo", "cp", service_file, "/etc/systemd/system/"],
                capture_output=True,
                text=True
            )
            
            if result.returncode != 0:
                self.colorize("red", "Failed to copy service file. You may need to manually install it.", bold=True)
                self.colorize("cyan", f"sudo cp {service_file} /etc/systemd/system/", bold=False)
                return False
            
            # Reload systemd and enable/start service
            result = subprocess.run(
                ["sudo", "systemctl", "daemon-reload"],
                capture_output=True,
                text=True
            )
            
            if result.returncode != 0:
                self.colorize("red", "Failed to reload systemd. You may need to manually install it.", bold=True)
                self.colorize("cyan", f"sudo systemctl daemon-reload", bold=False)
                self.colorize("cyan", f"sudo systemctl enable --now {service_name}.service", bold=False)
                return False
                
            # Now enable and start the service
            result = subprocess.run(
                ["sudo", "systemctl", "enable", "--now", f"{service_name}.service"],
                capture_output=True,
                text=True
            )
            
            if result.returncode != 0:
                self.colorize("red", "Failed to enable and start service. You may need to manually start it.", bold=True)
                self.colorize("red", f"Error: {result.stderr}", bold=True)
                
                # Try to get the detailed service status for debugging
                status_result = subprocess.run(
                    ["sudo", "systemctl", "status", f"{service_name}.service"],
                    capture_output=True,
                    text=True
                )
                if status_result.returncode == 0:
                    self.colorize("yellow", "Service status:", bold=True)
                    print(status_result.stdout)
                
                self.colorize("cyan", f"sudo systemctl enable --now {service_name}.service", bold=False)
                return False
            
            self.colorize("green", f"Service {service_name} installed and started successfully!", bold=True)
            return True
            
        except Exception as e:
            self.colorize("red", f"Error installing service: {str(e)}", bold=True)
            self.colorize("yellow", "You may need to manually install the service:", bold=True)
            self.colorize("cyan", f"sudo cp {service_file} /etc/systemd/system/", bold=False)
            self.colorize("cyan", f"sudo systemctl daemon-reload", bold=False)
            self.colorize("cyan", f"sudo systemctl enable --now {service_name}.service", bold=False)
            return False
    
    def modify_server_config(self, config_name: str) -> bool:
        """Modify an existing TinyVPN server configuration"""
        config_path = os.path.join(self.configs_dir, config_name)
        if not os.path.exists(config_path):
            self.colorize("red", f"Configuration '{config_name}' does not exist!", bold=True)
            return False
        
        # Load existing configuration
        existing_config = self.load_config(config_name)
        if not existing_config:
            self.colorize("red", f"Failed to load configuration for '{config_name}'!", bold=True)
            return False
        
        # Check if this is a server config
        if existing_config.get("CONFIG_TYPE") != "server":
            self.colorize("red", f"Configuration '{config_name}' is not a server configuration!", bold=True)
            return False
        
        # Parse existing values
        port = int(existing_config.get('PORT', '20002'))
        fec = existing_config.get('FEC', '-f2:4')
        subnet = existing_config.get('SUBNET', '10.22.23.0')
        mode = existing_config.get('MODE', '--mode 1 --timeout 0')
        mtu_str = existing_config.get('MTU', '--mtu 1450')
        mtu = int(mtu_str.split(' ')[1]) if ' ' in mtu_str else 1450
        
        # Extract fec value for display
        if fec == '--disable-fec':
            fec_display = '0'
        else:
            fec_display = fec[2:] if fec.startswith('-f') else fec  # Remove -f prefix
        
        # Extract mode value
        mode_choice = '1' if '--mode 1' in mode else '0'
        
        # Display current configuration
        self.colorize("cyan", f"Modifying TinyVPN Server Configuration: {config_name}", bold=True)
        self.colorize("yellow", "Current settings:", bold=True)
        print(f"Port: {port}")
        print(f"FEC: {fec_display}")
        print(f"Subnet: {subnet}")
        print(f"Mode: {mode_choice} ({'Gaming mode' if mode_choice == '1' else 'Non-gaming mode'})")
        print(f"MTU: {mtu}")
        print()
        
        # Collect new server configuration parameters
        # Get server port
        while True:
            new_port = IntPrompt.ask("Enter tunnel port (1024-65535)", default=port)
            if new_port != port:  # Only check if port changed
                if 1024 <= new_port <= 65535:
                    if self.is_port_open(new_port):
                        break
                    else:
                        self.colorize("red", f"Port {new_port} is already in use. Please choose another port.", bold=True)
                else:
                    self.colorize("red", "Port must be between 1024 and 65535", bold=True)
            else:
                break  # Using the same port, no need to check
        
        # Get FEC value
        while True:
            fec_input = Prompt.ask("Enter FEC value (x:y format, 0 to disable)", default=fec_display)
            if fec_input == "0":
                new_fec = "--disable-fec"
                break
            elif re.match(r'^\d+:\d+$', fec_input):
                new_fec = f"-f{fec_input}"
                break
            else:
                self.colorize("red", "Invalid FEC format. Use x:y format or 0 to disable.", bold=True)
        
        # Get subnet
        new_subnet = Prompt.ask("Enter subnet address", default=subnet)
        
        # Get mode
        new_mode_choice = Prompt.ask(
            "Select mode (0=non-gaming, 1=gaming)", 
            choices=["0", "1"], 
            default=mode_choice
        )
        
        if new_mode_choice == "0":
            new_mode = "--mode 0 --timeout 4"
            self.colorize("yellow", "Selected non-gaming mode with timeout 4", bold=False)
        else:
            new_mode = "--mode 1 --timeout 0"
            self.colorize("green", "Selected gaming mode with timeout 0", bold=False)
        
        # Get MTU
        new_mtu = IntPrompt.ask("Enter MTU value", default=mtu)
        
        # Check if anything changed
        if (new_port == port and new_fec == fec and new_subnet == subnet and 
            new_mode == mode and new_mtu == mtu):
            self.colorize("yellow", "No changes made to the configuration.", bold=True)
            return False
        
        # Confirm changes
        self.colorize("yellow", "Configuration changes summary:", bold=True)
        if new_port != port:
            print(f"Port: {port} → {new_port}")
        if new_fec != fec:
            print(f"FEC: {fec} → {new_fec}")
        if new_subnet != subnet:
            print(f"Subnet: {subnet} → {new_subnet}")
        if new_mode != mode:
            print(f"Mode: {mode} → {new_mode}")
        if new_mtu != mtu:
            print(f"MTU: {mtu} → {new_mtu}")
        
        if not Confirm.ask("Apply these changes?"):
            self.colorize("yellow", "Modification cancelled.", bold=True)
            return False
        
        # Prepare the configuration
        server_cmd = (
            f"-s \"-l[::]:{new_port}\" {new_fec} --sub-net {new_subnet} --mtu {new_mtu} "
            f"{new_mode} --tun-dev {config_name} --disable-obscure"
        )
        
        # Save configuration
        config_file = os.path.join(config_path, f"server_config_{config_name}.conf")
        with open(config_file, "w") as f:
            f.write(f"PORT={new_port}\n")
            f.write(f"FEC={new_fec}\n")
            f.write(f"SUBNET={new_subnet}\n")
            f.write(f"MODE={new_mode}\n")
            f.write(f"MTU=--mtu {new_mtu}\n")
            f.write(f"COMMAND={server_cmd}\n")
            f.write(f"CONFIG_TYPE=server\n")
        
        # Create systemd service file
        service_file = os.path.join(config_path, f"tinyvpn-{config_name}-server.service")
        with open(service_file, "w") as f:
            f.write(f"""[Unit]
Description=GamingVPN Server {config_name}
After=network.target
Wants=network.target

[Service]
Type=simple
WorkingDirectory={self.base_dir}
ExecStart={self.binary_path} {server_cmd}
Restart=always
RestartSec=1
LimitNOFILE=infinity

# Logging configuration
StandardOutput=append:/var/log/tunnel{config_name}.log
StandardError=append:/var/log/tunnel{config_name}.error.log

# Optional: log rotation to prevent huge log files
LogRateLimitIntervalSec=0
LogRateLimitBurst=0

[Install]
WantedBy=multi-user.target
""")
        
        # Update client config info
        client_info_file = os.path.join(config_path, "client_info.txt")
        server_ip = self.get_server_ip()
        with open(client_info_file, "w") as f:
            f.write(f"# Client configuration information for {config_name}\n")
            f.write(f"Server IP: {server_ip}\n")
            f.write(f"Server Port: {new_port}\n")
            f.write(f"Subnet: {new_subnet}\n")
            f.write(f"Server VPN IP: {new_subnet.rsplit('.', 1)[0]}.1\n")
            f.write(f"Client VPN IP: {new_subnet.rsplit('.', 1)[0]}.2\n")
            f.write(f"FEC: {new_fec}\n")
            f.write(f"MTU: {new_mtu}\n")
            
        self.colorize("green", f"TinyVPN server configuration '{config_name}' modified successfully!", bold=True)
        
        # Update the service
        self.colorize("yellow", "Updating service...", bold=True)
        try:
            # Copy service file
            result = subprocess.run(
                ["sudo", "cp", service_file, "/etc/systemd/system/"],
                capture_output=True,
                text=True
            )
            
            if result.returncode == 0:
                # Reload systemd and restart service
                subprocess.run(["sudo", "systemctl", "daemon-reload"], capture_output=True)
                subprocess.run(["sudo", "systemctl", "restart", f"tinyvpn-{config_name}-server.service"], capture_output=True)
                self.colorize("green", "Service updated and restarted successfully!", bold=True)
            else:
                self.colorize("yellow", "Failed to update service automatically. You may need to do it manually:", bold=True)
                self.colorize("cyan", f"sudo cp {service_file} /etc/systemd/system/", bold=False)
                self.colorize("cyan", f"sudo systemctl daemon-reload && sudo systemctl restart tinyvpn-{config_name}-server.service", bold=False)
        except Exception as e:
            self.colorize("red", f"Error updating service: {str(e)}", bold=True)
            self.colorize("yellow", "You may need to manually update the service:", bold=True)
            self.colorize("cyan", f"sudo cp {service_file} /etc/systemd/system/", bold=False)
            self.colorize("cyan", f"sudo systemctl daemon-reload && sudo systemctl restart tinyvpn-{config_name}-server.service", bold=False)
        
        return True
    
    def get_server_ip(self) -> str:
        """Get server's public IP address"""
        try:
            import requests
            return requests.get("https://api.ipify.org").text
        except:
            return "Unknown"
    
    def configure_server(self):
        """Configure a new TinyVPN server"""
        self.colorize("cyan", "Creating a new TinyVPN server configuration", bold=True)
        
        # Get configuration name
        config_name = Prompt.ask("Enter a name for this configuration")
        if not config_name or not re.match(r'^[a-zA-Z0-9_-]+$', config_name):
            self.colorize("red", "Invalid configuration name. Use only letters, numbers, underscores, and hyphens.", bold=True)
            return
        
        # Create server configuration
        self.create_server_config(config_name)
    
    def check_service_status(self):
        """Check the status of a TinyVPN service"""
        configs = self.get_available_configs()
        
        if not configs:
            self.colorize("yellow", "No TinyVPN configurations found.", bold=True)
            return
        
        self.colorize("cyan", "Available configurations:", bold=True)
        for i, config in enumerate(configs, 1):
            print(f"{i}. {config['name']} ({config['type']})")
        
        config_idx = IntPrompt.ask("Select a configuration to check", default=1)
        if 1 <= config_idx <= len(configs):
            selected_config = configs[config_idx - 1]
            config_name = selected_config['name']
            config_type = selected_config['type']
            service_suffix = "server" if config_type == "server" else "client"
            
            try:
                result = subprocess.run(
                    ["systemctl", "status", f"tinyvpn-{config_name}-{service_suffix}.service"],
                    capture_output=True,
                    text=True
                )
                print(result.stdout)
                
                if result.returncode != 0:
                    self.colorize("yellow", f"Service tinyvpn-{config_name}-{service_suffix} might not be installed or is not running.", bold=True)
            except Exception as e:
                self.colorize("red", f"Error checking service status: {str(e)}", bold=True)
        else:
            self.colorize("red", "Invalid selection", bold=True)
    
    def view_logs(self):
        """View logs for a TinyVPN service"""
        configs = self.get_available_configs()
        
        if not configs:
            self.colorize("yellow", "No TinyVPN configurations found.", bold=True)
            return
        
        self.colorize("cyan", "Available configurations:", bold=True)
        for i, config in enumerate(configs, 1):
            print(f"{i}. {config['name']} ({config['type']})")
        
        config_idx = IntPrompt.ask("Select a configuration to view logs", default=1)
        if 1 <= config_idx <= len(configs):
            selected_config = configs[config_idx - 1]
            config_name = selected_config['name']
            log_file = f"/var/log/tunnel{config_name}.log"
            
            try:
                if os.path.exists(log_file):
                    result = subprocess.run(
                        ["tail", "-n", "50", log_file],
                        capture_output=True,
                        text=True
                    )
                    print(result.stdout)
                else:
                    self.colorize("yellow", f"Log file {log_file} not found.", bold=True)
            except Exception as e:
                self.colorize("red", f"Error viewing logs: {str(e)}", bold=True)
        else:
            self.colorize("red", "Invalid selection", bold=True)
    
    def restart_service(self):
        """Restart a TinyVPN service"""
        configs = self.get_available_configs()
        
        if not configs:
            self.colorize("yellow", "No TinyVPN configurations found.", bold=True)
            return
        
        self.colorize("cyan", "Available configurations:", bold=True)
        for i, config in enumerate(configs, 1):
            print(f"{i}. {config['name']} ({config['type']})")
        
        config_idx = IntPrompt.ask("Select a configuration to restart", default=1)
        if 1 <= config_idx <= len(configs):
            selected_config = configs[config_idx - 1]
            config_name = selected_config['name']
            config_type = selected_config['type']
            service_suffix = "server" if config_type == "server" else "client"
            
            try:
                result = subprocess.run(
                    ["systemctl", "restart", f"tinyvpn-{config_name}-{service_suffix}.service"],
                    capture_output=True,
                    text=True
                )
                
                if result.returncode == 0:
                    self.colorize("green", f"Service tinyvpn-{config_name}-{service_suffix} restarted successfully.", bold=True)
                else:
                    self.colorize("red", f"Failed to restart service tinyvpn-{config_name}-{service_suffix}.", bold=True)
                    print(result.stderr)
            except Exception as e:
                self.colorize("red", f"Error restarting service: {str(e)}", bold=True)
        else:
            self.colorize("red", "Invalid selection", bold=True)
    
    def remove_service(self, config_name=None, config_type=None):
        """Remove a TinyVPN service"""
        configs = self.get_available_configs()
        
        if not configs:
            self.colorize("yellow", "No TinyVPN configurations found.", bold=True)
            return
            
        # If config_name and config_type were not specified, ask the user to select
        if config_name is None or config_type is None:
            self.colorize("cyan", "Available configurations:", bold=True)
            for i, config in enumerate(configs, 1):
                print(f"{i}. {config['name']} ({config['type']})")
            
            config_idx = IntPrompt.ask("Select a configuration to remove", default=1)
            if 1 <= config_idx <= len(configs):
                selected_config = configs[config_idx - 1]
                config_name = selected_config['name']
                config_type = selected_config['type']
            else:
                self.colorize("red", "Invalid selection", bold=True)
                return
            
        # Confirm removal if called interactively
        if config_name is not None and config_type is not None:
            confirm_message = f"Are you sure you want to remove the {config_type} configuration '{config_name}'?"
            if config_name and not Confirm.ask(confirm_message):
                self.colorize("yellow", "Operation cancelled.", bold=True)
                return
            
            try:
                service_suffix = "server" if config_type == "server" else "client"
                service_name = f"tinyvpn-{config_name}-{service_suffix}"
                
                # Stop and disable service if it exists
                subprocess.run(
                    ["systemctl", "stop", f"{service_name}.service"],
                    capture_output=True,
                    text=True
                )
                
                subprocess.run(
                    ["systemctl", "disable", f"{service_name}.service"],
                    capture_output=True,
                    text=True
                )
                
                # Remove service file if it exists
                service_path = f"/etc/systemd/system/{service_name}.service"
                if os.path.exists(service_path):
                    os.remove(service_path)
                    subprocess.run(["systemctl", "daemon-reload"], capture_output=True)
                
                # Remove configuration files
                config_path = os.path.join(self.configs_dir, config_name)
                if os.path.exists(config_path):
                    # If we're only removing one type of config (server or client) but both exist,
                    # we need to be careful not to delete the entire directory
                    server_config = os.path.join(config_path, f"server_config_{config_name}.conf")
                    client_config = os.path.join(config_path, f"client_config_{config_name}.conf")
                    
                    # If both types exist and we're only removing one type
                    if os.path.exists(server_config) and os.path.exists(client_config) and config_type in ["server", "client"]:
                        # Only remove the specific config file
                        if config_type == "server":
                            os.remove(server_config)
                            self.colorize("green", f"Server configuration '{config_name}' removed.", bold=True)
                        else:
                            os.remove(client_config)
                            self.colorize("green", f"Client configuration '{config_name}' removed.", bold=True)
                    else:
                        # Remove the entire directory if it only contains the type we're removing
                        import shutil
                        shutil.rmtree(config_path)
                        self.colorize("green", f"TinyVPN configuration '{config_name}' removed completely.", bold=True)
                
                self.colorize("green", f"TinyVPN {config_type} configuration '{config_name}' removed successfully.", bold=True)
            except Exception as e:
                self.colorize("red", f"Error removing configuration: {str(e)}", bold=True)
    
    def configure_client(self):
        """Configure a TinyVPN client"""
        self.colorize("cyan", "Creating a new TinyVPN client configuration", bold=True)
        
        # Get configuration name
        config_name = Prompt.ask("Enter a name for this configuration")
        if not config_name or not re.match(r'^[a-zA-Z0-9_-]+$', config_name):
            self.colorize("red", "Invalid configuration name. Use only letters, numbers, underscores, and hyphens.", bold=True)
            return
        
        # Get server address
        server_addr = Prompt.ask("Enter server IP address")
        if not server_addr:
            self.colorize("red", "Server address cannot be empty.", bold=True)
            return
        
        # Get server port
        while True:
            server_port = IntPrompt.ask("Enter server port (1024-65535)", default=20002)
            if 1024 <= server_port <= 65535:
                break
            else:
                self.colorize("red", "Port must be between 1024 and 65535", bold=True)
        
        # Get FEC value
        while True:
            fec_input = Prompt.ask("Enter FEC value (x:y format, 0 to disable)", default="2:4")
            if fec_input == "0":
                fec = "0"
                break
            elif re.match(r'^\d+:\d+$', fec_input):
                fec = fec_input
                break
            else:
                self.colorize("red", "Invalid FEC format. Use x:y format or 0 to disable.", bold=True)
        
        # Get subnet
        subnet = Prompt.ask("Enter subnet address", default="10.22.23.0")
        
        # Get mode - timeout is automatically determined by mode
        mode_choice = Prompt.ask(
            "Select mode (0=non-gaming, 1=gaming)", 
            choices=["0", "1"], 
            default="1"
        )
        
        if mode_choice == "0":
            self.colorize("yellow", "Selected non-gaming mode with timeout 4", bold=False)
        else:
            self.colorize("green", "Selected gaming mode with timeout 0", bold=False)
        
        # Get MTU
        mtu = IntPrompt.ask("Enter MTU value", default=1450)
        
        # Create client configuration - timeout is determined by mode
        self.create_client_config(config_name, server_addr, server_port, fec, subnet, mode_choice, mtu)
    
    def create_client_config(self, config_name, server_addr, server_port, fec, subnet, mode, mtu, timeout=None):
        """Create a new client configuration"""
        # Create config directory
        config_dir = os.path.join(self.configs_dir, config_name)
        if not os.path.exists(config_dir):
            os.makedirs(config_dir)
        
        # Format FEC parameter properly
        if fec == "0":
            fec_param = "--disable-fec"
        else:
            fec_param = f"-f{fec}"
        
        # Format mode parameter with appropriate timeout
        if mode == "0":
            mode_param = "0 --timeout 4"
            timeout_value = 4
        else:
            mode_param = "1 --timeout 0"
            timeout_value = 0
        
        # Use provided timeout only if explicitly set, otherwise use the mode-determined value
        if timeout is not None:
            timeout_value = timeout
        
        # Create client config file
        config_file = os.path.join(config_dir, f"client_config_{config_name}.conf")
        with open(config_file, 'w') as f:
            f.write(f"SERVER_ADDR={server_addr}\n")
            f.write(f"SERVER_PORT={server_port}\n")
            f.write(f"FEC={fec_param}\n")
            f.write(f"SUBNET={subnet}\n")
            f.write(f"MODE=--mode {mode_param}\n")
            f.write(f"MTU={mtu}\n")
            f.write(f"TIMEOUT={timeout_value}\n")
            f.write(f"CONFIG_NAME={config_name}\n")
            f.write(f"CONFIG_TYPE=client\n")
        
        # Create systemd service file
        service_file = os.path.join(config_dir, f"tinyvpn-{config_name}-client.service")
        with open(service_file, 'w') as f:
            f.write("[Unit]\n")
            f.write("Description=TinyVPN Client Service\n")
            f.write("After=network.target\n\n")
            
            f.write("[Service]\n")
            f.write("Type=simple\n")
            f.write(f"WorkingDirectory={self.base_dir}\n")
            f.write(f"ExecStart={self.binary_path} -c -r{server_addr}:{server_port} {fec_param} --sub-net {subnet} --mode {mode_param} --mtu {mtu} --tun-dev {config_name} --keep-reconnect --disable-obscure\n")
            f.write("Restart=always\n")
            f.write("RestartSec=3\n\n")
            
            # Add logging configuration like in server
            f.write("# Logging configuration\n")
            f.write(f"StandardOutput=append:/var/log/tunnel{config_name}.log\n")
            f.write(f"StandardError=append:/var/log/tunnel{config_name}.error.log\n\n")
            
            f.write("[Install]\n")
            f.write("WantedBy=multi-user.target\n")
        
        self.colorize("green", f"Client configuration created successfully at {os.path.abspath(config_file)}", bold=True)
        self.colorize("green", f"Service file created at {os.path.abspath(service_file)}", bold=True)
        
        # Install the service
        installed = self.install_service(config_name, service_file)
        
        if installed:
            self.colorize("green", "Client service installed and started successfully!", bold=True)
            self.colorize("cyan", f"TinyVPN client '{config_name}' is now connected to {server_addr}:{server_port}", bold=True)
        else:
            self.colorize("yellow", "To manually start the service:", bold=True)
            self.colorize("cyan", f"sudo cp {os.path.abspath(service_file)} /etc/systemd/system/", bold=False)
            self.colorize("cyan", "sudo systemctl daemon-reload", bold=False)
            self.colorize("cyan", f"sudo systemctl enable --now tinyvpn-{config_name}-client.service", bold=False)
        
        return config_file
    
    def check_connection(self, config_name: str) -> bool:
        """Check if VPN connection is established by pinging the server/client IP"""
        config = self.load_config(config_name)
        if not config:
            return False
        
        # First check if the VPN interface is up
        try:
            # Check if the interface exists using ip link
            ifconfig_result = subprocess.run(
                ["ip", "link", "show", config_name],
                capture_output=True,
                text=True
            )
            if ifconfig_result.returncode != 0:
                # Interface doesn't exist
                return False
            
            # Check if interface is UP
            if "state UP" not in ifconfig_result.stdout:
                return False
                
            # If we're here, the interface exists and is UP
            # Let's consider it connected if we can see traffic on it
            network_stats = self.get_network_stats(config_name)
            if network_stats["download"] > 0 or network_stats["upload"] > 0:
                # There's traffic on the interface, so it's likely connected
                return True
        except Exception as e:
            # Print exception for debugging
            print(f"Error checking interface: {str(e)}")
            return False
        
        # Get subnet from config
        subnet = config.get('SUBNET', '')
        if not subnet:
            return False
        
        # Determine IP to ping based on config type
        if config.get('CONFIG_TYPE') == 'server':
            # Server: Ping the client IP (x.x.x.2)
            ip_to_ping = f"{subnet.rsplit('.', 1)[0]}.2"
        else:
            # Client: Ping the server IP (x.x.x.1)
            ip_to_ping = f"{subnet.rsplit('.', 1)[0]}.1"
        
        try:
            # Run ping without specifying interface (-I flag) which can cause issues
            result = subprocess.run(
                ["ping", "-c", "1", "-W", "2", ip_to_ping],
                capture_output=True,
                text=True
            )
            return result.returncode == 0
        except Exception as e:
            # Print exception for debugging
            print(f"Error pinging endpoint: {str(e)}")
            return False
    
    def get_network_stats(self, config_name: str) -> dict:
        """Get network traffic statistics (download/upload) for a tunnel interface"""
        stats = {"download": 0, "upload": 0, "download_human": "0 B", "upload_human": "0 B"}
        
        try:
            # Read from /proc/net/dev which contains network interface statistics
            with open("/proc/net/dev", "r") as f:
                for line in f:
                    if config_name in line:
                        # Format: Interface: Rx bytes packets errs drop fifo frame compressed multicast Tx bytes ...
                        parts = line.split(":")
                        if len(parts) != 2:
                            continue
                        
                        values = parts[1].strip().split()
                        if len(values) < 9:
                            continue
                        
                        # Get received (download) and transmitted (upload) bytes
                        rx_bytes = int(values[0])  # Download
                        tx_bytes = int(values[8])  # Upload
                        
                        stats["download"] = rx_bytes
                        stats["upload"] = tx_bytes
                        
                        # Convert to human-readable format
                        stats["download_human"] = self.format_bytes(rx_bytes)
                        stats["upload_human"] = self.format_bytes(tx_bytes)
                        break
        except Exception as e:
            self.colorize("red", f"Error getting network stats: {str(e)}", bold=False)
        
        return stats
    
    def format_bytes(self, size):
        """Convert bytes to human-readable format"""
        power = 2**10  # 1024
        n = 0
        power_labels = {0: 'B', 1: 'KB', 2: 'MB', 3: 'GB', 4: 'TB'}
        
        while size > power-1:
            size /= power
            n += 1
        
        if n > 0:
            return f"{size:.2f} {power_labels[n]}"
        else:
            return f"{size} {power_labels[n]}"
    
    def show_network_usage(self, config_name: str):
        """Show detailed network usage information for a specific configuration"""
        config = self.load_config(config_name)
        if not config:
            self.colorize("red", f"Configuration '{config_name}' not found.", bold=True)
            return
        
        # Check if the VPN interface is up
        interface_status = "DOWN"
        try:
            # Check if the interface exists using ip link
            ifconfig_result = subprocess.run(
                ["ip", "link", "show", config_name],
                capture_output=True,
                text=True
            )
            if ifconfig_result.returncode == 0 and "state UP" in ifconfig_result.stdout:
                interface_status = "UP"
        except Exception:
            pass
        
        # Get network statistics
        stats = self.get_network_stats(config_name)
        
        # Print usage information
        self.colorize("cyan", f"Network Usage for '{config_name}':", bold=True)
        print(f"Interface Status: {interface_status}")
        print(f"Download: {stats['download_human']} ({stats['download']} bytes)")
        print(f"Upload: {stats['upload_human']} ({stats['upload']} bytes)")
        print(f"Total: {self.format_bytes(stats['download'] + stats['upload'])}")
        
        # Show current interface info if it's up
        if interface_status == "UP":
            try:
                # Get IP address information
                ip_result = subprocess.run(
                    ["ip", "addr", "show", config_name],
                    capture_output=True,
                    text=True
                )
                
                if ip_result.returncode == 0:
                    print("\nInterface Details:")
                    
                    # Extract and print IP address
                    import re
                    ip_match = re.search(r"inet\s+([0-9.]+)", ip_result.stdout)
                    if ip_match:
                        print(f"IP Address: {ip_match.group(1)}")
                
                # Try to get some stats like packet loss, latency, etc.
                subnet = config.get('SUBNET', '')
                if subnet:
                    # Determine other end's IP based on config type
                    if config.get('CONFIG_TYPE') == 'server':
                        # Server: Ping the client IP (x.x.x.2)
                        ip_to_ping = f"{subnet.rsplit('.', 1)[0]}.2"
                    else:
                        # Client: Ping the server IP (x.x.x.1)
                        ip_to_ping = f"{subnet.rsplit('.', 1)[0]}.1"
                    
                    print(f"\nConnectivity to {ip_to_ping}:")
                    
                    # Run ping with 3 packets to check latency
                    ping_result = subprocess.run(
                        ["ping", "-c", "3", "-I", config_name, ip_to_ping],
                        capture_output=True,
                        text=True
                    )
                    
                    if ping_result.returncode == 0:
                        # Extract average latency
                        latency_match = re.search(r"min/avg/max.*?= [0-9.]+/([0-9.]+)/[0-9.]+", ping_result.stdout)
                        if latency_match:
                            avg_latency = float(latency_match.group(1))
                            print(f"Latency: {avg_latency:.2f} ms")
                    else:
                        print("Connection failed: No response to ping")
            except Exception as e:
                self.colorize("red", f"Error getting interface details: {str(e)}", bold=False) 
    
    def debug_connection_status(self, config_name: str) -> dict:
        """Get detailed debug information about connection status for diagnostics"""
        debug_info = {
            "interface_exists": False,
            "interface_up": False,
            "has_traffic": False,
            "subnet_found": False,
            "ping_successful": False,
            "ip_to_ping": "N/A",
            "config_type": "N/A",
            "error": None
        }
        
        config = self.load_config(config_name)
        if not config:
            debug_info["error"] = "Configuration not found"
            return debug_info
            
        debug_info["config_type"] = config.get('CONFIG_TYPE', 'unknown')
        
        # Check if interface exists and is UP
        try:
            ifconfig_result = subprocess.run(
                ["ip", "link", "show", config_name],
                capture_output=True,
                text=True
            )
            debug_info["interface_exists"] = ifconfig_result.returncode == 0
            if debug_info["interface_exists"]:
                debug_info["interface_up"] = "state UP" in ifconfig_result.stdout
                
                # Check if there's traffic
                network_stats = self.get_network_stats(config_name)
                debug_info["has_traffic"] = network_stats["download"] > 0 or network_stats["upload"] > 0
                debug_info["rx_bytes"] = network_stats["download"]
                debug_info["tx_bytes"] = network_stats["upload"]
        except Exception as e:
            debug_info["error"] = f"Interface check error: {str(e)}"
        
        # Get subnet information
        subnet = config.get('SUBNET', '')
        debug_info["subnet_found"] = bool(subnet)
        if subnet:
            if config.get('CONFIG_TYPE') == 'server':
                debug_info["ip_to_ping"] = f"{subnet.rsplit('.', 1)[0]}.2"
            else:
                debug_info["ip_to_ping"] = f"{subnet.rsplit('.', 1)[0]}.1"
                
            # Try pinging without interface specification
            try:
                result = subprocess.run(
                    ["ping", "-c", "1", "-W", "2", debug_info["ip_to_ping"]],
                    capture_output=True,
                    text=True
                )
                debug_info["ping_successful"] = result.returncode == 0
                debug_info["ping_output"] = result.stdout
            except Exception as e:
                debug_info["error"] = f"Ping error: {str(e)}"
        
        return debug_info 