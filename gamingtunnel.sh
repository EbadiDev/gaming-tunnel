#!/bin/bash

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   sleep 1
   exit 1
fi


# just press key to continue
press_key(){
 read -p "Press any key to continue..."
}


# Define a function to colorize text
colorize() {
    local color="$1"
    local text="$2"
    local style="${3:-normal}"
    
    # Define ANSI color codes
    local black="\033[30m"
    local red="\033[31m"
    local green="\033[32m"
    local yellow="\033[33m"
    local blue="\033[34m"
    local magenta="\033[35m"
    local cyan="\033[36m"
    local white="\033[37m"
    local reset="\033[0m"
    
    # Define ANSI style codes
    local normal="\033[0m"
    local bold="\033[1m"
    local underline="\033[4m"
    # Select color code
    local color_code
    case $color in
        black) color_code=$black ;;
        red) color_code=$red ;;
        green) color_code=$green ;;
        yellow) color_code=$yellow ;;
        blue) color_code=$blue ;;
        magenta) color_code=$magenta ;;
        cyan) color_code=$cyan ;;
        white) color_code=$white ;;
        *) color_code=$reset ;;  # Default case, no color
    esac
    # Select style code
    local style_code
    case $style in
        bold) style_code=$bold ;;
        underline) style_code=$underline ;;
        normal | *) style_code=$normal ;;  # Default case, normal text
    esac

    # Print the colored and styled text
    echo -e "${style_code}${color_code}${text}${reset}"
}


install_gamingtunnel() {
    # Define the directory and files
    DEST_DIR="/root/gamingtunnel"
    CONFIG_DIR="/root/gamingtunnel"
    FILE="/root/gamingtunnel/tinyvpn"
    UDP2RAW_FILE="/root/gamingtunnel/udp2raw"
    URL_X86="https://github.com/ebadidev/gaming-tunnel/raw/main/core/tinyvpn_amd64"
    URL_ARM="https://github.com/ebadidev/gaming-tunnel/raw/main/core/tinyvpn_arm"       
    URL_UDP2RAW="https://github.com/ebadidev/gaming-tunnel/raw/main/core/udp2raw_amd64"
    URL_UDP2RAW_ARM="https://github.com/ebadidev/gaming-tunnel/raw/main/core/udp2raw_arm"
      
    echo
    if [ -f "$FILE" ] && [ -f "$UDP2RAW_FILE" ]; then
        colorize green "GamingVPN core installed already." bold
        return 1
    fi
    
    # Make sure the destination directory exists
    if ! [ -d "$DEST_DIR" ]; then
        mkdir -p "$DEST_DIR" &> /dev/null
        if ! [ -d "$DEST_DIR" ]; then
            colorize red "Failed to create directory $DEST_DIR. Check permissions." bold
            sleep 2
            return 1
        fi
    fi
    
    # Detect the system architecture
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        URL=$URL_X86
        UDP2RAW_URL=$URL_UDP2RAW
    elif [ "$ARCH" = "armv7l" ] || [ "$ARCH" = "aarch64" ]; then
        URL=$URL_ARM
        UDP2RAW_URL=$URL_UDP2RAW_ARM
    else
        colorize red "Unsupported architecture: $ARCH\n" bold
        sleep 2
        return 1
    fi

    # Download TinyVPN with better error handling
    colorize yellow "Installing GamingVPN Core..." bold
    echo
    curl -L $URL -o $FILE --fail
    if [ $? -ne 0 ]; then
        colorize red "Download failed for TinyVPN. URL: $URL" bold
        sleep 2
        # Try again with verbose output for debugging
        colorize yellow "Retrying download with verbose output..." bold
        curl -L $URL -o $FILE -v
    fi
    
    if [ -f "$FILE" ]; then
        chmod +x $FILE
        if [ $? -ne 0 ]; then
            colorize red "Failed to set executable permission on $FILE" bold
        fi
    else
        colorize red "TinyVPN file not found after download attempt. Check permissions or URL." bold
    fi
    
    # Download UDP2RAW with better error handling
    colorize yellow "Installing UDP2RAW..." bold
    echo
    curl -L $UDP2RAW_URL -o $UDP2RAW_FILE --fail
    if [ $? -ne 0 ]; then
        colorize red "Download failed for UDP2RAW. URL: $UDP2RAW_URL" bold
        sleep 2
        # Try again with verbose output for debugging
        colorize yellow "Retrying download with verbose output..." bold
        curl -L $UDP2RAW_URL -o $UDP2RAW_FILE -v
    fi
    
    if [ -f "$UDP2RAW_FILE" ]; then
        chmod +x $UDP2RAW_FILE
        if [ $? -ne 0 ]; then
            colorize red "Failed to set executable permission on $UDP2RAW_FILE" bold
        fi
    else
        colorize red "UDP2RAW file not found after download attempt. Check permissions or URL." bold
    fi
    
    # Check if files were installed successfully
    if [ -f "$FILE" ] && [ -f "$UDP2RAW_FILE" ]; then
        colorize green "GamingVPN core and UDP2RAW installed successfully...\n" bold
        sleep 1
        return 0
    elif [ -f "$FILE" ]; then
        colorize yellow "GamingVPN core installed but UDP2RAW installation failed...\n" bold
        sleep 1
        return 0
    elif [ -f "$UDP2RAW_FILE" ]; then
        colorize yellow "UDP2RAW installed but GamingVPN core installation failed...\n" bold
        sleep 1
        return 1
    else
        colorize red "Failed to install GamingVPN components...\n" bold
        return 1
    fi
}

# Function to get IPv4 and IPv6 addresses
get_ip_addresses() {
    # Get IPv4 address
    IPV4_ADDRESS=$(curl -s -4 icanhazip.com 2>/dev/null)
    if [ -z "$IPV4_ADDRESS" ]; then
        IPV4_ADDRESS=$(curl -s -4 ifconfig.me 2>/dev/null)
    fi
    if [ -z "$IPV4_ADDRESS" ]; then
        IPV4_ADDRESS=$(curl -s -4 ipinfo.io/ip 2>/dev/null)
    fi
    
    # Get IPv6 address if available
    IPV6_ADDRESS=$(curl -s -6 icanhazip.com 2>/dev/null)
    
    # Export variables for use in other functions
    export IPV4_ADDRESS
    export IPV6_ADDRESS
}

# Function to display server location and IP
display_server_info() {
    echo -e "\e[93m═════════════════════════════════════════════\e[0m"  
    
    # Get the server's public IP addresses
    if [ -z "$IPV4_ADDRESS" ] || [ -z "$IPV6_ADDRESS" ]; then
        get_ip_addresses
    fi
    
    # Set SERVER_IP to IPv4 for compatibility with existing code
    if [ -z "$SERVER_IP" ] && [ -n "$IPV4_ADDRESS" ]; then
        SERVER_IP=$IPV4_ADDRESS
    fi
    
    # Show current IP addresses
    echo -e "${CYAN}IPv4 Address:${NC} $IPV4_ADDRESS"
    if [ -n "$IPV6_ADDRESS" ]; then
        echo -e "${CYAN}IPv6 Address:${NC} $IPV6_ADDRESS"
    fi
    
    # Try to get location info if jq is available
    if command -v jq &> /dev/null; then
        if [ -z "$SERVER_COUNTRY" ] || [ -z "$SERVER_ISP" ]; then
            # Fetch server country and ISP if not already set
            SERVER_COUNTRY=$(curl -sS "http://ipwhois.app/json/$IPV4_ADDRESS" | jq -r '.country')
            SERVER_ISP=$(curl -sS "http://ipwhois.app/json/$IPV4_ADDRESS" | jq -r '.isp')
        fi
        
        echo -e "${CYAN}Location:${NC} $SERVER_COUNTRY "
        echo -e "${CYAN}Datacenter:${NC} $SERVER_ISP"
    fi
    
    echo -e "\e[93m═════════════════════════════════════════════\e[0m"
}

CONFIG_DIR='/root/gamingtunnel'
SERVICE_FILE='/etc/systemd/system/gamingtunnel.service'
# Function to display Rathole Core installation status
display_gamingtunnel_status() {
    if [[ -f "${CONFIG_DIR}/tinyvpn" ]]; then
        echo -e "${CYAN}GamingVPN:${NC} ${GREEN}Installed${NC}"
    else
        echo -e "${CYAN}GamingVPN:${NC} ${RED}Not installed${NC}"
    fi
    echo -e "\e[93m═════════════════════════════════════════════\e[0m"  
}

configure_tinyvpn_server(){
    # Check if service exists
    echo 
    if [ -f "$SERVICE_FILE" ]; then
    	colorize red "GamingVPN service is running, please remove it first to configure it again." bold
    	sleep 2
    	return 1
    fi
    
    #Clear and title
    clear
    colorize cyan "Configure TinyVPN Server" bold
        
    echo
    
    # Tunnel Port
    echo -ne "[-] Tunnel Port (default 4096): "
    read -r PORT
    if [ -z "$PORT" ]; then
    	colorize yellow "Tunnel port 4096 selected by default."
        PORT=4096
    fi
    
    # Check if port is already in use
    if command -v ss &> /dev/null; then
        # Using ss command (newer systems)
        PORT_CHECK=$(ss -tuln | grep ":$PORT ")
    elif command -v netstat &> /dev/null; then
        # Using netstat command (older systems)
        PORT_CHECK=$(netstat -tuln | grep ":$PORT ")
    else
        # If neither command is available, use a less reliable method
        PORT_CHECK=$(lsof -i:$PORT 2>/dev/null)
    fi
    
    if [ -n "$PORT_CHECK" ]; then
        colorize red "ERROR: Port $PORT is already in use!" bold
        colorize yellow "Please choose a different port number." bold
        echo
        echo "$PORT_CHECK"
        echo
        sleep 2
        return 1
    fi
    
    echo
    
    # FEC Value
    echo -ne "[-] FEC value (with x:y format, default 2:1, enter 0 to disable): "
    read -r FEC
    if [ -z "$FEC" ]; then
    	colorize yellow "FEC set to 2:1"
        FEC="-f2:1"
    elif [[ "$FEC" == "0" ]];then
   	    colorize yellow "FEC is disabled"
    	FEC="--disable-fec"
	else
		FEC="-f${FEC}"
    fi
  
    echo
    
    # Subnet address 
    echo -ne "[-] Subnet Address (default 10.22.22.0): "
    read -r SUBNET
    if [ -z "$SUBNET" ]; then
	    colorize yellow "Subnet address 10.22.22.0 selected by default"
        SUBNET="10.22.22.0"
    fi
    
    echo
    
    # Mode
    echo -ne "[-] Mode (0 for non-game usage, 1 for game usage): "
    read -r MODE
    if [ -z "$MODE" ]; then
    	colorize yellow "Optimized for gaming usage by default."
        MODE="--mode 1  --timeout 1"
    elif [[ "$MODE" = "0" ]]; then
    	colorize yellow "Optimized for non-gaming usage."
    	   MODE="--mode 0  --timeout 4"
    else
       	colorize yellow "Optimized for gaming usage."
        MODE="--mode 1  --timeout 1"   	
    fi
    
    echo
    
    # MTU Value
    echo -ne "[-] MTU value (default 1250): "
    read -r MTU
    if [ -z "$MTU" ]; then
        colorize yellow "MTU set to default value (1250)."
        MTU="--mtu 1250"
    else
        colorize yellow "MTU set to $MTU."
        MTU="--mtu $MTU"
    fi
    
    # Final command
    COMMAND="-s -l[::]:$PORT $FEC --sub-net $SUBNET $MTU $MODE --tun-dev gaming --disable-obscure"
    
    # Create the systemd service unit file
    cat << EOF > "$SERVICE_FILE"
[Unit]
Description=GamingVPN Server
After=network.target
Wants=network.target

[Service]
Type=simple
WorkingDirectory=$CONFIG_DIR
ExecStart=$CONFIG_DIR/tinyvpn $COMMAND
Restart=always
RestartSec=1
LimitNOFILE=infinity

# Logging configuration
StandardOutput=append:/var/log/gamingtunnel.log
StandardError=append:/var/log/gamingtunnel.error.log

# Optional: log rotation to prevent huge log files
LogRateLimitIntervalSec=0
LogRateLimitBurst=0

[Install]
WantedBy=multi-user.target
EOF

	systemctl daemon-reload &> /dev/null
	systemctl enable gamingtunnel &> /dev/null
	systemctl start gamingtunnel &> /dev/null
	
	# Check if service started successfully
	if ! systemctl is-active --quiet gamingtunnel; then
	    colorize red "GamingVPN server failed to start. Checking logs..." bold
	    if [ -f "/var/log/gamingtunnel.error.log" ]; then
	        echo "Last 10 lines of error log:"
	        tail -n 10 /var/log/gamingtunnel.error.log
	    fi
	    colorize yellow "For more details, check: /var/log/gamingtunnel.log and /var/log/gamingtunnel.error.log" bold
	else
	    colorize green "GamingVPN server started successfully." bold
	fi
	
	echo
	press_key
}

