import socket
import json
import threading
import time
import math
from datetime import datetime
from cryptography.fernet import Fernet
from ..utils.logger import get_logger

logger = get_logger(__name__)

class MeshNetwork:
    def __init__(self, start_port=5000, max_range_km=3):
        self.start_port = start_port
        self.port = self._find_available_port()
        self.nodes = {}  # {node_id: {'ip': ip, 'port': port, 'last_seen': timestamp, 'distance': km}}
        self.node_id = self._generate_node_id()
        self.encryption_key = Fernet.generate_key()
        self.fernet = Fernet(self.encryption_key)
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.socket.bind(('0.0.0.0', self.port))
        self.running = False
        self.max_range_km = max_range_km
        self.location = None  # Will be updated with GPS coordinates if available
        
    def _find_available_port(self):
        """Find first available port starting from start_port"""
        port = self.start_port
        max_port = self.start_port + 100  # Try up to 100 ports
        
        while port < max_port:
            try:
                with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
                    s.bind(('0.0.0.0', port))
                    return port
            except OSError:
                port += 1
        
        raise RuntimeError(f"No available ports found between {self.start_port} and {max_port}")
        
    def _generate_node_id(self):
        return f"node_{socket.gethostname()}_{int(time.time())}"
        
    def start(self):
        self.running = True
        self.discovery_thread = threading.Thread(target=self._node_discovery)
        self.listen_thread = threading.Thread(target=self._listen)
        self.cleanup_thread = threading.Thread(target=self._cleanup_inactive_nodes)
        
        self.discovery_thread.start()
        self.listen_thread.start()
        self.cleanup_thread.start()
        
        logger.info(f"Mesh node started with ID: {self.node_id} on port {self.port}")
        
    def stop(self):
        self.running = False
        self.socket.close()
        logger.info("Mesh network stopped")
        
    def _calculate_distance(self, lat1, lon1, lat2, lon2):
        """Calculate distance between two points in kilometers"""
        if None in (lat1, lon1, lat2, lon2):
            return 0
            
        R = 6371  # Earth's radius in km
        dlat = math.radians(lat2 - lat1)
        dlon = math.radians(lon2 - lon1)
        a = math.sin(dlat/2) * math.sin(dlat/2) + \
            math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * \
            math.sin(dlon/2) * math.sin(dlon/2)
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
        return R * c
        
    def _cleanup_inactive_nodes(self):
        """Remove nodes that haven't been seen in the last 30 seconds"""
        while self.running:
            current_time = time.time()
            inactive_nodes = []
            
            for node_id, info in self.nodes.items():
                if current_time - info['last_seen'] > 30:  # 30 seconds timeout
                    inactive_nodes.append(node_id)
                    
            for node_id in inactive_nodes:
                del self.nodes[node_id]
                logger.info(f"Node {node_id} removed due to inactivity")
                
            time.sleep(5)  # Check every 5 seconds
            
    def _node_discovery(self):
        while self.running:
            discovery_message = {
                'type': 'discovery',
                'node_id': self.node_id,
                'port': self.port,
                'timestamp': time.time(),
                'location': self.location
            }
            self._broadcast_message(discovery_message)
            time.sleep(5)  # Send beacon every 5 seconds
            
    def _listen(self):
        while self.running:
            try:
                data, addr = self.socket.recvfrom(4096)
                message = json.loads(data.decode())
                self._handle_message(message, addr)
            except Exception as e:
                logger.error(f"Error while listening: {e}")
                
    def _handle_message(self, message, addr):
        try:
            if message['type'] == 'discovery':
                node_id = message['node_id']
                if node_id != self.node_id:
                    distance = 0
                    if self.location and message.get('location'):
                        distance = self._calculate_distance(
                            self.location['lat'], self.location['lon'],
                            message['location']['lat'], message['location']['lon']
                        )
                        
                    # Only add node if within range
                    if distance <= self.max_range_km:
                        self.nodes[node_id] = {
                            'ip': addr[0],
                            'port': message['port'],
                            'last_seen': time.time(),
                            'distance': distance
                        }
                        logger.info(f"Node {node_id} at {distance:.1f}km updated")
                    else:
                        logger.debug(f"Node {node_id} ignored - too far ({distance:.1f}km)")
        except Exception as e:
            logger.error(f"Error handling message: {e}")
                
    def broadcast_message(self, message):
        """Broadcast a message to all known nodes"""
        try:
            encrypted_message = self.fernet.encrypt(json.dumps(message).encode())
            for node_id, info in self.nodes.items():
                try:
                    self.socket.sendto(encrypted_message, (info['ip'], info['port']))
                    logger.debug(f"Message sent to {node_id}")
                except Exception as e:
                    logger.error(f"Error sending to {node_id}: {e}")
        except Exception as e:
            logger.error(f"Error broadcasting message: {e}")
            
    def _broadcast_message(self, message):
        encoded_message = json.dumps(message).encode()
        self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        self.socket.sendto(encoded_message, ('<broadcast>', self.port))
        
    def get_network_status(self):
        """Get current network status"""
        return {
            'node_id': self.node_id,
            'active_nodes': len(self.nodes),
            'nodes': [{
                'id': node_id,
                'ip': info['ip'],
                'distance': info['distance'],
                'last_seen': int(time.time() - info['last_seen'])
            } for node_id, info in self.nodes.items()]
        }
        
    def update_location(self, lat, lon):
        """Update node's GPS location"""
        self.location = {'lat': lat, 'lon': lon}
        logger.info(f"Location updated: {lat}, {lon}")
        
    def get_active_nodes(self):
        return list(self.nodes.keys()) 