# Gaming Tunnel

A specialized VPN solution optimized for online gaming with low latency, packet loss reduction, and network optimization features.

## Features

- **Forward Error Correction (FEC)**: Recovers lost packets without retransmission to reduce lag spikes
- **MTU Optimization**: Configure Maximum Transmission Unit for optimal packet size
- **Gaming Mode**: Special mode optimized for real-time gaming traffic patterns
- **UDP2RAW Integration**: Encapsulates UDP traffic in TCP, ICMP, or fake-TCP packets to bypass network restrictions
- **Cross-platform**: Supports both x86_64 and ARM architectures
- **Systemd Service Management**: Easy to manage with systemd service configuration
- **Modern Python Environment**: Uses uv package manager for fast, reliable dependency management

## Requirements

- Linux-based operating system
- Root access
- Git (for repository cloning)
- Python 3.x

## Installation

You can install and run Gaming Tunnel with a single command:

```bash
sudo bash <(curl -Ls https://raw.githubusercontent.com/ebadidev/gaming-tunnel/main/run.sh)
```

This command will:
1. Clone the repository to `/root/gamingtunnel/src/`
2. Create the installation directory at `/root/gamingtunnel/`
3. Install the `uv` package manager if not already installed
4. Set up a Python virtual environment
5. Install all required dependencies
6. Launch the application

## Directory Structure

After installation, Gaming Tunnel uses the following directory structure:
- `/root/gamingtunnel/src/` - Repository code location
- `/root/gamingtunnel/` - Main installation directory
- `/root/gamingtunnel/tinyvpn` - The core TinyVPN binary
- `/root/gamingtunnel/udp2raw` - The UDP2RAW binary for traffic encapsulation
- `/root/gamingtunnel/configs/` - Configuration files for your tunnels

## Usage

### Server Configuration

1. Run the application and select option 1 (`Create a new configuration`)
2. Select "Configure TinyVPN Server" and follow the prompts:
   - Tunnel Port (default: 20002)
   - FEC Value (Forward Error Correction, format: x:y, default: 2:4)
   - Subnet Address (default: 10.22.23.0)
   - Mode (0 for non-game usage, 1 for game usage)
   - MTU Value (default: 1450)
3. Optionally configure UDP2RAW server:
   - Select "Configure UDP2RAW Server"
   - Enter TinyVPN tunnel port (should match the TinyVPN configuration)
   - Configure External UDP port
   - Set password and raw mode (faketcp, udp, icmp)

### Client Configuration

1. Run the application and select option 1 (`Create a new configuration`)
2. Select "Configure TinyVPN Client" and follow the prompts:
   - Server IP address
   - Server port (must match server port)
   - FEC Value (should match server settings for best results)
   - Subnet Address (must match server subnet)
   - Mode (should match server settings)
   - MTU Value (should match server settings)
3. Optionally configure UDP2RAW client:
   - Select "Configure UDP2RAW Client"
   - Enter TinyVPN tunnel port
   - Configure External UDP port
   - Enter the server IP address
   - Set password and raw mode (must match server settings)

### Management

The application provides several management options:
- **List configurations**: View all TinyVPN and UDP2RAW configurations
- **Service management**: Check status, view logs, restart or remove services
- **Restart all services**: Restart all configured services at once
- **Remove core components**: Delete the Gaming Tunnel installation files

## Technical Details

### FEC (Forward Error Correction)

The FEC feature uses a x:y format where:
- x: the number of redundant packets
- y: the number of original packets

For example, with FEC 2:4, for every 4 original packets, 2 redundant packets are generated, allowing recovery from up to 2 packet losses in that group.

#### Recommended FEC Settings

- **For non-gaming usage** (video, downloading, web browsing): `-f20:10` with `timeout 0`
  - Higher redundancy for better reliability with less time-sensitive data
- **For gaming usage** (low latency): `-f0` (disabled) or `-f2:4` with `timeout 0` 
  - Less or no redundancy for minimal latency with gaming traffic
- **For a balance** (between bandwidth and latency): `-f2:4` with `timeout 0`
  - Moderate redundancy for a compromise between reliability and latency

### UDP2RAW

UDP2RAW encapsulates your game traffic (UDP) into another protocol to bypass network restrictions:
- **faketcp**: Mimics TCP traffic but maintains UDP-like performance
- **udp**: Simple UDP encapsulation with encryption
- **icmp**: Encapsulates in ICMP packets (ping-like traffic)

## Troubleshooting

If you encounter issues:

### Service Installation Failures

If service installation fails with the message "Failed to enable and start service":

1. First, check if the service file was properly copied:
```bash
ls -l /etc/systemd/system/tinyvpn-*
ls -l /etc/systemd/system/udp2raw-*
```

2. If the service file exists, try starting it manually:
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now tinyvpn-[config_name]-[server/client].service
```

3. Check for errors in the service startup:
```bash
sudo systemctl status tinyvpn-[config_name]-[server/client].service
journalctl -u tinyvpn-[config_name]-[server/client].service
```

4. Common issues include:
   - Binary permission problems: Ensure binaries are executable (`chmod +x /root/gamingtunnel/tinyvpn`)
   - Path issues: Make sure paths in service files match actual binary locations
   - SELinux restrictions: Try `setenforce 0` temporarily to check if SELinux is blocking execution

### Service Status Checking

```bash
# For TinyVPN services
systemctl status tinyvpn-[config_name]-server.service
systemctl status tinyvpn-[config_name]-client.service

# For UDP2RAW services
systemctl status udp2raw-[config_name]-server.service
systemctl status udp2raw-[config_name]-client.service
```

### Log Viewing

```bash
# View service logs
journalctl -u tinyvpn-[config_name]-server.service
journalctl -u udp2raw-[config_name]-server.service

# View direct output logs
cat /var/log/tunnel[config_name].log
cat /var/log/udp2raw_[config_name].log
```

### Manual Installation

If the installation script fails, you can try running the steps manually:
```bash
cd /root
mkdir -p /root/gamingtunnel
git clone https://github.com/EbadiDev/gaming-tunnel.git /root/gamingtunnel/src
cd /root/gamingtunnel/src
python main.py
```

## License

This project is distributed under the GPL v3 License. See the LICENSE file for details.

## Credits

- Github: [Github.com/ebadidev/gaming-tunnel](https://github.com/ebadidev/gaming-tunnel)
