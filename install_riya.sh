sudo apt update && sudo apt install -y python3-pip python3-flask python3-rpi.gpio espeak mpg321 nmap arp-scan netdiscover lynis git && \
mkdir -p ~/riya_ai/{src/{core/{ai,memory,security},hardware,web/{templates,static/{js,css,music}}},systemd,docs} && cd ~/riya_ai && \
cat > src/main.py << 'EOL'
import os
import threading
import time
import json
import subprocess
import random
from flask import Flask, request, jsonify, render_template
from flask_socketio import SocketIO, emit

app = Flask(__name__)
socketio = SocketIO(app)

class RIYA:
    def __init__(self):
        self.intro_phrases = [
            "Hello! I am RIYA, your personal AI assistant",
            "Developed by ATL members to make your life easier",
            "I can control devices, monitor your plants, and scan networks",
            "Try saying: Turn on lights or Scan for devices"
        ]
        self.commands = {
            "scan network": self.scan_network,
            "play music": self.play_music,
            "lights on": lambda: self.control_relay(1, True),
            "lights off": lambda: self.control_relay(1, False),
            "check moisture": self.check_plant_moisture,
            "temperature": self.get_temperature,
            "humidity": self.get_humidity
        }

    def introduce(self):
        for phrase in self.intro_phrases:
            self.speak(phrase)
            time.sleep(1.5)
        emit('start_listening')

    def speak(self, text):
        os.system(f'espeak "{text}" --stdout | aplay 2>/dev/null')

    def scan_network(self):
        result = subprocess.run(['arp-scan', '-l'], capture_output=True, text=True)
        return f"Found {len(result.stdout.splitlines())} devices"

    def play_music(self):
        os.system("mpg321 ~/riya_ai/src/web/static/music/calm.mp3 &")
        return "Playing relaxing music"

    def process_command(self, command):
        for cmd, action in self.commands.items():
            if cmd in command.lower():
                return action()
        return "Sorry, I didn't understand that"

    def get_system_stats(self):
        cpu_usage = subprocess.check_output("top -bn1 | grep 'Cpu(s)' | sed 's/.*, *\\$[0-9.]*\\$%* id.*/\\1/' | awk '{print 100 - $1}'", shell=True).decode('utf-8').strip()
        memory_info = subprocess.check_output("free | grep Mem", shell=True).decode('utf-8').split()
        memory_usage = round((int(memory_info[2]) / int(memory_info[1])) * 100, 2)
        disk_usage = subprocess.check_output("df -h | grep '/$'", shell=True).decode('utf-8').split()
        disk_usage_percent = disk_usage[4]
        return {
            "cpu": cpu_usage,
            "memory": memory_usage,
            "disk": disk_usage_percent
        }

    def check_plant_moisture(self):
        moisture_level = random.randint(0, 100)  # Simulated moisture reading (0-100%)
        return f"Current soil moisture level is {moisture_level}%."

    def get_temperature(self):
        # Simulated temperature reading
        temperature = random.uniform(20.0, 30.0)
        return f"Current temperature is {temperature:.2f}°C."

    def get_humidity(self):
        # Simulated humidity reading
        humidity = random.uniform(30.0, 70.0)
        return f"Current humidity level is {humidity:.2f}%."

@app.route('/')
def dashboard():
    return render_template('dashboard.html')

@socketio.on('request_intro')
def handle_intro():
    riya = RIYA()
    riya.introduce()

@socketio.on('voice_command')
def handle_command(data):
    riya = RIYA()
    response = riya.process_command(data['command'])
    emit('voice_response', {'text': response})

@socketio.on('get_system_stats')
def handle_system_stats():
    riya = RIYA()
    stats = riya.get_system_stats()
    emit('system_stats', stats)

if __name__ == '__main__':
    socketio.run(app, host='0.0.0.0', port=5000)
