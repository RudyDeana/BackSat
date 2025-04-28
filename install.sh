#!/bin/bash
# BackSat OS - Installation Script
# ---------------------------------------
# This script configures a Raspberry Pi as a basic BackSat node
echo "====================================================="
echo "   BackSat OS - The Backpack Satellite"
echo "====================================================="
echo "Installation in progress..."
echo ""

# System update
echo "[1/8] Updating system..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y git dnsmasq hostapd python3-pip nginx sqlite3 python3-flask jq wget unzip network-manager uuidgen rfkill

# Creating BackSat directories
echo "[2/8] Creating BackSat directory structure..."
sudo mkdir -p /opt/backsat/{database,files,dashboard,logs,addons,config,bin}

# Wi-Fi hotspot configuration
echo "[3/8] Creating default Wi-Fi configuration..."
# Create configuration file
cat > /tmp/backsat_config.json << EOF
{
  "wifi": {
    "ssid": "BackSat-OS",
    "password": "backsat2025",
    "channel": 7
  },
  "system": {
    "node_name": "BackSat-Node",
    "mode": "public",
    "version": "0.1.0",
    "auto_start": true
  },
  "addons": {
    "enabled": []
  }
}
EOF
sudo mv /tmp/backsat_config.json /opt/backsat/config/config.json

# Configurazione NetworkManager
echo "[4/8] Configuring Wi-Fi Access Point..."
cat > /tmp/backsat-ap << EOF
[connection]
id=BackSat-AP
uuid=$(uuidgen)
type=wifi
interface-name=wlan0
permissions=

[wifi]
band=bg
mode=ap
ssid=BackSat-OS

[wifi-security]
key-mgmt=wpa-psk
psk=backsat2025

[ipv4]
method=shared
address1=192.168.4.1/24

[ipv6]
method=ignore
EOF

sudo mv /tmp/backsat-ap /etc/NetworkManager/system-connections/BackSat-AP
sudo chmod 600 /etc/NetworkManager/system-connections/BackSat-AP

# Configurazione hostapd semplificata per massima compatibilità
cat > /tmp/hostapd.conf << EOF
# Interfaccia Wi-Fi
interface=wlan0

# Configurazione driver
driver=nl80211

# Configurazione base AP
ssid=BackSat-OS
hw_mode=g
channel=6
beacon_int=100

# Sicurezza base
auth_algs=1
wpa=2
wpa_passphrase=backsat2025
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
rsn_pairwise=CCMP

# Disabilitare caratteristiche avanzate
wmm_enabled=0
macaddr_acl=0
ignore_broadcast_ssid=0
EOF

sudo mv /tmp/hostapd.conf /etc/hostapd/hostapd.conf
sudo chmod 600 /etc/hostapd/hostapd.conf

# Configurare il paese per il Wi-Fi
sudo raspi-config nonint do_wifi_country IT

# Configurazione dnsmasq più robusta
cat > /tmp/dnsmasq.conf << EOF
# Interfaccia Wi-Fi
interface=wlan0
# Non utilizzare /etc/resolv.conf
no-resolv
# Server DNS di Google come fallback
server=8.8.8.8
server=8.8.4.4
# Range DHCP
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
# Gateway
dhcp-option=3,192.168.4.1
# DNS
dhcp-option=6,192.168.4.1
# Dominio locale
local=/local/
domain=local
# Risoluzione nome BackSat
address=/backsat.local/192.168.4.1
EOF

sudo mv /tmp/dnsmasq.conf /etc/dnsmasq.conf

# Creare lo script di controllo BackSat
echo "[5/8] Creating control script..."
cat > /tmp/backsat << 'EOF'
#!/bin/bash

reload_services() {
    echo "Reloading systemd services..."
    sudo systemctl daemon-reload
}

start_services() {
    echo "Starting BackSat services..."
    reload_services
    
    # Preparazione interfaccia
    sudo rfkill unblock wifi
    sudo rfkill unblock wlan
    sudo ip link set wlan0 down
    sudo ip addr flush dev wlan0
    sudo ip link set wlan0 up
    sudo ip addr add 192.168.4.1/24 dev wlan0
    sleep 2
    
    # Avvio servizi
    sudo systemctl start dnsmasq
    sleep 2
    sudo hostapd -B /etc/hostapd/hostapd.conf
    sleep 2
    sudo systemctl start backsat
    sleep 2
    sudo systemctl start nginx
    
    echo "All services started. Wait 30 seconds before connecting."
    echo "If connection fails, try: backsat wifi-restart"
}

