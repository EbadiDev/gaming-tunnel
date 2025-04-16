import os
import subprocess
import re
import shutil
from typing import Dict, Optional, List, Tuple

from rich.console import Console
from rich.prompt import Prompt, IntPrompt, Confirm
from rich import print as rich_print


class UDP2Raw:
    def __init__(self):
        self.console = Console()
        self.base_dir = "gamingtunnel"
        self.binary_path = f"{self.base_dir}/udp2raw"
        self.configs_dir = f"{self.base_dir}/configs"
        self.default_tunnel_port = 20002  # Default port as a class variable
        
        # Create configs directory if it doesn't exist
        if not os.path.isdir(self.configs_dir):
            os.makedirs(self.configs_dir, exist_ok=True)
    
    def colorize(self, color, text, bold=False):
        """Print colored text using rich"""
        style = color
        if bold:
            style = f"{color} bold"
        rich_print(f"[{style}]{text}[/{style}]")

    def get_available_configs(self) -> List[dict]:
        """Get a list of available UDP2Raw configurations with their types"""
        if not os.path.exists(self.configs_dir):
            return []
        
        configs = []
        for item in os.listdir(self.configs_dir):
            item_path = os.path.join(self.configs_dir, item)
            if os.path.isdir(item_path):
                # Check for server configuration
                server_config_path = os.path.join(item_path, f"udp2raw_server_config_{item}.conf")
                client_config_path = os.path.join(item_path, f"udp2raw_client_config_{item}.conf")
                
                # If both server and client configs exist with the same name
                if os.path.exists(server_config_path):
                    configs.append({"name": item, "type": "server"})
                
                if os.path.exists(client_config_path):
                    configs.append({"name": item, "type": "client"})
        
        return configs
    
    def load_config(self, config_name: str) -> Dict[str, str]:
        """Load a UDP2Raw configuration from a file"""
        config_path = os.path.join(self.configs_dir, config_name)
        server_config_path = os.path.join(config_path, f"udp2raw_server_config_{config_name}.conf")
        client_config_path = os.path.join(config_path, f"udp2raw_client_config_{config_name}.conf")
        
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
    
    def auto_detect_tinyvpn_port(self, config_name: str) -> Tuple[int, bool]:
        """Try to detect TinyVPN port from an existing TinyVPN config with the same name
        Returns a tuple of (port, was_detected)
        """
        config_path = os.path.join(self.configs_dir, config_name)
        tinyvpn_server_config = os.path.join(config_path, f"server_config_{config_name}.conf")
        tinyvpn_client_config = os.path.join(config_path, f"client_config_{config_name}.conf")
        
        # Check for server config first
        if os.path.exists(tinyvpn_server_config):
            with open(tinyvpn_server_config, 'r') as f:
                for line in f:
                    if line.startswith("PORT="):
                        try:
                            return (int(line.strip().split('=')[1]), True)
                        except:
                            pass
        
        # Then check client config
        if os.path.exists(tinyvpn_client_config):
            with open(tinyvpn_client_config, 'r') as f:
                for line in f:
                    if line.startswith("SERVER_PORT="):
                        try:
                            return (int(line.strip().split('=')[1]), True)
                        except:
                            pass
        
        # Default port if not found, with flag indicating no config was found
        return (self.default_tunnel_port, False)
    
    def configure_server(self):
        """Configure a UDP2Raw server (for non-Iran servers)"""
        self.colorize("cyan", "Creating a new UDP2Raw server configuration", bold=True)
        
        # Get configuration name
        config_name = Prompt.ask("Enter a name for this configuration")
        if not config_name or not re.match(r'^[a-zA-Z0-9_-]+$', config_name):
            self.colorize("red", "Invalid configuration name. Use only letters, numbers, underscores, and hyphens.", bold=True)
            return
        
        # Auto-detect TinyVPN tunnel port
        detected_port, was_detected = self.auto_detect_tinyvpn_port(config_name)
        if was_detected:
            tunnel_port = detected_port
            self.colorize("green", f"Automatically using TinyVPN tunnel port {tunnel_port} from existing configuration", bold=True)
        else:
            # If no matching TinyVPN config is found, ask the user
            tunnel_port = IntPrompt.ask(
                "Enter TinyVPN tunnel port (should match the TinyVPN configuration)", 
                default=detected_port
            )
        
        if tunnel_port < 1 or tunnel_port > 65535:
            self.colorize("red", "Invalid port number. Must be between 1 and 65535.", bold=True)
            return
        
        # Get external UDP port
        external_port = IntPrompt.ask("Enter External UDP port", default=53443)
        if external_port < 1 or external_port > 65535:
            self.colorize("red", "Invalid port number. Must be between 1 and 65535.", bold=True)
            return
        
        # Get password
        password = Prompt.ask("Enter UDP2Raw password", default="hysteria2")
        if not password:
            self.colorize("red", "Password cannot be empty.", bold=True)
            return
        
        # Get raw mode
        raw_mode = Prompt.ask(
            "Select raw mode", 
            choices=["udp", "faketcp", "icmp"], 
            default="faketcp"
        )
        
        # Create config directory if it doesn't exist
        config_dir = os.path.join(self.configs_dir, config_name)
        if not os.path.exists(config_dir):
            os.makedirs(config_dir, exist_ok=True)
        
        # Create server command
        server_cmd = f"-s -l0.0.0.0:{tunnel_port} -r127.0.0.1:{external_port} -a -k \"{password}\" --cipher-mode xor --auth-mode simple --raw-mode {raw_mode}"
        
        # Save configuration
        config_file = os.path.join(config_dir, f"udp2raw_server_config_{config_name}.conf")
        with open(config_file, "w") as f:
            f.write(f"TUNNEL_PORT={tunnel_port}\n")
            f.write(f"EXTERNAL_PORT={external_port}\n")
            f.write(f"PASSWORD={password}\n")
            f.write(f"RAW_MODE={raw_mode}\n")
            f.write(f"COMMAND={server_cmd}\n")
            f.write(f"CONFIG_TYPE=server\n")
        
        # Create systemd service file
        service_file = os.path.join(config_dir, f"udp2raw-{config_name}-server.service")
        with open(service_file, "w") as f:
            f.write(f"""[Unit]
Description=UDP2Raw Server {config_name}
After=network.target
Wants=network.target

[Service]
Type=simple
WorkingDirectory={os.path.abspath(self.base_dir)}
ExecStart={os.path.abspath(self.binary_path)} {server_cmd}
Restart=always
RestartSec=1
LimitNOFILE=infinity

# Logging configuration
StandardOutput=append:/var/log/udp2raw_{config_name}.log
StandardError=append:/var/log/udp2raw_{config_name}.error.log

# Optional: log rotation to prevent huge log files
LogRateLimitIntervalSec=0
LogRateLimitBurst=0

[Install]
WantedBy=multi-user.target
""")
        
        self.colorize("green", f"UDP2Raw server configuration '{config_name}' created successfully!", bold=True)
        
        # Automatically install and start the service
        self.install_service(config_name, service_file)
    
    def configure_client(self):
        """Configure a UDP2Raw client (for Iran servers)"""
        self.colorize("cyan", "Creating a new UDP2Raw client configuration", bold=True)
        
        # Get configuration name
        config_name = Prompt.ask("Enter a name for this configuration")
        if not config_name or not re.match(r'^[a-zA-Z0-9_-]+$', config_name):
            self.colorize("red", "Invalid configuration name. Use only letters, numbers, underscores, and hyphens.", bold=True)
            return
        
        # Auto-detect TinyVPN tunnel port
        detected_port, was_detected = self.auto_detect_tinyvpn_port(config_name)
        if was_detected:
            tunnel_port = detected_port
            self.colorize("green", f"Automatically using TinyVPN tunnel port {tunnel_port} from existing configuration", bold=True)
        else:
            # If no matching TinyVPN config is found, ask the user
            tunnel_port = IntPrompt.ask(
                "Enter TinyVPN tunnel port (should match the TinyVPN configuration)", 
                default=detected_port
            )
        
        if tunnel_port < 1 or tunnel_port > 65535:
            self.colorize("red", "Invalid port number. Must be between 1 and 65535.", bold=True)
            return
        
        # Get external UDP port
        external_port = IntPrompt.ask("Enter UDP external port", default=53443)
        if external_port < 1 or external_port > 65535:
            self.colorize("red", "Invalid port number. Must be between 1 and 65535.", bold=True)
            return
        
        # Get server address
        server_addr = Prompt.ask("Enter remote server IP address", default="10.22.22.2")
        if not server_addr:
            self.colorize("red", "Server address cannot be empty.", bold=True)
            return
        
        # Get password
        password = Prompt.ask("Enter UDP2Raw password", default="hysteria2")
        if not password:
            self.colorize("red", "Password cannot be empty.", bold=True)
            return
        
        # Get raw mode
        raw_mode = Prompt.ask(
            "Select raw mode", 
            choices=["udp", "faketcp", "icmp"], 
            default="faketcp"
        )
        
        # Create config directory if it doesn't exist
        config_dir = os.path.join(self.configs_dir, config_name)
        if not os.path.exists(config_dir):
            os.makedirs(config_dir, exist_ok=True)
        
        # Create client command
        client_cmd = f"-c -l0.0.0.0:{external_port} -r{server_addr}:{tunnel_port} -a -k \"{password}\" --cipher-mode xor --auth-mode simple --raw-mode {raw_mode}"
        
        # Save configuration
        config_file = os.path.join(config_dir, f"udp2raw_client_config_{config_name}.conf")
        with open(config_file, "w") as f:
            f.write(f"TUNNEL_PORT={tunnel_port}\n")
            f.write(f"EXTERNAL_PORT={external_port}\n")
            f.write(f"SERVER_ADDR={server_addr}\n")
            f.write(f"PASSWORD={password}\n")
            f.write(f"RAW_MODE={raw_mode}\n")
            f.write(f"COMMAND={client_cmd}\n")
            f.write(f"CONFIG_TYPE=client\n")
        
        # Create systemd service file
        service_file = os.path.join(config_dir, f"udp2raw-{config_name}-client.service")
        with open(service_file, "w") as f:
            f.write(f"""[Unit]
Description=UDP2Raw Client {config_name}
After=network.target
Wants=network.target

[Service]
Type=simple
WorkingDirectory={os.path.abspath(self.base_dir)}
ExecStart={os.path.abspath(self.binary_path)} {client_cmd}
Restart=always
RestartSec=1
LimitNOFILE=infinity

# Logging configuration
StandardOutput=append:/var/log/udp2raw_{config_name}.log
StandardError=append:/var/log/udp2raw_{config_name}.error.log

# Optional: log rotation to prevent huge log files
LogRateLimitIntervalSec=0
LogRateLimitBurst=0

[Install]
WantedBy=multi-user.target
""")
        
        self.colorize("green", f"UDP2Raw client configuration '{config_name}' created successfully!", bold=True)
        
        # Automatically install and start the service
        self.install_service(config_name, service_file)
    
    def install_service(self, config_name: str, service_file: str) -> bool:
        """Install and start a systemd service"""
        self.colorize("yellow", "Installing and starting service...", bold=True)
        
        # Determine if this is a server or client service based on the service filename
        is_server = "-server.service" in service_file
        is_client = "-client.service" in service_file
        service_type = "server" if is_server else "client" if is_client else ""
        service_name = f"udp2raw-{config_name}-{service_type}"
        
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
                ["sudo", "systemctl", "daemon-reload", "&&", "sudo", "systemctl", "enable", "--now", service_name],
                capture_output=True,
                text=True,
                shell=True  # Using shell=True to support command chaining with &&
            )
            
            if result.returncode != 0:
                self.colorize("red", "Failed to enable and start service. You may need to manually start it.", bold=True)
                self.colorize("cyan", f"sudo systemctl daemon-reload && sudo systemctl enable --now {service_name}", bold=False)
                return False
            
            self.colorize("green", f"Service {service_name} installed and started successfully!", bold=True)
            return True
            
        except Exception as e:
            self.colorize("red", f"Error installing service: {str(e)}", bold=True)
            self.colorize("yellow", "You may need to manually install the service:", bold=True)
            self.colorize("cyan", f"sudo cp {service_file} /etc/systemd/system/", bold=False)
            self.colorize("cyan", f"sudo systemctl daemon-reload && sudo systemctl enable --now {service_name}", bold=False)
            return False
    
    def check_service_status(self):
        """Check status of UDP2Raw services"""
        configs = self.get_available_configs()
        
        if not configs:
            self.colorize("yellow", "No UDP2Raw configurations found", bold=True)
            return
        
        self.colorize("cyan", "Select a configuration to check:", bold=True)
        for i, config in enumerate(configs, 1):
            print(f"{i}. {config['name']} ({config['type']})")
        
        config_idx = IntPrompt.ask("Select a configuration", default=1)
        if 1 <= config_idx <= len(configs):
            config = configs[config_idx - 1]
            config_name = config['name']
            
            try:
                # Get service status
                result = subprocess.run(
                    ["systemctl", "status", f"udp2raw-{config_name}-{config['type']}.service"],
                    capture_output=True,
                    text=True
                )
                
                print(result.stdout)
                
                if result.returncode != 0:
                    self.colorize("yellow", f"Service udp2raw-{config_name}-{config['type']} is not running or not properly installed.", bold=True)
            except Exception as e:
                self.colorize("red", f"Error checking service status: {str(e)}", bold=True)
        else:
            self.colorize("red", "Invalid selection", bold=True)
    
    def view_logs(self):
        """View logs for a UDP2Raw service"""
        configs = self.get_available_configs()
        
        if not configs:
            self.colorize("yellow", "No UDP2Raw configurations found", bold=True)
            return
        
        self.colorize("cyan", "Select a configuration to view logs:", bold=True)
        for i, config in enumerate(configs, 1):
            print(f"{i}. {config['name']} ({config['type']})")
        
        config_idx = IntPrompt.ask("Select a configuration", default=1)
        if 1 <= config_idx <= len(configs):
            config = configs[config_idx - 1]
            config_name = config['name']
            
            try:
                # View logs using journalctl
                result = subprocess.run(
                    ["journalctl", "-u", f"udp2raw-{config_name}-{config['type']}.service", "--no-pager", "-n", "100"],
                    capture_output=True,
                    text=True
                )
                
                print(result.stdout)
            except Exception as e:
                self.colorize("red", f"Error viewing logs: {str(e)}", bold=True)
                
                # Alternative method using log files
                self.colorize("yellow", "Trying to read log files directly...", bold=True)
                try:
                    with open(f"/var/log/udp2raw_{config_name}.log", "r") as f:
                        print(f.read())
                except:
                    self.colorize("red", "Failed to read log files.", bold=True)
        else:
            self.colorize("red", "Invalid selection", bold=True)
    
    def restart_service(self):
        """Restart a UDP2Raw service"""
        configs = self.get_available_configs()
        
        if not configs:
            self.colorize("yellow", "No UDP2Raw configurations found", bold=True)
            return
        
        self.colorize("cyan", "Select a configuration to restart:", bold=True)
        for i, config in enumerate(configs, 1):
            print(f"{i}. {config['name']} ({config['type']})")
        
        config_idx = IntPrompt.ask("Select a configuration", default=1)
        if 1 <= config_idx <= len(configs):
            config = configs[config_idx - 1]
            config_name = config['name']
            
            try:
                # Restart service
                result = subprocess.run(
                    ["sudo", "systemctl", "restart", f"udp2raw-{config_name}-{config['type']}.service"],
                    capture_output=True,
                    text=True
                )
                
                if result.returncode == 0:
                    self.colorize("green", f"Service udp2raw-{config_name}-{config['type']} restarted successfully!", bold=True)
                else:
                    self.colorize("red", f"Failed to restart service: {result.stderr}", bold=True)
            except Exception as e:
                self.colorize("red", f"Error restarting service: {str(e)}", bold=True)
        else:
            self.colorize("red", "Invalid selection", bold=True)
    
    def remove_service(self, config_name=None, config_type=None):
        """Remove a UDP2Raw service and configuration"""
        configs = self.get_available_configs()
        
        if not configs:
            self.colorize("yellow", "No UDP2Raw configurations found", bold=True)
            return
        
        # Select configuration interactively if not specified
        if config_name is None or config_type is None:
            self.colorize("cyan", "Select a configuration to remove:", bold=True)
            for i, config in enumerate(configs, 1):
                print(f"{i}. {config['name']} ({config['type']})")
            
            config_idx = IntPrompt.ask("Select a configuration", default=1)
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
                # Stop and disable service if it exists
                subprocess.run(
                    ["systemctl", "stop", f"udp2raw-{config_name}-{config_type}.service"],
                    capture_output=True,
                    text=True
                )
                
                subprocess.run(
                    ["systemctl", "disable", f"udp2raw-{config_name}-{config_type}.service"],
                    capture_output=True,
                    text=True
                )
                
                # Remove service file if it exists
                service_path = f"/etc/systemd/system/udp2raw-{config_name}-{config_type}.service"
                if os.path.exists(service_path):
                    os.remove(service_path)
                    subprocess.run(["systemctl", "daemon-reload"], capture_output=True)
                
                # Remove configuration files
                config_path = os.path.join(self.configs_dir, config_name)
                if os.path.exists(config_path):
                    # If we're only removing one type of config (server or client) but both exist,
                    # we need to be careful not to delete the entire directory
                    server_config = os.path.join(config_path, f"udp2raw_server_config_{config_name}.conf")
                    client_config = os.path.join(config_path, f"udp2raw_client_config_{config_name}.conf")
                    tinyvpn_server_config = os.path.join(config_path, f"server_config_{config_name}.conf")
                    tinyvpn_client_config = os.path.join(config_path, f"client_config_{config_name}.conf")
                    
                    # Only remove the specific UDP2Raw config file if TinyVPN configs exist or both UDP2Raw types exist
                    if (os.path.exists(tinyvpn_server_config) or os.path.exists(tinyvpn_client_config) or 
                        (os.path.exists(server_config) and os.path.exists(client_config))):
                        
                        if config_type == "server" and os.path.exists(server_config):
                            os.remove(server_config)
                            self.colorize("green", f"UDP2Raw server configuration for '{config_name}' removed.", bold=True)
                        elif config_type == "client" and os.path.exists(client_config):
                            os.remove(client_config)
                            self.colorize("green", f"UDP2Raw client configuration for '{config_name}' removed.", bold=True)
                    else:
                        # Remove the entire directory only if no TinyVPN configs exist
                        if not (os.path.exists(tinyvpn_server_config) or os.path.exists(tinyvpn_client_config)):
                            shutil.rmtree(config_path)
                            self.colorize("green", f"Configuration directory for '{config_name}' removed completely.", bold=True)
                
                self.colorize("green", f"UDP2Raw {config_type} configuration '{config_name}' removed successfully.", bold=True)
            except Exception as e:
                self.colorize("red", f"Error removing configuration: {str(e)}", bold=True) 