configure_tinyvpn_client(){
    # Check if service exists
    echo 
    if [ -f "$SERVICE_FILE" ]; then
    	colorize red "GamingVPN service is running, please remove it first to configure it again." bold
    	sleep 2
    	return 1
    fi
   
    #Clear and title
    clear
    colorize cyan "Configure TinyVPN Client" bold
        
    echo
    
    # Remote Server Address
    echo -ne "[*] Remote server address (in IPv4 or [IPv6] format): "
    read -r IP
    if [ -z "$IP" ]; then
        colorize red "Enter a valid IP address..." bold
        sleep 2
        return 1
    fi
    
    echo
    
    # Tunnel Port
    echo -ne "[-] Tunnel Port (default 4096): "
    read -r PORT
    if [ -z "$PORT" ]; then
    	colorize yellow "Tunnel port 4096 selected by default."
        PORT=4096
    fi
    
    echo
    
    # FEC Value
    echo -ne "[-] FEC value (with x:y format, default 2:1, enter 0 to disable): "
    read -r FEC
    if [ -z "$FEC" ]; then
    	colorize yellow "FEC set to 2:1"
        FEC="-f2:1"
    elif [[ "$FEC" == "0" ]];then
   	    colorize yellow "FEC is disabled"
    	FEC="--disable-fec"
	else
		FEC="-f${FEC}"
    fi

    echo
    
    # Subnet address 
    echo -ne "[-] Subnet Address (default 10.22.22.0): "
    read -r SUBNET
    if [ -z "$SUBNET" ]; then
    	colorize yellow "Subnet address 10.22.22.0 selected by default"
        SUBNET="10.22.22.0"
    fi
    
    echo
    
    # Mode
    echo -ne "[-] Mode (0 for non-game usage, 1 for game usage): "
    read -r MODE
    if [ -z "$MODE" ]; then
    	colorize yellow "Optimized for gaming usage by default."
        MODE="--mode 1  --timeout 1"
    elif [[ "$MODE" = "0" ]]; then
    	colorize yellow "Optimized for non-gaming usage."
    	   MODE="--mode 0  --timeout 4"
    else
       	colorize yellow "Optimized for gaming usage."
        MODE="--mode 1  --timeout 1"   	
    fi
    
    echo
    
    # MTU Value
    echo -ne "[-] MTU value (default 1250): "
    read -r MTU
    if [ -z "$MTU" ]; then
        colorize yellow "MTU set to default value (1250)." 
        MTU="--mtu 1250"
    else
        colorize yellow "MTU set to $MTU."
        MTU="--mtu $MTU"
    fi
    
    # Final command
    COMMAND="-c -r${IP}:${PORT} $FEC --sub-net $SUBNET $MTU $MODE --tun-dev gaming --keep-reconnect --disable-obscure"

    # Create the systemd service unit file
    cat << EOF > "$SERVICE_FILE"
[Unit]
Description=GamingVPN Client
After=network.target
Wants=network.target

[Service]
Type=simple
WorkingDirectory=$CONFIG_DIR
ExecStart=$CONFIG_DIR/tinyvpn $COMMAND
Restart=always
RestartSec=1
LimitNOFILE=infinity

# Logging configuration
StandardOutput=append:/var/log/gamingtunnel.log
StandardError=append:/var/log/gamingtunnel.error.log

# Optional: log rotation to prevent huge log files
LogRateLimitIntervalSec=0
LogRateLimitBurst=0

[Install]
WantedBy=multi-user.target
EOF

	systemctl daemon-reload &> /dev/null
	systemctl enable gamingtunnel &> /dev/null
	systemctl start gamingtunnel &> /dev/null
	
	# Check if service started successfully
	if ! systemctl is-active --quiet gamingtunnel; then
	    colorize red "GamingVPN client failed to start. Checking logs..." bold
	    if [ -f "/var/log/gamingtunnel.error.log" ]; then
	        echo "Last 10 lines of error log:"
	        tail -n 10 /var/log/gamingtunnel.error.log
	    fi
	    colorize yellow "For more details, check: /var/log/gamingtunnel.log and /var/log/gamingtunnel.error.log" bold
	else
	    colorize green "GamingVPN client started successfully." bold
	fi
	
	echo
	press_key
}

configure_tinyvpn_client_multi(){
    # Prompt for a unique identifier for this connection
    echo
    colorize cyan "Configure TinyVPN Client (Multi-Config)" bold
    echo
    
    # Get a unique name for this connection
    echo -ne "[*] Enter a unique name for this connection (e.g., server-b, gaming, work): "
    read -r CONFIG_NAME
    if [ -z "$CONFIG_NAME" ]; then
        colorize red "Configuration name is required." bold
        sleep 2
        return 1
    fi
    
    # Sanitize the name to be safe for a filename
    CONFIG_NAME=$(echo "$CONFIG_NAME" | tr -cd '[:alnum:]-_')
    
    # Create unique service file path
    SERVICE_FILE_MULTI="/etc/systemd/system/gamingtunnel-${CONFIG_NAME}.service"
    
    # Check if service exists
    if [ -f "$SERVICE_FILE_MULTI" ]; then
        colorize red "GamingVPN service for '${CONFIG_NAME}' is already running, please remove it first to configure it again." bold
        sleep 2
        return 1
    fi
   
    # Clear and title
    clear
    colorize cyan "Configure TinyVPN Client for '${CONFIG_NAME}'" bold
    echo
    
    # Remote Server Address
    echo -ne "[*] Remote server address (in IPv4 or [IPv6] format): "
    read -r IP
    if [ -z "$IP" ]; then
        colorize red "Enter a valid IP address..." bold
        sleep 2
        return 1
    fi
    
    echo
    
    # Tunnel Port
    echo -ne "[-] Tunnel Port (default 4096): "
    read -r PORT
    if [ -z "$PORT" ]; then
        colorize yellow "Tunnel port 4096 selected by default."
        PORT=4096
    fi
    
    echo
    
    # FEC Value
    echo -ne "[-] FEC value (with x:y format, default 2:1, enter 0 to disable): "
    read -r FEC
    if [ -z "$FEC" ]; then
        colorize yellow "FEC set to 2:1"
        FEC="-f2:1"
    elif [[ "$FEC" == "0" ]];then
        colorize yellow "FEC is disabled"
        FEC="--disable-fec"
    else
        FEC="-f${FEC}"
    fi

    echo
    
    # Subnet address - IMPORTANT: Must be unique for each connection 
    echo -ne "[-] Subnet Address (MUST be unique for multi-config, default 10.22.22.0): "
    read -r SUBNET
    if [ -z "$SUBNET" ]; then
        # Generate a random number between 1-254 for the third octet to help make it unique
        RANDOM_OCTET=$((1 + RANDOM % 254))
        SUBNET="10.22.${RANDOM_OCTET}.0"
        colorize yellow "Generated unique subnet address ${SUBNET} for this connection"
    fi
    
    echo
    
    # Mode
    echo -ne "[-] Mode (0 for non-game usage, 1 for game usage): "
    read -r MODE
    if [ -z "$MODE" ]; then
        colorize yellow "Optimized for gaming usage by default."
        MODE="--mode 1  --timeout 1"
    elif [[ "$MODE" = "0" ]]; then
        colorize yellow "Optimized for non-gaming usage."
        MODE="--mode 0  --timeout 4"
    else
        colorize yellow "Optimized for gaming usage."
        MODE="--mode 1  --timeout 1"    
    fi
    
    echo
    
    # MTU Value
    echo -ne "[-] MTU value (default 1250): "
    read -r MTU
    if [ -z "$MTU" ]; then
        colorize yellow "MTU set to default value (1250)."
        MTU="--mtu 1250"
    else
        colorize yellow "MTU set to $MTU."
        MTU="--mtu $MTU"
    fi
    
    # TUN device name - must be unique for each connection
    TUN_DEV="gaming-${CONFIG_NAME}"
    colorize yellow "Using TUN device name: ${TUN_DEV}"
    
    # Final command
    COMMAND="-c -r${IP}:${PORT} $FEC --sub-net $SUBNET $MTU $MODE --tun-dev ${TUN_DEV} --keep-reconnect --disable-obscure"

    # Create the systemd service unit file
    cat << EOF > "$SERVICE_FILE_MULTI"
[Unit]
Description=GamingVPN Client (${CONFIG_NAME})
After=network.target
Wants=network.target

[Service]
Type=simple
WorkingDirectory=$CONFIG_DIR
ExecStart=$CONFIG_DIR/tinyvpn $COMMAND
Restart=always
RestartSec=1
LimitNOFILE=infinity

# Logging configuration
StandardOutput=append:/var/log/gamingtunnel-${CONFIG_NAME}.log
StandardError=append:/var/log/gamingtunnel-${CONFIG_NAME}.error.log

# Optional: log rotation to prevent huge log files
LogRateLimitIntervalSec=0
LogRateLimitBurst=0

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload &> /dev/null
    systemctl enable gamingtunnel-${CONFIG_NAME} &> /dev/null
    systemctl start gamingtunnel-${CONFIG_NAME} &> /dev/null
    
    # Check if service started successfully
    if ! systemctl is-active --quiet gamingtunnel-${CONFIG_NAME}; then
        colorize red "GamingVPN client for '${CONFIG_NAME}' failed to start. Checking logs..." bold
        if [ -f "/var/log/gamingtunnel-${CONFIG_NAME}.error.log" ]; then
            echo "Last 10 lines of error log:"
            tail -n 10 /var/log/gamingtunnel-${CONFIG_NAME}.error.log
        fi
        colorize yellow "For more details, check: /var/log/gamingtunnel-${CONFIG_NAME}.log and /var/log/gamingtunnel-${CONFIG_NAME}.error.log" bold
    else
        colorize green "GamingVPN client for '${CONFIG_NAME}' started successfully." bold
    fi
    
    echo
    press_key
}