EOL && \
cat > src/web/templates/dashboard.html << 'EOL'
<!DOCTYPE html>
<html>
<head>
    <title>RIYA AI Dashboard</title>
    <script src="https://cdn.socket.io/4.5.4/socket.io.min.js"></script>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 20px;
            background: #121212;
            color: #E0E0E0;
        }
        .panel {
            background: #1E1E1E;
            padding: 20px;
            margin-bottom: 20px;
            border-radius: 5px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.5);
        }
        button {
            padding: 10px 15px;
            background: #4285f4;
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
        }
        #response {
            margin-top: 20px;
            padding: 10px;
            background: #e8f5e9;
            border-radius: 4px;
        }
        #system-stats {
            margin-top: 20px;
            padding: 10px;
            background: #2E2E2E;
            border-radius: 4px;
        }
    </style>
</head>
<body>
    <div class="panel">
        <h1>RIYA AI Control Panel</h1>
        <button id="listenBtn">Start Listening</button>
        <div id="response"></div>
    </div>

    <div class="panel" id="system-stats">
        <h2>System Stats</h2>
        <p>CPU Usage: <span id="cpu-usage">0%</span></p>
        <p>Memory Usage: <span id="memory-usage">0%</span>%</p>
        <p>Disk Usage: <span id="disk-usage">0%</span></p>
        <p>Moisture Level: <span id="moisture-level">N/A</span></p>
        <p>Temperature: <span id="temperature">N/A</span></p>
        <p>Humidity: <span id="humidity">N/A</span></p>
    </div>

    <script>
        const socket = io();
        const recognition = new (window.SpeechRecognition || window.webkitSpeechRecognition)();
        recognition.continuous = true;
        recognition.interimResults = true;

        document.getElementById('listenBtn').addEventListener('click', () => {
            recognition.start();
        });

        recognition.onresult = (event) => {
            const transcript = event.results[0][0].transcript;
            document.getElementById('response').textContent = `You said: ${transcript}`;
            socket.emit('voice_command', {command: transcript});
        };

        socket.on('voice_response', (data) => {
            document.getElementById('response').textContent += `\nRIYA: ${data.text}`;
        });

        socket.on('start_listening', () => {
            document.getElementById('response').textContent = "RIYA is listening...";
        });

        function updateSystemStats() {
            socket.emit('get_system_stats');
        }

        socket.on('system_stats', (stats) => {
            document.getElementById('cpu-usage').textContent = stats.cpu + '%';
            document.getElementById('memory-usage').textContent = stats.memory + '%';
            document.getElementById('disk-usage').textContent = stats.disk;
            document.getElementById('moisture-level').textContent = stats.moisture || 'N/A';
            document.getElementById('temperature').textContent = stats.temperature || 'N/A';
            document.getElementById('humidity').textContent = stats.humidity || 'N/A';
        });

        setInterval(updateSystemStats, 5000); // Update stats every 5 seconds
    </script>
</body>
</html>
EOL && \
mkdir -p src/web/static/music && \
wget -O src/web/static/music/calm.mp3 https://example.com/sample-music.mp3 && \
cat > setup.sh << 'EOL'
#!/bin/bash
pip3 install flask-socketio eventlet RPi.GPIO
sudo usermod -a -G gpio $USER
sudo cp systemd/riya.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable riya.service
echo "RIYA AI installation complete!"
EOL && \
cat > systemd/riya.service << 'EOL'
[Unit]
Description=RIYA AI Assistant
After=network.target

[Service]
User  =$USER
WorkingDirectory=/home/$USER/riya_ai
ExecStart=/usr/bin/python3 src/main.py
Restart=always
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOL && \
chmod +x setup.sh && \
sudo ./setup.sh && \
echo -e "\n\033[1;32mRIYA AI is ready!\033[0m\nAccess the dashboard at: \033[1;34mhttp://$(hostname -I | awk '{print $1}'):5000\033[0m\nSay 'Hello RIYA' to begin!"
