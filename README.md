# BackSat

# BackSat - The Backpack Satellite

BackSat is an open-source project that transforms any compatible device into an independent communication node without requiring SIM cards, cell towers or internet connection. It's designed to work offline in emergency situations, remote missions, or simply to create resilient and secure local networks.

The core idea is: every device is a node. Like a "terrestrial satellite in your backpack".



## What is BackSat?

BackSat is the first personal terrestrial satellite. It doesn't fly, but does the work of a satellite: creates networks, exchanges data, communicates, all without internet.

## Main Features

- **Decentralized Mesh Network**
  - Automatically creates a local network between nearby BackSats
  - Works even during total blackouts
  - No central server

- **Private or Public Mode**
  - Private: just you and your devices
  - Public: communicate with other active BackSats in the area

- **Compatible with any device**
  - Computer, Raspberry Pi, tablet, portable router, etc.
  - Only requires: a Wi-Fi card + BackSat OS

- **Custom Operating System**
  - Automatic network boot
  - Local web dashboard (browser-accessible interface)
  - Included functions:
    - P2P Chat
    - File sharing
    - Notifications of other detected nodes
    - Automatic backup
    - Map of active nodes
    - SOS sending

## Two Versions of BackSat

### 🖥 BackSat OS
- Works on Raspberry Pi, mini PC, laptop
- Includes a custom operating system with Wi-Fi hotspot and local web dashboard
- Can be flashed to a microSD card
- Dashboard enables offline chat, file sending, document access, emergency tools, orientation, and more
- Can manage mesh connections with other BackSat nodes or serve as the main network node

### 🔌 BackSat Lite
- Works on compatible microcontrollers (ESP32, Arduino with LoRa, Meshtastic devices)
- Connects via serial or Wi-Fi to an external interface (PC, smartphone)
- Sends and receives messages, signals
