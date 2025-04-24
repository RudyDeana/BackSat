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
sudo apt install -y git dnsmasq hostapd python3-pip nginx sqlite3 python3-flask jq wget unzip network-manager

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

# Configurazione hostapd
sudo mkdir -p /etc/hostapd
cat > /tmp/hostapd.conf << EOF
interface=wlan0
driver=nl80211
ssid=BackSat-OS
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=backsat2025
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
country_code=IT
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
# Log per debug
log-queries
log-dhcp
EOF

sudo mv /tmp/dnsmasq.conf /etc/dnsmasq.conf

# Configurazione iniziale dell'interfaccia di rete
echo "Configuring network interface..."
cat > /tmp/interfaces << EOF
allow-hotplug wlan0
iface wlan0 inet static
    address 192.168.4.1
    netmask 255.255.255.0
    network 192.168.4.0
    broadcast 192.168.4.255
EOF
sudo mv /tmp/interfaces /etc/network/interfaces.d/wlan0

# Configurazione di hostapd
sudo mkdir -p /etc/hostapd
sudo cp /opt/backsat/config/hostapd.template /etc/hostapd/hostapd.conf
sudo sed -i "s/{{SSID}}/BackSat-OS/g; s/{{PASSWORD}}/backsat2025/g; s/{{CHANNEL}}/7/g" /etc/hostapd/hostapd.conf
sudo chmod 600 /etc/hostapd/hostapd.conf

# Assicurarsi che hostapd non sia masked
sudo systemctl unmask hostapd

# Configurare hostapd per avviarsi all'avvio
cat > /tmp/hostapd << EOF
DAEMON_CONF="/etc/hostapd/hostapd.conf"
EOF
sudo mv /tmp/hostapd /etc/default/hostapd

# Configurazione di dnsmasq
sudo cp /opt/backsat/config/dnsmasq.template /etc/dnsmasq.conf

# Abilitare il forwarding IP
echo "Enabling IP forwarding..."
sudo sh -c "echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf"
sudo sysctl -p

# Abilitare e avviare i servizi
sudo systemctl enable hostapd
sudo systemctl enable dnsmasq

# Configurare rfkill
sudo rfkill unblock wifi
sudo rfkill unblock wlan

# Riavviare i servizi di rete
sudo systemctl restart networking
sudo systemctl restart hostapd
sudo systemctl restart dnsmasq

# BackSat control script
echo "[4/8] Creating BackSat control script..."
cat > /tmp/backsat << 'EOF'
#!/bin/bash

update_backsat() {
    echo "Updating BackSat OS..."
    curl -s https://raw.githubusercontent.com/RudyDeana/BackSat/refs/heads/main/install.sh | bash
}

restart_wifi() {
    echo "Restarting Wi-Fi services..."
    sudo rfkill unblock wifi
    sudo rfkill unblock wlan
    sudo systemctl restart NetworkManager
    sudo ip link set wlan0 down
    sudo ip addr flush dev wlan0
    sudo ip link set wlan0 up
    sudo systemctl restart hostapd
    sudo systemctl restart dnsmasq
    echo "Wi-Fi services restarted. Wait 30 seconds and try connecting again."
}

case "$1" in
    "start")
        sudo systemctl start hostapd dnsmasq backsat nginx
        ;;
    "stop")
        sudo systemctl stop hostapd dnsmasq backsat nginx
        ;;
    "restart")
        sudo systemctl restart hostapd dnsmasq backsat nginx
        ;;
    "update")
        update_backsat
        ;;
    "wifi-restart")
        restart_wifi
        ;;
    "status")
        echo "=== BackSat Services Status ==="
        systemctl status hostapd dnsmasq backsat nginx | cat
        ;;
    *)
        echo "BackSat OS Control"
        echo "Usage: backsat <command>"
        echo ""
        echo "Commands:"
        echo "  start        - Start all services"
        echo "  stop         - Stop all services"
        echo "  restart      - Restart all services"
        echo "  update       - Update BackSat OS"
        echo "  wifi-restart - Restart Wi-Fi services"
        echo "  status       - Show services status"
        echo ""
        echo "Debug commands:"
        echo "  backsat-test   - Test connectivity"
        echo "  backsat-debug  - Show Wi-Fi diagnostic"
        ;;
