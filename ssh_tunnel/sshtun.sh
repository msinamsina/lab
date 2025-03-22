#!/bin/bash
# ASCII Logo for MSA SSH Tunnel Manager with colors and visual effects
display_logo() {
    # ANSI color codes
    local RED='\033[0;31m'
    local GREEN='\033[0;32m'
    local BLUE='\033[0;34m'
    local YELLOW='\033[1;33m'
    local NC='\033[0m' # No Color

    clear
    echo -e "${BLUE}"
    echo "  ███╗   ███╗███████╗ █████╗ "
    echo "  ████╗ ████║██╔════╝██╔══██╗"
    echo "  ██╔████╔██║███████╗███████║"
    echo "  ██║╚██╔╝██║╚════██║██╔══██║"
    echo "  ██║ ╚═╝ ██║███████║██║  ██║"
    echo "  ╚═╝     ╚═╝╚══════╝╚═╝  ╚═╝"
    echo -e "${YELLOW}  =================================="
    echo "       SSH TUNNEL MANAGER"
    echo -e "  ==================================${NC}"
    echo ""
}

# Function to generate and copy SSH key
generate_ssh_key() {
    echo "Checking for existing SSH keys..."
    
    # Check if SSH keys already exist
    if [ -f ~/.ssh/id_ed25519 ] || [ -f ~/.ssh/id_rsa ]; then
        echo -e "\033[1;32mSSH key already exists!\033[0m"
        key_exists=true
    else
        echo -e "\033[1;33mNo SSH key found. Generating new key...\033[0m"
        key_exists=false
        
        # Ask user for key type
        echo -e "\033[1;36mSelect key type:\033[0m"
        echo -e "  \033[1;32m1)\033[0m Ed25519 (recommended, more secure)"
        echo -e "  \033[1;32m2)\033[0m RSA (more compatible with older servers)"
        read -p "Select an option (1-2): " key_type
        
        case $key_type in
            1)
                key_algorithm="ed25519"
                ;;
            2)
                key_algorithm="rsa"
                key_bits=4096
                ;;
            *)
                echo -e "\033[1;31mInvalid option. Using Ed25519 as default.\033[0m"
                key_algorithm="ed25519"
                ;;
        esac
        
        # Ask user for email or comment
        read -p "Enter your email (for key comment): " key_email
        key_email=${key_email:-"user@$(hostname)"}
        
        # Create .ssh directory if it doesn't exist
        mkdir -p ~/.ssh
        chmod 700 ~/.ssh
        
        # Generate the key
        if [ "$key_algorithm" = "ed25519" ]; then
            ssh-keygen -t ed25519 -C "$key_email" -f ~/.ssh/id_ed25519
        else
            ssh-keygen -t rsa -b $key_bits -C "$key_email" -f ~/.ssh/id_rsa
        fi
        
        if [ $? -eq 0 ]; then
            echo -e "\033[1;32mSSH key generated successfully!\033[0m"
            key_exists=true
        else
            echo -e "\033[1;31mFailed to generate SSH key.\033[0m"
            return 1
        fi
    fi
    
    # If key exists (either already or newly generated), offer to copy to server
    if [ "$key_exists" = true ]; then
        read -p "Do you want to copy the key to a remote server? (y/n): " copy_key
        
        if [[ "$copy_key" == "y" || "$copy_key" == "Y" ]]; then
            # Get server details
            read -p "Enter SSH username: " username
            read -p "Enter SSH host: " host
            read -p "Enter SSH port [22]: " ssh_port
            ssh_port=${ssh_port:-22}
            
            # Display summary
            echo "Summary of connection details:"
            echo "  User: $username"
            echo "  Host: $host"
            echo "  SSH Port: $ssh_port"
            
            # Copy the key using ssh-copy-id
            echo -e "\033[1;33mCopying SSH key to ${username}@${host}:${ssh_port}...\033[0m"
            
            if command -v ssh-copy-id >/dev/null 2>&1; then
                ssh-copy-id -p $ssh_port "${username}@${host}"
                
                if [ $? -eq 0 ]; then
                    echo -e "\033[1;32mSSH key copied successfully!\033[0m"
                    echo -e "\033[1;32mYou can now connect to the server without a password.\033[0m"
                else
                    echo -e "\033[1;31mFailed to copy SSH key. Check your connection details and try again.\033[0m"
                fi
            else
                echo -e "\033[1;31mssh-copy-id command not found. Trying alternative method...\033[0m"
                
                # Alternative method if ssh-copy-id is not available
                cat ~/.ssh/id_ed25519.pub 2>/dev/null || cat ~/.ssh/id_rsa.pub 2>/dev/null | ssh -p $ssh_port "${username}@${host}" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
                
                if [ $? -eq 0 ]; then
                    echo -e "\033[1;32mSSH key copied successfully!\033[0m"
                    echo -e "\033[1;32mYou can now connect to the server without a password.\033[0m"
                else
                    echo -e "\033[1;31mFailed to copy SSH key. Check your connection details and try again.\033[0m"
                fi
            fi
        fi
    fi
}
# Function to start SSH tunnel
start_tunnel() {
    # Default values
    DEFAULT_SSH_PORT=22
    DEFAULT_SOCKS_PORT=1080

    # Get connection details from user
    read -p "Enter SSH username: " username
    read -p "Enter SSH host: " host
    read -p "Enter SSH port [$DEFAULT_SSH_PORT]: " ssh_port
    ssh_port=${ssh_port:-$DEFAULT_SSH_PORT}
    read -p "Enter SOCKS proxy port [$DEFAULT_SOCKS_PORT]: " socks_port
    socks_port=${socks_port:-$DEFAULT_SOCKS_PORT}


    echo "Summary of connection details:"
    echo "  User: $username"
    echo "  Host: $host"
    echo "  SSH Port: $ssh_port"
    echo "  SOCKS Port: $socks_port"

    read -p "Continue with these settings? (y/n): " confirm_choice
    if [[ "$confirm_choice" != "y" && "$confirm_choice" != "Y" ]]; then
        return 0
    fi

    # Validate inputs
    if [[ -z "$username" || -z "$host" ]]; then
        echo "Error: Username and host cannot be empty."
        return 1
    fi

    # Start the SSH tunnel
    echo "Starting SSH SOCKS Proxy..."
    echo "Connecting to ${username}@${host}:${ssh_port}"
    echo "Setting up SOCKS proxy on port ${socks_port}"

    
    # Start the SSH tunnel with dynamic port forwarding (-D) in the background
    SSH_CMD="ssh -f -N -D $socks_port -o ConnectTimeout=10 -o ServerAliveInterval=60 -o TCPKeepAlive=yes -o ConnectionAttempts=3 $username@$host -p $ssh_port 2>> ./msa_ssh_tunnel.log"
    echo "Running command: $SSH_CMD"
    $SSH_CMD

    if [ $? -eq 0 ]; then
        echo "SSH tunnel started successfully."
        echo "User: $username" > /tmp/msa_ssh_tunnel
        echo "Host: $host" >> /tmp/msa_ssh_tunnel
        echo "SSH Port: $ssh_port" >> /tmp/msa_ssh_tunnel
        echo "SOCKS Port: $socks_port" >> /tmp/msa_ssh_tunnel
    else
        echo "Error: Failed to start SSH tunnel."
    fi

    # Get the PID of the SSH process
    ssh_pid=$(pgrep -f "$SSH_CMD")
    if [ -n "$ssh_pid" ]; then
        echo "SSH tunnel PID: $ssh_pid"
    else
        echo "Error: Failed to get SSH tunnel PID."
    fi
}


