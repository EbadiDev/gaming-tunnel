import time
import os
import platform
import requests
import json
import socket
import subprocess
from typing import Optional, List, Dict

import typer
from rich.progress import track, Progress, SpinnerColumn, TextColumn
from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.prompt import Prompt, IntPrompt
from rich.box import ROUNDED
from rich import print as rich_print

from tinyvpn import TinyVPN
from udp2raw import UDP2Raw


class GamingTunnel:
    def __init__(self):
        self.tinyvpn = TinyVPN()
        self.udp2raw = UDP2Raw()
        self.console = Console()
        self.dest_dir = "/root/gamingtunnel"
        self.config_dir = "/root/gamingtunnel"
        self.tinyvpn_file = "/root/gamingtunnel/tinyvpn"
        self.udp2raw_file = "/root/gamingtunnel/udp2raw"
        self.url_x86 = "https://github.com/ebadidev/gaming-tunnel/raw/main/core/tinyvpn_amd64"
        self.url_arm = "https://github.com/ebadidev/gaming-tunnel/raw/main/core/tinyvpn_arm"
        self.url_udp2raw = "https://github.com/ebadidev/gaming-tunnel/raw/main/core/udp2raw_amd64"
        self.url_udp2raw_arm = "https://github.com/ebadidev/gaming-tunnel/raw/main/core/udp2raw_arm"
        self.tinyvpn_installed = self.check_tinyvpn_installed()
        self.udp2raw_installed = self.check_udp2raw_installed()
        self.cores_installed = self.tinyvpn_installed and self.udp2raw_installed
        
        # Server info cache
        self.server_info_cache = None
        self.server_info_cache_time = 0
        self.server_info_cache_ttl = 3600  # Extend cache TTL to 1 hour
        self.skip_server_info = False  # New flag to optionally skip server info display

    def check_tinyvpn_installed(self):
        """Check if TinyVPN core is installed"""
        return os.path.isfile(self.tinyvpn_file)
        
    def check_udp2raw_installed(self):
        """Check if UDP2RAW core is installed"""
        return os.path.isfile(self.udp2raw_file)

    def check_cores_installed(self):
        """Check if both cores are installed"""
        return self.check_tinyvpn_installed() and self.check_udp2raw_installed()

    def colorize(self, color, text, bold=False):
        """Print colored text using rich"""
        style = color
        if bold:
            style = f"{color} bold"
        rich_print(f"[{style}]{text}[/{style}]")

    def install_dependencies(self):
        """Install TinyVPN and UDP2RAW binaries based on system architecture"""
        print()  # Empty line
        
        # Check if files already exist
        if self.check_cores_installed():
            self.colorize("green", "All cores installed already.", bold=True)
            self.tinyvpn_installed = True
            self.udp2raw_installed = True
            self.cores_installed = True
            return False
        
        # Create directory if it doesn't exist
        if not os.path.isdir(self.dest_dir):
            os.makedirs(self.dest_dir, exist_ok=True)
        
        # Detect system architecture
        arch = platform.machine()
        if arch == "x86_64":
            url = self.url_x86
            udp2raw_url = self.url_udp2raw
        elif arch in ["armv7l", "aarch64"]:
            url = self.url_arm
            udp2raw_url = self.url_udp2raw_arm
        else:
            self.colorize("red", f"Unsupported architecture: {arch}", bold=True)
            time.sleep(2)
            return False
        
        tinyvpn_success = False
        udp2raw_success = False
        
        # Use Rich's Progress for installation feedback
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            transient=False,
        ) as progress:
            # Download and install TinyVPN
            tinyvpn_task = progress.add_task(description="Installing TinyVPN Core...", total=None)
            try:
                response = requests.get(url)
                with open(self.tinyvpn_file, 'wb') as f:
                    f.write(response.content)
                os.chmod(self.tinyvpn_file, 0o755)  # Equivalent to chmod +x
                tinyvpn_success = True
                self.tinyvpn_installed = True
                progress.update(tinyvpn_task, description="TinyVPN Core installed successfully")
            except Exception:
                progress.update(tinyvpn_task, description="TinyVPN Core installation failed")
                tinyvpn_success = False
                self.tinyvpn_installed = False
            
            # Download and install UDP2RAW
            udp2raw_task = progress.add_task(description="Installing UDP2RAW...", total=None)
            try:
                response = requests.get(udp2raw_url)
                with open(self.udp2raw_file, 'wb') as f:
                    f.write(response.content)
                os.chmod(self.udp2raw_file, 0o755)  # Equivalent to chmod +x
                udp2raw_success = True
                self.udp2raw_installed = True
                progress.update(udp2raw_task, description="UDP2RAW installed successfully")
            except Exception:
                progress.update(udp2raw_task, description="UDP2RAW installation failed")
                udp2raw_success = False
                self.udp2raw_installed = False
            
            # Update overall installation status
            self.cores_installed = self.tinyvpn_installed and self.udp2raw_installed
            
            # Give the user time to see the final status
            time.sleep(1)
        
        # Check installation results and report
        if tinyvpn_success and udp2raw_success:
            self.colorize("green", "TinyVPN core and UDP2RAW installed successfully...", bold=True)
            return True
        elif tinyvpn_success:
            self.colorize("yellow", "TinyVPN core installed but UDP2RAW installation failed...", bold=True)
            return True
        elif udp2raw_success:
            self.colorize("yellow", "UDP2RAW installed but TinyVPN core installation failed...", bold=True)
            return False
        else:
            self.colorize("red", "Failed to install components...", bold=True)
            return False

    def get_server_info(self) -> Dict[str, str]:
        """Fetch server information including IP, location, and datacenter"""
        # Return cached server info if it's still valid
        current_time = time.time()
        if self.server_info_cache and (current_time - self.server_info_cache_time) < self.server_info_cache_ttl:
            return self.server_info_cache
        
        info = {}
        
        # Get IPv4 address with a shorter timeout
        try:
            info["ipv4"] = requests.get("https://api.ipify.org", timeout=2).text
        except Exception:
            info["ipv4"] = "Unknown"
        
        # Get IPv6 address if available with a shorter timeout
        try:
            info["ipv6"] = requests.get("https://api6.ipify.org", timeout=2).text
        except Exception:
            info["ipv6"] = None
        
        # Get location and datacenter information with a shorter timeout
        try:
            response = requests.get(f"http://ipwhois.app/json/{info['ipv4']}", timeout=2)
            data = response.json()
            info["country"] = data.get("country", "Unknown")
            info["isp"] = data.get("isp", "Unknown")
            info["region"] = data.get("region", "Unknown")
            info["city"] = data.get("city", "Unknown")
        except Exception:
            info["country"] = "Unknown"
            info["isp"] = "Unknown"
            info["region"] = "Unknown"
            info["city"] = "Unknown"
        
        # Update cache
        self.server_info_cache = info
        self.server_info_cache_time = current_time
        
        return info

    def display_status(self, force_refresh=False):
        """Display server status information"""
        # If skip_server_info is True and we're not forcing a refresh, return early
        if self.skip_server_info and not force_refresh:
            return
            
        if force_refresh:
            # Reset cache time to force refresh
            self.server_info_cache_time = 0
            
        info = self.get_server_info()
        
        table = Table(show_header=False, box=None)
        table.add_column("Property", style="green")
        table.add_column("Value", style="yellow")
        
        table.add_row("IPv4", info["ipv4"])
        if info["ipv6"]:
            table.add_row("IPv6", info["ipv6"])
        table.add_row("Location", f"{info['city']}, {info['region']}, {info['country']}")
        table.add_row("Datacenter", info["isp"])
        
        self.console.print(Panel(table, title="Server Information", border_style="cyan"))

    def create_config(self):
        """Create a new configuration"""
        if not self.cores_installed:
            self.colorize("red", "Core components not installed. Please install them first.", bold=True)
            return
        
        self.console.clear()
        
        # Config menu
        menu = Table(show_header=True, box=None)
        menu.add_column("Option", style="cyan", justify="center")
        menu.add_column("Description", style="green")
        
        menu.add_row("1", "Configure TinyVPN Server")
        menu.add_row("2", "Configure TinyVPN Client")
        menu.add_row("3", "Configure UDP2RAW Server")
        menu.add_row("4", "Configure UDP2RAW Client")
        menu.add_row("0", "Return to main menu")
        
        self.console.print(Panel(menu, title="Configuration Menu", border_style="cyan"))
        
        choice = Prompt.ask("Enter your choice", choices=["0", "1", "2", "3", "4"], default="0")
        
        if choice == "1":
            self.tinyvpn.configure_server()
        elif choice == "2":
            self.tinyvpn.configure_client()
        elif choice == "3":
            self.udp2raw.configure_server()
        elif choice == "4":
            self.udp2raw.configure_client()
        elif choice == "0":
            return

    def list_configs(self):
        """List all existing configurations"""
        if not self.cores_installed:
            self.colorize("red", "Core components not installed. Please install them first.", bold=True)
            return

        self.console.clear()
        
        # Get TinyVPN configurations
        tinyvpn_configs = self.tinyvpn.get_available_configs()
        
        # Get UDP2Raw configurations
        udp2raw_configs = self.udp2raw.get_available_configs()
        
        if not tinyvpn_configs and not udp2raw_configs:
            self.colorize("yellow", "No configurations found", bold=True)
            return
        
        while True:
            self.console.clear()
            
            # Display configurations
            table = Table(show_header=True)
            table.add_column("Name", style="cyan")
            table.add_column("Type", style="green")
            table.add_column("Status", style="yellow")
            table.add_column("Connection", style="magenta")
            table.add_column("↓ Download", style="blue")
            table.add_column("↑ Upload", style="red")
            
            # Add TinyVPN configs to the table
            for config in tinyvpn_configs:
                config_name = config['name']
                config_type = "TinyVPN Server" if config['type'] == "server" else "TinyVPN Client"
                
                # Check if service is active
                try:
                    service_suffix = "server" if config['type'] == "server" else "client"
                    result = subprocess.run(
                        ["systemctl", "is-active", f"tinyvpn-{config_name}-{service_suffix}.service"],
                        capture_output=True,
                        text=True
                    )
                    status = "[green]Active[/green]" if result.stdout.strip() == "active" else "[red]Inactive[/red]"
                except:
                    status = "[gray]Unknown[/gray]"
                
                # Check connection status
                connection_status = "[green]Online[/green]" if self.tinyvpn.check_connection(config_name) else "[red]Offline[/red]"
                
                # Get network statistics
                network_stats = self.tinyvpn.get_network_stats(config_name)
                download = network_stats["download_human"]
                upload = network_stats["upload_human"]
                
                # If there's traffic, mark as connected regardless of ping result
                if network_stats["download"] > 0 or network_stats["upload"] > 0:
                    connection_status = "[green]Online[/green]"
                    
                table.add_row(config_name, config_type, status, connection_status, download, upload)
            
            # Add UDP2Raw configs to the table
            for config in udp2raw_configs:
                config_name = config['name']
                config_type = "UDP2Raw Server" if config['type'] == "server" else "UDP2Raw Client"
                
                # Check if service is active
                try:
                    service_suffix = "server" if config['type'] == "server" else "client"
                    result = subprocess.run(
                        ["systemctl", "is-active", f"udp2raw-{config_name}-{service_suffix}.service"],
                        capture_output=True,
                        text=True
                    )
                    status = "[green]Active[/green]" if result.stdout.strip() == "active" else "[red]Inactive[/red]"
                except:
                    status = "[gray]Unknown[/gray]"
                
                # UDP2Raw doesn't have built-in connection checking or stats like TinyVPN
                connection_status = "[gray]N/A[/gray]"
                download = "N/A"
                upload = "N/A"
                
                table.add_row(config_name, config_type, status, connection_status, download, upload)
            
            self.console.print(Panel(table, title="Available Configurations", border_style="cyan"))
            
            # Display actions menu
            action_menu = Table(show_header=True, box=None)
            action_menu.add_column("Option", style="cyan", justify="center")
            action_menu.add_column("Action", style="green")
            
            action_menu.add_row("1", "Select a configuration to view/modify")
            action_menu.add_row("2", "Delete a configuration")
            action_menu.add_row("3", "Refresh connection status")
            action_menu.add_row("4", "View detailed network statistics")
            action_menu.add_row("5", "Run connection diagnostics")
            action_menu.add_row("0", "Return to main menu")
            
            self.console.print(Panel(action_menu, title="Configuration Actions", border_style="cyan"))
            
            # Get user choice
            choice = Prompt.ask("Select an action", choices=["0", "1", "2", "3", "4", "5"], default="0")
            
            if choice == "0":
                return
                
            elif choice == "1":
                # Select a configuration to view/modify
                self.colorize("cyan", "Available configurations:", bold=True)
                
                # Combine configs for selection, keeping track of their type
                all_configs = []
                for config in tinyvpn_configs:
                    all_configs.append({
                        'name': config['name'],
                        'type': config['type'],
                        'service': 'tinyvpn'
                    })
                for config in udp2raw_configs:
                    all_configs.append({
                        'name': config['name'],
                        'type': config['type'],
                        'service': 'udp2raw'
                    })
                
                for i, config in enumerate(all_configs, 1):
                    service_name = "TinyVPN" if config['service'] == 'tinyvpn' else "UDP2Raw"
                    print(f"{i}. {config['name']} ({service_name} {config['type']})")
                
                config_idx = IntPrompt.ask("Select a configuration", default=1)
                if 1 <= config_idx <= len(all_configs):
                    selected_config = all_configs[config_idx - 1]
                    config_name = selected_config['name']
                    config_type = selected_config['type']
                    service = selected_config['service']
                    
                    # Display configuration details based on service type
                    if service == 'tinyvpn':
                        config_data = self.tinyvpn.load_config(config_name)
                        service_display = "TinyVPN"
                    else:  # udp2raw
                        config_data = self.udp2raw.load_config(config_name)
                        service_display = "UDP2Raw"
                    
                    if config_data:
                        self.console.clear()
                        self.colorize("cyan", f"Configuration details for '{config_name}' ({service_display} {config_type}):", bold=True)
                        for key, value in config_data.items():
                            if key != "COMMAND":  # Skip the long command string
                                print(f"{key}: {value}")
                        
                        # Ask if user wants to modify
                        if Prompt.ask("Do you want to modify this configuration?", choices=["y", "n"], default="n") == "y":
                            if service == 'tinyvpn':
                                if config_type == "server":
                                    self.tinyvpn.modify_server_config(config_name)
                                else:
                                    self.colorize("yellow", "TinyVPN client configuration modification is not implemented yet.", bold=True)
                            else:  # udp2raw
                                self.colorize("yellow", "UDP2Raw configuration modification is not implemented yet.", bold=True)
                    else:
                        self.colorize("red", f"Failed to load configuration for '{config_name}'", bold=True)
                else:
                    self.colorize("red", "Invalid selection", bold=True)
                
                input("\nPress Enter to continue...")
                
            elif choice == "2":
                # Delete a configuration
                self.colorize("cyan", "Available configurations:", bold=True)
                
                # Combine configs for selection, keeping track of their type
                all_configs = []
                for config in tinyvpn_configs:
                    all_configs.append({
                        'name': config['name'],
                        'type': config['type'],
                        'service': 'tinyvpn'
                    })
                for config in udp2raw_configs:
                    all_configs.append({
                        'name': config['name'],
                        'type': config['type'],
                        'service': 'udp2raw'
                    })
                
                for i, config in enumerate(all_configs, 1):
                    service_name = "TinyVPN" if config['service'] == 'tinyvpn' else "UDP2Raw"
                    print(f"{i}. {config['name']} ({service_name} {config['type']})")
                
                config_idx = IntPrompt.ask("Select a configuration to delete", default=1)
                if 1 <= config_idx <= len(all_configs):
                    selected_config = all_configs[config_idx - 1]
                    config_name = selected_config['name']
                    config_type = selected_config['type']
                    service = selected_config['service']
                    service_display = "TinyVPN" if service == 'tinyvpn' else "UDP2Raw"
                    
                    from rich.prompt import Confirm
                    if Confirm.ask(f"Are you sure you want to delete the {service_display} {config_type} configuration '{config_name}'?"):
                        try:
                            # Call the appropriate remove_service method based on service type
                            if service == 'tinyvpn':
                                self.tinyvpn.remove_service(config_name, config_type)
                                tinyvpn_configs = self.tinyvpn.get_available_configs()
                            else:  # udp2raw
                                self.udp2raw.remove_service(config_name, config_type)
                                udp2raw_configs = self.udp2raw.get_available_configs()
                            
                            # Check if all configurations have been deleted
                            if not tinyvpn_configs and not udp2raw_configs:
                                self.colorize("green", "All configurations have been deleted.", bold=True)
                                input("\nPress Enter to continue...")
                                return
                        except Exception as e:
                            self.colorize("red", f"Error deleting configuration: {str(e)}", bold=True)
                            input("\nPress Enter to continue...")
                else:
                    self.colorize("red", "Invalid selection", bold=True)
                    input("\nPress Enter to continue...")
            
            elif choice == "3":
                # Refresh connection status - just continue the loop to refresh the display
                self.colorize("cyan", "Refreshing connection status...", bold=True)
                time.sleep(1)  # Give a small delay to show the message
                
            elif choice == "4":
                # View detailed network statistics
                self.colorize("cyan", "Available configurations:", bold=True)
                
                # For network stats, we only include TinyVPN configs as UDP2Raw doesn't provide this
                for i, config in enumerate(tinyvpn_configs, 1):
                    print(f"{i}. {config['name']} ({config['type']})")
                
                if not tinyvpn_configs:
                    self.colorize("yellow", "No TinyVPN configurations available for network statistics.", bold=True)
                    input("\nPress Enter to continue...")
                    continue
                
                config_idx = IntPrompt.ask("Select a configuration to view network statistics", default=1)
                if 1 <= config_idx <= len(tinyvpn_configs):
                    config_name = tinyvpn_configs[config_idx - 1]['name']
                    self.console.clear()
                    self.tinyvpn.show_network_usage(config_name)
                else:
                    self.colorize("red", "Invalid selection", bold=True)
                
                input("\nPress Enter to continue...")
                
            elif choice == "5":
                # Run connection diagnostics
                self.colorize("cyan", "Available configurations:", bold=True)
                
                # For diagnostics, we only include TinyVPN configs
                for i, config in enumerate(tinyvpn_configs, 1):
                    print(f"{i}. {config['name']} ({config['type']})")
                
                if not tinyvpn_configs:
                    self.colorize("yellow", "No TinyVPN configurations available for diagnostics.", bold=True)
                    input("\nPress Enter to continue...")
                    continue
                
                config_idx = IntPrompt.ask("Select a configuration to run diagnostics", default=1)
                if 1 <= config_idx <= len(tinyvpn_configs):
                    config_name = tinyvpn_configs[config_idx - 1]['name']
                    self.console.clear()
                    
                    # Run detailed diagnostics
                    self.colorize("cyan", f"Running connection diagnostics for '{config_name}'...", bold=True)
                    debug_info = self.tinyvpn.debug_connection_status(config_name)
                    
                    # Display diagnostics in a readable format
                    print(f"\nConfiguration Type: {debug_info['config_type']}")
                    print(f"Interface exists: {'✅' if debug_info['interface_exists'] else '❌'}")
                    if debug_info['interface_exists']:
                        print(f"Interface is UP: {'✅' if debug_info['interface_up'] else '❌'}")
                        print(f"Has traffic: {'✅' if debug_info['has_traffic'] else '❌'}")
                        print(f"Received bytes: {debug_info['rx_bytes']}")
                        print(f"Transmitted bytes: {debug_info['tx_bytes']}")
                    
                    print(f"Subnet found: {'✅' if debug_info['subnet_found'] else '❌'}")
                    if debug_info['subnet_found']:
                        print(f"Remote IP to ping: {debug_info['ip_to_ping']}")
                        print(f"Ping successful: {'✅' if debug_info['ping_successful'] else '❌'}")
                        
                        if 'ping_output' in debug_info:
                            print("\nPing output:")
                            print(debug_info['ping_output'])
                    
                    if debug_info['error']:
                        self.colorize("red", f"\nError: {debug_info['error']}", bold=True)
                    
                    # Add manual detection instructions
                    print("\nManual connection verification:")
                    print(f"1. Try direct ping: ping {debug_info['ip_to_ping']}")
                    print(f"2. Check interface: ip link show {config_name}")
                    print(f"3. Check routing: ip route | grep {config_name}")
                    print(f"4. Check service: sudo systemctl status tinyvpn-{config_name}-{debug_info['config_type']}.service")
                    
                    # Connection status determination
                    if debug_info['interface_exists'] and debug_info['interface_up']:
                        if debug_info['has_traffic'] or debug_info['ping_successful']:
                            self.colorize("green", "\nDiagnosis: Connection appears to be WORKING properly", bold=True)
                            if not debug_info['ping_successful']:
                                self.colorize("yellow", "Note: Ping failed but traffic is flowing, which suggests the connection is still functional", bold=True)
                        else:
                            self.colorize("yellow", "\nDiagnosis: Interface is up but no traffic or ping response detected", bold=True)
                            self.colorize("yellow", "The tunnel may be partially working. Try manually pinging or using the connection.", bold=True)
                    else:
                        self.colorize("red", "\nDiagnosis: Connection is DOWN or not established correctly", bold=True)
                else:
                    self.colorize("red", "Invalid selection", bold=True)
                
                input("\nPress Enter to continue...")

    def service_menu(self, show_status=False):
        """Show service management menu"""
        if not self.cores_installed:
            self.colorize("red", "Core components not installed. Please install them first.", bold=True)
            return
        
        self.console.clear()
        
        # Optionally display server information
        if show_status:
            self.display_status()
        
        # Service menu
        menu = Table(show_header=True, box=None)
        menu.add_column("Option", style="cyan", justify="center")
        menu.add_column("Description", style="green")
        
        menu.add_row("1", "Check TinyVPN Service Status")
        menu.add_row("2", "View TinyVPN Logs")
        menu.add_row("3", "Restart TinyVPN Service")
        menu.add_row("4", "Remove TinyVPN Service")
        menu.add_row("5", "Check UDP2RAW Service Status")
        menu.add_row("6", "View UDP2RAW Logs")
        menu.add_row("7", "Restart UDP2RAW Service")
        menu.add_row("8", "Remove UDP2RAW Service")
        menu.add_row("9", "Update Server Information")
        menu.add_row("0", "Return to main menu")
        
        self.console.print(Panel(menu, title="Service Management", border_style="cyan"))
        
        choice = Prompt.ask("Enter your choice", choices=["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"], default="0")
        
        if choice == "1":
            self.tinyvpn.check_service_status()
        elif choice == "2":
            self.tinyvpn.view_logs()
        elif choice == "3":
            self.tinyvpn.restart_service()
        elif choice == "4":
            self.tinyvpn.remove_service()
        elif choice == "5":
            self.udp2raw.check_service_status()
        elif choice == "6":
            self.udp2raw.view_logs()
        elif choice == "7":
            self.udp2raw.restart_service()
        elif choice == "8":
            self.udp2raw.remove_service()
        elif choice == "9":
            self.display_status(force_refresh=True)
            input("\nPress Enter to continue...")
            self.service_menu(show_status=True)
            return
        elif choice == "0":
            return

    def restart_configs(self):
        """Restart all configurations"""
        if not self.cores_installed:
            self.colorize("red", "Core components not installed. Please install them first.", bold=True)
            return
        
        self.colorize("yellow", "Restarting all configurations...", bold=True)
        
        # Get TinyVPN configurations
        tinyvpn_configs = self.tinyvpn.get_available_configs()
        
        # Get UDP2Raw configurations
        udp2raw_configs = self.udp2raw.get_available_configs()
        
        if not tinyvpn_configs and not udp2raw_configs:
            self.colorize("yellow", "No configurations found to restart", bold=True)
            return
        
        # Restart each service
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            transient=False,
        ) as progress:
            restart_task = progress.add_task(description="Restarting services...", total=None)
            
            # Restart TinyVPN services
            for config in tinyvpn_configs:
                service_suffix = "server" if config['type'] == "server" else "client"
                progress.update(restart_task, description=f"Restarting tinyvpn-{config['name']}-{service_suffix} service...")
                try:
                    subprocess.run(
                        ["systemctl", "restart", f"tinyvpn-{config['name']}-{service_suffix}.service"],
                        capture_output=True,
                        text=True
                    )
                except:
                    pass
                time.sleep(0.5)
            
            # Restart UDP2Raw services
            for config in udp2raw_configs:
                service_suffix = "server" if config['type'] == "server" else "client"
                progress.update(restart_task, description=f"Restarting udp2raw-{config['name']}-{service_suffix} service...")
                try:
                    subprocess.run(
                        ["systemctl", "restart", f"udp2raw-{config['name']}-{service_suffix}.service"],
                        capture_output=True,
                        text=True
                    )
                except:
                    pass
                time.sleep(0.5)
            
            progress.update(restart_task, description="All services restarted")
            time.sleep(1)
        
        self.colorize("green", "All configurations restarted successfully", bold=True)

    def show_menu(self):
        """Show main menu"""
        self.console.clear()
        
        # Set skip_server_info to False for the main menu, we want to see server info here
        self.skip_server_info = False
        
        # Server information
        self.display_status()
        
        # Display installed components
        components = Table(show_header=False, box=None)
        components.add_column("Component", style="cyan")
        components.add_column("Status", style="green")
        
        components.add_row("TinyVPN", "Installed ✓" if self.tinyvpn_installed else "Not Installed ✗")
        components.add_row("UDP2RAW", "Installed ✓" if self.udp2raw_installed else "Not Installed ✗")
        
        self.console.print(Panel(components, title="Components", border_style="cyan"))
        
        # Main menu
        menu = Table(show_header=True, box=None)
        menu.add_column("Option", style="cyan", justify="center")
        menu.add_column("Description", style="green")
        
        if not self.cores_installed:
            menu.add_row("1", "Install Core Components")
        menu.add_row("2", "Configuration Management")
        menu.add_row("3", "Service Management")
        menu.add_row("4", "Network Statistics")
        menu.add_row("0", "Exit")
        
        self.console.print(Panel(menu, title="Main Menu", border_style="cyan"))
        
        choices = ["0", "2", "3", "4"]
        if not self.cores_installed:
            choices.append("1")
        
        choice = Prompt.ask("Enter your choice", choices=choices, default="0")
        
        # Set the skip_server_info flag to True for sub-menus to make them load faster
        self.skip_server_info = True
        
        if choice == "1" and not self.cores_installed:
            self.install_dependencies()
            self.show_menu()
        elif choice == "2":
            self.create_config()
            self.show_menu()
        elif choice == "3":
            self.service_menu()  # No need to show status by default, making it faster
            self.show_menu()
        elif choice == "4":
            self.network_stats()
            self.show_menu()
        elif choice == "0":
            self.console.clear()
            self.console.print(Panel("Thank you for using [green]Gaming Tunnel[/green]!", border_style="cyan"))
            sys.exit(0)

    def remove_all_services(self):
        pass

    def remove_core(self):
        """Remove TinyVPN and UDP2RAW cores"""
        if not self.tinyvpn_installed and not self.udp2raw_installed:
            self.colorize("yellow", "No core components are installed.", bold=True)
            return
            
        self.colorize("yellow", "Removing core components...", bold=True)
        
        try:
            if os.path.exists(self.tinyvpn_file):
                os.remove(self.tinyvpn_file)
                self.colorize("green", "TinyVPN core removed.", bold=True)
            
            if os.path.exists(self.udp2raw_file):
                os.remove(self.udp2raw_file)
                self.colorize("green", "UDP2RAW core removed.", bold=True)
                
            self.tinyvpn_installed = False
            self.udp2raw_installed = False
            self.cores_installed = False
            self.colorize("green", "All core components removed successfully.", bold=True)
        except Exception as e:
            self.colorize("red", f"Failed to remove core components: {str(e)}", bold=True)

    def create_symlink(self):
        """Create a symlink for the Gaming Tunnel"""
    pass
    
    
def main():
    app = GamingTunnel()
    # Only try to install if not already installed
    if not app.cores_installed:
        app.install_dependencies()
    app.show_menu()


if __name__ == "__main__":
    typer.run(main)