esac
EOF
sudo mv /tmp/backsat /usr/local/bin/backsat
sudo chmod +x /usr/local/bin/backsat
# Installing web dashboard (Flask)
echo "[5/8] Installing web dashboard..."
cat > /opt/backsat/dashboard/app.py << EOF
from flask import Flask, render_template, request, jsonify, send_from_directory
import os
import sqlite3
import datetime
import json
import subprocess
app = Flask(__name__)
# Database configuration
def get_db():
    conn = sqlite3.connect('/opt/backsat/database/backsat.db')
    conn.row_factory = sqlite3.Row
    return conn
# Load configuration
def load_config():
    with open('/opt/backsat/config/config.json', 'r') as f:
        return json.load(f)
# Create tables if they don't exist
def init_db():
    with get_db() as db:
        db.execute('''
        CREATE TABLE IF NOT EXISTS messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sender TEXT NOT NULL,
            content TEXT NOT NULL,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        )
        ''')
        
        db.execute('''
        CREATE TABLE IF NOT EXISTS nodes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            node_id TEXT UNIQUE NOT NULL,
            node_name TEXT NOT NULL,
            last_seen DATETIME DEFAULT CURRENT_TIMESTAMP
        )
        ''')
        
        db.execute('''
        CREATE TABLE IF NOT EXISTS files (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            filename TEXT NOT NULL,
            description TEXT,
            uploaded_by TEXT NOT NULL,
            path TEXT NOT NULL,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        )
        ''')
init_db()
@app.route('/')
def index():
    config = load_config()
    return render_template('index.html', config=config)
@app.route('/messages', methods=['GET', 'POST'])
def messages():
    if request.method == 'POST':
        data = request.json
        sender = data.get('sender', 'Anonymous')
        content = data.get('content')
        
        if content:
            with get_db() as db:
                db.execute('INSERT INTO messages (sender, content) VALUES (?, ?)',
                          (sender, content))
            return jsonify({'status': 'success'})
        return jsonify({'status': 'error', 'message': 'Content required'})
    
    # GET request - retrieve messages
    with get_db() as db:
        messages = db.execute('SELECT * FROM messages ORDER BY timestamp DESC LIMIT 100').fetchall()
    
    return jsonify([dict(msg) for msg in messages])
@app.route('/system/info')
def system_info():
    config = load_config()
    
    # System information
    uptime = subprocess.check_output("uptime -p", shell=True).decode('utf-8').strip()
    
    # Count nearby nodes (simulated for now)
    with get_db() as db:
        nearby_nodes = len(db.execute('SELECT * FROM nodes').fetchall())
    
    return jsonify({
        'node_name': config['system']['node_name'],
        'mode': config['system']['mode'],
        'version': config['system']['version'],
        'uptime': uptime,
        'nearby_nodes': nearby_nodes,
        'wifi': {
            'ssid': config['wifi']['ssid']
        }
    })
@app.route('/files', methods=['GET', 'POST'])
def files():
    if request.method == 'POST':
        # File upload handling (to be implemented)
        return jsonify({'status': 'error', 'message': 'Feature in development'})
    
    # GET request - retrieve files
    with get_db() as db:
        files = db.execute('SELECT * FROM files ORDER BY timestamp DESC').fetchall()
    
    return jsonify([dict(f) for f in files])