# Function to manage SSH tunnels
manage_tunnels() {
    # Find all SSH tunnels with SOCKS proxy (-D option)
    echo "Checking SSH Tunnel Status..."
    echo "============================="
    
    # Find SSH tunnels with SOCKS proxy
    ssh_tunnels=$(ps aux | grep "ssh" | grep "\-D" | grep -v grep)
    
    if [ -z "$ssh_tunnels" ]; then
        echo "No active SSH tunnels found."
        return 0
    fi
    
    # Create arrays to store the details
    declare -a tunnel_pids
    declare -a tunnel_details
    
    # Display all tunnels with numbers
    counter=1
    echo -e "\033[1;36mActive SSH Tunnels:\033[0m"
    echo -e "\033[1;33m------------------\033[0m"
    
    while IFS= read -r line; do
        pid=$(echo "$line" | awk '{print $2}')
        cmd=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i}')
        # Extract SOCKS port
        socks_port=$(echo "$cmd" | grep -o -E '\-D [0-9]+' | awk '{print $2}')
        if [ -z "$socks_port" ]; then
            socks_port="unknown"
        fi
        
        # Extract connection details
        connection=$(echo "$cmd" | grep -o -E '[^ ]+@[^ ]+')
        if [ -z "$connection" ]; then
            connection="unknown connection"
        fi
        
        echo -e "  \033[1;32m$counter)\033[0m PID: \033[1;33m$pid\033[0m - SOCKS Port: \033[1;34m$socks_port\033[0m - Connection: \033[1;36m$connection\033[0m"
        tunnel_pids[$counter]=$pid
        tunnel_details[$counter]="SOCKS Port: $socks_port - Connection: $connection"
        
        ((counter++))
    done <<< "$ssh_tunnels"
    
    echo ""
    echo -e "\033[1;37mOptions:\033[0m"
    echo -e "  \033[1;31mk.\033[0m Kill a specific tunnel"
    echo -e "  \033[1;32ma.\033[0m Kill all tunnels"
    echo -e "  \033[1;33mq.\033[0m Quit without action"
    echo ""
    
    read -p "Please choose an option: " choice
    
    case $choice in
        k)
            read -p "Enter the number of the tunnel to kill: " tunnel_num
            if [[ "$tunnel_num" =~ ^[0-9]+$ ]] && [ "$tunnel_num" -ge 1 ] && [ "$tunnel_num" -lt "$counter" ]; then
                kill_pid=${tunnel_pids[$tunnel_num]}
                echo -e "Terminating: \033[1;33m${tunnel_details[$tunnel_num]}\033[0m"
                sudo kill $kill_pid
                if [ $? -eq 0 ]; then
                    echo -e "\033[1;32mTunnel with PID $kill_pid has been terminated.\033[0m"
                else
                    echo -e "\033[1;31mFailed to terminate tunnel with PID $kill_pid.\033[0m"
                fi
            else
                echo -e "\033[1;31mInvalid tunnel number.\033[0m"
            fi
            ;;
        a)
            echo "Terminating all SSH tunnels..."
            for i in $(seq 1 $((counter-1))); do
                pid=${tunnel_pids[$i]}
                echo -e "Terminating: \033[1;33m${tunnel_details[$i]}\033[0m"
                sudo kill $pid
                if [ $? -eq 0 ]; then
                    echo -e "\033[1;32mTunnel with PID $pid has been terminated.\033[0m"
                else
                    echo -e "\033[1;31mFailed to terminate tunnel with PID $pid.\033[0m"
                fi
            done
            echo -e "\033[1;32mAll tunnels terminated.\033[0m"
            ;;
        q)
            echo "No action taken."
            return 0
            ;;
        *)
            echo -e "\033[1;31mInvalid option.\033[0m"
            ;;
    esac
    read -p "Press [Enter] key to continue..."
    clear
    display_logo
    manage_tunnels
}

