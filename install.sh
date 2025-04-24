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
sudo apt install -y git dnsmasq hostapd python3-pip nginx sqlite3 python3-flask jq wget unzip
# Creating BackSat directories
echo "[2/8] Creating BackSat directory structure..."
sudo mkdir -p /opt/backsat
sudo mkdir -p /opt/backsat/database
sudo mkdir -p /opt/backsat/files
sudo mkdir -p /opt/backsat/dashboard
sudo mkdir -p /opt/backsat/logs
sudo mkdir -p /opt/backsat/addons
sudo mkdir -p /opt/backsat/config
sudo mkdir -p /opt/backsat/bin
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

# Creating hostapd and dnsmasq templates
cat > /opt/backsat/config/hostapd.template << EOF
interface=wlan0
driver=nl80211
ssid={{SSID}}
hw_mode=g
channel={{CHANNEL}}
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase={{PASSWORD}}
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF

cat > /opt/backsat/config/dnsmasq.template << EOF
interface=wlan0
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
domain=local
address=/backsat.local/192.168.4.1
EOF

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
cat > /tmp/backsat << EOF
#!/bin/bash
# BackSat - Main control script
BACKSAT_DIR="/opt/backsat"
CONFIG_FILE="\$BACKSAT_DIR/config/config.json"
# Function to generate configuration files from templates
generate_config_files() {
  # Read from configuration
  SSID=\$(jq -r '.wifi.ssid' \$CONFIG_FILE)
  PASSWORD=\$(jq -r '.wifi.password' \$CONFIG_FILE)
  CHANNEL=\$(jq -r '.wifi.channel' \$CONFIG_FILE)
  
  # Generate hostapd.conf
  sed "s/{{SSID}}/\$SSID/g; s/{{PASSWORD}}/\$PASSWORD/g; s/{{CHANNEL}}/\$CHANNEL/g" \
    \$BACKSAT_DIR/config/hostapd.template > /etc/hostapd/hostapd.conf
  
  # Copy dnsmasq.conf
  cp \$BACKSAT_DIR/config/dnsmasq.template /etc/dnsmasq.conf
  
  echo "Network configuration generated with SSID: \$SSID"
}
# Function to start services
start_services() {
  echo "Starting BackSat services..."
  
  # Generate updated configurations
  generate_config_files
  
  # Restart network services
  systemctl restart hostapd
  systemctl restart dnsmasq
  
  # Start dashboard
  systemctl restart backsat
  systemctl restart nginx
  
  echo "BackSat OS started! Connect to the Wi-Fi network to access."
}
# Function to stop services
stop_services() {
  echo "Stopping BackSat services..."
  systemctl stop hostapd
  systemctl stop dnsmasq
  systemctl stop backsat
  echo "BackSat OS stopped."
}
# Function to modify SSID and password
change_wifi() {
  if [ -z "\$1" ] || [ -z "\$2" ]; then
    echo "Usage: backsat wifi-config <new-ssid> <new-password>"
    return 1
  fi
  
  # Update JSON configuration file
  TMP_FILE="\$(mktemp)"
  jq ".wifi.ssid = \"\$1\" | .wifi.password = \"\$2\"" \$CONFIG_FILE > \$TMP_FILE
  mv \$TMP_FILE \$CONFIG_FILE
  
  echo "Wi-Fi configuration updated with SSID: \$1"
  echo "To apply changes run: backsat restart"
}
# Update function
update_backsat() {
  echo "Updating BackSat OS..."
  
  # Backup current configuration
  cp \$CONFIG_FILE \$BACKSAT_DIR/config/config.backup.json
  
  # Download latest version from repository
  TMP_DIR="\$(mktemp -d)"
  wget -q https://github.com/backsatos/installer/archive/main.zip -O \$TMP_DIR/backsat.zip
  
  # Extract and update
  unzip -q \$TMP_DIR/backsat.zip -d \$TMP_DIR
  cp -r \$TMP_DIR/installer-main/dashboard/* \$BACKSAT_DIR/dashboard/
  cp -r \$TMP_DIR/installer-main/bin/* \$BACKSAT_DIR/bin/
  
  # Update version in config
  NEW_VERSION=\$(cat \$TMP_DIR/installer-main/version)
  TMP_FILE="\$(mktemp)"
  jq ".system.version = \"\$NEW_VERSION\"" \$CONFIG_FILE > \$TMP_FILE
  mv \$TMP_FILE \$CONFIG_FILE
  
  # Cleanup
  rm -rf \$TMP_DIR
  
  echo "BackSat OS updated to version \$NEW_VERSION"
  echo "To apply changes run: backsat restart"
}
# Add-on management
list_addons() {
  echo "Available add-ons:"
  ls -1 \$BACKSAT_DIR/addons/available/ 2>/dev/null || echo "No add-ons available"
  
  echo -e "\nActive add-ons:"
  ENABLED=\$(jq -r '.addons.enabled[]' \$CONFIG_FILE 2>/dev/null)
  if [ -z "\$ENABLED" ]; then
    echo "No active add-ons"
  else
    echo "\$ENABLED"
  fi
}
install_addon() {
  if [ -z "\$1" ]; then
    echo "Usage: backsat addon-install <addon-name>"
    return 1
  fi
  
  # Verify add-on existence
  if [ ! -d "\$BACKSAT_DIR/addons/available/\$1" ]; then
    echo "Add-on '\$1' not found."
    echo "Downloading from repository..."
    
    # Download add-on from repository
    TMP_DIR="\$(mktemp -d)"
    wget -q "https://github.com/backsatos/addons/archive/\$1.zip" -O \$TMP_DIR/addon.zip
    
    if [ \$? -ne 0 ]; then
      echo "Add-on '\$1' not found in repository."
      rm -rf \$TMP_DIR
      return 1
    fi
    
    # Create directory if it doesn't exist
    mkdir -p \$BACKSAT_DIR/addons/available/
    
    # Extract add-on
    unzip -q \$TMP_DIR/addon.zip -d \$TMP_DIR
    cp -r \$TMP_DIR/addons-\$1 \$BACKSAT_DIR/addons/available/\$1
    
    # Cleanup
    rm -rf \$TMP_DIR
  fi
  
  # Activate add-on
  TMP_FILE="\$(mktemp)"
  jq ".addons.enabled += [\"\$1\"]" \$CONFIG_FILE > \$TMP_FILE
  mv \$TMP_FILE \$CONFIG_FILE
  
  # Run installation script if present
  if [ -f "\$BACKSAT_DIR/addons/available/\$1/install.sh" ]; then
    bash "\$BACKSAT_DIR/addons/available/\$1/install.sh"
  fi
  
  echo "Add-on '\$1' installed. Restart BackSat to activate it: backsat restart"
}
# Help menu
show_help() {
  echo "BackSat OS - The Backpack Satellite"
  echo ""
  echo "Usage: backsat <command>"
  echo ""
  echo "Available commands:"
  echo "  start         - Start BackSat services"
  echo "  stop          - Stop BackSat services"
  echo "  restart       - Restart BackSat services"
  echo "  status        - Show services status"
  echo "  wifi-config   - Change SSID and password (backsat wifi-config <ssid> <password>)"
  echo "  update        - Update BackSat to the latest version"
  echo "  addon-list    - List available and active add-ons"
  echo "  addon-install - Install an add-on (backsat addon-install <addon-name>)"
  echo "  help          - Show this help message"
}
# Argument handling
case "\$1" in
  start)
    start_services
    ;;
  stop)
    stop_services
    ;;
  restart)
    stop_services
    sleep 2
    start_services
    ;;
  status)
    systemctl status hostapd dnsmasq backsat nginx
    ;;
  wifi-config)
    change_wifi "\$2" "\$3"
    ;;
  update)
    update_backsat
    ;;
  addon-list)
    list_addons
    ;;
  addon-install)
    install_addon "\$2"
    ;;
  *)
    show_help
    ;;
esac
exit 0
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
# Configure Nginx as reverse proxy
echo "[6/8] Configuring Nginx as reverse proxy..."
cat > /tmp/backsat << EOF
server {
    listen 80;
    server_name backsat.local;
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF
sudo mv /tmp/backsat /etc/nginx/sites-available/backsat
sudo ln -s /etc/nginx/sites-available/backsat /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
# BackSat startup script
echo "[7/8] Configuring systemd service for BackSat..."
cat > /tmp/backsat.service << EOF
[Unit]
Description=BackSat OS Dashboard
After=network.target
[Service]
User=root
WorkingDirectory=/opt/backsat/dashboard
ExecStart=/usr/bin/python3 app.py
Restart=always
[Install]
WantedBy=multi-user.target
EOF
sudo mv /tmp/backsat.service /etc/systemd/system/backsat.service
sudo systemctl enable backsat.service
sudo systemctl enable hostapd
sudo systemctl enable dnsmasq
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
echo "  backsat start    - Start BackSat services"
echo "  backsat stop     - Stop BackSat services"
echo "  backsat restart  - Restart BackSat services"
echo "  backsat wifi-config <new-ssid> <new-password>  - Change Wi-Fi configuration"
echo "  backsat update   - Update BackSat to the latest version"
echo ""

# Avvio iniziale dei servizi
echo "Starting initial services..."
sudo systemctl restart dnsmasq
sudo systemctl restart hostapd
sudo systemctl restart backsat
sudo systemctl restart nginx

echo "To start BackSat now, run:"
echo "  backsat start"
echo ""
echo "After startup:"
echo "1. Connect to the 'BackSat-OS' Wi-Fi network (password: backsat2025)"
echo "2. Access the dashboard: http://backsat.local"
echo ""
echo "To see all available commands:"
echo "  backsat help"
echo ""
echo "Good journey with BackSat!"
