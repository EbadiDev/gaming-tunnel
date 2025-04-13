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

# Get server IP addresses - using more robust methods
get_ip_addresses() {
    # Initialize variables
    local ipv4=""
    local ipv6=""
    
    # Function to validate IPv4 address
    is_valid_ipv4() {
        [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && return 0 || return 1
    }
    
    # Function to validate IPv6 address (basic check)
    is_valid_ipv6() {
        [[ $1 =~ ^[0-9a-fA-F:]+$ ]] && [[ $1 == *:* ]] && return 0 || return 1
    }
    
    # Method 1: Use ip command (most reliable for most servers)
    ipv4=$(ip -4 addr show scope global | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
    ipv6=$(ip -6 addr show scope global | grep -oP '(?<=inet6\s)[0-9a-fA-F:]+' | head -n 1)
    
    # Method 2: Use ifconfig command if available
    if [ -z "$ipv4" ]; then
        if command -v ifconfig >/dev/null 2>&1; then
            ipv4=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n 1)
        fi
    fi
    
    if [ -z "$ipv6" ]; then
        if command -v ifconfig >/dev/null 2>&1; then
            ipv6=$(ifconfig | grep -Eo 'inet6 (addr:)?([0-9a-fA-F:]+)' | grep -Eo '([0-9a-fA-F:]+)' | grep -v '::1' | head -n 1)
        fi
    fi
    
    # Method 3: Use hostname command as fallback
    if [ -z "$ipv4" ]; then
        local ip_list=$(hostname -I)
        for ip in $ip_list; do
            if is_valid_ipv4 "$ip" && [[ ! "$ip" =~ ^127\. ]]; then
                ipv4="$ip"
                break
            fi
        done
    fi
    
    if [ -z "$ipv6" ]; then
        local ip_list=$(hostname -I)
        for ip in $ip_list; do
            if is_valid_ipv6 "$ip" && [[ "$ip" != "::1" ]]; then
                ipv6="$ip"
                break
            fi
        done
    fi
    
    # Method 4: External services as last resort - with multiple fallbacks and error checking
    if [ -z "$ipv4" ]; then
        # List of services to try for IPv4
        local ipv4_services=(
            "https://api.ipify.org"
            "https://ipinfo.io/ip"
            "https://ifconfig.me/ip"
            "https://icanhazip.com"
            "https://ident.me"
            "https://myexternalip.com/raw"
        )
        
        for service in "${ipv4_services[@]}"; do
            local result=$(curl -s -4 --max-time 5 "$service" 2>/dev/null)
            # Check if result is a valid IPv4 and not an HTML error page
            if is_valid_ipv4 "$result" && [[ "$result" != *"<html"* ]] && [[ "$result" != *"<!DOCTYPE"* ]]; then
                ipv4="$result"
                break
            fi
        done
    fi
    
    if [ -z "$ipv6" ]; then
        # List of services to try for IPv6
        local ipv6_services=(
            "https://api6.ipify.org"
            "https://ifconfig.co/ip"
            "https://icanhazip.com"
            "https://ident.me"
        )
        
        for service in "${ipv6_services[@]}"; do
            local result=$(curl -s -6 --max-time 5 "$service" 2>/dev/null)
            # Check if result is a valid IPv6 and not an HTML error page
            if is_valid_ipv6 "$result" && [[ "$result" != *"<html"* ]] && [[ "$result" != *"<!DOCTYPE"* ]]; then
                ipv6="$result"
                break
            fi
        done
    fi
    
    # Assign the detected IP addresses to global variables
    SERVER_IPV4="$ipv4"
    SERVER_IPV6="$ipv6"
}

# Initialize IP addresses
get_ip_addresses

# Fetch server country and ISP (only if IPv4 is available)
if [ -n "$SERVER_IPV4" ] && [[ "$SERVER_IPV4" != *"<html"* ]]; then
    SERVER_COUNTRY=$(curl -sS --max-time 5 "http://ipwhois.app/json/$SERVER_IPV4" 2>/dev/null | jq -r '.country' 2>/dev/null || echo "Unknown")
    SERVER_ISP=$(curl -sS --max-time 5 "http://ipwhois.app/json/$SERVER_IPV4" 2>/dev/null | jq -r '.isp' 2>/dev/null || echo "Unknown")
    
    # Check if valid responses (not HTML error pages)
    if [[ "$SERVER_COUNTRY" == *"<html"* ]] || [[ "$SERVER_COUNTRY" == "null" ]]; then
        SERVER_COUNTRY="Unknown"
    fi
    if [[ "$SERVER_ISP" == *"<html"* ]] || [[ "$SERVER_ISP" == "null" ]]; then
        SERVER_ISP="Unknown"
    fi
else
    SERVER_COUNTRY="Unknown"
    SERVER_ISP="Unknown"
fi

# Function to display server location and IP
display_server_info() {
    echo -e "\e[93m═════════════════════════════════════════════\e[0m"  
    
    if [ -n "$SERVER_IPV4" ] && [[ "$SERVER_IPV4" != *"<html"* ]]; then
        echo -e "${CYAN}IPv4 Address:${NC} $SERVER_IPV4"
    else
        echo -e "${CYAN}IPv4 Address:${NC} ${RED}Not detected${NC}"
    fi
    
    if [ -n "$SERVER_IPV6" ] && [[ "$SERVER_IPV6" != *"<html"* ]]; then
        echo -e "${CYAN}IPv6 Address:${NC} $SERVER_IPV6"
    else
        if [ -z "$SERVER_IPV6" ]; then
            echo -e "${CYAN}IPv6 Address:${NC} ${YELLOW}Not available${NC}"
        else
            echo -e "${CYAN}IPv6 Address:${NC} ${RED}Not detected${NC}"
        fi
    fi
    
    echo -e "${CYAN}Location:${NC} $SERVER_COUNTRY "
    echo -e "${CYAN}Datacenter:${NC} $SERVER_ISP"
}

CONFIG_DIR='/root/gamingtunnel'
CONFIGS_DIR='/root/gamingtunnel/configs'
SERVICE_FILE='/etc/systemd/system/gamingtunnel.service'
UDP2RAW_SERVICE_FILE='/etc/systemd/system/udp2raw.service'

# Function to display Rathole Core installation status
display_gamingtunnel_status() {
    if [[ -f "${CONFIG_DIR}/tinyvpn" ]]; then
        echo -e "${CYAN}GamingVPN:${NC} ${GREEN}Installed${NC}"
    else
        echo -e "${CYAN}GamingVPN:${NC} ${RED}Not installed${NC}"
    fi
    
    # Check if any services are running
    if [ -f "$SERVICE_FILE" ]; then
        if systemctl is-active --quiet gamingtunnel; then
            echo -e "${CYAN}TinyVPN Service:${NC} ${GREEN}Running${NC}"
        else
            echo -e "${CYAN}TinyVPN Service:${NC} ${RED}Installed but not running${NC}"
        fi
    fi
    
    if [ -f "$UDP2RAW_SERVICE_FILE" ]; then
        if systemctl is-active --quiet udp2raw; then
            echo -e "${CYAN}UDP2RAW Service:${NC} ${GREEN}Running${NC}"
        else
            echo -e "${CYAN}UDP2RAW Service:${NC} ${RED}Installed but not running${NC}"
        fi
    fi
    
    echo -e "\e[93m═════════════════════════════════════════════\e[0m"  
}

# Create configs directory if it doesn't exist
ensure_configs_dir() {
    if ! [ -d "$CONFIGS_DIR" ]; then
        mkdir -p "$CONFIGS_DIR" &> /dev/null
    fi
}

# Save a configuration to a profile
save_config() {
    ensure_configs_dir
    
    echo
    echo -ne "[-] Enter profile name to save configuration: "
    read -r PROFILE_NAME
    
    if [ -z "$PROFILE_NAME" ]; then
        colorize red "Profile name cannot be empty." bold
        sleep 2
        return 1
    fi
    
    PROFILE_DIR="$CONFIGS_DIR/$PROFILE_NAME"
    mkdir -p "$PROFILE_DIR" &> /dev/null
    
    # Check if services are running and save their configurations
    if [ -f "$SERVICE_FILE" ]; then
        cp "$SERVICE_FILE" "$PROFILE_DIR/tinyvpn.service"
        colorize green "TinyVPN configuration saved." bold
    else
        colorize yellow "No TinyVPN service found to save." bold
    fi
    
    if [ -f "$UDP2RAW_SERVICE_FILE" ]; then
        cp "$UDP2RAW_SERVICE_FILE" "$PROFILE_DIR/udp2raw.service"
        colorize green "UDP2RAW configuration saved." bold
    else
        colorize yellow "No UDP2RAW service found to save." bold
    fi
    
    colorize green "Configuration saved as profile: $PROFILE_NAME" bold
    sleep 1
}

# List saved configuration profiles
list_configs() {
    ensure_configs_dir
    
    echo
    colorize cyan "Saved Configuration Profiles:" bold
    echo
    
    # Check if there are any profiles
    if [ -z "$(ls -A "$CONFIGS_DIR" 2>/dev/null)" ]; then
        colorize yellow "No saved profiles found." bold
        echo
        press_key
        return 0
    fi
    
    # List all profiles and their components
    for PROFILE in "$CONFIGS_DIR"/*; do
        if [ -d "$PROFILE" ]; then
            PROFILE_NAME=$(basename "$PROFILE")
            echo -e "${CYAN}Profile:${NC} $PROFILE_NAME"
            
            if [ -f "$PROFILE/tinyvpn.service" ]; then
                echo -e "  ${GREEN}• TinyVPN configuration available${NC}"
            fi
            
            if [ -f "$PROFILE/udp2raw.service" ]; then
                echo -e "  ${GREEN}• UDP2RAW configuration available${NC}"
            fi
            
            echo
        fi
    done
    
    press_key
}

# Load a saved configuration profile
load_config() {
    ensure_configs_dir
    
    echo
    # Check if there are any profiles
    if [ -z "$(ls -A "$CONFIGS_DIR" 2>/dev/null)" ]; then
        colorize yellow "No saved profiles found." bold
        echo
        press_key
        return 0
    fi
    
    # List available profiles
    colorize cyan "Available Profiles:" bold
    echo
    
    # Create numbered list of profiles
    PROFILES=()
    i=1
    for PROFILE in "$CONFIGS_DIR"/*; do
        if [ -d "$PROFILE" ]; then
            PROFILE_NAME=$(basename "$PROFILE")
            PROFILES+=("$PROFILE_NAME")
            echo -e "$i. $PROFILE_NAME"
            i=$((i+1))
        fi
    done
    
    echo
    echo -ne "[-] Select profile number to load (or 0 to cancel): "
    read -r SELECTION
    
    # Check if selection is valid
    if [[ "$SELECTION" =~ ^[0-9]+$ ]]; then
        if [ "$SELECTION" -eq 0 ]; then
            return 0
        elif [ "$SELECTION" -le "${#PROFILES[@]}" ]; then
            PROFILE_NAME="${PROFILES[$SELECTION-1]}"
            PROFILE_DIR="$CONFIGS_DIR/$PROFILE_NAME"
            
            # Stop current services if running
            if [ -f "$SERVICE_FILE" ]; then
                systemctl stop gamingtunnel &> /dev/null
                systemctl disable gamingtunnel &> /dev/null
            fi
            
            if [ -f "$UDP2RAW_SERVICE_FILE" ]; then
                systemctl stop udp2raw &> /dev/null
                systemctl disable udp2raw &> /dev/null
            fi
            
            # Load TinyVPN service if available
            if [ -f "$PROFILE_DIR/tinyvpn.service" ]; then
                cp "$PROFILE_DIR/tinyvpn.service" "$SERVICE_FILE"
                systemctl daemon-reload &> /dev/null
                systemctl enable gamingtunnel &> /dev/null
                systemctl start gamingtunnel &> /dev/null
                
                if systemctl is-active --quiet gamingtunnel; then
                    colorize green "TinyVPN service loaded and started successfully." bold
                else
                    colorize red "TinyVPN service failed to start." bold
                fi
            else
                colorize yellow "No TinyVPN configuration in this profile." bold
            fi
            
            # Load UDP2RAW service if available
            if [ -f "$PROFILE_DIR/udp2raw.service" ]; then
                cp "$PROFILE_DIR/udp2raw.service" "$UDP2RAW_SERVICE_FILE"
                systemctl daemon-reload &> /dev/null
                systemctl enable udp2raw &> /dev/null
                systemctl start udp2raw &> /dev/null
                
                if systemctl is-active --quiet udp2raw; then
                    colorize green "UDP2RAW service loaded and started successfully." bold
                else
                    colorize red "UDP2RAW service failed to start." bold
                fi
            else
                colorize yellow "No UDP2RAW configuration in this profile." bold
            fi
            
            colorize green "Profile $PROFILE_NAME loaded." bold
        else
            colorize red "Invalid selection." bold
        fi
    else
        colorize red "Invalid input. Please enter a number." bold
    fi
    
    sleep 2
}

# Delete a saved configuration profile
delete_config() {
    ensure_configs_dir
    
    echo
    # Check if there are any profiles
    if [ -z "$(ls -A "$CONFIGS_DIR" 2>/dev/null)" ]; then
        colorize yellow "No saved profiles found." bold
        echo
        press_key
        return 0
    fi
    
    # List available profiles
    colorize cyan "Available Profiles:" bold
    echo
    
    # Create numbered list of profiles
    PROFILES=()
    i=1
    for PROFILE in "$CONFIGS_DIR"/*; do
        if [ -d "$PROFILE" ]; then
            PROFILE_NAME=$(basename "$PROFILE")
            PROFILES+=("$PROFILE_NAME")
            echo -e "$i. $PROFILE_NAME"
            i=$((i+1))
        fi
    done
    
    echo
    echo -ne "[-] Select profile number to delete (or 0 to cancel): "
    read -r SELECTION
    
    # Check if selection is valid
    if [[ "$SELECTION" =~ ^[0-9]+$ ]]; then
        if [ "$SELECTION" -eq 0 ]; then
            return 0
        elif [ "$SELECTION" -le "${#PROFILES[@]}" ]; then
            PROFILE_NAME="${PROFILES[$SELECTION-1]}"
            PROFILE_DIR="$CONFIGS_DIR/$PROFILE_NAME"
            
            echo -ne "[-] Are you sure you want to delete profile '$PROFILE_NAME'? (y/n): "
            read -r CONFIRM
            
            if [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]]; then
                rm -rf "$PROFILE_DIR"
                colorize green "Profile $PROFILE_NAME deleted." bold
            else
                colorize yellow "Deletion cancelled." bold
            fi
        else
            colorize red "Invalid selection." bold
        fi
    else
        colorize red "Invalid input. Please enter a number." bold
    fi
    
    sleep 2
}

configure_tinyvpn_server() {
    # Check if service or config file existing and returns
    echo 
    if [ -f "$SERVICE_FILE" ]; then
    	colorize red "TinyVPN service is running, please remove it first to configure it again." bold
    	sleep 2
    	return 1
    fi
    
    #Clear and title
    clear
    colorize cyan "Configure TinyVPN for server mode" bold
        
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
        MODE="--mode 1  --timeout 0"   	
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
	    colorize red "TinyVPN server failed to start. Checking logs..." bold
	    if [ -f "/var/log/gamingtunnel.error.log" ]; then
	        echo "Last 10 lines of error log:"
	        tail -n 10 /var/log/gamingtunnel.error.log
	    fi
	    colorize yellow "For more details, check: /var/log/gamingtunnel.log and /var/log/gamingtunnel.error.log" bold
	else
	    colorize green "TinyVPN server started successfully." bold
	fi
	
	echo
	press_key
}

configure_tinyvpn_client() {
    # Check if service or config file existing and returns
    echo 
    if [ -f "$SERVICE_FILE" ]; then
    	colorize red "TinyVPN service is running, please remove it first to configure it again." bold
    	sleep 2
    	return 1
    fi
   
    #Clear and title
    clear
    colorize cyan "Configure TinyVPN for client mode" bold
        
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
        MODE="--mode 1  --timeout 0"   	
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
    
    # Check if UDP2RAW is running and should be used
    if [ -f "$UDP2RAW_SERVICE_FILE" ]; then
        echo
        echo -ne "[-] UDP2RAW is installed. Do you want to connect through UDP2RAW? (y/n, default: n): "
        read -r USE_UDP2RAW
        
        if [[ "$USE_UDP2RAW" == "y" || "$USE_UDP2RAW" == "Y" ]]; then
            # Get the port from UDP2RAW service
            LOCAL_PORT=$(grep -o "\-l0.0.0.0:[0-9]\+" "$UDP2RAW_SERVICE_FILE" | cut -d':' -f2)
            
            if [ -n "$LOCAL_PORT" ]; then
                colorize yellow "Configuring TinyVPN to connect through local UDP2RAW on port $LOCAL_PORT" bold
                # Final command for UDP2RAW setup
                COMMAND="-c -r127.0.0.1:${LOCAL_PORT} $FEC --sub-net $SUBNET $MTU $MODE --tun-dev gaming --keep-reconnect --disable-obscure"
            else
                colorize red "Could not determine UDP2RAW local port. Using direct connection." bold
                COMMAND="-c -r${IP}:${PORT} $FEC --sub-net $SUBNET $MTU $MODE --tun-dev gaming --keep-reconnect --disable-obscure"
            fi
        else
            # Final command for direct connection
            COMMAND="-c -r${IP}:${PORT} $FEC --sub-net $SUBNET $MTU $MODE --tun-dev gaming --keep-reconnect --disable-obscure"
        fi
    else
        # Final command for direct connection
        COMMAND="-c -r${IP}:${PORT} $FEC --sub-net $SUBNET $MTU $MODE --tun-dev gaming --keep-reconnect --disable-obscure"
    fi

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
	    colorize red "TinyVPN client failed to start. Checking logs..." bold
	    if [ -f "/var/log/gamingtunnel.error.log" ]; then
	        echo "Last 10 lines of error log:"
	        tail -n 10 /var/log/gamingtunnel.error.log
	    fi
	    colorize yellow "For more details, check: /var/log/gamingtunnel.log and /var/log/gamingtunnel.error.log" bold
	else
	    colorize green "TinyVPN client started successfully." bold
	fi
	
	echo
	press_key
}

configure_udp2raw_server() {
    echo
    # Check if UDP2RAW service is already running
    if [ -f "$UDP2RAW_SERVICE_FILE" ]; then
        colorize red "UDP2RAW service is already running. Please remove it first." bold
        sleep 2
        return 1
    fi
    
    clear
    colorize cyan "Configure UDP2RAW for server mode" bold
    echo
    
    # UDP2RAW Port
    echo -ne "[-] UDP2RAW listening port: "
    read -r UDP2RAW_PORT
    if [ -z "$UDP2RAW_PORT" ]; then
        colorize red "UDP2RAW port is required." bold
        sleep 2
        return 1
    fi
    
    # Check if TinyVPN is running
    if [ -f "$SERVICE_FILE" ]; then
        # Get the port from TinyVPN service
        TINYVPN_PORT=$(grep -o "\-l\[::]\:[0-9]\+" "$SERVICE_FILE" | cut -d':' -f3)
        
        if [ -z "$TINYVPN_PORT" ]; then
            echo -ne "[-] TinyVPN port (to forward traffic to): "
            read -r TINYVPN_PORT
            if [ -z "$TINYVPN_PORT" ]; then
                colorize red "TinyVPN port is required." bold
                sleep 2
                return 1
            fi
        else
            colorize yellow "Using TinyVPN port $TINYVPN_PORT from existing configuration." bold
        fi
    else
        echo -ne "[-] TinyVPN port (to forward traffic to): "
        read -r TINYVPN_PORT
        if [ -z "$TINYVPN_PORT" ]; then
            colorize red "TinyVPN port is required." bold
            sleep 2
            return 1
        fi
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
    
    # UDP2RAW command
    UDP2RAW_COMMAND="-c -l0.0.0.0:${UDP2RAW_PORT} -r10.22.22.2:${TINYVPN_PORT} -a -k \"${UDP2RAW_PASS}\" --cipher-mode xor --auth-mode simple --raw-mode ${UDP2RAW_MODE}"
    
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
    
    if ! systemctl is-active --quiet udp2raw; then
        colorize red "UDP2RAW server failed to start. Checking logs..." bold
        if [ -f "/var/log/udp2raw.error.log" ]; then
            echo "Last 10 lines of error log:"
            tail -n 10 /var/log/udp2raw.error.log
        fi
        colorize yellow "For more details, check: /var/log/udp2raw.log and /var/log/udp2raw.error.log" bold
    else
        colorize green "UDP2RAW server configured and started." bold
    fi
    
    echo
    press_key
}

configure_udp2raw_client() {
    echo
    # Check if UDP2RAW service is already running
    if [ -f "$UDP2RAW_SERVICE_FILE" ]; then
        colorize red "UDP2RAW service is already running. Please remove it first." bold
        sleep 2
        return 1
    fi
    
    clear
    colorize cyan "Configure UDP2RAW for client mode" bold
    echo
    
    # Remote Server Address
    echo -ne "[*] Remote server address (in IPv4 format): "
    read -r IP
    if [ -z "$IP" ]; then
        colorize red "Enter a valid IP address..." bold
        sleep 2
        return 1
    fi
    
    # UDP2RAW Remote Port
    echo -ne "[-] UDP2RAW remote port (on server): "
    read -r UDP2RAW_PORT
    if [ -z "$UDP2RAW_PORT" ]; then
        colorize red "UDP2RAW remote port is required." bold
        sleep 2
        return 1
    fi
    
    # UDP2RAW Local Port
    echo -ne "[-] UDP2RAW local port (for TinyVPN to connect to): "
    read -r UDP2RAW_LOCAL_PORT
    if [ -z "$UDP2RAW_LOCAL_PORT" ]; then
        colorize red "UDP2RAW local port is required." bold
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
    
    # UDP2RAW command
    UDP2RAW_COMMAND="-s -l0.0.0.0:${UDP2RAW_LOCAL_PORT} -r${IP}:${UDP2RAW_PORT} -a -k \"${UDP2RAW_PASS}\" --cipher-mode xor --auth-mode simple --raw-mode ${UDP2RAW_MODE}"
    
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
    
    if ! systemctl is-active --quiet udp2raw; then
        colorize red "UDP2RAW client failed to start. Checking logs..." bold
        if [ -f "/var/log/udp2raw.error.log" ]; then
            echo "Last 10 lines of error log:"
            tail -n 10 /var/log/udp2raw.error.log
        fi
        colorize yellow "For more details, check: /var/log/udp2raw.log and /var/log/udp2raw.error.log" bold
    else
        colorize green "UDP2RAW client configured and started. To use with TinyVPN, configure TinyVPN to connect to 127.0.0.1:${UDP2RAW_LOCAL_PORT}" bold
        
        # Suggest configuring TinyVPN
        echo
        echo -ne "[-] Would you like to configure TinyVPN to use this UDP2RAW tunnel? (y/n): "
        read -r CONFIGURE_TINYVPN
        
        if [[ "$CONFIGURE_TINYVPN" == "y" || "$CONFIGURE_TINYVPN" == "Y" ]]; then
            if [ -f "$SERVICE_FILE" ]; then
                systemctl stop gamingtunnel &> /dev/null
                systemctl disable gamingtunnel &> /dev/null
                rm -f "$SERVICE_FILE"
            fi
            
            configure_tinyvpn_client
        fi
    fi
    
    echo
    press_key
}

remove_tinyvpn_service() {
    echo
    if ! [ -f "$SERVICE_FILE" ]; then
        colorize red "TinyVPN service is not found" bold
        sleep 2
        return 1
    fi
    
    systemctl disable gamingtunnel &> /dev/null
    systemctl stop gamingtunnel &> /dev/null
    rm -rf "$SERVICE_FILE"
    
    systemctl daemon-reload &> /dev/null
    
    colorize green "TinyVPN service stopped and deleted successfully." bold
    sleep 2
}

remove_udp2raw_service() {
    echo
    if ! [ -f "$UDP2RAW_SERVICE_FILE" ]; then
        colorize red "UDP2RAW service is not found" bold
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

remove_service() {
    echo
    SERVICES_REMOVED=0
    
    if [ -f "$SERVICE_FILE" ]; then
        systemctl disable gamingtunnel &> /dev/null
        systemctl stop gamingtunnel &> /dev/null
        rm -rf "$SERVICE_FILE"
        colorize green "TinyVPN service stopped and deleted." bold
        SERVICES_REMOVED=1
    fi
    
    if [ -f "$UDP2RAW_SERVICE_FILE" ]; then
        systemctl disable udp2raw &> /dev/null
        systemctl stop udp2raw &> /dev/null
        rm -rf "$UDP2RAW_SERVICE_FILE"
        colorize green "UDP2RAW service stopped and deleted." bold
        SERVICES_REMOVED=1
    fi
    
    if [ $SERVICES_REMOVED -eq 0 ]; then
        colorize red "No services found to remove." bold
    else
        systemctl daemon-reload &> /dev/null
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
    colorize cyan " 3. UDP2RAW Server Configuration" bold
    colorize cyan " 4. UDP2RAW Client Configuration" bold
    echo
    colorize yellow "═══ SERVICE MANAGEMENT ═══" bold
    colorize magenta " 5. Check TinyVPN service status" 
    colorize magenta " 6. Check UDP2RAW service status" 
    colorize yellow " 7. View TinyVPN logs"
    colorize yellow " 8. View UDP2RAW logs"
    colorize yellow " 9. Restart TinyVPN service" 
    colorize yellow "10. Restart UDP2RAW service" 
    echo
    colorize red "═══ REMOVAL ═══" bold
    colorize red "11. Remove TinyVPN service"
    colorize red "12. Remove UDP2RAW service"
    colorize red "13. Remove all services"
    colorize red "14. Remove core files"
    echo
    colorize magenta "═══ CONFIGURATION PROFILES ═══" bold
    colorize magenta "15. Save current configuration as profile" bold
    colorize magenta "16. Load configuration profile" bold
    colorize magenta "17. List saved configuration profiles" bold
    colorize magenta "18. Delete configuration profile" bold
    echo
    colorize cyan "═══ SYSTEM ═══" bold
    colorize cyan "19. Create symlink to script" bold
    echo -e " 0. Exit"
    echo
    echo "-------------------------------"
}

# Function to read user input
read_option() {
    read -p "Enter your choice [0-19]: " choice
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
        13) remove_service ;;
        14) remove_core ;;
        15) save_config ;;
        16) load_config ;;
        17) list_configs ;;
        18) delete_config ;;
        19) create_symlink ;;
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

check_service_status_tinyvpn(){
	echo
    if ! [ -f "$SERVICE_FILE" ]; then
    	colorize red "TinyVPN service is not found" bold
    	sleep 2
    	return 1
    fi
    clear
    
    # First check if service exists
    if ! systemctl --all --type=service | grep -q "gamingtunnel.service"; then
        colorize red "TinyVPN service is not registered in systemd" bold
        sleep 2
        return 1
    fi
    
    # Show detailed status
    systemctl status gamingtunnel.service
    
    echo
    press_key
}

check_service_status_udp2raw(){
	echo
    if ! [ -f "$UDP2RAW_SERVICE_FILE" ]; then
    	colorize red "UDP2RAW service is not found" bold
    	sleep 2
    	return 1
    fi
    clear
    
    # First check if service exists
    if ! systemctl --all --type=service | grep -q "udp2raw.service"; then
        colorize red "UDP2RAW service is not registered in systemd" bold
        sleep 2
        return 1
    fi
    
    # Show detailed status
    systemctl status udp2raw.service
    
    echo
    press_key
}

view_logs_tinyvpn(){
	echo
    if ! [ -f "$SERVICE_FILE" ]; then
    	colorize red "TinyVPN service is not found" bold
    	sleep 2
    	return 1
    fi
    clear
    
    if [ -f "/var/log/gamingtunnel.log" ]; then
        echo -e "${CYAN}TinyVPN Log:${NC}\n"
        cat /var/log/gamingtunnel.log
    else
        colorize yellow "TinyVPN log file not found at /var/log/gamingtunnel.log" bold
        echo "Showing service journal logs instead:"
        journalctl -xeu gamingtunnel.service --no-pager
    fi
    
    echo
    echo -e "${YELLOW}Press 'q' to exit${NC}"
    read -p "Press any key to continue..." -n 1
}

view_logs_udp2raw(){
	echo
    if ! [ -f "$UDP2RAW_SERVICE_FILE" ]; then
    	colorize red "UDP2RAW service is not found" bold
    	sleep 2
    	return 1
    fi
    clear
    
    if [ -f "/var/log/udp2raw.log" ]; then
        echo -e "${CYAN}UDP2RAW Log:${NC}\n"
        cat /var/log/udp2raw.log
    else
        colorize yellow "UDP2RAW log file not found at /var/log/udp2raw.log" bold
        echo "Showing service journal logs instead:"
        journalctl -xeu udp2raw.service --no-pager
    fi
    
    echo
    echo -e "${YELLOW}Press 'q' to exit${NC}"
    read -p "Press any key to continue..." -n 1
}

restart_service_tinyvpn(){
	echo
    if ! [ -f "$SERVICE_FILE" ]; then
    	colorize red "TinyVPN service is not found" bold
    	sleep 2
    	return 1
    fi
    
    systemctl restart gamingtunnel.service &> /dev/null
    if systemctl is-active --quiet gamingtunnel; then
        colorize green "TinyVPN service restarted successfully." bold
    else
        colorize red "Failed to restart TinyVPN service. Check logs for details." bold
    fi
	sleep 2
}

restart_service_udp2raw(){
	echo
    if ! [ -f "$UDP2RAW_SERVICE_FILE" ]; then
    	colorize red "UDP2RAW service is not found" bold
    	sleep 2
    	return 1
    fi
    
    systemctl restart udp2raw.service &> /dev/null
    if systemctl is-active --quiet udp2raw; then
        colorize green "UDP2RAW service restarted successfully." bold
    else
        colorize red "Failed to restart UDP2RAW service. Check logs for details." bold
    fi
	sleep 2
}