# Function to display the menu
display_menu() {
    display_logo
    echo -e "  \033[1;32m1.\033[0m Start SSH Tunnel"
    echo -e "  \033[1;31m2.\033[0m Manage SSH Tunnels"
    echo -e "  \033[1;33m3.\033[0m Exit"
    echo ""
    echo -e "  \033[1;37m--------------------------------\033[0m"
}

# Function to install redsocks
install_redsocks() {
    echo "Checking for redsocks installation..."
    
    # Check if redsocks is already installed
    if command -v redsocks >/dev/null 2>&1; then
        echo -e "\033[1;32mRedsocks is already installed!\033[0m"
        return 0
    fi
    
    echo -e "\033[1;33mRedsocks is not installed. Installing now...\033[0m"
    
    # Check the package manager and install redsocks
    if command -v apt >/dev/null 2>&1; then
        echo "Using apt package manager..."
        sudo apt update
        sudo apt install -y redsocks
    elif command -v dnf >/dev/null 2>&1; then
        echo "Using dnf package manager..."
        sudo dnf install -y redsocks
    elif command -v yum >/dev/null 2>&1; then
        echo "Using yum package manager..."
        sudo yum install -y redsocks
    elif command -v pacman >/dev/null 2>&1; then
        echo "Using pacman package manager..."
        sudo pacman -S --noconfirm redsocks
    else
        echo -e "\033[1;31mUnsupported package manager. Please install redsocks manually.\033[0m"
        return 1
    fi
    
    # Check if installation was successful
    if command -v redsocks >/dev/null 2>&1; then
        echo -e "\033[1;32mRedsocks installed successfully!\033[0m"
    else
        echo -e "\033[1;31mFailed to install redsocks. Please try manual installation.\033[0m"
        return 1
    fi
}

# Function to configure redsocks
configure_redsocks() {
    echo "Configuring Redsocks..."
    
    # Check if redsocks is installed
    if ! command -v redsocks >/dev/null 2>&1; then
        echo -e "\033[1;31mRedsocks is not installed. Please install it first (Option 3).\033[0m"
        return 1
    fi
    
    # Find SSH tunnels with SOCKS proxy to display as options
    ssh_tunnels=$(ps aux | grep "ssh" | grep "\-D" | grep -v grep)
    
    if [ -z "$ssh_tunnels" ]; then
        echo "No active SSH tunnels found. Please start an SSH tunnel first (Option 1)."
        return 0
    fi
    
    # Display all tunnels with numbers
    counter=1
    echo -e "\033[1;36mAvailable SSH Tunnels:\033[0m"
    echo -e "\033[1;33m----------------------\033[0m"
    
    declare -a socks_ports
    
    while IFS= read -r line; do
        cmd=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i}')
        
        # Extract SOCKS port
        socks_port=$(echo "$cmd" | grep -o -E '\-D [0-9]+' | awk '{print $2}')
        if [ -z "$socks_port" ]; then
            socks_port="unknown"
        fi
        
        # Extract connection details
        connection=$(echo "$cmd" | grep -o -E '[^ ]+@[^ ]+')
        if [ -z "$connection" ]; then
            connection="unknown connection"
        fi
        
        echo -e "  \033[1;32m$counter)\033[0m SOCKS Port: \033[1;34m$socks_port\033[0m - Connection: \033[1;36m$connection\033[0m"
        socks_ports[$counter]=$socks_port
        
        ((counter++))
    done <<< "$ssh_tunnels"
    
    if [ $counter -eq 1 ]; then
        echo "No valid SSH tunnels found."
        return 0
    fi
    
    # Ask user to select a proxy
    read -p "Select a proxy to use (1-$((counter-1))): " proxy_choice
    if [[ ! "$proxy_choice" =~ ^[0-9]+$ ]] || [ "$proxy_choice" -lt 1 ] || [ "$proxy_choice" -ge "$counter" ]; then
        echo -e "\033[1;31mInvalid selection.\033[0m"
        return 1
    fi
    
    selected_port=${socks_ports[$proxy_choice]}
    
    # Ask for the port to be used by redsocks
    read -p "Enter port for redsocks to listen on [8123]: " redsocks_port
    redsocks_port=${redsocks_port:-8123}
    
    # Create redsocks configuration
    cat > /tmp/redsocks.conf << EOF
