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
    
    if ! [ -d "$DEST_DIR" ]; then
    	mkdir "$DEST_DIR" &> /dev/null
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


    colorize yellow "Installing GamingVPN Core..." bold
    echo
    curl -L $URL -o $FILE &> /dev/null
    chmod +x $FILE
    
    colorize yellow "Installing UDP2RAW..." bold
    echo
    curl -L $UDP2RAW_URL -o $UDP2RAW_FILE &> /dev/null
    chmod +x $UDP2RAW_FILE
    
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


# Fetch server country
SERVER_COUNTRY=$(curl -sS "http://ipwhois.app/json/$SERVER_IP" | jq -r '.country')

# Fetch server isp 
SERVER_ISP=$(curl -sS "http://ipwhois.app/json/$SERVER_IP" | jq -r '.isp')

# Function to display server location and IP
display_server_info() {
    echo -e "\e[93m═════════════════════════════════════════════\e[0m"  
 	#	Hidden for security issues   
    echo -e "${CYAN}IP Address:${NC} $SERVER_IP"
    echo -e "${CYAN}Location:${NC} $SERVER_COUNTRY "
    echo -e "${CYAN}Datacenter:${NC} $SERVER_ISP"
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

configure_udp2raw_server(){
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
    colorize cyan "Configure UDP2RAW Server" bold
    echo
    
    # External UDP2RAW Port (what clients connect to)
    echo -ne "[-] UDP2RAW external listening port: "
    read -r UDP2RAW_PORT
    if [ -z "$UDP2RAW_PORT" ]; then
        colorize red "UDP2RAW port is required." bold
        sleep 2
        return 1
    fi
    
    # TinyVPN Port
    echo -ne "[-] TinyVPN service port (the port TinyVPN listens on): "
    read -r TINYVPN_PORT
    if [ -z "$TINYVPN_PORT" ]; then
        colorize red "TinyVPN port is required." bold
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
    
    # UDP2RAW command - fixed for server mode with correct port order
    UDP2RAW_COMMAND="-s -l0.0.0.0:${TINYVPN_PORT} -r127.0.0.1:${UDP2RAW_PORT} -a -k \"${UDP2RAW_PASS}\" --cipher-mode xor --auth-mode simple --raw-mode ${UDP2RAW_MODE}"
    
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
    read -r IP
    if [ -z "$IP" ]; then
        colorize red "Enter a valid IP address..." bold
        sleep 2
        return 1
    fi
    
    # NOTE: Changed the parameter names to clarify the intended port usage
    # Local Port for UDP2RAW to listen on
    echo -ne "[-] Local UDP2RAW listening port: "
    read -r LOCAL_PORT
    if [ -z "$LOCAL_PORT" ]; then
        colorize red "Local UDP2RAW port is required." bold
        sleep 2
        return 1
    fi
    
    # Remote TinyVPN port on server
    echo -ne "[-] Remote TinyVPN port on the server: "
    read -r REMOTE_PORT
    if [ -z "$REMOTE_PORT" ]; then
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
    
    # Fixed UDP2RAW command with proper port order
    UDP2RAW_COMMAND="-c -l0.0.0.0:${LOCAL_PORT} -r${IP}:${REMOTE_PORT} -a -k \"${UDP2RAW_PASS}\" --cipher-mode xor --auth-mode simple --raw-mode ${UDP2RAW_MODE}"
    
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
    colorize yellow "NOTE: Configure TinyVPN to connect to 127.0.0.1:${LOCAL_PORT} to use this UDP2RAW tunnel" bold
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
    colorize cyan "═══ CONFIGURATION ═══" bold
    colorize green " 1. TinyVPN Server Configuration" bold
    colorize green " 2. TinyVPN Client Configuration" bold
    colorize green " 3. UDP2RAW Server Configuration" bold
    colorize green " 4. UDP2RAW Client Configuration" bold
    echo
    colorize cyan "═══ SERVICE MANAGEMENT ═══" bold
    colorize magenta " 5. Check TinyVPN service status" 
    colorize magenta " 6. Check UDP2RAW service status" 
    colorize yellow " 7. View TinyVPN logs"
    colorize yellow " 8. View UDP2RAW logs"
    colorize yellow " 9. Restart TinyVPN service" 
    colorize yellow "10. Restart UDP2RAW service" 
    echo
    colorize cyan "═══ REMOVAL ═══" bold
    colorize red "11. Remove TinyVPN service" 
    colorize red "12. Remove UDP2RAW service"
    colorize red "13. Remove all services"
    colorize red "14. Remove core files"
    echo
    colorize cyan "═══ UTILITIES ═══" bold
    colorize magenta "15. Create symlink to script" bold
    echo -e " 0. Exit"
    echo
    echo "-------------------------------"
}

# Function to read user input
read_option() {
    read -p "Enter your choice [0-15]: " choice
    case $choice in
        1) configure_tinyvpn_server ;;
        2) configure_tinyvpn_client ;;
        3) configure_udp2raw_server ;;
        4) configure_udp2raw_client ;;
        5) check_service_status_tinyvpn ;;
        6) check_service_status_udp2raw ;;
	    7) view_logs_tinyvpn ;;
	    8) view_logs_udp2raw ;;
	    9) restart_service_tinyvpn ;;
	    10) restart_service_udp2raw ;;
        11) remove_tinyvpn_service ;;
        12) remove_udp2raw_service ;;
        13) remove_all_services ;;
        14) remove_core ;;
        15) create_symlink ;;
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