configure_udp2raw_server(){
    UDP2RAW_SERVICE_FILE='/etc/systemd/system/udp2raw.service'
    
    # Check if service exists
    if [ -f "$UDP2RAW_SERVICE_FILE" ]; then
        colorize red "UDP2RAW service is running, please remove it first to configure it again." bold
        sleep 2
        return 1
    fi
    
    #Clear and title
    clear
    colorize cyan "Configure UDP2RAW Server" bold
    echo
    
    # TinyVPN service port that UDP2RAW will forward to
    echo -ne "[-] Local TinyVPN service port (UDP2RAW will forward to this): "
    read -r TINYVPN_LOCAL_PORT
    if [ -z "$TINYVPN_LOCAL_PORT" ]; then
        colorize red "TinyVPN service port is required." bold
        sleep 2
        return 1
    fi
    
    # External UDP2RAW port that clients will connect to
    echo -ne "[-] External UDP2RAW port (clients will connect to this): "
    read -r UDP2RAW_EXTERNAL_PORT
    if [ -z "$UDP2RAW_EXTERNAL_PORT" ]; then
        colorize red "UDP2RAW port is required." bold
        sleep 2
        return 1
    fi
    
    # Password
    echo -ne "[-] UDP2RAW password: "
    read -r UDP2RAW_PASS
    if [ -z "$UDP2RAW_PASS" ]; then
        colorize yellow "Using default password 'gaming'."
        UDP2RAW_PASS="gaming"
    fi
    
    # Raw mode
    echo -ne "[-] UDP2RAW mode (faketcp, udp, icmp, default: faketcp): "
    read -r UDP2RAW_MODE
    if [ -z "$UDP2RAW_MODE" ]; then
        colorize yellow "Using default mode 'faketcp'."
        UDP2RAW_MODE="faketcp"
    elif [[ "$UDP2RAW_MODE" != "faketcp" && "$UDP2RAW_MODE" != "udp" && "$UDP2RAW_MODE" != "icmp" ]]; then
        colorize yellow "Invalid mode. Using default 'faketcp' instead."
        UDP2RAW_MODE="faketcp"
    fi
    
    # UDP2RAW server command with CORRECT port order (listening on TinyVPN port)
    UDP2RAW_COMMAND="-s -l0.0.0.0:${TINYVPN_LOCAL_PORT} -r127.0.0.1:${UDP2RAW_EXTERNAL_PORT} -a -k \"${UDP2RAW_PASS}\" --cipher-mode xor --auth-mode simple --raw-mode ${UDP2RAW_MODE}"
    
    # Show the command for troubleshooting
    colorize yellow "Using UDP2RAW command:" bold
    echo "$UDP2RAW_COMMAND"
    echo
    
    # Create the UDP2RAW service file
    cat << EOF > "$UDP2RAW_SERVICE_FILE"
[Unit]
Description=UDP2RAW Service
After=network.target
Wants=network.target

[Service]
Type=simple
WorkingDirectory=$CONFIG_DIR
ExecStart=$CONFIG_DIR/udp2raw $UDP2RAW_COMMAND
Restart=always
RestartSec=1
LimitNOFILE=infinity

# Logging configuration
StandardOutput=append:/var/log/udp2raw.log
StandardError=append:/var/log/udp2raw.error.log

# Optional: log rotation to prevent huge log files
LogRateLimitIntervalSec=0
LogRateLimitBurst=0

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload &> /dev/null
    systemctl enable udp2raw &> /dev/null
    systemctl start udp2raw &> /dev/null
    
    # Check if service started successfully
    if ! systemctl is-active --quiet udp2raw; then
        colorize red "UDP2RAW server failed to start. Checking logs..." bold
        if [ -f "/var/log/udp2raw.error.log" ]; then
            echo "Last 10 lines of error log:"
            tail -n 10 /var/log/udp2raw.error.log
        fi
        colorize yellow "For more details, check: /var/log/udp2raw.log and /var/log/udp2raw.error.log" bold
        colorize yellow "Try running the command manually to see errors:" bold
        echo "$CONFIG_DIR/udp2raw $UDP2RAW_COMMAND"
    else
        colorize green "UDP2RAW server configured and started successfully." bold
    fi
    
    echo
    colorize yellow "NOTE: UDP2RAW server is listening on port ${TINYVPN_LOCAL_PORT} and forwarding to external port ${UDP2RAW_EXTERNAL_PORT}" bold
    echo
    press_key
}

configure_udp2raw_client(){
    UDP2RAW_SERVICE_FILE='/etc/systemd/system/udp2raw.service'
    
    # Check if service exists
    echo 
    if [ -f "$UDP2RAW_SERVICE_FILE" ]; then
    	colorize red "UDP2RAW service is running, please remove it first to configure it again." bold
    	sleep 2
    	return 1
    fi
    
    #Clear and title
    clear
    colorize cyan "Configure UDP2RAW Client" bold
    echo
    
    # Remote Server Address
    echo -ne "[*] Remote server address (in IPv4 or [IPv6] format): "
    read -r SERVER_IP
    if [ -z "$SERVER_IP" ]; then
        colorize red "Enter a valid IP address..." bold
        sleep 2
        return 1
    fi
    
    # Local UDP2RAW listening port
    echo -ne "[-] Local UDP2RAW listening port: "
    read -r LOCAL_UDP2RAW_PORT
    if [ -z "$LOCAL_UDP2RAW_PORT" ]; then
        colorize red "Local UDP2RAW listening port is required." bold
        sleep 2
        return 1
    fi
    
    # Remote TinyVPN port on server
    echo -ne "[-] Remote TinyVPN port on the server: "
    read -r REMOTE_TINYVPN_PORT
    if [ -z "$REMOTE_TINYVPN_PORT" ]; then
        colorize red "Remote TinyVPN port is required." bold
        sleep 2
        return 1
    fi
    
    # Password
    echo -ne "[-] UDP2RAW password (must match server): "
    read -r UDP2RAW_PASS
    if [ -z "$UDP2RAW_PASS" ]; then
        colorize yellow "Using default password 'gaming'."
        UDP2RAW_PASS="gaming"
    fi
    
    # Raw mode
    echo -ne "[-] UDP2RAW mode (faketcp, udp, icmp, default: faketcp): "
    read -r UDP2RAW_MODE
    if [ -z "$UDP2RAW_MODE" ]; then
        colorize yellow "Using default mode 'faketcp'."
        UDP2RAW_MODE="faketcp"
    elif [[ "$UDP2RAW_MODE" != "faketcp" && "$UDP2RAW_MODE" != "udp" && "$UDP2RAW_MODE" != "icmp" ]]; then
        colorize yellow "Invalid mode. Using default 'faketcp' instead."
        UDP2RAW_MODE="faketcp"
    fi
    
    # UDP2RAW client command with CORRECT port order
    UDP2RAW_COMMAND="-c -l0.0.0.0:${LOCAL_UDP2RAW_PORT} -r${SERVER_IP}:${REMOTE_TINYVPN_PORT} -a -k \"${UDP2RAW_PASS}\" --cipher-mode xor --auth-mode simple --raw-mode ${UDP2RAW_MODE}"
    
    # Show the command for troubleshooting
    colorize yellow "Using UDP2RAW command:" bold
    echo "$UDP2RAW_COMMAND"
    echo
    
    # Create the UDP2RAW service file
    cat << EOF > "$UDP2RAW_SERVICE_FILE"
[Unit]
Description=UDP2RAW Service
After=network.target
Wants=network.target

[Service]
Type=simple
WorkingDirectory=$CONFIG_DIR
ExecStart=$CONFIG_DIR/udp2raw $UDP2RAW_COMMAND
Restart=always
RestartSec=1
LimitNOFILE=infinity

# Logging configuration
StandardOutput=append:/var/log/udp2raw.log
StandardError=append:/var/log/udp2raw.error.log

# Optional: log rotation to prevent huge log files
LogRateLimitIntervalSec=0
LogRateLimitBurst=0

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload &> /dev/null
    systemctl enable udp2raw &> /dev/null
    systemctl start udp2raw &> /dev/null
    
    # Check if service started successfully
    if ! systemctl is-active --quiet udp2raw; then
        colorize red "UDP2RAW client failed to start. Checking logs..." bold
        if [ -f "/var/log/udp2raw.error.log" ]; then
            echo "Last 10 lines of error log:"
            tail -n 10 /var/log/udp2raw.error.log
        fi
        colorize yellow "For more details, check: /var/log/udp2raw.log and /var/log/udp2raw.error.log" bold
        colorize yellow "Try running the command manually to see errors:" bold
        echo "$CONFIG_DIR/udp2raw $UDP2RAW_COMMAND"
    else
        colorize green "UDP2RAW client configured and started successfully." bold
    fi
    
    echo
    colorize yellow "NOTE: Configure TinyVPN to connect to 127.0.0.1:${LOCAL_UDP2RAW_PORT} to use this UDP2RAW tunnel" bold
    echo
    colorize yellow "The UDP2RAW client is listening on port ${LOCAL_UDP2RAW_PORT} and connecting to the server TinyVPN port at ${SERVER_IP}:${REMOTE_TINYVPN_PORT}" bold
    echo
    press_key
}