base {
    log_debug = off;
    log_info = on;
    log = "stderr";
    daemon = off;
    redirector = iptables;
}

redsocks {
    local_ip = 127.0.0.1;
    local_port = $redsocks_port;
    
    ip = 127.0.0.1;
    port = $selected_port;
    
    type = socks5;
}
EOF
    
    echo -e "\033[1;32mRedsocks configuration created at /tmp/redsocks.conf\033[0m"
    echo "To start redsocks, run: sudo redsocks -c /tmp/redsocks.conf"
    echo ""
    echo "To redirect traffic through redsocks, you can use these iptables commands:"
    echo "sudo iptables -t nat -N REDSOCKS"
    echo "sudo iptables -t nat -A REDSOCKS -d 0.0.0.0/8 -j RETURN"
    echo "sudo iptables -t nat -A REDSOCKS -d 10.0.0.0/8 -j RETURN"
    echo "sudo iptables -t nat -A REDSOCKS -d 127.0.0.0/8 -j RETURN"
    echo "sudo iptables -t nat -A REDSOCKS -d 169.254.0.0/16 -j RETURN"
    echo "sudo iptables -t nat -A REDSOCKS -d 172.16.0.0/12 -j RETURN"
    echo "sudo iptables -t nat -A REDSOCKS -d 192.168.0.0/16 -j RETURN"
    echo "sudo iptables -t nat -A REDSOCKS -d 224.0.0.0/4 -j RETURN"
    echo "sudo iptables -t nat -A REDSOCKS -d 240.0.0.0/4 -j RETURN"
    echo "sudo iptables -t nat -A REDSOCKS -p tcp -j REDIRECT --to-ports $redsocks_port"
    echo "sudo iptables -t nat -A OUTPUT -p tcp --dport 80 -j REDSOCKS"
    echo "sudo iptables -t nat -A OUTPUT -p tcp --dport 443 -j REDSOCKS"
    echo ""
    echo "To stop redirection: sudo iptables -t nat -F OUTPUT"
    
    # Ask if user wants to start redsocks
    read -p "Do you want to start redsocks as a service? (y/n): " start_choice
    if [[ "$start_choice" == "y" || "$start_choice" == "Y" ]]; then
        # Create a systemd service file for redsocks
        sudo bash -c "cat > /etc/systemd/system/redsocks.service << EOF
[Unit]
Description=Redsocks transparent SOCKS proxy redirector
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/redsocks -c /tmp/redsocks.conf
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF"
        
        # First try using service command
        if command -v service >/dev/null 2>&1; then
            echo "Using service command to manage redsocks..."
            
            # Copy configuration file to a standard location
            sudo cp /tmp/redsocks.conf /etc/redsocks.conf
            
            # Try to start using service command
            sudo service redsocks start &> ./redsocks_service.log &
            if [ $? -eq 0 ]; then
            echo -e "\033[1;32mRedsocks service started successfully!\033[0m"
            
            # Try to enable on boot if update-rc.d exists
            if command -v update-rc.d >/dev/null 2>&1; then
                sudo update-rc.d redsocks defaults
                echo -e "\033[1;32mRedsocks service enabled to start at boot.\033[0m"
            else
                echo -e "\033[1;33mCould not enable redsocks to start at boot automatically.\033[0m"
            fi
            # Service successfully started, return from function
            return 0
            else
            echo -e "\033[1;31mFailed to start redsocks service with service command.\033[0m"
            fi
        fi
        
        # If service command failed or doesn't exist, try systemctl
        if command -v systemctl >/dev/null 2>&1; then
            echo "Using systemctl to manage redsocks..."
            
            # Reload systemd to recognize the new service
            sudo systemctl daemon-reload
            
            # Start and enable the service
            sudo systemctl start redsocks
            if [ $? -eq 0 ]; then
            echo -e "\033[1;32mRedsocks service started successfully!\033[0m"
            sudo systemctl enable redsocks
            echo -e "\033[1;32mRedsocks service enabled to start at boot.\033[0m"
            
            # Show service status
            echo -e "\033[1;34mRedsocks service status:\033[0m"
            sudo systemctl status redsocks --no-pager
            return 0
            else
            echo -e "\033[1;31mFailed to start redsocks service with systemctl.\033[0m"
            fi
        fi
        
        # If both service and systemctl failed or don't exist, try direct execution
        echo -e "\033[1;31mTrying to start redsocks directly...\033[0m"
        sudo /usr/bin/redsocks -c /tmp/redsocks.conf &
        if [ $? -eq 0 ]; then
            echo -e "\033[1;32mRedsocks started directly in background.\033[0m"
            echo -e "\033[1;33mNote: You will need to restart it manually after reboot.\033[0m"
        else
            echo -e "\033[1;31mFailed to start redsocks.\033[0m"
        fi
        fi
}

