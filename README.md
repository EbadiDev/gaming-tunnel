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
1. Clone the repository to `/root/gaming-tunnel/`
2. Create the installation directory at `/root/gamingtunnel/`
3. Install the `uv` package manager if not already installed
4. Set up a Python virtual environment
5. Install all required dependencies
6. Launch the application

## Directory Structure

After installation, Gaming Tunnel uses the following directory structure:
- `/root/gaming-tunnel/` - Repository code location
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

### UDP2RAW

UDP2RAW encapsulates your game traffic (UDP) into another protocol to bypass network restrictions:
- **faketcp**: Mimics TCP traffic but maintains UDP-like performance
- **udp**: Simple UDP encapsulation with encryption
- **icmp**: Encapsulates in ICMP packets (ping-like traffic)

## Troubleshooting

If you encounter issues:

1. Check the service status:
```bash
systemctl status tinyvpn-<config_name>-server.service
# or for clients
systemctl status tinyvpn-<config_name>-client.service
# or for UDP2RAW
systemctl status udp2raw-<config_name>-server.service
```

2. View logs:
```bash
journalctl -u tinyvpn-<config_name>-server.service
```

3. If the installation script fails, you can try running the steps manually:
```bash
cd /root
git clone https://github.com/EbadiDev/gaming-tunnel.git
cd gaming-tunnel
python main.py
```

## License

This project is distributed under the GPL v3 License. See the LICENSE file for details.

## Credits

- Github: [Github.com/ebadidev/gaming-tunnel](https://github.com/ebadidev/gaming-tunnel)