stop_services() {
    echo "Stopping BackSat services..."
    sudo systemctl stop nginx
    sudo systemctl stop backsat
    sudo killall hostapd
    sudo systemctl stop dnsmasq
    sudo ip link set wlan0 down
}

restart_wifi() {
    echo "Restarting Wi-Fi services..."
    
    # Stop tutti i servizi
    sudo systemctl stop hostapd dnsmasq
    sudo killall hostapd 2>/dev/null
    
    # Reset completo Wi-Fi
    sudo rfkill unblock all
    sudo ifconfig wlan0 down
    sudo ifconfig wlan0 up
    sleep 2
    
    # Configurazione IP statico
    sudo ifconfig wlan0 192.168.4.1 netmask 255.255.255.0
    sleep 2
    
    # Test configurazione hostapd
    echo "Testing hostapd configuration..."
    sudo hostapd -d /etc/hostapd/hostapd.conf &
    HOSTAPD_PID=$!
    sleep 5
    
    if ps -p $HOSTAPD_PID > /dev/null; then
        echo "hostapd started successfully"
        sudo kill $HOSTAPD_PID
    else
        echo "hostapd failed to start, trying backup configuration..."
        # Configurazione di backup ultra-base
        cat > /tmp/hostapd_backup.conf << EOB
interface=wlan0
driver=nl80211
ssid=BackSat-OS
hw_mode=g
channel=6
auth_algs=1
wpa=2
wpa_passphrase=backsat2025
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
EOB
        sudo mv /tmp/hostapd_backup.conf /etc/hostapd/hostapd.conf
    fi
    
    # Avvio finale dei servizi
    echo "Starting services..."
    sudo hostapd -B /etc/hostapd/hostapd.conf
    sleep 2
    sudo systemctl restart dnsmasq
    
    # Verifica finale
    echo -e "\nNetwork configuration:"
    ifconfig wlan0
    echo -e "\nActive wireless networks:"
    iwconfig wlan0
    echo -e "\nRunning processes:"
    ps aux | grep hostapd | grep -v grep
    
    echo -e "\nWi-Fi services restarted. The network should be available in 30 seconds."
    echo "Network name: BackSat-OS"
    echo "Password: backsat2025"
    echo "If connection fails, run: backsat debug"
}

update_backsat() {
    echo "Updating BackSat OS..."
    curl -s https://raw.githubusercontent.com/RudyDeana/BackSat/refs/heads/main/install.sh | bash
}

debug_wifi() {
    echo "=== BackSat Wi-Fi Debug ==="
    
    echo -e "\n[1/8] Kernel Wi-Fi modules:"
    lsmod | grep -E 'wifi|wlan|cfg80211|mac80211'
    
    echo -e "\n[2/8] RF Kill status:"
    sudo rfkill list all
    
    echo -e "\n[3/8] Network interfaces:"
    ifconfig -a
    
    echo -e "\n[4/8] Wireless interfaces:"
    iwconfig
    
    echo -e "\n[5/8] hostapd configuration:"
    cat /etc/hostapd/hostapd.conf
    
    echo -e "\n[6/8] Running processes:"
    ps aux | grep -E 'hostapd|dnsmasq' | grep -v grep
    
    echo -e "\n[7/8] System logs:"
    journalctl -n 50 | grep -i "hostapd\|dnsmasq"
    
    echo -e "\n[8/8] Network routing:"
    netstat -rn
    
    echo -e "\nTo restart Wi-Fi completely:"
    echo "1. Run: backsat stop"
    echo "2. Wait 10 seconds"
    echo "3. Run: backsat wifi-restart"
    echo "4. Wait 30 seconds before trying to connect"
}