# Function to set iptables rules for redsocks
set_iptables_rules() {
    echo "Setting up iptables rules for transparent proxying..."
    
    # Check if redsocks is installed and running
    if ! command -v redsocks >/dev/null 2>&1; then
        echo -e "\033[1;31mRedsocks is not installed. Please install it first (Option 3).\033[0m"
        return 1
    fi
    
    # Check if redsocks is running
    if ! pgrep redsocks >/dev/null; then
        echo -e "\033[1;31mRedsocks is not running. Please configure and start it first (Option 4).\033[0m"
        return 1
    fi
    
    # Get the redsocks port from the configuration
    if [ -f "/tmp/redsocks.conf" ]; then
        redsocks_port=$(grep "local_port" /tmp/redsocks.conf | head -1 | awk '{print $3}' | tr -d ';')
    elif [ -f "/etc/redsocks.conf" ]; then
        redsocks_port=$(grep "local_port" /etc/redsocks.conf | head -1 | awk '{print $3}' | tr -d ';')
    else
        read -p "Enter the redsocks listening port: " redsocks_port
    fi
    
    if [ -z "$redsocks_port" ]; then
        echo -e "\033[1;31mCould not determine redsocks port.\033[0m"
        read -p "Enter the redsocks listening port: " redsocks_port
    fi
    
    echo -e "Using redsocks port: \033[1;33m$redsocks_port\033[0m"
    
    # Ask which traffic to redirect
    echo -e "\033[1;36mSelect traffic to redirect through the proxy:\033[0m"
    echo -e "  \033[1;31m1.\033[0m HTTP and HTTPS traffic only (ports 80, 443)"
    echo -e "  \033[1;32m2.\033[0m All TCP traffic (except local networks)"
    echo -e "  \033[1;33m3.\033[0m Custom port selection"
    read -p "Please choose an option: " traffic_option
    
    # Create REDSOCKS chain
    echo "Creating iptables REDSOCKS chain..."
    sudo iptables -t nat -N REDSOCKS 2>/dev/null || sudo iptables -t nat -F REDSOCKS
    
    # Add rules to bypass local networks
    echo "Adding rules to bypass local networks..."
    sudo iptables -t nat -A REDSOCKS -d 0.0.0.0/8 -j RETURN
    sudo iptables -t nat -A REDSOCKS -d 10.0.0.0/8 -j RETURN
    sudo iptables -t nat -A REDSOCKS -d 127.0.0.0/8 -j RETURN
    sudo iptables -t nat -A REDSOCKS -d 169.254.0.0/16 -j RETURN
    sudo iptables -t nat -A REDSOCKS -d 172.16.0.0/12 -j RETURN
    sudo iptables -t nat -A REDSOCKS -d 192.168.0.0/16 -j RETURN
    sudo iptables -t nat -A REDSOCKS -d 224.0.0.0/4 -j RETURN
    sudo iptables -t nat -A REDSOCKS -d 240.0.0.0/4 -j RETURN
    
    # Add the redirect rule
    echo "Adding TCP traffic redirect rule to port $redsocks_port..."
    sudo iptables -t nat -A REDSOCKS -p tcp -j REDIRECT --to-ports $redsocks_port
    
    case $traffic_option in
        1)
            echo "Redirecting HTTP and HTTPS traffic..."
            sudo iptables -t nat -A OUTPUT -p tcp --dport 80 -j REDSOCKS
            sudo iptables -t nat -A OUTPUT -p tcp --dport 443 -j REDSOCKS
            echo -e "\033[1;32mIPTables rules for HTTP and HTTPS have been set!\033[0m"
            ;;
        2)
            echo "Redirecting all TCP traffic..."
            sudo iptables -t nat -A OUTPUT -p tcp -j REDSOCKS
            echo -e "\033[1;32mIPTables rules for all TCP traffic have been set!\033[0m"
            ;;
        3)
            echo "Custom port selection..."
            read -p "Enter the ports to redirect (space-separated, e.g., '80 443 8080'): " custom_ports
            
            for port in $custom_ports; do
                if [[ "$port" =~ ^[0-9]+$ ]]; then
                    echo "Redirecting traffic on port $port..."
                    sudo iptables -t nat -A OUTPUT -p tcp --dport $port -j REDSOCKS
                else
                    echo -e "\033[1;31mInvalid port: $port. Skipping.\033[0m"
                fi
            done
            echo -e "\033[1;32mIPTables rules for custom ports have been set!\033[0m"
            ;;
        *)
            echo -e "\033[1;31mInvalid option. No traffic redirection rules applied.\033[0m"
            return 1
            ;;
    esac
    
    # Save the current configuration
    echo "redsocks_port=$redsocks_port" > /tmp/redsocks_iptables_config
    echo "traffic_option=$traffic_option" >> /tmp/redsocks_iptables_config
    if [ "$traffic_option" = "3" ]; then
        echo "custom_ports=\"$custom_ports\"" >> /tmp/redsocks_iptables_config
    fi
    
    echo -e "\033[1;32mTraffic is now being redirected through your SSH tunnel!\033[0m"
}

