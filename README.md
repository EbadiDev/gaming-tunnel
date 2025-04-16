# GamingVPN


A specialized VPN solution optimized for online gaming with low latency, packet loss reduction, and network optimization features.

## Features

- **Forward Error Correction (FEC)**: Recovers lost packets without retransmission to reduce lag spikes
- **MTU Optimization**: Configure Maximum Transmission Unit for optimal packet size
- **Gaming Mode**: Special mode optimized for real-time gaming traffic patterns
- **UDP2RAW Integration**: Encapsulates UDP traffic in TCP, ICMP, or fake-TCP packets to bypass network restrictions
- **Cross-platform**: Supports both x86_64 and ARM architectures
- **Systemd Service Management**: Easy to manage with systemd service configuration

## Requirements

- Linux-based operating system
- Root access
- `curl` and `jq` utilities (will be installed automatically if missing)

## Installation

You can install and run GamingVPN with a single command:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/ebadidev/gaming-tunnel/main/run.sh)
```

This command will download and execute the script directly with root privileges.

## Directory Structure

After installation, GamingVPN uses the following directory structure:
- `/root/gamingtunnel/` - Main installation directory
- `/root/gamingtunnel/tinyvpn` - The core GamingVPN binary
- `/root/gamingtunnel/udp2raw` - The UDP2RAW binary for traffic encapsulation

## Usage

### Server Configuration

1. Run the script and select option 1 (`Configure for server`)
2. Configure the following options:
   - Tunnel Port (default: 4096)
   - FEC Value (Forward Error Correction, format: x:y, default: 2:1)
   - Subnet Address (default: 10.22.22.0)
   - Mode (0 for non-game usage, 1 for game usage)
   - MTU Value (default: 1250)
   - UDP2RAW (optional):
     - UDP2RAW listening port
     - Password
     - Raw mode (faketcp, udp, icmp)

### Client Configuration

1. Run the script and select option 2 (`Configure for client`)
2. Configure the following options:
   - Remote Server Address (the IP of your GamingVPN server)
   - Tunnel Port (must match server port)
   - FEC Value (should match server settings for best results)
   - Subnet Address (must match server subnet)
   - Mode (should match server settings)
   - MTU Value (should match server settings)
   - UDP2RAW (optional, must be enabled on server):
     - UDP2RAW local port
     - Password (must match server password)
     - Raw mode (must match server raw mode)

### Management

The script provides several management options:
- **Check service status**: View the status of the GamingVPN service
- **View logs**: Check service logs for troubleshooting
- **Restart service**: Restart the GamingVPN service
- **Remove service**: Stop and remove the GamingVPN service
- **Remove core files**: Delete the GamingVPN installation files

## Technical Details

### FEC (Forward Error Correction)

The FEC feature uses a x:y format where:
- x: the number of redundant packets
- y: the number of original packets

For example, with FEC 2:1, for every original packet, 2 redundant packets are generated, allowing recovery from up to 2 packet losses.

### UDP2RAW

UDP2RAW encapsulates your game traffic (UDP) into another protocol to bypass network restrictions:
- **faketcp**: Mimics TCP traffic but maintains UDP-like performance
- **udp**: Simple UDP encapsulation with encryption
- **icmp**: Encapsulates in ICMP packets (ping-like traffic)

## Troubleshooting

If you encounter issues:

1. Check the service status:
```bash
systemctl status gamingtunnel.service
```

2. View detailed logs:
```bash
journalctl -xeu gamingtunnel.service
```

3. If using UDP2RAW, check its service status:
```bash
systemctl status udp2raw.service
```

## License

This project is distributed under the GPL v3 License. See the LICENSE file for details.

## Credits

- Github: [Github.com/ebadidev/gaming-tunnel](https://github.com/ebadidev/gaming-tunnel)