configure_udp2raw_client_multi(){
    # Prompt for a unique identifier for this connection
    echo
    colorize cyan "Configure UDP2RAW Client (Multi-Config)" bold
    echo
    
    # Get a unique name for this connection
    echo -ne "[*] Enter a unique name for this connection (e.g., server-b, gaming, work): "
    read -r CONFIG_NAME
    if [ -z "$CONFIG_NAME" ]; then
        colorize red "Configuration name is required." bold
        sleep 2
        return 1
    fi
    
    # Sanitize the name to be safe for a filename
    CONFIG_NAME=$(echo "$CONFIG_NAME" | tr -cd '[:alnum:]-_')
    
    # Create unique service file path
    UDP2RAW_SERVICE_FILE_MULTI="/etc/systemd/system/udp2raw-${CONFIG_NAME}.service"
    
    # Check if service exists 
    if [ -f "$UDP2RAW_SERVICE_FILE_MULTI" ]; then
        colorize red "UDP2RAW service for '${CONFIG_NAME}' is already running, please remove it first to configure it again." bold
        sleep 2
        return 1
    fi
    
    # Clear and title
    clear
    colorize cyan "Configure UDP2RAW Client for '${CONFIG_NAME}'" bold
    echo
    
    # Remote Server Address
    echo -ne "[*] Remote server address (in IPv4 or [IPv6] format): "
    read -r SERVER_IP
    if [ -z "$SERVER_IP" ]; then
        colorize red "Enter a valid IP address..." bold
        sleep 2
        return 1
    fi
    
    # Local UDP2RAW listening port - MUST be unique for each connection
    echo -ne "[-] Local UDP2RAW listening port (MUST be unique for multi-config): "
    read -r LOCAL_UDP2RAW_PORT
    if [ -z "$LOCAL_UDP2RAW_PORT" ]; then
        colorize red "Local UDP2RAW listening port is required." bold
        sleep 2
        return 1
    fi
    
    # Remote TinyVPN port on server
    echo -ne "[-] Remote TinyVPN port on the server: "
    read -r REMOTE_TINYVPN_PORT
    if [ -z "$REMOTE_TINYVPN_PORT" ]; then
        colorize red "Remote TinyVPN port is required." bold
        sleep 2
        return 1
    fi
    
    # Password
    echo -ne "[-] UDP2RAW password (must match server): "
    read -r UDP2RAW_PASS
    if [ -z "$UDP2RAW_PASS" ]; then
        colorize yellow "Using default password 'gaming'."
        UDP2RAW_PASS="gaming"
    fi
    
    # Raw mode
    echo -ne "[-] UDP2RAW mode (faketcp, udp, icmp, default: faketcp): "
    read -r UDP2RAW_MODE
    if [ -z "$UDP2RAW_MODE" ]; then
        colorize yellow "Using default mode 'faketcp'."
        UDP2RAW_MODE="faketcp"
    elif [[ "$UDP2RAW_MODE" != "faketcp" && "$UDP2RAW_MODE" != "udp" && "$UDP2RAW_MODE" != "icmp" ]]; then
        colorize yellow "Invalid mode. Using default 'faketcp' instead."
        UDP2RAW_MODE="faketcp"
    fi
    
    # UDP2RAW client command with CORRECT port order
    UDP2RAW_COMMAND="-c -l0.0.0.0:${LOCAL_UDP2RAW_PORT} -r${SERVER_IP}:${REMOTE_TINYVPN_PORT} -a -k \"${UDP2RAW_PASS}\" --cipher-mode xor --auth-mode simple --raw-mode ${UDP2RAW_MODE}"
    
    # Show the command for troubleshooting
    colorize yellow "Using UDP2RAW command:" bold
    echo "$UDP2RAW_COMMAND"
    echo
    
    # Create the UDP2RAW service file
    cat << EOF > "$UDP2RAW_SERVICE_FILE_MULTI"
[Unit]
Description=UDP2RAW Service (${CONFIG_NAME})
After=network.target
Wants=network.target

[Service]
Type=simple
WorkingDirectory=$CONFIG_DIR
ExecStart=$CONFIG_DIR/udp2raw $UDP2RAW_COMMAND
Restart=always
RestartSec=1
LimitNOFILE=infinity

# Logging configuration
StandardOutput=append:/var/log/udp2raw-${CONFIG_NAME}.log
StandardError=append:/var/log/udp2raw-${CONFIG_NAME}.error.log

# Optional: log rotation to prevent huge log files
LogRateLimitIntervalSec=0
LogRateLimitBurst=0

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload &> /dev/null
    systemctl enable udp2raw-${CONFIG_NAME} &> /dev/null
    systemctl start udp2raw-${CONFIG_NAME} &> /dev/null
    
    # Check if service started successfully
    if ! systemctl is-active --quiet udp2raw-${CONFIG_NAME}; then
        colorize red "UDP2RAW client for '${CONFIG_NAME}' failed to start. Checking logs..." bold
        if [ -f "/var/log/udp2raw-${CONFIG_NAME}.error.log" ]; then
            echo "Last 10 lines of error log:"
            tail -n 10 /var/log/udp2raw-${CONFIG_NAME}.error.log
        fi
        colorize yellow "For more details, check: /var/log/udp2raw-${CONFIG_NAME}.log and /var/log/udp2raw-${CONFIG_NAME}.error.log" bold
        colorize yellow "Try running the command manually to see errors:" bold
        echo "$CONFIG_DIR/udp2raw $UDP2RAW_COMMAND"
    else
        colorize green "UDP2RAW client for '${CONFIG_NAME}' configured and started successfully." bold
    fi
    
    echo
    colorize yellow "NOTE: Configure TinyVPN to connect to 127.0.0.1:${LOCAL_UDP2RAW_PORT} to use this UDP2RAW tunnel" bold
    echo
    colorize yellow "The UDP2RAW client '${CONFIG_NAME}' is listening on port ${LOCAL_UDP2RAW_PORT} and connecting to the server TinyVPN port at ${SERVER_IP}:${REMOTE_TINYVPN_PORT}" bold
    echo
    press_key
}

check_service_status_tinyvpn(){
	echo
    if ! [ -f "$SERVICE_FILE" ]; then
    	colorize red "GamingVPN service is not found" bold
    	sleep 2
    	return 1
    fi
    clear
    systemctl status gamingtunnel.service
    
    echo
    press_key
}

check_service_status_udp2raw(){
	echo
    UDP2RAW_SERVICE_FILE='/etc/systemd/system/udp2raw.service'
    if ! [ -f "$UDP2RAW_SERVICE_FILE" ]; then
    	colorize red "UDP2RAW service is not found" bold
    	sleep 2
    	return 1
    fi
    clear
    systemctl status udp2raw.service
    
    echo
    press_key
}

view_logs_tinyvpn(){
	echo
    if ! [ -f "$SERVICE_FILE" ]; then
    	colorize red "GamingVPN service is not found" bold
    	sleep 2
    	return 1
    fi
    clear
    if [ -f "/var/log/gamingtunnel.log" ]; then
        cat /var/log/gamingtunnel.log
    else
        colorize yellow "Log file not found. Checking service logs..." bold
        journalctl -xeu gamingtunnel.service
    fi
    
    echo
    press_key
}

view_logs_udp2raw(){
	echo
    UDP2RAW_SERVICE_FILE='/etc/systemd/system/udp2raw.service'
    if ! [ -f "$UDP2RAW_SERVICE_FILE" ]; then
    	colorize red "UDP2RAW service is not found" bold
    	sleep 2
    	return 1
    fi
    clear
    if [ -f "/var/log/udp2raw.log" ]; then
        cat /var/log/udp2raw.log
    else
        colorize yellow "Log file not found. Checking service logs..." bold
        journalctl -xeu udp2raw.service
    fi
    
    echo
    press_key
}

restart_service_tinyvpn(){
	echo
    if ! [ -f "$SERVICE_FILE" ]; then
    	colorize red "GamingVPN service is not found" bold
    	sleep 2
    	return 1
    fi
    
    systemctl restart gamingtunnel.service &> /dev/null
    colorize green "GamingVPN service restarted successfully." bold
	sleep 2
}

restart_service_udp2raw(){
	echo
    UDP2RAW_SERVICE_FILE='/etc/systemd/system/udp2raw.service'
    if ! [ -f "$UDP2RAW_SERVICE_FILE" ]; then
    	colorize red "UDP2RAW service is not found" bold
    	sleep 2
    	return 1
    fi
    
    systemctl restart udp2raw.service &> /dev/null
    colorize green "UDP2RAW service restarted successfully." bold
	sleep 2
}

remove_tinyvpn_service(){
	echo
    if ! [ -f "$SERVICE_FILE" ]; then
		colorize red "GamingVPN service not found." bold
		sleep 2
		return 1
    fi
	
	systemctl disable gamingtunnel &> /dev/null
	systemctl stop gamingtunnel &> /dev/null
	rm -rf "$SERVICE_FILE"
	systemctl daemon-reload &> /dev/null
	
	colorize green "GamingVPN service stopped and deleted successfully." bold
	sleep 2
}

remove_udp2raw_service(){
	echo
    UDP2RAW_SERVICE_FILE='/etc/systemd/system/udp2raw.service'
    if ! [ -f "$UDP2RAW_SERVICE_FILE" ]; then
		colorize red "UDP2RAW service not found." bold
		sleep 2
		return 1
    fi
	
	systemctl disable udp2raw &> /dev/null
	systemctl stop udp2raw &> /dev/null
	rm -rf "$UDP2RAW_SERVICE_FILE"
	systemctl daemon-reload &> /dev/null
	
	colorize green "UDP2RAW service stopped and deleted successfully." bold
	sleep 2
}

remove_all_services(){
	echo
    local services_found=false
    
    if [ -f "$SERVICE_FILE" ]; then
        systemctl disable gamingtunnel &> /dev/null
        systemctl stop gamingtunnel &> /dev/null
        rm -rf "$SERVICE_FILE"
        colorize green "GamingVPN service stopped and deleted." bold
        services_found=true
    fi
    
    UDP2RAW_SERVICE_FILE='/etc/systemd/system/udp2raw.service'
    if [ -f "$UDP2RAW_SERVICE_FILE" ]; then
        systemctl disable udp2raw &> /dev/null
        systemctl stop udp2raw &> /dev/null
        rm -rf "$UDP2RAW_SERVICE_FILE"
        colorize green "UDP2RAW service stopped and deleted." bold
        services_found=true
    fi
    
    if [ "$services_found" = true ]; then
        systemctl daemon-reload &> /dev/null
        colorize green "All services stopped and deleted successfully." bold
    else
        colorize red "No services found to remove." bold
    fi
    
    sleep 2
}

remove_core(){
	echo
	if ! [ -d "$CONFIG_DIR" ]; then
		colorize red "Gaming VPN directory not found"
		sleep 2
		return 1
	fi
	
    if [ -f "$SERVICE_FILE" ]; then
    	colorize red "GamingVPN service is running, please remove it first and then remove then core." bold
    	sleep 2
    	return 1
    fi
	
	rm -rf "$CONFIG_DIR"
	colorize green "GamingVPN directory deleted successfully." bold
	sleep 2
}