# Function to unset iptables rules for redsocks
unset_iptables_rules() {
    echo "Removing iptables rules for transparent proxying..."
    
    # Check if there are any REDSOCKS rules to remove
    if sudo iptables -t nat -L | grep -q REDSOCKS; then
        echo "Removing REDSOCKS chain and related rules..."
        
        # First remove references to the REDSOCKS chain
        sudo iptables -t nat -D OUTPUT -p tcp -j REDSOCKS 2>/dev/null
        
        # Try to remove more specific references if they exist
        sudo iptables -t nat -D OUTPUT -p tcp --dport 80 -j REDSOCKS 2>/dev/null
        sudo iptables -t nat -D OUTPUT -p tcp --dport 443 -j REDSOCKS 2>/dev/null
        
        # If custom ports were used, try to read and remove them
        if [ -f "/tmp/redsocks_iptables_config" ]; then
            source /tmp/redsocks_iptables_config
            if [ "$traffic_option" = "3" ] && [ -n "$custom_ports" ]; then
                for port in $custom_ports; do
                    if [[ "$port" =~ ^[0-9]+$ ]]; then
                        sudo iptables -t nat -D OUTPUT -p tcp --dport $port -j REDSOCKS 2>/dev/null
                    fi
                done
            fi
        fi
        
        # Then flush and remove the REDSOCKS chain
        sudo iptables -t nat -F REDSOCKS
        sudo iptables -t nat -X REDSOCKS
        
        echo -e "\033[1;32mIPTables redirection rules have been removed!\033[0m"
    else
        echo -e "\033[1;33mNo REDSOCKS iptables rules found.\033[0m"
    fi
}

