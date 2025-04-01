#!/bin/bash
# filepath: /workspaces/lab/vless-vpn.sh

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Function to parse VLESS link
parse_vless_link() {
  local vless_link="$1"
  
  # Check if the input is a valid VLESS link
  if [[ ! "$vless_link" =~ ^vless:// ]]; then
    echo "Error: Invalid VLESS link format. It should start with 'vless://'"
    exit 1
  fi
  
  # Extract UUID (between vless:// and @)
  UUID=$(echo "$vless_link" | sed -n 's/^vless:\/\/\([^@]*\)@.*/\1/p')
  
  # Extract server and port (between @ and ?)
  SERVER_INFO=$(echo "$vless_link" | sed -n 's/^vless:\/\/[^@]*@\([^?]*\).*/\1/p')
  SERVER_IP=$(echo "$SERVER_INFO" | cut -d ':' -f1)
  SERVER_PORT=$(echo "$SERVER_INFO" | cut -d ':' -f2)
  
  # Extract parameters
  PARAMS=$(echo "$vless_link" | sed -n 's/^.*?\(.*\)#.*/\1/p')
  if [[ -z "$PARAMS" ]]; then
    PARAMS=$(echo "$vless_link" | sed -n 's/^.*?\(.*\)/\1/p')
  fi
  
  # Parse security type
  SECURITY=$(echo "$PARAMS" | grep -o 'security=[^&]*' | cut -d '=' -f2)
  
  # Parse public key (pbk)
  PUBLIC_KEY=$(echo "$PARAMS" | grep -o 'pbk=[^&]*' | cut -d '=' -f2)
  
  # Parse fingerprint (fp)
  FINGERPRINT=$(echo "$PARAMS" | grep -o 'fp=[^&]*' | cut -d '=' -f2)
  
  # Parse SNI
  SNI=$(echo "$PARAMS" | grep -o 'sni=[^&]*' | cut -d '=' -f2)
  
  # Parse short ID (sid)
  SHORT_ID=$(echo "$PARAMS" | grep -o 'sid=[^&]*' | cut -d '=' -f2)
  
  # Parse spider X (spx)
  SPIDER_X=$(echo "$PARAMS" | grep -o 'spx=[^&]*' | cut -d '=' -f2)
  SPIDER_X=$(echo "$SPIDER_X" | sed 's/%2F/\//g')  # URL decode
  
  # Verify essential parameters
  if [[ -z "$UUID" || -z "$SERVER_IP" || -z "$SERVER_PORT" ]]; then
    echo "Error: Missing essential parameters in VLESS link."
    exit 1
  fi
  
  # Set default values for optional parameters
  SECURITY=${SECURITY:-"reality"}
  FINGERPRINT=${FINGERPRINT:-"chrome"}
  SNI=${SNI:-""}
  SHORT_ID=${SHORT_ID:-""}
  SPIDER_X=${SPIDER_X:-"/"}
  # Print extracted information
  echo "PARAMS: $PARAMS"
  echo "Extracted configuration:"
  echo "Server: $SERVER_IP:$SERVER_PORT"
  echo "UUID: $UUID"
  echo "Security: $SECURITY"
  echo "Public Key: $PUBLIC_KEY"
  echo "Fingerprint: $FINGERPRINT"
  echo "SNI: $SNI"
  echo "Short ID: $SHORT_ID"
  echo "Spider X: $SPIDER_X"
  
  # Local port for dokodemo-door
  LOCAL_PORT="12345"
}

# Install required packages
install_dependencies() {
  apt update
  apt install -y iproute2 dnsutils iptables-persistent net-tools curl unzip
}

# Install Xray if not already installed
install_xray() {
  if ! command -v xray &> /dev/null; then
    echo "Installing Xray..."
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
  fi
}

# Create Xray configuration
create_config() {
  mkdir -p /usr/local/etc/xray
  
  cat > /usr/local/etc/xray/config.json << EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": ${LOCAL_PORT},
      "protocol": "dokodemo-door",
      "settings": {
        "network": "tcp,udp",
        "followRedirect": true
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "${SERVER_IP}",
            "port": ${SERVER_PORT},
            "users": [
              {
                "id": "${UUID}",
                "encryption": "none"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "${SECURITY}",
        "realitySettings": {
          "fingerprint": "${FINGERPRINT}",
          "serverName": "${SNI}",
          "publicKey": "${PUBLIC_KEY}",
          "shortId": "${SHORT_ID}",
          "spiderX": "${SPIDER_X}"
        }
      },
      "tag": "proxy"
    },
    {
      "protocol": "freedom",
      "settings": {},
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "block"
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "ip": ["geoip:private"],
        "outboundTag": "direct"
      },
      {
        "type": "field",
        "domain": ["geosite:category-ads"],
        "outboundTag": "block"
      },
      {
        "type": "field",
        "network": "tcp,udp",
        "outboundTag": "proxy"
      }
    ]
  },
  "dns": {
    "servers": [
      "8.8.8.8",
      "1.1.1.1"
    ]
  }
}
EOF
}

