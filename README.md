# 🌐 BackSat - The Backpack Satellite

**BackSat** is an open-source project that transforms any compatible device into an independent communication node — without SIM cards, cell towers, or internet.

Think of it as a **terrestrial satellite in your backpack**. It creates secure offline networks that work in blackouts, disasters, or remote missions.

## 📡 What is BackSat?

BackSat doesn't fly — but it works like a satellite:
- Forms a local mesh network
- Exchanges encrypted messages and files
- Connects people even without infrastructure
- Works in emergencies and remote locations

## 🚀 Core Features

- 🔁 **Decentralized Mesh Network**
  - Auto-discovery of nearby nodes
  - No central server needed
  - Resilient peer-to-peer communication

- 🔒 **Security First**
  - End-to-end encryption
  - Private or public modes
  - Stealth operation option
  - No data stored on external servers

- 💻 **Universal Compatibility**
  - Works on PC, Raspberry Pi, ESP32
  - Cross-platform support
  - Easy to deploy and use

- 📱 **Modern Interface**
  - Web-based dashboard
  - Multi-language support (EN, IT, ES, FR, DE)
  - QR code quick connect
  - Responsive design

- 🛠 **Advanced Features**
  - Real-time chat
  - File sharing
  - SOS alerts with geolocation
  - System monitoring
  - Node mapping
  - Emergency communication tools

## 🧩 Three Versions Available

### 💻 1. BackSat Python (PC/Laptop)
Perfect for development and testing:
- Quick setup with Python
- Full feature set
- Great for local networks
- Auto-opens dashboard in browser

**Requirements:**
- Python 3.7+
- pip

**Installation:**
```bash
cd python
pip install -r requirements.txt
python backsat.py
```
Dashboard opens automatically at: http://localhost:3030

### 🍓 2. BackSat OS (Raspberry Pi)
For permanent nodes and field deployment:
- Automatic Wi-Fi hotspot
- Runs on boot
- Perfect for fixed installations
- DNS support (backsat.local)

**Requirements:**
- Raspberry Pi (3/4/Zero W)
- Raspberry Pi OS

**Installation:**
```bash
cd raspberry
sudo chmod +x setup_backsat.sh
sudo ./setup_backsat.sh
```
Access at: http://192.168.4.1:3030 or http://backsat.local:3030

### 📡 3. BackSat Lite (ESP32)
Ultra-portable version:
- Low power consumption
- Minimal hardware needed
- Perfect for mobile nodes
- Mesh networking capable

**Requirements:**
- ESP32
- Arduino IDE
- Required libraries

**Installation:**
1. Open Arduino IDE
2. Install ESP32 support
3. Install required libraries
4. Upload data folder
5. Flash the code

Access at: http://192.168.4.1

## 🛠 Technical Details

### Network Architecture
- Mesh topology
- Auto-discovery
- Multi-hop routing
- No central infrastructure

### Security Features
- AES-256 encryption
- Secure key exchange
- Private channels
- Ephemeral messaging

### Communication
- WebSocket real-time
- REST API
- Local web interface
- QR code pairing

### Data Storage
- Local only
- Encrypted storage
- No cloud dependency
- Optional persistence

## 🤝 Contributing

This is an open-source project. You can help by:
- Opening issues
- Submitting pull requests
- Improving documentation
- Testing in different environments
- Translating to new languages

## 📄 License

MIT License - Feel free to use, modify, and distribute.
See [LICENSE](LICENSE) file for details.

---

Made with ❤️ by Rudy

For setup instructions specific to your needs, choose the appropriate folder:
- `/python` - For PC/Laptop installation
- `/raspberry` - For Raspberry Pi setup
- `/esp32` - For ESP32 deployment 