show_status() {
    echo "=== BackSat Services Status ==="
    echo -e "\n[1/5] hostapd process:"
    ps aux | grep hostapd
    
    echo -e "\n[2/5] dnsmasq status:"
    systemctl status dnsmasq | cat
    
    echo -e "\n[3/5] backsat status:"
    systemctl status backsat | cat
    
    echo -e "\n[4/5] nginx status:"
    systemctl status nginx | cat
    
    echo -e "\n[5/5] Network Interface:"
    ip addr show wlan0
}

case "$1" in
    "start")
        start_services
        ;;
    "stop")
        stop_services
        ;;
    "restart")
        stop_services
        sleep 5
        start_services
        ;;
    "update")
        update_backsat
        ;;
    "wifi-restart")
        restart_wifi
        ;;
    "debug")
        debug_wifi
        ;;
    "status")
        show_status
        ;;
    "reload")
        reload_services
        ;;
    "check")
        echo "=== BackSat Installation Check ==="
        echo -e "\n[1/7] Checking directories..."
        for dir in database files dashboard logs addons config bin; do
            if [ -d "/opt/backsat/$dir" ]; then
                echo "✓ /opt/backsat/$dir exists"
            else
                echo "✗ /opt/backsat/$dir missing!"
            fi
        done
        
        echo -e "\n[2/7] Checking core files..."
        for file in "/opt/backsat/dashboard/app.py" "/opt/backsat/dashboard/templates/index.html" "/opt/backsat/config/config.json"; do
            if [ -f "$file" ]; then
                echo "✓ $file exists"
            else
                echo "✗ $file missing!"
            fi
        done
        
        echo -e "\n[3/7] Checking services..."
        for service in nginx hostapd dnsmasq backsat; do
            if systemctl is-enabled $service >/dev/null 2>&1; then
                echo "✓ $service is enabled"
            else
                echo "✗ $service not enabled!"
            fi
        done
        
        echo -e "\n[4/7] Checking network configuration..."
        if [ -f "/etc/hostapd/hostapd.conf" ]; then
            echo "✓ hostapd configuration exists"
        else
            echo "✗ hostapd configuration missing!"
        fi
        
        echo -e "\n[5/7] Checking database..."
        if [ -f "/opt/backsat/database/backsat.db" ]; then
            echo "✓ Database file exists"
        else
            echo "✗ Database file missing!"
        fi
        
        echo -e "\n[6/7] Checking permissions..."
        for file in "/opt/backsat/dashboard/app.py" "/opt/backsat/dashboard/templates/index.html"; do
            if [ "$(stat -c %a $file 2>/dev/null)" = "644" ]; then
                echo "✓ $file has correct permissions"
            else
                echo "✗ $file has wrong permissions!"
            fi
        done
        
        echo -e "\n[7/7] Network interface status..."
        ip link show wlan0
        ;;
    *)
        echo "BackSat OS Control"
        echo "Usage: backsat <command>"
        echo ""
        echo "Main Commands:"
        echo "  start        - Start all BackSat services"
        echo "  stop         - Stop all services"
        echo "  restart      - Restart all services"
        echo "  status       - Show detailed status of all services"
        echo ""
        echo "Network Commands:"
        echo "  wifi-restart - Reset and restart Wi-Fi services"
        echo "  debug        - Show detailed Wi-Fi debug information"
        echo ""
        echo "System Commands:"
        echo "  update       - Update BackSat OS from GitHub"
        echo "  reload       - Reload systemd services"
        echo "  check        - Check installation status and files"
        echo ""
        echo "Quick Start:"
        echo "1. Run 'backsat start' to start all services"
        echo "2. Wait 30 seconds"
        echo "3. Connect to 'BackSat-OS' Wi-Fi (password: backsat2025)"
        echo "4. Open http://backsat.local or http://192.168.4.1"
        echo ""
        echo "Troubleshooting:"
        echo "- If Wi-Fi doesn't work: backsat wifi-restart"
        echo "- If web interface doesn't work: backsat restart"
        echo "- For detailed diagnostics: backsat debug"
        echo "- To check installation: backsat check"
        echo ""
        echo "For more information visit:"
        echo "  https://github.com/RudyDeana/BackSat"
        ;;
esac

sudo mv /tmp/backsat /usr/local/bin/backsat
sudo chmod +x /usr/local/bin/backsat