# Function to check the status of iptables rules for redsocks
check_iptables_status() {
    echo -e "\033[1;36mChecking iptables redirection status...\033[0m"
    echo -e "\033[1;33m--------------------------------\033[0m"
    
    # Check if the REDSOCKS chain exists
    if ! sudo iptables -t nat -L REDSOCKS -n >/dev/null 2>&1; then
        echo -e "\033[1;31mREDSOCKS chain does not exist. No redirection is active.\033[0m"
        return 0
    fi
    
    echo -e "\033[1;32mREDSOCKS chain exists. Redirection is configured.\033[0m"
    
    # Get the redsocks port from the configuration
    redsocks_port="unknown"
    if [ -f "/tmp/redsocks_iptables_config" ]; then
        source /tmp/redsocks_iptables_config
        echo -e "Redsocks port: \033[1;33m$redsocks_port\033[0m"
    fi
    
    # Check which traffic is being redirected
    echo -e "\033[1;36mTraffic being redirected:\033[0m"
    
    # Check for specific port redirections
    http_redirect=$(sudo iptables -t nat -C OUTPUT -p tcp --dport 80 -j REDSOCKS 2>/dev/null && echo "yes" || echo "no")
    https_redirect=$(sudo iptables -t nat -C OUTPUT -p tcp --dport 443 -j REDSOCKS 2>/dev/null && echo "yes" || echo "no")
    all_tcp_redirect=$(sudo iptables -t nat -C OUTPUT -p tcp -j REDSOCKS 2>/dev/null && echo "yes" || echo "no")
    
    if [ "$http_redirect" = "yes" ]; then
        echo -e "  - HTTP (port 80): \033[1;32mActive\033[0m"
    else
        echo -e "  - HTTP (port 80): \033[1;31mInactive\033[0m"
    fi
    
    if [ "$https_redirect" = "yes" ]; then
        echo -e "  - HTTPS (port 443): \033[1;32mActive\033[0m"
    else
        echo -e "  - HTTPS (port 443): \033[1;31mInactive\033[0m"
    fi
    
    if [ "$all_tcp_redirect" = "yes" ]; then
        echo -e "  - All TCP Traffic: \033[1;32mActive\033[0m"
    else
        echo -e "  - All TCP Traffic: \033[1;31mInactive\033[0m"
    fi
    
    # If custom ports were used, check them
    if [ -f "/tmp/redsocks_iptables_config" ] && [ "$traffic_option" = "3" ] && [ -n "$custom_ports" ]; then
        echo -e "  - Custom Ports:"
        for port in $custom_ports; do
            if [[ "$port" =~ ^[0-9]+$ ]]; then
                port_active=$(sudo iptables -t nat -C OUTPUT -p tcp --dport $port -j REDSOCKS 2>/dev/null && echo "yes" || echo "no")
                
                if [ "$port_active" = "yes" ]; then
                    echo -e "    - Port $port: \033[1;32mActive\033[0m"
                else
                    echo -e "    - Port $port: \033[1;31mInactive\033[0m"
                fi
            fi
        done
    fi
    
    # Display the REDSOCKS chain rules
    echo -e "\033[1;36mREDSOCKS Chain Configuration:\033[0m"
    sudo iptables -t nat -L REDSOCKS -n 
    echo -e "\033[1;36mREDSOCKS related iptables OUTPUT rules:\033[0m"
    sudo iptables -t nat -L OUTPUT -n | grep REDSOCKS



    
    # Check if redsocks process is running
    if pgrep redsocks >/dev/null; then
        echo -e "\033[1;32mRedsocks process is running.\033[0m"
    else
        echo -e "\033[1;31mRedsocks process is NOT running. Redirection will not work properly!\033[0m"
    fi
}
# Function to view redsocks logs
view_redsocks_logs() {
    echo "Checking for redsocks logs..."
    
    # Check if redsocks is installed
    if ! command -v redsocks >/dev/null 2>&1; then
        echo -e "\033[1;31mRedsocks is not installed. Please install it first (Option 3).\033[0m"
        return 1
    fi
    
    # Options for viewing logs
    echo -e "\033[1;36mRedsocks Log Options:\033[0m"
    echo -e "\033[1;33m--------------------\033[0m"
    echo -e "  \033[1;31m1.\033[0m View systemd journal logs (if running as a service)"
    echo -e "  \033[1;32m2.\033[0m View standard log files"
    echo -e "  \033[1;33m3.\033[0m View running process output"
    echo -e "  \033[1;34mq.\033[0m Return to main menu"
    echo ""
    
    read -p "Please choose an option: " log_option
    
    case $log_option in
        1)
            echo "Checking systemd journal logs..."
            if command -v journalctl >/dev/null 2>&1; then
                echo -e "\033[1;34mDisplaying last 50 log entries for redsocks service:\033[0m"
                sudo journalctl -u redsocks -n 50 --no-pager
                
                # Option to see more logs
                read -p "Display more logs? (y/n): " more_logs
                if [[ "$more_logs" == "y" || "$more_logs" == "Y" ]]; then
                    sudo journalctl -u redsocks | less
                fi
            else
                echo -e "\033[1;31mjournalctl command not found. System might not be using systemd.\033[0m"
            fi
            ;;
        2)
            echo "Checking standard log files..."
            log_locations=(
                "/var/log/redsocks.log"
                "/var/log/redsocks/redsocks.log"
                "/tmp/redsocks.log"
            )
            
            log_found=false
            
            for log_file in "${log_locations[@]}"; do
                if [ -f "$log_file" ]; then
                    echo -e "\033[1;34mDisplaying log file: $log_file\033[0m"
                    sudo tail -n 50 "$log_file"
                    
                    # Option to see more logs
                    read -p "View full log file? (y/n): " view_full
                    if [[ "$view_full" == "y" || "$view_full" == "Y" ]]; then
                        sudo less "$log_file"
                    fi
                    
                    log_found=true
                    break
                fi
            done
            
            if [ "$log_found" = false ]; then
                echo -e "\033[1;31mNo redsocks log files found in common locations.\033[0m"
            fi
            ;;
        3)
            echo "Checking for running redsocks process..."
            redsocks_pid=$(pgrep redsocks)
            
            if [ -n "$redsocks_pid" ]; then
                echo -e "\033[1;34mRedsocks is running with PID: $redsocks_pid\033[0m"
                
                # Check if we can view the process stdout/stderr
                if [ -e "/proc/$redsocks_pid/fd/1" ] || [ -e "/proc/$redsocks_pid/fd/2" ]; then
                    echo "Attempting to show process output (might be empty if not writing to stdout/stderr):"
                    
                    if [ -e "/proc/$redsocks_pid/fd/1" ]; then
                        echo -e "\033[1;33mStandard output:\033[0m"
                        sudo cat "/proc/$redsocks_pid/fd/1" 2>/dev/null | tail -n 50 || echo "Cannot access stdout"
                    fi
                    
                    if [ -e "/proc/$redsocks_pid/fd/2" ]; then
                        echo -e "\033[1;33mStandard error:\033[0m"
                        sudo cat "/proc/$redsocks_pid/fd/2" 2>/dev/null | tail -n 50 || echo "Cannot access stderr"
                    fi
                else
                    echo -e "\033[1;31mCannot directly access process output.\033[0m"
                fi
                
                # Show process information
                echo -e "\033[1;33mProcess information:\033[0m"
                ps -p "$redsocks_pid" -o pid,ppid,cmd,etime
            else
                echo -e "\033[1;31mNo running redsocks process found.\033[0m"
            fi
            ;;
        q|Q)
            echo "Returning to main menu..."
            return 0
            ;;
        *)
            echo -e "\033[1;31mInvalid option.\033[0m"
            ;;
    esac
}

