sudo apt update && sudo apt install -y python3-pip arp-scan python3-flask python3-netifaces python3-rpi.gpio mpg321 && \
mkdir -p ~/riya_ai/{src/{core/{ai,memory},hardware,web/{templates,static/{js,css,music}}},systemd,docs} && cd ~/riya_ai && \
cat > src/main.py << 'EOL'
import threading
import time
import random
import json
import os
from datetime import datetime
from core.riya import RIYA
from web.app import create_app
from core.ai.memory import Memory
from hardware.relays import RelayController
from hardware.sensors import DHTSensor

class PlantMonitor:
    def __init__(self):
        self.relays = RelayController()
        self.sensor = DHTSensor()
        self.alarm_threshold = 30

    def check_plants(self):
        while True:
            hum, temp = self.sensor.get_temp_humidity()
            if hum and hum < self.alarm_threshold:
                RIYA().speak(f"Alert! Plants need water. Humidity is {hum}%")
            time.sleep(3600)

class RIYAAI:
    def __init__(self):
        self.memory = Memory()
        self.quotes = ["The best way to predict the future is to invent it.", 
                      "Stay hungry, stay foolish."]
        
    def process_command(self, cmd):
        # Store conversation in memory
        self.memory.add_to_history(cmd)
        
        if "play music" in cmd:
            return self.play_music()
        elif "set reminder" in cmd:
            return self.set_reminder(cmd)
        elif "joke" in cmd:
            return self.tell_joke()
        # Other commands...
        
    def speak(self, text):
        # Text-to-speech implementation
        pass

def run_background_tasks():
    PlantMonitor().check_plants()

if __name__ == '__main__':
    app = create_app()
    threading.Thread(target=run_background_tasks, daemon=True).start()
    app.run(host='0.0.0.0', port=5000)
EOL && \
cat > src/core/ai/memory.py << 'EOL'
import json
import os

class Memory:
    def __init__(self):
        self.file = "memory.json"
        if not os.path.exists(self.file):
            with open(self.file, 'w') as f:
                json.dump({"history": [], "prefs": {}}, f)

    def add_to_history(self, text):
        data = self._load()
        data["history"].append({
            "text": text,
            "time": datetime.now().isoformat()
        })
        self._save(data)

    def _load(self):
        with open(self.file) as f:
            return json.load(f)

    def _save(self, data):
        with open(self.file, 'w') as f:
            json.dump(data, f)
EOL && \
cat > src/web/templates/dashboard.html << 'EOL'
<!DOCTYPE html>
<html>
<head>
    <title>RIYA AI System</title>
    <script src="https://cdn.socket.io/4.5.4/socket.io.min.js"></script>
    <style>
        /* Styles for all components */
        .panel { margin: 15px; padding: 15px; border-radius: 5px; }
        .voice-btn { background: #4285F4; color: white; }
    </style>
</head>
<body>
    <h1>RIYA AI Control Panel</h1>
    
    <div class="panel">
        <h2>Voice Control</h2>
        <button class="voice-btn" onclick="startListening()">🎤 Speak Command</button>
    </div>

    <script>
        const socket = io();
        const recognition = new (window.SpeechRecognition || window.webkitSpeechRecognition)();
        
        // Voice control
        function startListening() {
            recognition.start();
        }
        
        recognition.onresult = function(e) {
            const cmd = e.results[0][0].transcript;
            socket.emit('voice_command', {command: cmd}); 
        };
    </script>
</body>
</html>
EOL && \
cat > setup.sh << 'EOL'
#!/bin/bash
pip3 install flask-socketio eventlet Adafruit-DHT RPi.GPIO python-dateutil
sudo usermod -a -G gpio $USER
sudo cp systemd/riya.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable riya.service
echo "RIYA AI installation complete!"
EOL && \
chmod +x setup.sh && \
sudo ./setup.sh && \
echo -e "\nAccess RIYA at: \033[1;34mhttp://$(hostname -I | awk '{print $1}'):5000\033[0m"
