#!/usr/bin/env python3
import os
import sys
import json
import psutil
import qrcode
import socket
import webbrowser
from threading import Thread
from datetime import datetime
from flask import Flask, render_template, jsonify, request
from flask_socketio import SocketIO
from rich.console import Console
from rich.panel import Panel
from ..network.mesh import MeshNetwork
from .survival import SurvivalTools

# Initialize colorful logger
console = Console()

class BackSat:
    def __init__(self):
        template_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), 'templates'))
        static_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), 'static'))
        
        # Ensure static directory exists
        os.makedirs(static_dir, exist_ok=True)
        
        self.app = Flask(__name__, 
                        template_folder=template_dir,
                        static_folder=static_dir)
                        
        # Disable Flask's reloader when in debug mode
        self.app.config['DEBUG'] = True
        self.app.config['USE_RELOADER'] = False
        
        self.socketio = SocketIO(self.app, cors_allowed_origins="*", async_mode='threading')
        self.mesh = MeshNetwork(max_range_km=3)
        self.survival = SurvivalTools()
        self.connected_clients = set()
        self.setup_routes()
        self.setup_websocket_handlers()
        
    def setup_routes(self):
        @self.app.route('/')
        def index():
            return render_template('index.html')
            
        @self.app.route('/status')
        def status():
            """API endpoint for checking connection status"""
            mesh_status = self.mesh.get_network_status()
            return jsonify({
                'status': 'connected' if mesh_status['active_nodes'] > 0 else 'connecting',
                'nodes': mesh_status['nodes'],
                'clients': len(self.connected_clients)
            })
            
        @self.app.route('/qr')
        def get_qr():
            """Generate QR code for quick connection"""
            hostname = socket.gethostname()
            try:
                ip = socket.gethostbyname(hostname)
            except:
                ip = '127.0.0.1'  # Fallback to localhost
            url = f"http://{ip}:3030"
            
            # Generate QR code
            qr = qrcode.QRCode(version=1, box_size=10, border=5)
            qr.add_data(url)
            qr.make(fit=True)
            qr_image = qr.make_image(fill_color="black", back_color="white")
            
            # Save temporarily
            temp_path = os.path.join(self.app.static_folder, 'qr.png')
            qr_image.save(temp_path)
            
            return jsonify({'qr_url': '/static/qr.png'})
            
        @self.app.route('/api/first-aid')
        def get_first_aid():
            condition = request.args.get('condition')
            return jsonify(self.survival.get_first_aid(condition))
            
        @self.app.route('/api/morse')
        def get_morse():
            text = request.args.get('text', '')
            return jsonify({'morse': self.survival.text_to_morse(text)})
            
        @self.app.route('/api/emergency/logs')
        def get_emergency_logs():
            return jsonify(self.survival.get_emergency_logs())
            
    def setup_websocket_handlers(self):
        @self.socketio.on('connect')
        def handle_connect():
            client_id = request.sid
            self.connected_clients.add(client_id)
            console.log(f"[green]New client connected! ID: {client_id}[/green]")
            # Send initial status
            self._emit_system_status()
            self._emit_network_status()
            
        @self.socketio.on('disconnect')
        def handle_disconnect():
            client_id = request.sid
            self.connected_clients.discard(client_id)
            console.log(f"[yellow]Client disconnected! ID: {client_id}[/yellow]")
            
        @self.socketio.on('message')
        def handle_message(data):
            console.log(f"[blue]Message received: {data}[/blue]")
            # Broadcast to mesh network
            if data['type'] == 'chat':
                self.mesh.broadcast_message(data)
            self.socketio.emit('message', data, broadcast=True)
            
        @self.socketio.on('sos')
        def handle_sos(data):
            console.log("[red]SOS signal received![/red]")
            # Add timestamp and node info
            data['node_id'] = self.mesh.node_id
            data['timestamp'] = datetime.now().isoformat()
            
            # Log emergency
            self.survival.log_emergency({
                'type': 'sos',
                'location': data.get('location'),
                'details': data.get('details')
            })
            
            # Convert to Morse code
            morse_sos = self.survival.text_to_morse('SOS')
            data['morse'] = morse_sos
            
            # Broadcast SOS to all nodes
            self.mesh.broadcast_message({
                'type': 'sos',
                'data': data
            })
            self.socketio.emit('sos', data, broadcast=True)
            
        @self.socketio.on('update_location')
        def handle_location_update(data):
            """Handle location updates from clients"""
            try:
                lat = float(data['lat'])
                lon = float(data['lon'])
                self.mesh.update_location(lat, lon)
                self.socketio.emit('location_updated', {
                    'status': 'success',
                    'lat': lat,
                    'lon': lon
                })
            except Exception as e:
                console.log(f"[red]Error updating location: {e}[/red]")
                self.socketio.emit('location_updated', {
                    'status': 'error',
                    'message': str(e)
                })
            
    def _emit_system_status(self):
        """Emit system status updates periodically"""
        while True:
            try:
                cpu = psutil.cpu_percent()
                memory = psutil.virtual_memory().percent
                self.socketio.emit('system_status', {
                    'cpu': cpu,
                    'memory': memory
                })
                self.socketio.sleep(2)
            except Exception as e:
                console.log(f"[red]Error updating system status: {e}[/red]")
                
    def _emit_network_status(self):
        """Emit network status updates periodically"""
        first_run = True
        while True:
            try:
                status = self.mesh.get_network_status()
                connection_status = {
                    'status': 'connected' if status['active_nodes'] > 0 else 'waiting_for_nodes',
                    'nodes': status['nodes'],
                    'clients': len(self.connected_clients),
                    'node_id': status['node_id']
                }
                
                if first_run:
                    console.log(f"[blue]BackSat node {status['node_id']} initialized[/blue]")
                    first_run = False
                
                if status['active_nodes'] > 0:
                    console.log(f"[green]Mesh network active: {status['active_nodes']} nodes connected[/green]")
                else:
                    console.log(f"[yellow]Node {status['node_id']} active, searching for peers...[/yellow]")
                
                self.socketio.emit('network_status', connection_status)
                self.socketio.sleep(2)  # Increased sleep time to reduce console spam
            except Exception as e:
                console.log(f"[red]Network status error: {str(e)}[/red]")
                self.socketio.sleep(2)
                
    def open_dashboard(self):
        webbrowser.open('http://localhost:3030')
            
    def run(self):
        console.print(Panel.fit(
            "[bold blue]BackSat[/bold blue] - The Backpack Satellite 🛰",
            title="BackSat v1.0"
        ))
        
        try:
            # Start mesh network
            self.mesh.start()
            
            # Start monitoring threads
            Thread(target=self._emit_system_status, daemon=True).start()
            Thread(target=self._emit_network_status, daemon=True).start()
            
            # Open dashboard in separate thread
            Thread(target=self.open_dashboard).start()
            
            # Start server
            self.socketio.run(self.app, 
                            host='0.0.0.0', 
                            port=3030,
                            debug=True,
                            use_reloader=False)
                            
        except KeyboardInterrupt:
            console.log("[yellow]Shutting down BackSat...[/yellow]")
            self.mesh.stop()
        except Exception as e:
            console.log(f"[red]Error starting BackSat: {e}[/red]")
            self.mesh.stop()
            raise

if __name__ == '__main__':
    backsat = BackSat()
    backsat.run() 