#!/bin/bash
# Function to display the status of each step
display_status() {
    echo "Checking the status of each step..."
    echo "-------------------------------------"
    echo "1. Redsocks installation status:"
    if command -v redsocks &> /dev/null; then
        echo "   Redsocks is installed"
    else
        echo "   Redsocks is not installed"
    fi
    echo "-------------------------------------"
    echo "2. Redsocks configuration status:"
    if [ -f /etc/redsocks.conf ]; then
        echo "   Redsocks is configured"
    else
        echo "   Redsocks is not configured"
    fi
    echo "-------------------------------------"
    echo "3. SSH tunnel status:"
    status_ssh_tunnel
    echo "-------------------------------------"
    echo "4. iptables rules status:"
    display_iptables_rules
    echo "-------------------------------------"
    echo "5. Redsocks service status:"
    status_redsocks
    echo "-------------------------------------"
}

# Display initial status
display_status
# Function to display a menu
display_menu() {
    echo "1. Install redsocks"
    echo "2. Configure redsocks"
    echo "3. Set up SSH tunnel"
    echo "4. Set up iptables rules"
    echo "5. Remove iptables rules"
    echo "6. Close SSH tunnel"
    echo "7. Stop redsocks"
    echo "8. Exit"
}

# Function to install redsocks
install_redsocks() {
    if ! command -v redsocks &> /dev/null
    then
        echo "redsocks could not be found, installing..."
        sudo apt-get update
        sudo apt-get install -y redsocks
    else
        echo "redsocks is already installed"
    fi
}

# Function to configure redsocks
configure_redsocks() {
    default_local_port=12345
    default_proxy_ip="127.0.0.1"
    default_proxy_port=1080

    read -p "Enter the local port to listen on [default: $default_local_port]: " local_port
    local_port=${local_port:-$default_local_port}

    read -p "Enter the proxy server IP [default: $default_proxy_ip]: " proxy_ip
    proxy_ip=${proxy_ip:-$default_proxy_ip}

    read -p "Enter the proxy server port [default: $default_proxy_port]: " proxy_port
    proxy_port=${proxy_port:-$default_proxy_port}

    cat <<EOL > /etc/redsocks.conf
base {
    log_debug = on;
    log_info = on;
    log = "file:/var/log/redsocks.log";
    daemon = on;
    redirector = iptables;
}

redsocks {
    local_ip = 127.0.0.1;
    local_port = $local_port;
    ip = $proxy_ip;
    port = $proxy_port;
    type = socks5;
}
EOL

    echo "Redsocks configuration file created at /etc/redsocks.conf"

    systemctl enable redsocks
    systemctl start redsocks

    echo "Redsocks service started"
}

# Function to set up SSH tunnel
setup_ssh_tunnel() {
    while true; do
        read -p "Enter SSH user: " ssh_user
        read -p "Enter SSH host: " ssh_host

        if ssh -f -N -D $proxy_port $ssh_user@$ssh_host; then
            echo "SSH tunnel started on port $proxy_port"
            break
        else
            echo "Failed to establish SSH tunnel. Please try again or press 'q' to quit."
            read -p "Do you want to change the SSH user and host? (y/n/q): " choice
            if [[ "$choice" == "q" ]]; then
                echo "Exiting..."
                exit 1
            elif [[ "$choice" != "y" ]]; then
                echo "Retrying with the same SSH user and host..."
            fi
        fi
    done
}

# Function to set up iptables rules
setup_iptables() {
    iptables -t nat -N REDSOCKS

    iptables -t nat -A REDSOCKS -d 0.0.0.0/8 -j RETURN
    iptables -t nat -A REDSOCKS -d 127.0.0.0/8 -j RETURN
    iptables -t nat -A REDSOCKS -d 192.168.0.0/16 -j RETURN
    iptables -t nat -A REDSOCKS -d 10.0.0.0/8 -j RETURN
    iptables -t nat -A REDSOCKS -d 172.16.0.0/12 -j RETURN

    iptables -t nat -A REDSOCKS -p tcp -j REDIRECT --to-ports 12345

    iptables -t nat -A OUTPUT -p tcp -j REDSOCKS

    echo "iptables rules set up to redirect HTTP and HTTPS traffic through redsocks"
}

# Function to remove iptables rules
remove_iptables() {
    iptables -t nat -D OUTPUT -p tcp -j REDSOCKS
    iptables -t nat -F REDSOCKS
    iptables -t nat -X REDSOCKS
    echo "iptables rules removed"
}

# Function to close SSH tunnel
close_ssh_tunnel() {
    ssh_pid=$(pgrep -f "ssh -f -N -D $proxy_port")
    if [ -n "$ssh_pid" ]; then
        kill $ssh_pid
        echo "SSH tunnel closed"
    else
        echo "No SSH tunnel found"
    fi
}

# Function to stop redsocks
stop_redsocks() {
    systemctl stop redsocks
    echo "Redsocks service stopped"
}

# Function to display the status of redsocks
status_redsocks() {
    systemctl status redsocks
}

# Function to display the current iptables rules
display_iptables_rules() {
    iptables -t nat -L -v -n
}

# Function to display the status of the SSH tunnel
status_ssh_tunnel() {
    ssh_pid=$(pgrep -f "ssh -f -N -D $proxy_port")
    if [ -n "$ssh_pid" ]; then
        echo "SSH tunnel is running with PID: $ssh_pid"
    else
        echo "No SSH tunnel found"
    fi
}
# Main script
while true; do
    display_menu
    read -p "Choose an option: " choice
    case $choice in
        1) install_redsocks ;;
        2) configure_redsocks ;;
        3) setup_ssh_tunnel ;;
        4) setup_iptables ;;
        5) remove_iptables ;;
        6) close_ssh_tunnel ;;
        7) stop_redsocks ;;
        8) echo "Exiting..."; exit 0 ;;
        *) echo "Invalid option. Please try again." ;;
    esac
done
then
    echo "redsocks could not be found, installing..."
    sudo apt-get update
    sudo apt-get install -y redsocks
else
    echo "redsocks is already installed"
fi