create_symlink() {
    local SYMLINK_PATH="/usr/local/bin/gamingtunnel"
    local SCRIPT_PATH="$(realpath $0)"
    
    echo
    if [ -L "$SYMLINK_PATH" ]; then
        colorize yellow "Symlink already exists at $SYMLINK_PATH" bold
        
        # Check if it's pointing to the current script
        local CURRENT_TARGET="$(readlink $SYMLINK_PATH)"
        if [ "$CURRENT_TARGET" != "$SCRIPT_PATH" ]; then
            echo -ne "[-] Update symlink to point to current script? (y/n): "
            read -r UPDATE_SYMLINK
            if [[ "$UPDATE_SYMLINK" == "y" || "$UPDATE_SYMLINK" == "Y" ]]; then
                rm -f "$SYMLINK_PATH"
                ln -s "$SCRIPT_PATH" "$SYMLINK_PATH"
                colorize green "Symlink updated. You can now run 'gamingtunnel' from anywhere." bold
            fi
        else
            colorize green "Symlink is already pointing to the current script." bold
        fi
    else
        ln -s "$SCRIPT_PATH" "$SYMLINK_PATH"
        if [ -L "$SYMLINK_PATH" ]; then
            colorize green "Symlink created successfully. You can now run 'gamingtunnel' from anywhere." bold
        else
            colorize red "Failed to create symlink." bold
        fi
    fi
    
    echo
    press_key
}

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\e[36m'
MAGENTA="\e[95m"
NC='\033[0m' # No Color


# Function to display menu
display_menu() {
    clear
    display_server_info
    display_gamingtunnel_status
    echo
    colorize cyan "═══ MAIN MENU ═══" bold
    colorize green " 1. TinyVPN Management" bold
    colorize green " 2. UDP2RAW Server Configuration" bold
    colorize green " 3. UDP2RAW Client Configuration" bold
    echo
    colorize cyan "═══ MULTI-CONFIGURATION ═══" bold
    colorize green " 4. UDP2RAW Client Multi-Config" bold
    colorize green " 5. List UDP2RAW Configurations" bold
    echo
    colorize cyan "═══ SERVICE MANAGEMENT ═══" bold
    colorize magenta " 6. Check UDP2RAW service status" 
    colorize yellow " 7. View UDP2RAW logs"
    colorize yellow " 8. Restart UDP2RAW service" 
    echo
    colorize cyan "═══ REMOVAL ═══" bold
    colorize red " 9. Remove UDP2RAW service"
    colorize red "10. Remove all services"
    colorize red "11. Remove core files"
    echo
    colorize cyan "═══ UTILITIES ═══" bold
    colorize magenta "12. Create symlink to script" bold
    colorize magenta "13. Check External IP Address" bold
    echo -e " 0. Exit"
    echo
    echo "-------------------------------"
}

# Function to read user input
read_option() {
    read -p "Enter your choice [0-13]: " choice
    case $choice in
        1) tinyvpn_menu ;;
        2) configure_udp2raw_server ;;
        3) configure_udp2raw_client ;;
        4) configure_udp2raw_client_multi ;;
        5) list_multi_configs ;;
        6) check_service_status_udp2raw ;;
        7) view_logs_udp2raw ;;
        8) restart_service_udp2raw ;;
        9) remove_udp2raw_service ;;
        10) remove_all_services ;;
        11) remove_core ;;
        12) create_symlink ;;
        13) check_external_ip ;;
        0) exit 0 ;;
        *) echo -e "${RED} Invalid option!${NC}" && sleep 1 ;;
    esac
}

# Main script
while true
do
    display_menu
    read_option
done

