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
    ssh -f -N -D $socks_port $username@$host -p $ssh_port
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
    ssh_pid=$(pgrep -f "ssh -f -N -D $socks_port $username@$host -p $ssh_port")
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
    3
        
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
    echo -e "  \033[1;31mk\033[0m - Kill a specific tunnel"
    echo -e "  \033[1;31ma\033[0m - Kill all tunnels"
    echo -e "  \033[1;32mq\033[0m - Quit without action"
    echo ""
    
    read -p "Enter your choice: " choice
    
    case $choice in
        k)
            read -p "Enter the number of the tunnel to kill: " tunnel_num
            if [[ "$tunnel_num" =~ ^[0-9]+$ ]] && [ "$tunnel_num" -ge 1 ] && [ "$tunnel_num" -lt "$counter" ]; then
                kill_pid=${tunnel_pids[$tunnel_num]}
                echo -e "Terminating: \033[1;33m${tunnel_details[$tunnel_num]}\033[0m"
                kill $kill_pid
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
                kill $pid
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
    read -p "Do you want to start redsocks now? (y/n): " start_choice
    if [[ "$start_choice" == "y" || "$start_choice" == "Y" ]]; then
        sudo redsocks -c /tmp/redsocks.conf &
        if [ $? -eq 0 ]; then
            echo -e "\033[1;32mRedsocks started successfully!\033[0m"
        else
            echo -e "\033[1;31mFailed to start redsocks.\033[0m"
        fi
    fi
}

# Function to display the menu
display_menu() {
    display_logo
    echo -e "  \033[1;32m1.\033[0m Start SSH Tunnel"
    echo -e "  \033[1;31m2.\033[0m Manage SSH Tunnels"
    echo -e "  \033[1;34m3.\033[0m Install Redsocks"
    echo -e "  \033[1;35m4.\033[0m Configure Redsocks"
    echo -e "  \033[1;33m5.\033[0m Exit"
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
            start_tunnel
            ;;
        2)
            manage_tunnels
            ;;
        3)
            install_redsocks
            ;;
        4)
            configure_redsocks
            ;;
        5)
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
