import json
import os
from datetime import datetime

class SurvivalTools:
    def __init__(self):
        self.data_dir = os.path.join(os.path.dirname(__file__), 'data')
        os.makedirs(self.data_dir, exist_ok=True)
        self._load_first_aid()
        self._load_morse_code()
        
    def _load_first_aid(self):
        """Load first aid guide"""
        self.first_aid = {
            "bleeding": {
                "title": "Bleeding Control",
                "steps": [
                    "Apply direct pressure to the wound",
                    "Use clean cloth or gauze",
                    "Elevate the injured area",
                    "Apply pressure bandage"
                ]
            },
            "burns": {
                "title": "Burns Treatment",
                "steps": [
                    "Cool the burn under cold water",
                    "Cover with clean, dry dressing",
                    "Don't break blisters",
                    "Seek medical help if severe"
                ]
            },
            "fractures": {
                "title": "Fracture Care",
                "steps": [
                    "Immobilize the injured area",
                    "Apply ice to reduce swelling",
                    "Check circulation",
                    "Seek immediate medical help"
                ]
            }
        }
        
    def _load_morse_code(self):
        """Load Morse code patterns"""
        self.morse = {
            'A': '.-', 'B': '-...', 'C': '-.-.', 'D': '-..', 'E': '.', 'F': '..-.',
            'G': '--.', 'H': '....', 'I': '..', 'J': '.---', 'K': '-.-', 'L': '.-..',
            'M': '--', 'N': '-.', 'O': '---', 'P': '.--.', 'Q': '--.-', 'R': '.-.',
            'S': '...', 'T': '-', 'U': '..-', 'V': '...-', 'W': '.--', 'X': '-..-',
            'Y': '-.--', 'Z': '--..', '0': '-----', '1': '.----', '2': '..---',
            '3': '...--', '4': '....-', '5': '.....', '6': '-....', '7': '--...',
            '8': '---..', '9': '----.', 'SOS': '...---...'
        }
        
    def get_first_aid(self, condition=None):
        """Get first aid instructions"""
        if condition and condition in self.first_aid:
            return self.first_aid[condition]
        return self.first_aid
        
    def text_to_morse(self, text):
        """Convert text to Morse code"""
        if text.upper() == 'SOS':
            return self.morse['SOS']
            
        morse_text = []
        for char in text.upper():
            if char in self.morse:
                morse_text.append(self.morse[char])
            elif char == ' ':
                morse_text.append('/')
        return ' '.join(morse_text)
        
    def log_emergency(self, data):
        """Log emergency events"""
        log_file = os.path.join(self.data_dir, 'emergency.log')
        timestamp = datetime.now().isoformat()
        
        with open(log_file, 'a') as f:
            log_entry = {
                'timestamp': timestamp,
                'type': data.get('type', 'unknown'),
                'location': data.get('location'),
                'details': data.get('details')
            }
            f.write(json.dumps(log_entry) + '\n')
            
    def get_emergency_logs(self):
        """Get emergency event logs"""
        log_file = os.path.join(self.data_dir, 'emergency.log')
        logs = []
        
        if os.path.exists(log_file):
            with open(log_file, 'r') as f:
                for line in f:
                    logs.append(json.loads(line.strip()))
                    
        return logs 