# Function to show IP addresses
show_ip_addresses() {
    display_logo
    echo -e "\033[1;36mIP Address Information\033[0m"
    echo -e "\033[1;33m--------------------\033[0m"
    
    # Show hostname
    echo -e "\033[1;34mHostname:\033[0m $(hostname)"
    
    # Show local IP addresses
    echo -e "\033[1;34mLocal IP Addresses:\033[0m"
    if command -v ip >/dev/null 2>&1; then
        ip -4 addr show | grep inet | grep -v 127.0.0.1 | awk '{print "  - " $2}' | cut -d/ -f1
    elif command -v hostname >/dev/null 2>&1 && hostname -I >/dev/null 2>&1; then
        for ip in $(hostname -I); do
            echo "  - $ip"
        done
    else
        echo "  - Could not determine local IP address"
    fi
    
    # Show public IP address
    echo -e "\033[1;34mPublic IP Address:\033[0m"
    if command -v curl >/dev/null 2>&1; then
        public_ip=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || curl -s icanhazip.com)
        if [ -n "$public_ip" ]; then
            echo "  - $public_ip"
        else
            echo "  - Could not determine public IP address"
        fi
    elif command -v wget >/dev/null 2>&1; then
        public_ip=$(wget -qO- ifconfig.me || wget -qO- ipinfo.io/ip || wget -qO- icanhazip.com)
        if [ -n "$public_ip" ]; then
            echo "  - $public_ip"
        else
            echo "  - Could not determine public IP address"
        fi
    else
        echo "  - Could not determine public IP address (curl or wget required)"
    fi
    
    # Show if proxy is active
    echo -e "\033[1;34mProxy Status:\033[0m"
    if sudo iptables -t nat -L REDSOCKS -n >/dev/null 2>&1 && pgrep redsocks >/dev/null; then
        echo -e "  - \033[1;32mProxy redirection is ACTIVE\033[0m"
    else
        echo -e "  - \033[1;31mProxy redirection is NOT ACTIVE\033[0m"
    fi
}

# Function to display the menu
display_menu() {
    display_logo
    echo -e "  \033[1;34m1.\033[0m Install Redsocks"
    echo -e "  \033[1;33m2.\033[0m Generate/Copy SSH Key"
    echo -e "  \033[1;32m3.\033[0m Start SSH Tunnel"
    echo -e "  \033[1;31m4.\033[0m Manage SSH Tunnels"
    echo -e "  \033[1;35m5.\033[0m Configure Redsocks"
    echo -e "  \033[1;36m6.\033[0m View Redsocks Logs"
    echo -e "  \033[1;32m7.\033[0m Set iptables Rules"
    echo -e "  \033[1;31m8.\033[0m Unset iptables Rules"
    echo -e "  \033[1;36m9.\033[0m Check iptables Status"
    echo -e "  \033[1;34m10.\033[0m Show IP Addresses"
    echo -e "  \033[1;33mq.\033[0m Exit"
    echo ""
    echo -e "  \033[1;37m--------------------------------\033[0m"
}

# Main loop
while true; do
    clear
    display_menu
    read -p "Please choose an option: " choice
    clear
    display_logo
    case $choice in
        1)
            install_redsocks
            ;;
        2)
            generate_ssh_key
            ;;
        3)
            start_tunnel
            ;;
        4)
            manage_tunnels
            ;;
        5)
            configure_redsocks
            ;;
        6)
            view_redsocks_logs
            ;;
        7)
            set_iptables_rules
            ;;
        8)
            unset_iptables_rules
            ;;
        9)
            check_iptables_status
            ;;
        10)
            show_ip_addresses
            ;;
        q|Q)
            clear
            echo -e "\033[1;32mThank you for using MSA SSH Tunnel Manager!\033[0m"
            echo -e "\033[1;36mHave a great day!\033[0m"
            echo -e "\033[1;33m================================\033[0m"
            exit 0
            ;;
        *)
            echo "Invalid option, please try again."
            ;;
    esac
    read -p "Press [Enter] key to continue..."
done
# Function to display the menu
display_menu() {
    display_logo
    echo -e "  \033[1;34m1.\033[0m Install Redsocks"
    echo -e "  \033[1;33m2.\033[0m Generate/Copy SSH Key"
    echo -e "  \033[1;32m3.\033[0m Start SSH Tunnel"
    echo -e "  \033[1;31m4.\033[0m Manage SSH Tunnels"
    echo -e "  \033[1;35m5.\033[0m Configure Redsocks"
    echo -e "  \033[1;36m6.\033[0m View Redsocks Logs"
    echo -e "  \033[1;32m7.\033[0m Set iptables Rules"
    echo -e "  \033[1;31m8.\033[0m Unset iptables Rules"
    echo -e "  \033[1;36m9.\033[0m Check iptables Status"
    echo -e "  \033[1;33mq.\033[0m Exit"
    echo ""
    echo -e "  \033[1;37m--------------------------------\033[0m"
}

# Main loop
while true; do
    clear
    display_menu
    read -p "Please choose an option: " choice
    clear
    display_logo
    case $choice in
        1)
            install_redsocks
            ;;
        2)
            generate_ssh_key
            ;;
        3)
            start_tunnel
            ;;
        4)
            manage_tunnels
            ;;
        5)
            configure_redsocks
            ;;
        6)
            view_redsocks_logs
            ;;
        7)
            set_iptables_rules
            ;;
        8)
            unset_iptables_rules
            ;;
        9)
            check_iptables_status
            ;;
        q|Q)
            clear
            echo -e "\033[1;32mThank you for using MSA SSH Tunnel Manager!\033[0m"
            echo -e "\033[1;36mHave a great day!\033[0m"
            echo -e "\033[1;33m================================\033[0m"
            exit 0
            ;;
        *)
            echo "Invalid option, please try again."
            ;;
    esac
    read -p "Press [Enter] key to continue..."
done