setup_iptables() {
  # Create XRAY chain if it doesn't exist
  iptables -t nat -N XRAY 2>/dev/null || true
  
  # Clear existing rules
  iptables -t nat -F XRAY
  
  # Add routing rules
  iptables -t nat -A XRAY -d ${SERVER_IP} -j RETURN
  iptables -t nat -A XRAY -d 0.0.0.0/8 -j RETURN
  iptables -t nat -A XRAY -d 10.0.0.0/8 -j RETURN
  iptables -t nat -A XRAY -d 127.0.0.0/8 -j RETURN
  iptables -t nat -A XRAY -d 169.254.0.0/16 -j RETURN
  iptables -t nat -A XRAY -d 172.16.0.0/12 -j RETURN
  iptables -t nat -A XRAY -d 192.168.0.0/16 -j RETURN
  iptables -t nat -A XRAY -d 224.0.0.0/4 -j RETURN
  iptables -t nat -A XRAY -d 240.0.0.0/4 -j RETURN
  
  # Redirect TCP traffic to Xray
  iptables -t nat -A XRAY -p tcp -j REDIRECT --to-port ${LOCAL_PORT}
  
  # Apply rules to OUTPUT chain (for local traffic)
  iptables -t nat -C OUTPUT -p tcp -j XRAY 2>/dev/null || iptables -t nat -A OUTPUT -p tcp -j XRAY
  
  # Save the rules
  iptables-save > /etc/iptables/rules.v4
}

setup_dns() {
  # Backup original DNS configuration
  if [ ! -f /etc/resolv.conf.backup ]; then
    cp /etc/resolv.conf /etc/resolv.conf.backup
  fi
  
  # Set DNS servers to prevent leaks
  echo "nameserver 8.8.8.8" > /etc/resolv.conf
  echo "nameserver 1.1.1.1" >> /etc/resolv.conf
}

start_vpn() {
  echo "Starting VPN..."
  
  if [ -z "$VLESS_LINK" ]; then
    echo "No VLESS link provided. Please provide one with -l or --link option."
    exit 1
  fi
  
  # Parse the VLESS link
  parse_vless_link "$VLESS_LINK"
  
  # Install dependencies if needed
  install_dependencies
  install_xray
  
  # Configure Xray
  create_config
  
  # Setup iptables
  setup_iptables
  
  # Configure DNS
  setup_dns
  
  # Start Xray
  if [ -f "/var/run/xray-vpn.pid" ]; then
    kill $(cat /var/run/xray-vpn.pid) 2>/dev/null
  fi
  
  xray -config /usr/local/etc/xray/config.json &
  echo $! > /var/run/xray-vpn.pid
  
  echo "VPN started. All traffic is now routed through the tunnel."
  echo "Your original network settings are backed up and can be restored with: $0 stop"
}

stop_vpn() {
  echo "Stopping VPN..."
  
  # Kill Xray
  if [ -f "/var/run/xray-vpn.pid" ]; then
    kill $(cat /var/run/xray-vpn.pid) 2>/dev/null
    rm /var/run/xray-vpn.pid
  fi
  
  # Restore DNS
  if [ -f "/etc/resolv.conf.backup" ]; then
    cp /etc/resolv.conf.backup /etc/resolv.conf
  fi
  
  # Clear iptables rules
  iptables -t nat -D OUTPUT -p tcp -j XRAY 2>/dev/null || true
  iptables -t nat -F XRAY 2>/dev/null
  
  echo "VPN stopped. Original network settings restored."
}

status_vpn() {
  if [ -f "/var/run/xray-vpn.pid" ] && ps -p $(cat /var/run/xray-vpn.pid) > /dev/null; then
    echo "VPN is running."
    echo "Current external IP:"
    curl -s https://ipinfo.io/ip
  else
    echo "VPN is not running."
  fi
}

# Parse command line arguments
VLESS_LINK=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -l|--link)
      VLESS_LINK="$2"
      shift 2
      ;;
    start|stop|restart|status)
      COMMAND="$1"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 {start|stop|restart|status} [-l|--link VLESS_LINK]"
      exit 1
      ;;
  esac
done

# Execute the command
case "$COMMAND" in
  start)
    start_vpn
    ;;
  stop)
    stop_vpn
    ;;
  restart)
    stop_vpn
    sleep 2
    start_vpn
    ;;
  status)
    status_vpn
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status} [-l|--link VLESS_LINK]"
    exit 1
    ;;
esac

exit 0
