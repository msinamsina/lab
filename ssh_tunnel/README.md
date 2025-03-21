## Create ssh tunnel
ssh -D <PORT (eg. 1080)>  <USER>@<HOST>

## Installing redsocks
### On Debian
```bash
sudo apt install redsocks
```

##  Redsocks Config

```json
base {
  log_debug = off;
  log_info = on;
  daemon = on;
  redirector = iptables;
}

redsocks {
  local_ip = 127.0.0.1;
  local_port = <redsocks PORT eg. 12345>;

  ip = 127.0.0.1;
  port = <SSH PORT eg. 1080>;

  type = socks5;
  login = "";
  password = "";
}
```

## IPTables Rules (redirect traffic to redsocks)
```bash
# Create new chain
iptables -t nat -N REDSOCKS

# Ignore local/internal traffic
iptables -t nat -A REDSOCKS -d 0.0.0.0/8 -j RETURN
iptables -t nat -A REDSOCKS -d 127.0.0.0/8 -j RETURN
iptables -t nat -A REDSOCKS -d 192.168.0.0/16 -j RETURN
iptables -t nat -A REDSOCKS -d 10.0.0.0/8 -j RETURN
iptables -t nat -A REDSOCKS -d 172.16.0.0/12 -j RETURN

# Redirect all other TCP traffic to redsocks
iptables -t nat -A REDSOCKS -p tcp -j REDIRECT --to-ports 12345

# Apply to OUTPUT chain (for local apps)
iptables -t nat -A OUTPUT -p tcp -j REDSOCKS
```

## Start redsocks
```bash
sudo redsocks -c /path/to/redsocks.conf
```