@app.route('/addons')
def addons():
    config = load_config()
    return jsonify({
        'enabled': config['addons']['enabled'],
        'available': os.listdir('/opt/backsat/addons/available') if os.path.exists('/opt/backsat/addons/available') else []
    })
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
EOF
# Creating basic HTML templates
mkdir -p /opt/backsat/dashboard/templates
cat > /opt/backsat/dashboard/templates/index.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>BackSat OS - Dashboard</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f0f0f0;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background: white;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            text-align: center;
        }
        .module {
            margin-bottom: 20px;
            padding: 15px;
            border: 1px solid #ddd;
            border-radius: 5px;
        }
        .module h2 {
            margin-top: 0;
            color: #444;
        }
        .chat-container {
            height: 300px;
            overflow-y: auto;
            border: 1px solid #ccc;
            padding: 10px;
            margin-bottom: 10px;
        }
        .message {
            margin-bottom: 10px;
            padding: 8px;
            border-radius: 5px;
        }
        .message .sender {
            font-weight: bold;
        }
        .message .time {
            font-size: 0.8em;
            color: #888;
        }
        #message-form {
            display: flex;
        }
        #message-input {
            flex-grow: 1;
            padding: 8px;
            margin-right: 10px;
        }
        .tabs {
            display: flex;
            margin-bottom: 20px;
            border-bottom: 1px solid #ddd;
        }
        .tab {
            padding: 10px 20px;
            cursor: pointer;
            background: #f5f5f5;
            border: 1px solid #ddd;
            border-bottom: none;
            margin-right: 5px;
            border-radius: 5px 5px 0 0;
        }
        .tab.active {
            background: white;
            font-weight: bold;
        }
        .tab-content {
            display: none;
        }
        .tab-content.active {
            display: block;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>BackSat OS - Dashboard</h1>
        
        <div class="tabs">
            <div class="tab active" data-tab="home">Home</div>
            <div class="tab" data-tab="chat">P2P Chat</div>
            <div class="tab" data-tab="files">Files</div>
            <div class="tab" data-tab="settings">Settings</div>
        </div>
        
        <div id="home" class="tab-content active">
            <div class="module">
                <h2>System Status</h2>
                <p>Node name: <strong id="node-name">Loading...</strong></p>
                <p>Mode: <strong id="mode">Loading...</strong></p>
                <p>Version: <strong id="version">Loading...</strong></p>
                <p>Network SSID: <strong id="wifi-ssid">Loading...</strong></p>
                <p>Uptime: <strong id="uptime">Loading...</strong></p>
                <p>Nearby nodes: <strong id="nearby-nodes">Loading...</strong></p>
            </div>
            
            <div class="module">
                <h2>Installed Add-ons</h2>
                <div id="addon-list">Loading...</div>
            </div>
        </div>
        
        <div id="chat" class="tab-content">
            <div class="module">
                <h2>P2P Chat</h2>
                <div id="chat-container" class="chat-container">
                    <!-- Messages will be loaded here -->
                </div>
                <form id="message-form">
                    <input type="text" id="message-input" placeholder="Write a message...">
                    <button type="submit">Send</button>
                </form>
            </div>
        </div>
        
        <div id="files" class="tab-content">
            <div class="module">
                <h2>Shared Files</h2>
                <p>Feature in development...</p>
            </div>
        </div>
        
        <div id="settings" class="tab-content">
            <div class="module">
                <h2>Settings</h2>
                <p>Settings can be modified from command line:</p>
                <code>backsat wifi-config new-ssid new-password</code>
                <p>To see all available commands:</p>
                <code>backsat help</code>
            </div>
        </div>
    </div>
    <script>
        // Tab switching
        document.querySelectorAll('.tab').forEach(tab => {
            tab.addEventListener('click', function() {
                // Remove active from all tabs
                document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
                document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
                
                // Add active to clicked tab
                this.classList.add('active');
                document.getElementById(this.dataset.tab).classList.add('active');
            });
        });
        
        // Load system information
        function loadSystemInfo() {
            fetch('/system/info')
                .then(response => response.json())
                .then(info => {
                    document.getElementById('node-name').textContent = info.node_name;
                    document.getElementById('mode').textContent = info.mode;
                    document.getElementById('version').textContent = info.version;
                    document.getElementById('wifi-ssid').textContent = info.wifi.ssid;
                    document.getElementById('uptime').textContent = info.uptime;
                    document.getElementById('nearby-nodes').textContent = info.nearby_nodes + ' nodes';
                })
                .catch(error => console.error('Error loading system info:', error));
        }
        
        // Load addons
        function loadAddons() {
            fetch('/addons')
                .then(response => response.json())
                .then(data => {
                    const addonList = document.getElementById('addon-list');
                    if (data.enabled.length === 0) {
                        addonList.textContent = 'No active add-ons';
                    } else {
                        addonList.innerHTML = '<ul>' + 
                            data.enabled.map(addon => `<li>${addon}</li>`).join('') +
                            '</ul>';
                    }
                })
                .catch(error => console.error('Error loading addons:', error));
        }
        
        // Function to load messages
        function loadMessages() {
            fetch('/messages')
                .then(response => response.json())
                .then(messages => {
                    const chatContainer = document.getElementById('chat-container');
                    chatContainer.innerHTML = '';
                    
                    messages.forEach(msg => {
                        const messageDiv = document.createElement('div');
                        messageDiv.className = 'message';
                        
                        const senderSpan = document.createElement('span');
                        senderSpan.className = 'sender';
                        senderSpan.textContent = msg.sender + ': ';
                        
                        const contentSpan = document.createElement('span');
                        contentSpan.textContent = msg.content;
                        
                        const timeSpan = document.createElement('span');
                        timeSpan.className = 'time';
                        timeSpan.textContent = ' - ' + new Date(msg.timestamp).toLocaleTimeString();
                        
                        messageDiv.appendChild(senderSpan);
                        messageDiv.appendChild(contentSpan);
                        messageDiv.appendChild(timeSpan);
                        
                        chatContainer.appendChild(messageDiv);
                    });
                })
                .catch(error => console.error('Error loading messages:', error));
        }
        
        // Send a new message
        document.getElementById('message-form').addEventListener('submit', function(e) {
            e.preventDefault();
            
            const input = document.getElementById('message-input');
            const content = input.value.trim();
            
            if (content) {
                fetch('/messages', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        sender: 'Local user',
                        content: content
                    })
                })
                .then(response => response.json())
                .then(data => {
                    if (data.status === 'success') {
                        input.value = '';
                        loadMessages();
                    }
                })
                .catch(error => console.error('Error sending message:', error));
            }
        });
        
        // Load information at startup
        loadSystemInfo();
        loadAddons();
        loadMessages();
        
        // Update every 10 seconds
        setInterval(loadSystemInfo, 10000);
        setInterval(loadMessages, 5000);
    </script>