list_multi_configs() {
    clear
    colorize cyan "List of active GamingVPN configurations" bold
    echo
    
    # Check if there are any TinyVPN multi-configs
    TINYVPN_MULTI_SERVICES=$(systemctl list-units --all --plain --no-legend "gamingtunnel-*.service" | grep -v "^gamingtunnel\.service" | awk '{print $1}')
    
    if [ -z "$TINYVPN_MULTI_SERVICES" ]; then
        colorize yellow "No TinyVPN multi-configurations found." bold
    else
        colorize green "TinyVPN Multi-Configurations:" bold
        echo "$TINYVPN_MULTI_SERVICES" | while read -r service; do
            config_name=${service%.service}
            config_name=${config_name#gamingtunnel-}
            status=$(systemctl is-active "$service" 2>/dev/null)
            if [ "$status" = "active" ]; then
                colorize green "  • $config_name (Status: $status)" 
            else
                colorize red "  • $config_name (Status: $status)"
            fi
        done
    fi
    
    echo
    
    # Check if there are any UDP2RAW multi-configs
    UDP2RAW_MULTI_SERVICES=$(systemctl list-units --all --plain --no-legend "udp2raw-*.service" | grep -v "^udp2raw\.service" | awk '{print $1}')
    
    if [ -z "$UDP2RAW_MULTI_SERVICES" ]; then
        colorize yellow "No UDP2RAW multi-configurations found." bold
    else
        colorize green "UDP2RAW Multi-Configurations:" bold
        echo "$UDP2RAW_MULTI_SERVICES" | while read -r service; do
            config_name=${service%.service}
            config_name=${config_name#udp2raw-}
            status=$(systemctl is-active "$service" 2>/dev/null)
            if [ "$status" = "active" ]; then
                colorize green "  • $config_name (Status: $status)" 
            else
                colorize red "  • $config_name (Status: $status)"
            fi
        done
    fi
    
    echo
    press_key
}

restart_multi_config() {
    clear
    colorize cyan "Restart a specific configuration" bold
    echo
    
    echo -ne "[*] Enter the configuration name to restart: "
    read -r CONFIG_NAME
    
    if [ -z "$CONFIG_NAME" ]; then
        colorize red "Configuration name is required." bold
        sleep 2
        return 1
    fi
    
    # Check and restart TinyVPN service if it exists
    if systemctl list-units --all --plain --no-legend "gamingtunnel-${CONFIG_NAME}.service" &>/dev/null; then
        systemctl restart "gamingtunnel-${CONFIG_NAME}.service" &>/dev/null
        if systemctl is-active --quiet "gamingtunnel-${CONFIG_NAME}.service"; then
            colorize green "TinyVPN service for '$CONFIG_NAME' restarted successfully." bold
        else
            colorize red "Failed to restart TinyVPN service for '$CONFIG_NAME'." bold
        fi
    else
        colorize yellow "No TinyVPN service found for configuration '$CONFIG_NAME'." bold
    fi
    
    # Check and restart UDP2RAW service if it exists
    if systemctl list-units --all --plain --no-legend "udp2raw-${CONFIG_NAME}.service" &>/dev/null; then
        systemctl restart "udp2raw-${CONFIG_NAME}.service" &>/dev/null
        if systemctl is-active --quiet "udp2raw-${CONFIG_NAME}.service"; then
            colorize green "UDP2RAW service for '$CONFIG_NAME' restarted successfully." bold
        else
            colorize red "Failed to restart UDP2RAW service for '$CONFIG_NAME'." bold
        fi
    else
        colorize yellow "No UDP2RAW service found for configuration '$CONFIG_NAME'." bold
    fi
    
    echo
    press_key
}

check_status_multi_config() {
    clear
    colorize cyan "Check status of a specific configuration" bold
    echo
    
    echo -ne "[*] Enter the configuration name to check: "
    read -r CONFIG_NAME
    
    if [ -z "$CONFIG_NAME" ]; then
        colorize red "Configuration name is required." bold
        sleep 2
        return 1
    fi
    
    # Check TinyVPN service status
    if systemctl list-units --all --plain --no-legend "gamingtunnel-${CONFIG_NAME}.service" &>/dev/null; then
        colorize green "TinyVPN service status for '$CONFIG_NAME':" bold
        systemctl status "gamingtunnel-${CONFIG_NAME}.service"
    else
        colorize yellow "No TinyVPN service found for configuration '$CONFIG_NAME'." bold
    fi
    
    echo
    
    # Check UDP2RAW service status
    if systemctl list-units --all --plain --no-legend "udp2raw-${CONFIG_NAME}.service" &>/dev/null; then
        colorize green "UDP2RAW service status for '$CONFIG_NAME':" bold
        systemctl status "udp2raw-${CONFIG_NAME}.service"
    else
        colorize yellow "No UDP2RAW service found for configuration '$CONFIG_NAME'." bold
    fi
    
    echo
    press_key
}

view_logs_multi_config() {
    clear
    colorize cyan "View logs for a specific configuration" bold
    echo
    
    echo -ne "[*] Enter the configuration name to view logs: "
    read -r CONFIG_NAME
    
    if [ -z "$CONFIG_NAME" ]; then
        colorize red "Configuration name is required." bold
        sleep 2
        return 1
    fi
    
    # Check TinyVPN logs
    if [ -f "/var/log/gamingtunnel-${CONFIG_NAME}.log" ]; then
        colorize green "TinyVPN logs for '$CONFIG_NAME':" bold
        tail -n 50 "/var/log/gamingtunnel-${CONFIG_NAME}.log"
    elif systemctl list-units --all --plain --no-legend "gamingtunnel-${CONFIG_NAME}.service" &>/dev/null; then
        colorize yellow "Log file not found. Checking service logs..." bold
        journalctl -xeu "gamingtunnel-${CONFIG_NAME}.service" | tail -n 50
    else
        colorize yellow "No TinyVPN service found for configuration '$CONFIG_NAME'." bold
    fi
    
    echo
    press_key
    
    # Check UDP2RAW logs
    clear
    if [ -f "/var/log/udp2raw-${CONFIG_NAME}.log" ]; then
        colorize green "UDP2RAW logs for '$CONFIG_NAME':" bold
        tail -n 50 "/var/log/udp2raw-${CONFIG_NAME}.log"
    elif systemctl list-units --all --plain --no-legend "udp2raw-${CONFIG_NAME}.service" &>/dev/null; then
        colorize yellow "Log file not found. Checking service logs..." bold
        journalctl -xeu "udp2raw-${CONFIG_NAME}.service" | tail -n 50
    else
        colorize yellow "No UDP2RAW service found for configuration '$CONFIG_NAME'." bold
    fi
    
    echo
    press_key
}

remove_multi_config() {
    clear
    colorize cyan "Remove a specific configuration" bold
    echo
    
    echo -ne "[*] Enter the configuration name to remove: "
    read -r CONFIG_NAME
    
    if [ -z "$CONFIG_NAME" ]; then
        colorize red "Configuration name is required." bold
        sleep 2
        return 1
    fi
    
    local services_removed=false
    
    # Remove TinyVPN service if it exists
    if systemctl list-units --all --plain --no-legend "gamingtunnel-${CONFIG_NAME}.service" &>/dev/null; then
        systemctl stop "gamingtunnel-${CONFIG_NAME}.service" &>/dev/null
        systemctl disable "gamingtunnel-${CONFIG_NAME}.service" &>/dev/null
        rm -f "/etc/systemd/system/gamingtunnel-${CONFIG_NAME}.service"
        colorize green "TinyVPN service for '$CONFIG_NAME' removed successfully." bold
        services_removed=true
    else
        colorize yellow "No TinyVPN service found for configuration '$CONFIG_NAME'." bold
    fi
    
    # Remove UDP2RAW service if it exists
    if systemctl list-units --all --plain --no-legend "udp2raw-${CONFIG_NAME}.service" &>/dev/null; then
        systemctl stop "udp2raw-${CONFIG_NAME}.service" &>/dev/null
        systemctl disable "udp2raw-${CONFIG_NAME}.service" &>/dev/null
        rm -f "/etc/systemd/system/udp2raw-${CONFIG_NAME}.service"
        colorize green "UDP2RAW service for '$CONFIG_NAME' removed successfully." bold
        services_removed=true
    else
        colorize yellow "No UDP2RAW service found for configuration '$CONFIG_NAME'." bold
    fi
    
    if [ "$services_removed" = true ]; then
        systemctl daemon-reload &>/dev/null
        colorize green "Configuration '$CONFIG_NAME' has been fully removed." bold
    else
        colorize red "No services found for configuration '$CONFIG_NAME'." bold
    fi
    
    echo
    press_key
}

check_external_ip() {
    clear
    colorize cyan "External IP Address Check" bold
    echo
    
    # Get the current IP addresses
    colorize yellow "Checking your external IP addresses..." bold
    get_ip_addresses
    
    if [ -z "$IPV4_ADDRESS" ]; then
        colorize red "Failed to retrieve external IPv4 address. Please check your internet connection." bold
    else
        colorize green "Your current external IPv4 address is:" bold
        echo
        colorize cyan "$IPV4_ADDRESS" bold
        echo
        
        # Try to get additional information
        if command -v jq &> /dev/null; then
            colorize yellow "Retrieving IPv4 details..." bold
            IP_INFO=$(curl -sS "http://ipwhois.app/json/$IPV4_ADDRESS")
            
            if [ -n "$IP_INFO" ]; then
                COUNTRY=$(echo "$IP_INFO" | jq -r '.country')
                REGION=$(echo "$IP_INFO" | jq -r '.region')
                CITY=$(echo "$IP_INFO" | jq -r '.city')
                ISP=$(echo "$IP_INFO" | jq -r '.isp')
                
                echo
                echo "Country: $COUNTRY"
                echo "Region: $REGION"
                echo "City: $CITY"
                echo "ISP: $ISP"
            fi
        fi
    fi
    
    # Display IPv6 if available
    if [ -n "$IPV6_ADDRESS" ]; then
        echo
        colorize green "Your current external IPv6 address is:" bold
        echo
        colorize cyan "$IPV6_ADDRESS" bold
    else
        echo
        colorize yellow "No IPv6 address detected." bold
    fi
    
    echo
    press_key
}

# Install the Gaming Tunnel components
install_gamingtunnel

# Function to install jq if not already installed
install_jq() {
    if ! command -v jq &> /dev/null; then
        # Check if the system is using apt package manager
        if command -v apt-get &> /dev/null; then
            echo -e "${RED}jq is not installed. Installing...${NC}"
            sleep 1
            sudo apt-get update
            sudo apt-get install -y jq
        else
            echo -e "${RED}Error: Unsupported package manager. Please install jq manually.${NC}\n"
            read -p "Press any key to continue..."
            exit 1
        fi
    fi
}

# Install jq
install_jq

# TinyVPN Config Database
TINYVPN_CONFIG_DIR="/root/gamingtunnel/configs"
TINYVPN_CONFIG_DB="$TINYVPN_CONFIG_DIR/tinyvpn_configs.json"

# Initialize TinyVPN config database if it doesn't exist
initialize_tinyvpn_config_db() {
    # Create config directory if it doesn't exist
    if [ ! -d "$TINYVPN_CONFIG_DIR" ]; then
        mkdir -p "$TINYVPN_CONFIG_DIR"
    fi
    
    # Create config database if it doesn't exist
    if [ ! -f "$TINYVPN_CONFIG_DB" ]; then
        echo '{
            "server_configs": [],
            "client_configs": []
        }' > "$TINYVPN_CONFIG_DB"
    fi
}

configure_tinyvpn_server_multi() {
    initialize_tinyvpn_config_db
    
    clear
    colorize cyan "Configure TinyVPN Server" bold
    echo
    
    # Get a unique name for this server configuration
    echo -ne "[*] Enter a name for this server configuration: "
    read -r CONFIG_NAME
    if [ -z "$CONFIG_NAME" ]; then
        colorize red "Configuration name is required." bold
        sleep 2
        return 1
    fi
    
    # Sanitize the name to be safe for a filename
    CONFIG_NAME=$(echo "$CONFIG_NAME" | tr -cd '[:alnum:]-_')
    
    # Create unique service file path
    SERVICE_FILE_MULTI="/etc/systemd/system/tinyvpn-server-${CONFIG_NAME}.service"
    
    # Check if service already exists
    if [ -f "$SERVICE_FILE_MULTI" ]; then
        colorize red "A TinyVPN server with name '${CONFIG_NAME}' already exists." bold
        sleep 2
        return 1
    fi
    
    echo
    
    # Tunnel Port - check for existing ports in the database
    echo -ne "[-] Tunnel Port (default 4096): "
    read -r PORT
    if [ -z "$PORT" ]; then
        colorize yellow "Tunnel port 4096 selected by default."
        PORT=4096
    fi
    
    # Check if port is already in use by the system
    if command -v ss &> /dev/null; then
        # Using ss command (newer systems)
        PORT_CHECK=$(ss -tuln | grep ":$PORT ")
    elif command -v netstat &> /dev/null; then
        # Using netstat command (older systems)
        PORT_CHECK=$(netstat -tuln | grep ":$PORT ")
    else
        # If neither command is available, use a less reliable method
        PORT_CHECK=$(lsof -i:$PORT 2>/dev/null)
    fi
    
    if [ -n "$PORT_CHECK" ]; then
        colorize red "ERROR: Port $PORT is already in use!" bold
        colorize yellow "Please choose a different port number." bold
        echo
        echo "$PORT_CHECK"
        echo
        sleep 2
        return 1
    fi
    
    # Check if port is already used by another TinyVPN config
    if [ -f "$TINYVPN_CONFIG_DB" ]; then
        local EXISTING_PORTS=$(jq -r '.server_configs[].port' "$TINYVPN_CONFIG_DB" 2>/dev/null)
        if echo "$EXISTING_PORTS" | grep -q "^$PORT$"; then
            colorize red "ERROR: Port $PORT is already used by another TinyVPN configuration!" bold
            colorize yellow "Please choose a different port number." bold
            echo
            sleep 2
            return 1
        fi
    fi
    
    echo
    
    # FEC Value
    echo -ne "[-] FEC value (with x:y format, default 2:1, enter 0 to disable): "
    read -r FEC
    if [ -z "$FEC" ]; then
    	colorize yellow "FEC set to 2:1"
        FEC="-f2:1"
    elif [[ "$FEC" == "0" ]]; then
   	    colorize yellow "FEC is disabled"
    	FEC="--disable-fec"
	else
		FEC="-f${FEC}"
    fi
  
    echo
    
    # Subnet address - generate a unique one if not specified
    echo -ne "[-] Subnet Address (leave empty for automatic unique subnet): "
    read -r SUBNET
    if [ -z "$SUBNET" ]; then
        # Get existing subnets
        local EXISTING_SUBNETS=""
        if [ -f "$TINYVPN_CONFIG_DB" ]; then
            EXISTING_SUBNETS=$(jq -r '.server_configs[].subnet' "$TINYVPN_CONFIG_DB" 2>/dev/null)
        fi
        
        # Generate a random subnet that doesn't conflict
        local SUBNET_BASE="10.22"
        local RANDOM_OCTET=0
        local MAX_ATTEMPTS=50
        local ATTEMPT=0
        
        while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
            RANDOM_OCTET=$((1 + RANDOM % 254))
            SUBNET="${SUBNET_BASE}.${RANDOM_OCTET}.0"
            
            if ! echo "$EXISTING_SUBNETS" | grep -q "^$SUBNET$"; then
                break
            fi
            
            ATTEMPT=$((ATTEMPT + 1))
        done
        
        if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
            colorize red "Failed to generate a unique subnet after $MAX_ATTEMPTS attempts." bold
            sleep 2
            return 1
        fi
        
        colorize yellow "Generated unique subnet: $SUBNET"
    else
        # Check if subnet is already used
        if [ -f "$TINYVPN_CONFIG_DB" ]; then
            local EXISTING_SUBNETS=$(jq -r '.server_configs[].subnet' "$TINYVPN_CONFIG_DB" 2>/dev/null)
            if echo "$EXISTING_SUBNETS" | grep -q "^$SUBNET$"; then
                colorize red "ERROR: Subnet $SUBNET is already used by another TinyVPN configuration!" bold
                colorize yellow "Please choose a different subnet." bold
                echo
                sleep 2
                return 1
            fi
        fi
    fi
    
    echo
    
    # Mode
    echo -ne "[-] Mode (0 for non-game usage, 1 for game usage): "
    read -r MODE
    if [ -z "$MODE" ]; then
    	colorize yellow "Optimized for gaming usage by default."
        MODE="--mode 1 --timeout 1"
    elif [[ "$MODE" = "0" ]]; then
    	colorize yellow "Optimized for non-gaming usage."
    	MODE="--mode 0 --timeout 4"
    else
       	colorize yellow "Optimized for gaming usage."
        MODE="--mode 1 --timeout 1"   	
    fi
    
    echo
    
    # MTU Value
    echo -ne "[-] MTU value (default 1250, enter 0 to skip): "
    read -r MTU_VALUE
    if [ -z "$MTU_VALUE" ] || [ "$MTU_VALUE" = "0" ]; then
        colorize yellow "MTU parameter will be skipped."
        MTU=""
    else
        colorize yellow "MTU set to $MTU_VALUE."
        MTU="--mtu $MTU_VALUE"
    fi
    
    # TUN device name
    TUN_DEV="gaming-${CONFIG_NAME}"
    colorize yellow "Using TUN device name: ${TUN_DEV}"
    
    # Final command
    COMMAND="-s -l[::]:$PORT $FEC --sub-net $SUBNET $MTU $MODE --tun-dev $TUN_DEV --disable-obscure"
    
    # Save this configuration to the database
    if [ -f "$TINYVPN_CONFIG_DB" ]; then
        # Create a temporary file for the new config
        local TEMP_CONFIG=$(mktemp)
        jq --arg name "$CONFIG_NAME" \
           --arg port "$PORT" \
           --arg subnet "$SUBNET" \
           --arg tun_dev "$TUN_DEV" \
           --arg command "$COMMAND" \
           --arg service "$SERVICE_FILE_MULTI" \
           '.server_configs += [{"name": $name, "port": $port, "subnet": $subnet, "tun_dev": $tun_dev, "command": $command, "service": $service}]' \
           "$TINYVPN_CONFIG_DB" > "$TEMP_CONFIG"
        
        # Replace the original file with the updated one
        mv "$TEMP_CONFIG" "$TINYVPN_CONFIG_DB"
    fi
    
    # Create the systemd service unit file
    cat << EOF > "$SERVICE_FILE_MULTI"
[Unit]
Description=TinyVPN Server (${CONFIG_NAME})
After=network.target
Wants=network.target

[Service]
Type=simple
WorkingDirectory=$CONFIG_DIR
ExecStart=$CONFIG_DIR/tinyvpn $COMMAND
Restart=always
RestartSec=1
LimitNOFILE=infinity

# Logging configuration
StandardOutput=append:/var/log/tinyvpn-server-${CONFIG_NAME}.log
StandardError=append:/var/log/tinyvpn-server-${CONFIG_NAME}.error.log

# Optional: log rotation to prevent huge log files
LogRateLimitIntervalSec=0
LogRateLimitBurst=0

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload &> /dev/null
    systemctl enable "tinyvpn-server-${CONFIG_NAME}" &> /dev/null
    systemctl start "tinyvpn-server-${CONFIG_NAME}" &> /dev/null
    
    # Check if service started successfully
    if ! systemctl is-active --quiet "tinyvpn-server-${CONFIG_NAME}"; then
        colorize red "TinyVPN server for '${CONFIG_NAME}' failed to start. Checking logs..." bold
        if [ -f "/var/log/tinyvpn-server-${CONFIG_NAME}.error.log" ]; then
            echo "Last 10 lines of error log:"
            tail -n 10 "/var/log/tinyvpn-server-${CONFIG_NAME}.error.log"
        fi
        colorize yellow "For more details, check: /var/log/tinyvpn-server-${CONFIG_NAME}.log and /var/log/tinyvpn-server-${CONFIG_NAME}.error.log" bold
    else
        colorize green "TinyVPN server for '${CONFIG_NAME}' started successfully." bold
        echo
        colorize yellow "Server Configuration Summary:" bold
        echo "Configuration Name: $CONFIG_NAME"
        echo "Listening Port: $PORT"
        echo "Subnet: $SUBNET"
        echo "TUN Device: $TUN_DEV"
    fi
    
    echo
    press_key
}

configure_tinyvpn_client_multi_v2() {
    initialize_tinyvpn_config_db
    
    clear
    colorize cyan "Configure TinyVPN Client" bold
    echo
    
    # Get a unique name for this client configuration
    echo -ne "[*] Enter a name for this client configuration: "
    read -r CONFIG_NAME
    if [ -z "$CONFIG_NAME" ]; then
        colorize red "Configuration name is required." bold
        sleep 2
        return 1
    fi
    
    # Sanitize the name to be safe for a filename
    CONFIG_NAME=$(echo "$CONFIG_NAME" | tr -cd '[:alnum:]-_')
    
    # Create unique service file path
    SERVICE_FILE_MULTI="/etc/systemd/system/tinyvpn-client-${CONFIG_NAME}.service"
    
    # Check if service already exists
    if [ -f "$SERVICE_FILE_MULTI" ]; then
        colorize red "A TinyVPN client with name '${CONFIG_NAME}' already exists." bold
        sleep 2
        return 1
    fi
    
    echo
    
    # Remote Server Address
    echo -ne "[*] Remote server address (in IPv4 or [IPv6] format): "
    read -r SERVER_IP
    if [ -z "$SERVER_IP" ]; then
        colorize red "Enter a valid IP address..." bold
        sleep 2
        return 1
    fi
    
    echo
    
    # Tunnel Port
    echo -ne "[-] Remote Server Port (default 4096): "
    read -r PORT
    if [ -z "$PORT" ]; then
        colorize yellow "Remote server port 4096 selected by default."
        PORT=4096
    fi
    
    echo
    
    # FEC Value
    echo -ne "[-] FEC value (with x:y format, default 2:1, enter 0 to disable): "
    read -r FEC
    if [ -z "$FEC" ]; then
        colorize yellow "FEC set to 2:1"
        FEC="-f2:1"
    elif [[ "$FEC" == "0" ]]; then
        colorize yellow "FEC is disabled"
        FEC="--disable-fec"
    else
        FEC="-f${FEC}"
    fi

    echo
    
    # Subnet address - try to match server subnet if known
    local SUGGESTED_SUBNET=""
    local SERVER_CONFIGS=()
    
    if [ -f "$TINYVPN_CONFIG_DB" ]; then
        # Get a list of server configurations to suggest matching subnet
        SERVER_CONFIGS=($(jq -r '.server_configs[] | "\(.name):\(.subnet)"' "$TINYVPN_CONFIG_DB" 2>/dev/null))
        
        if [ ${#SERVER_CONFIGS[@]} -gt 0 ]; then
            echo "Available server configurations:"
            for i in "${!SERVER_CONFIGS[@]}"; do
                echo "  $((i+1)). ${SERVER_CONFIGS[$i]}"
            done
            
            echo -ne "[*] Enter server number to match configuration (or press enter to skip): "
            read -r SERVER_NUM
            
            if [ -n "$SERVER_NUM" ] && [ "$SERVER_NUM" -ge 1 ] && [ "$SERVER_NUM" -le ${#SERVER_CONFIGS[@]} ]; then
                SELECTED_SERVER="${SERVER_CONFIGS[$((SERVER_NUM-1))]}"
                SUGGESTED_SUBNET=$(echo "$SELECTED_SERVER" | cut -d':' -f2)
                colorize yellow "Using subnet from selected server: $SUGGESTED_SUBNET"
            fi
        fi
    fi
    
    if [ -z "$SUGGESTED_SUBNET" ]; then
        echo -ne "[-] Subnet Address (leave empty for automatic unique subnet): "
        read -r SUBNET
        
        if [ -z "$SUBNET" ]; then
            # Generate a random subnet that doesn't conflict
            local EXISTING_SUBNETS=""
            if [ -f "$TINYVPN_CONFIG_DB" ]; then
                EXISTING_SUBNETS=$(jq -r '.client_configs[].subnet' "$TINYVPN_CONFIG_DB" 2>/dev/null)
            fi
            
            local SUBNET_BASE="10.22"
            local RANDOM_OCTET=0
            local MAX_ATTEMPTS=50
            local ATTEMPT=0
            
            while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
                RANDOM_OCTET=$((1 + RANDOM % 254))
                SUBNET="${SUBNET_BASE}.${RANDOM_OCTET}.0"
                
                if ! echo "$EXISTING_SUBNETS" | grep -q "^$SUBNET$"; then
                    break
                fi
                
                ATTEMPT=$((ATTEMPT + 1))
            done
            
            if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
                colorize red "Failed to generate a unique subnet after $MAX_ATTEMPTS attempts." bold
                sleep 2
                return 1
            fi
            
            colorize yellow "Generated unique subnet: $SUBNET"
        fi
    else
        SUBNET=$SUGGESTED_SUBNET
    fi
    
    echo
    
    # Mode
    echo -ne "[-] Mode (0 for non-game usage, 1 for game usage): "
    read -r MODE
    if [ -z "$MODE" ]; then
        colorize yellow "Optimized for gaming usage by default."
        MODE="--mode 1 --timeout 1"
    elif [[ "$MODE" = "0" ]]; then
        colorize yellow "Optimized for non-gaming usage."
        MODE="--mode 0 --timeout 4"
    else
        colorize yellow "Optimized for gaming usage."
        MODE="--mode 1 --timeout 1"    
    fi
    
    echo
    
    # MTU Value
    echo -ne "[-] MTU value (default 1250, enter 0 to skip): "
    read -r MTU_VALUE
    if [ -z "$MTU_VALUE" ] || [ "$MTU_VALUE" = "0" ]; then
        colorize yellow "MTU parameter will be skipped."
        MTU=""
    else
        colorize yellow "MTU set to $MTU_VALUE."
        MTU="--mtu $MTU_VALUE"
    fi
    
    # TUN device name
    TUN_DEV="gaming-${CONFIG_NAME}"
    colorize yellow "Using TUN device name: ${TUN_DEV}"
    
    # Final command
    COMMAND="-c -r${SERVER_IP}:${PORT} $FEC --sub-net $SUBNET $MTU $MODE --tun-dev $TUN_DEV --keep-reconnect --disable-obscure"
    
    # Save this configuration to the database
    if [ -f "$TINYVPN_CONFIG_DB" ]; then
        # Create a temporary file for the new config
        local TEMP_CONFIG=$(mktemp)
        jq --arg name "$CONFIG_NAME" \
           --arg server_ip "$SERVER_IP" \
           --arg port "$PORT" \
           --arg subnet "$SUBNET" \
           --arg tun_dev "$TUN_DEV" \
           --arg command "$COMMAND" \
           --arg service "$SERVICE_FILE_MULTI" \
           '.client_configs += [{"name": $name, "server_ip": $server_ip, "port": $port, "subnet": $subnet, "tun_dev": $tun_dev, "command": $command, "service": $service}]' \
           "$TINYVPN_CONFIG_DB" > "$TEMP_CONFIG"
        
        # Replace the original file with the updated one
        mv "$TEMP_CONFIG" "$TINYVPN_CONFIG_DB"
    fi
    
    # Create the systemd service unit file
    cat << EOF > "$SERVICE_FILE_MULTI"
[Unit]
Description=TinyVPN Client (${CONFIG_NAME})
After=network.target
Wants=network.target

[Service]
Type=simple
WorkingDirectory=$CONFIG_DIR
ExecStart=$CONFIG_DIR/tinyvpn $COMMAND
Restart=always
RestartSec=1
LimitNOFILE=infinity

# Logging configuration
StandardOutput=append:/var/log/tinyvpn-client-${CONFIG_NAME}.log
StandardError=append:/var/log/tinyvpn-client-${CONFIG_NAME}.error.log

# Optional: log rotation to prevent huge log files
LogRateLimitIntervalSec=0
LogRateLimitBurst=0

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload &> /dev/null
    systemctl enable "tinyvpn-client-${CONFIG_NAME}" &> /dev/null
    systemctl start "tinyvpn-client-${CONFIG_NAME}" &> /dev/null
    
    # Check if service started successfully
    if ! systemctl is-active --quiet "tinyvpn-client-${CONFIG_NAME}"; then
        colorize red "TinyVPN client for '${CONFIG_NAME}' failed to start. Checking logs..." bold
        if [ -f "/var/log/tinyvpn-client-${CONFIG_NAME}.error.log" ]; then
            echo "Last 10 lines of error log:"
            tail -n 10 "/var/log/tinyvpn-client-${CONFIG_NAME}.error.log"
        fi
        colorize yellow "For more details, check: /var/log/tinyvpn-client-${CONFIG_NAME}.log and /var/log/tinyvpn-client-${CONFIG_NAME}.error.log" bold
    else
        colorize green "TinyVPN client for '${CONFIG_NAME}' started successfully." bold
        echo
        colorize yellow "Client Configuration Summary:" bold
        echo "Configuration Name: $CONFIG_NAME"
        echo "Remote Server: $SERVER_IP:$PORT"
        echo "Subnet: $SUBNET"
        echo "TUN Device: $TUN_DEV"
    fi
    
    echo
    press_key
}

list_tinyvpn_configs() {
    initialize_tinyvpn_config_db
    
    clear
    colorize cyan "TinyVPN Configurations" bold
    echo
    
    if [ ! -f "$TINYVPN_CONFIG_DB" ]; then
        colorize yellow "No TinyVPN configurations found." bold
        echo
        press_key
        return 0
    fi
    
    # Extract server configurations
    local SERVER_CONFIGS=($(jq -r '.server_configs[].name' "$TINYVPN_CONFIG_DB" 2>/dev/null))
    
    if [ ${#SERVER_CONFIGS[@]} -gt 0 ]; then
        colorize green "Server Configurations:" bold
        echo
        
        for i in "${!SERVER_CONFIGS[@]}"; do
            local server_name="${SERVER_CONFIGS[$i]}"
            local server_port=$(jq -r ".server_configs[] | select(.name == \"$server_name\") | .port" "$TINYVPN_CONFIG_DB")
            local server_subnet=$(jq -r ".server_configs[] | select(.name == \"$server_name\") | .subnet" "$TINYVPN_CONFIG_DB")
            local server_service=$(jq -r ".server_configs[] | select(.name == \"$server_name\") | .service" "$TINYVPN_CONFIG_DB")
            
            # Check service status
            local status="inactive"
            if systemctl is-active --quiet "tinyvpn-server-${server_name}"; then
                status="active"
            fi
            
            if [ "$status" = "active" ]; then
                colorize cyan " $((i+1)). $server_name" bold
                colorize green "    Status: $status" bold
            else
                colorize cyan " $((i+1)). $server_name" bold
                colorize red "    Status: $status" bold
            fi
            
            echo "    Port: $server_port"
            echo "    Subnet: $server_subnet"
            echo
        done
    else
        colorize yellow "No server configurations found." bold
        echo
    fi
    
    # Extract client configurations
    local CLIENT_CONFIGS=($(jq -r '.client_configs[].name' "$TINYVPN_CONFIG_DB" 2>/dev/null))
    
    if [ ${#CLIENT_CONFIGS[@]} -gt 0 ]; then
        colorize green "Client Configurations:" bold
        echo
        
        for i in "${!CLIENT_CONFIGS[@]}"; do
            local client_name="${CLIENT_CONFIGS[$i]}"
            local client_server=$(jq -r ".client_configs[] | select(.name == \"$client_name\") | .server_ip" "$TINYVPN_CONFIG_DB")
            local client_port=$(jq -r ".client_configs[] | select(.name == \"$client_name\") | .port" "$TINYVPN_CONFIG_DB")
            local client_subnet=$(jq -r ".client_configs[] | select(.name == \"$client_name\") | .subnet" "$TINYVPN_CONFIG_DB")
            
            # Check service status
            local status="inactive"
            if systemctl is-active --quiet "tinyvpn-client-${client_name}"; then
                status="active"
            fi
            
            if [ "$status" = "active" ]; then
                colorize cyan " $((i+1)). $client_name" bold
                colorize green "    Status: $status" bold
            else
                colorize cyan " $((i+1)). $client_name" bold
                colorize red "    Status: $status" bold
            fi
            
            echo "    Server: $client_server:$client_port"
            echo "    Subnet: $client_subnet"
            echo
        done
    else
        colorize yellow "No client configurations found." bold
        echo
    fi
    
    press_key
}

manage_tinyvpn_config() {
    initialize_tinyvpn_config_db
    
    clear
    colorize cyan "Manage TinyVPN Configuration" bold
    echo
    
    if [ ! -f "$TINYVPN_CONFIG_DB" ]; then
        colorize yellow "No TinyVPN configurations found." bold
        echo
        press_key
        return 0
    fi
    
    # Combined list of configs
    local ALL_CONFIGS=()
    local CONFIG_TYPES=()
    
    # First get server configs
    local SERVER_CONFIGS=($(jq -r '.server_configs[].name' "$TINYVPN_CONFIG_DB" 2>/dev/null))
    for server in "${SERVER_CONFIGS[@]}"; do
        ALL_CONFIGS+=("$server")
        CONFIG_TYPES+=("server")
    done
    
    # Then client configs
    local CLIENT_CONFIGS=($(jq -r '.client_configs[].name' "$TINYVPN_CONFIG_DB" 2>/dev/null))
    for client in "${CLIENT_CONFIGS[@]}"; do
        ALL_CONFIGS+=("$client")
        CONFIG_TYPES+=("client")
    done
    
    if [ ${#ALL_CONFIGS[@]} -eq 0 ]; then
        colorize yellow "No configurations found." bold
        echo
        press_key
        return 0
    fi
    
    echo "Available configurations:"
    for i in "${!ALL_CONFIGS[@]}"; do
        local name="${ALL_CONFIGS[$i]}"
        local type="${CONFIG_TYPES[$i]}"
        local status="inactive"
        
        if [ "$type" = "server" ]; then
            if systemctl is-active --quiet "tinyvpn-server-${name}"; then
                status="active"
            fi
            
            if [ "$status" = "active" ]; then
                colorize green " $((i+1)). [Server] $name ($status)" bold
            else
                colorize red " $((i+1)). [Server] $name ($status)" bold
            fi
        else
            if systemctl is-active --quiet "tinyvpn-client-${name}"; then
                status="active"
            fi
            
            if [ "$status" = "active" ]; then
                colorize green " $((i+1)). [Client] $name ($status)" bold
            else
                colorize red " $((i+1)). [Client] $name ($status)" bold
            fi
        fi
    done
    
    echo
    echo -ne "[*] Enter configuration number to manage (0 to go back): "
    read -r CONFIG_NUM
    
    if [ -z "$CONFIG_NUM" ] || [ "$CONFIG_NUM" -eq 0 ]; then
        return 0
    fi
    
    if [ "$CONFIG_NUM" -ge 1 ] && [ "$CONFIG_NUM" -le ${#ALL_CONFIGS[@]} ]; then
        local selected_name="${ALL_CONFIGS[$((CONFIG_NUM-1))]}"
        local selected_type="${CONFIG_TYPES[$((CONFIG_NUM-1))]}"
        
        manage_tinyvpn_config_actions "$selected_name" "$selected_type"
    else
        colorize red "Invalid selection." bold
        sleep 2
    fi
}

manage_tinyvpn_config_actions() {
    local config_name="$1"
    local config_type="$2"
    local service_prefix="tinyvpn-${config_type}"
    
    while true; do
        clear
        if [ "$config_type" = "server" ]; then
            colorize cyan "Managing TinyVPN Server: $config_name" bold
        else
            colorize cyan "Managing TinyVPN Client: $config_name" bold
        fi
        echo
        
        # Get current status
        local status="inactive"
        if systemctl is-active --quiet "${service_prefix}-${config_name}"; then
            status="active"
        fi
        
        if [ "$status" = "active" ]; then
            colorize green "Status: $status" bold
        else
            colorize red "Status: $status" bold
        fi
        
        echo
        echo "1. View Configuration"
        
        if [ "$status" = "active" ]; then
            echo "2. Stop Service"
        else
            echo "2. Start Service"
        fi
        
        echo "3. Restart Service"
        echo "4. View Logs"
        echo "5. Delete Configuration"
        echo "0. Back"
        echo
        
        echo -ne "Enter option: "
        read -r option
        
        case $option in
            1)
                clear
                colorize cyan "Configuration Details:" bold
                echo
                
                if [ "$config_type" = "server" ]; then
                    local config=$(jq -r ".server_configs[] | select(.name == \"$config_name\")" "$TINYVPN_CONFIG_DB")
                    
                    echo "Name: $config_name"
                    echo "Type: Server"
                    echo "Port: $(echo "$config" | jq -r '.port')"
                    echo "Subnet: $(echo "$config" | jq -r '.subnet')"
                    echo "TUN Device: $(echo "$config" | jq -r '.tun_dev')"
                    echo "Command: $(echo "$config" | jq -r '.command')"
                    echo "Service File: $(echo "$config" | jq -r '.service')"
                else
                    local config=$(jq -r ".client_configs[] | select(.name == \"$config_name\")" "$TINYVPN_CONFIG_DB")
                    
                    echo "Name: $config_name"
                    echo "Type: Client"
                    echo "Server: $(echo "$config" | jq -r '.server_ip'):$(echo "$config" | jq -r '.port')"
                    echo "Subnet: $(echo "$config" | jq -r '.subnet')"
                    echo "TUN Device: $(echo "$config" | jq -r '.tun_dev')"
                    echo "Command: $(echo "$config" | jq -r '.command')"
                    echo "Service File: $(echo "$config" | jq -r '.service')"
                fi
                
                echo
                press_key
                ;;
            2)
                if [ "$status" = "active" ]; then
                    systemctl stop "${service_prefix}-${config_name}" &>/dev/null
                    colorize yellow "Stopping ${config_type} service for $config_name..." bold
                    sleep 2
                    
                    if ! systemctl is-active --quiet "${service_prefix}-${config_name}"; then
                        colorize green "Service stopped successfully." bold
                    else
                        colorize red "Failed to stop service." bold
                    fi
                else
                    systemctl start "${service_prefix}-${config_name}" &>/dev/null
                    colorize yellow "Starting ${config_type} service for $config_name..." bold
                    sleep 2
                    
                    if systemctl is-active --quiet "${service_prefix}-${config_name}"; then
                        colorize green "Service started successfully." bold
                    else
                        colorize red "Failed to start service." bold
                        colorize yellow "Checking logs:" bold
                        journalctl -xeu "${service_prefix}-${config_name}" | tail -n 10
                    fi
                fi
                
                sleep 2
                ;;
            3)
                systemctl restart "${service_prefix}-${config_name}" &>/dev/null
                colorize yellow "Restarting ${config_type} service for $config_name..." bold
                sleep 2
                
                if systemctl is-active --quiet "${service_prefix}-${config_name}"; then
                    colorize green "Service restarted successfully." bold
                else
                    colorize red "Failed to restart service." bold
                    colorize yellow "Checking logs:" bold
                    journalctl -xeu "${service_prefix}-${config_name}" | tail -n 10
                fi
                
                sleep 2
                ;;
            4)
                clear
                colorize cyan "Log for ${config_type} $config_name:" bold
                echo
                
                local log_file="/var/log/${service_prefix}-${config_name}.log"
                local error_log_file="/var/log/${service_prefix}-${config_name}.error.log"
                
                if [ -f "$log_file" ]; then
                    tail -n 50 "$log_file"
                else
                    journalctl -xeu "${service_prefix}-${config_name}" | tail -n 50
                fi
                
                echo
                colorize cyan "Error log:" bold
                echo
                
                if [ -f "$error_log_file" ]; then
                    tail -n 20 "$error_log_file"
                else
                    colorize yellow "No error log file found." bold
                fi
                
                echo
                press_key
                ;;
            5)
                clear
                colorize red "Delete Configuration" bold
                echo
                
                echo -ne "Are you sure you want to delete the ${config_type} configuration '$config_name'? (y/N): "
                read -r confirm
                
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    # Stop the service
                    systemctl stop "${service_prefix}-${config_name}" &>/dev/null
                    systemctl disable "${service_prefix}-${config_name}" &>/dev/null
                    
                    # Remove the service file
                    local service_file=$(jq -r ".${config_type}_configs[] | select(.name == \"$config_name\") | .service" "$TINYVPN_CONFIG_DB")
                    if [ -f "$service_file" ]; then
                        rm -f "$service_file"
                    fi
                    
                    # Remove from database
                    local TEMP_CONFIG=$(mktemp)
                    if [ "$config_type" = "server" ]; then
                        jq --arg name "$config_name" '.server_configs = [.server_configs[] | select(.name != $name)]' "$TINYVPN_CONFIG_DB" > "$TEMP_CONFIG"
                    else
                        jq --arg name "$config_name" '.client_configs = [.client_configs[] | select(.name != $name)]' "$TINYVPN_CONFIG_DB" > "$TEMP_CONFIG"
                    fi
                    
                    # Replace the original file with the updated one
                    mv "$TEMP_CONFIG" "$TINYVPN_CONFIG_DB"
                    
                    systemctl daemon-reload &>/dev/null
                    
                    colorize green "Configuration deleted successfully." bold
                    sleep 2
                    return 0
                else
                    colorize yellow "Deletion cancelled." bold
                    sleep 2
                fi
                ;;
            0)
                return 0
                ;;
            *)
                colorize red "Invalid option." bold
                sleep 2
                ;;
        esac
    done
}

tinyvpn_menu() {
    initialize_tinyvpn_config_db
    
    while true; do
        clear
        colorize cyan "════════ TinyVPN Management ════════" bold
        echo
        colorize green "1. Configure TinyVPN Server" bold
        colorize green "2. Configure TinyVPN Client" bold
        colorize green "3. List All Configurations" bold
        colorize green "4. Manage Configurations" bold
        echo
        colorize yellow "0. Back to Main Menu" bold
        echo
        echo "────────────────────────────────────"
        
        echo -ne "Enter option: "
        read -r option
        
        case $option in
            1)
                configure_tinyvpn_server_multi
                ;;
            2)
                configure_tinyvpn_client_multi_v2
                ;;
            3)
                list_tinyvpn_configs
                ;;
            4)
                manage_tinyvpn_config
                ;;
            0)
                return 0
                ;;
            *)
                colorize red "Invalid option." bold
                sleep 2
                ;;
        esac
    done
}