</body>
</html>
EOF
# Configurazione Nginx migliorata
cat > /tmp/backsat << EOF
server {
    listen 80;
    listen [::]:80;
    
    server_name backsat.local;
    
    access_log /var/log/nginx/backsat.access.log;
    error_log /var/log/nginx/backsat.error.log;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeouts più lunghi per debug
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

sudo mv /tmp/backsat /etc/nginx/sites-available/backsat
sudo ln -sf /etc/nginx/sites-available/backsat /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Configurazione systemd per Flask
cat > /tmp/backsat.service << EOF
[Unit]
Description=BackSat OS Dashboard
After=network.target

[Service]
User=root
WorkingDirectory=/opt/backsat/dashboard
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=/usr/bin/python3 app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo mv /tmp/backsat.service /etc/systemd/system/backsat.service

# Aggiungere script di test connettività
cat > /tmp/backsat-test << 'EOF'
#!/bin/bash

echo "=== Test Connettività BackSat ==="
echo "1. Test DNS locale..."
nslookup backsat.local 192.168.4.1

echo -e "\n2. Test connessione web..."
curl -v http://backsat.local

echo -e "\n3. Status servizi web..."
systemctl status nginx
systemctl status backsat

echo -e "\n4. Log nginx..."
tail -n 20 /var/log/nginx/error.log

echo -e "\n5. Log applicazione..."
journalctl -u backsat -n 20
EOF

sudo mv /tmp/backsat-test /usr/local/bin/backsat-test
sudo chmod +x /usr/local/bin/backsat-test

# Configure permissions
echo "[8/8] Configuring final permissions..."
sudo chown -R pi:pi /opt/backsat
# Create wrapper installer script for GitHub
cat > /tmp/installer.sh << EOF
#!/bin/bash
# BackSat OS - Installer Wrapper
echo "====================================================="
echo "   BackSat OS - The Backpack Satellite"
echo "====================================================="
echo "Downloading..."
# Download installation script
wget -q https://raw.githubusercontent.com/backsatos/installer/main/install.sh -O /tmp/backsat_install.sh
chmod +x /tmp/backsat_install.sh
# Run installation script
bash /tmp/backsat_install.sh
# Cleanup
rm -f /tmp/backsat_install.sh
EOF
sudo mv /tmp/installer.sh /usr/local/bin/backsat-installer
sudo chmod +x /usr/local/bin/backsat-installer
echo ""
echo "====================================================="
echo "BackSat OS installation completed!"
echo "====================================================="
echo ""
echo "Your BackSat node is ready."
echo ""
echo "Main commands:"
echo "  backsat start      - Start BackSat services"
echo "  backsat stop       - Stop BackSat services"
echo "  backsat restart    - Restart BackSat services"
echo "  backsat debug      - Show diagnostic information"
echo ""

# Aggiungere al messaggio finale
echo "For connection issues:"
echo "  backsat wifi-restart  - Restart Wi-Fi services"
echo "  backsat-test         - Test connectivity"
echo "  backsat-debug        - Show Wi-Fi diagnostic"
echo ""
echo "To update BackSat:"
echo "  backsat update"
echo ""
echo "After startup:"
echo "1. Connect to the 'BackSat-OS' Wi-Fi network (password: backsat2025)"
echo "2. If connection fails, wait 30 seconds and try:"
echo "   backsat wifi-restart"
echo "3. Access the dashboard: http://backsat.local or http://192.168.4.1"
echo ""
echo "Good journey with BackSat!"
