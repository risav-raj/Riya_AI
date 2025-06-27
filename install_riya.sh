sudo apt update && sudo apt install -y python3-pip python3-flask python3-rpi.gpio espeak mpg321 nmap arp-scan netdiscover lynis git && \
mkdir -p ~/riya_ai/{src/{core/{ai,memory,security},hardware,web/{templates,static/{js,css,music}}},systemd,docs} && cd ~/riya_ai && \
cat > src/main.py << 'EOL'
import os
import threading
import time
import json
import subprocess
import random
from datetime import datetime
from flask import Flask, request, jsonify, render_template
from flask_socketio import SocketIO, emit
from gtts import gTTS
import playsound

app = Flask(__name__)
socketio = SocketIO(app)

class RIYA:
    def __init__(self):
        self.intro_phrases = [
            "Hello! I am RIYA, your personal AI assistant",
            "Developed by ATL members to make your life easier",
            "I can control devices, monitor your plants, set reminders, and tell you the time",
            "Try saying: Set a reminder, Set an alarm, or What time is it?"
        ]
        self.commands = {
            "scan network": self.scan_network,
            "play music": self.play_music,
            "lights on": lambda: self.control_relay(1, True),
            "lights off": lambda: self.control_relay(1, False),
            "check moisture": self.check_plant_moisture,
            "temperature": self.get_temperature,
            "humidity": self.get_humidity,
            "tell me a joke": self.tell_joke,
            "tell me a story": self.tell_story,
            "give me information": self.give_information,
            "set a reminder": self.set_reminder,
            "set an alarm": self.set_alarm,
            "what time is it": self.tell_time
        }
        self.reminders = []
        self.alarms = []

    def introduce(self):
        for phrase in self.intro_phrases:
            self.speak(phrase)
            time.sleep(1.5)
        emit('start_listening')

    def speak(self, text):
        tts = gTTS(text=text, lang='en', slow=False)  # Use 'en' for English
        audio_file = "/tmp/riya_voice.mp3"
        tts.save(audio_file)
        playsound.playsound(audio_file)

    def scan_network(self):
        result = subprocess.run(['arp-scan', '-l'], capture_output=True, text=True)
        return f"Found {len(result.stdout.splitlines())} devices"

    def play_music(self):
        os.system("mpg321 ~/riya_ai/src/web/static/music/calm.mp3 &")
        return "Playing relaxing music"

    def tell_joke(self):
        jokes = [
            "Why did the scarecrow win an award? Because he was outstanding in his field!",
            "Why don't scientists trust atoms? Because they make up everything!",
            "What do you call fake spaghetti? An impasta!"
        ]
        return random.choice(jokes)

    def tell_story(self):
        stories = [
            "Once upon a time in a land far away, there lived a brave knight who fought dragons...",
            "In a small village, there was a wise old man who knew the secrets of the universe...",
            "A young girl discovered a magical book that could transport her to different worlds..."
        ]
        return random.choice(stories)

    def give_information(self):
        return "I can provide information on various topics. Just ask me anything!"

    def set_reminder(self):
        # This is a placeholder for setting reminders
        reminder_text = input("What should I remind you about? ")
        reminder_time = input("When should I remind you? (e.g., 'in 10 minutes' or 'at 3 PM'): ")
        self.reminders.append((reminder_time, reminder_text))
        return f"Reminder set for {reminder_time}: {reminder_text}"

    def set_alarm(self):
        # This is a placeholder for setting alarms
        alarm_time = input("Please tell me the time for the alarm (e.g., 'in 10 minutes' or 'at 3 PM'): ")
        self.alarms.append(alarm_time)
        return f"Alarm set for {alarm_time}."

    def tell_time(self):
        current_time = datetime.now().strftime("%H:%M:%S")
        return f"The current time is {current_time}."

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

@app.route('/startup')
def startup():
    return render_template('startup.html')

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
cat > src/web/templates/startup.html << 'EOL'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Welcome to RIYA AI</title>
    <style>
        body {
            margin: 0;
            overflow: hidden;
            background: #121212;
            color: #E0E0E0;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            position: relative;
            font-family: Arial, sans-serif;
        }
        .floating-text {
            position: absolute;
            font-size: 5em;
            color: pink; /* Changed to pink */
            animation: float 3s ease-in-out infinite; /* Floating effect */
            white-space: nowrap;
            text-shadow: 0 0 20px rgba(255, 20, 147, 0.8), 0 0 30px rgba(255, 20, 147, 0.6); /* Added glow effect */
        }
        @keyframes float {
            0% { transform: translateY(-20px); }
            50% { transform: translateY(20px); }
            100% { transform: translateY(-20px); }
        }
        .intro {
            z-index: 1;
            text-align: center;
            animation: fadeIn 3s ease-in-out;
        }
        @keyframes fadeIn {
            from { opacity: 0; }
            to { opacity: 1; }
        }
        .riya-animation {
            font-size: 3em;
            margin-top: 20px;
            animation: slideIn 2s ease-in-out;
        }
        @keyframes slideIn {
            from { transform: translateY(-50px); opacity: 0; }
            to { transform: translateY(0); opacity: 1; }
        }
    </style>
</head>
<body>
    <div class="floating-text">RIYA AI</div>
    <div class="intro">
        <h1>Welcome to RIYA AI</h1>
        <p class="riya-animation">Hello! I am RIYA, your personal AI assistant.</p>
        <p>Loading...</p>
    </div>
    <script>
        setTimeout(() => {
            window.location.href = '/'; // Redirect to the dashboard after 5 seconds
        }, 5000);
    </script>
</body>
</html>
EOL && \
cat > src/web/templates/dashboard.html << 'EOL'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>RIYA AI Dashboard</title>
    <script src="https://cdn.socket.io/4.5.4/socket.io.min.js"></script>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 20px;
            background: linear-gradient(135deg, #1E1E1E, #121212);
            color: #E0E0E0;
            animation: backgroundAnimation 10s infinite alternate;
            position: relative;
            overflow: hidden; /* Prevent overflow from floating elements */
        }
        @keyframes backgroundAnimation {
            0% { background-color: #121212; }
            50% { background-color: #1E1E1E; }
            100% { background-color: #121212; }
        }
        .header {
            text-align: center;
            padding: 20px;
            background: rgba(255, 20, 147, 0.8);
            border-radius: 10px;
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.5);
        }
        .panel {
            background: rgba(30, 30, 30, 0.9);
            padding: 20px;
            margin: 20px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.5);
            transition: transform 0.3s;
        }
        .panel:hover {
            transform: scale(1.02);
        }
        button {
            padding: 10px 15px;
            background: #4285f4;
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            transition: background 0.3s;
        }
        button:hover {
            background: #357ae8;
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
        h1, h2 {
            color: #FF1493; /* Deep pink */
        }
        .stat-card {
            background: rgba(0, 0, 0, 0.7);
            border-radius: 10px;
            padding: 20px;
            margin: 10px;
            box-shadow: 0 2px 10px rgba(0, 255, 255, 0.5);
            transition: transform 0.3s, box-shadow 0.3s;
        }
        .stat-card:hover {
            transform: scale(1.05);
            box-shadow: 0 4px 20px rgba(0, 255, 255, 0.7);
        }
        .floating-text {
            position: absolute;
            font-size: 5em;
            color: pink; /* Floating text color */
            animation: float 3s ease-in-out infinite; /* Floating effect */
            white-space: nowrap;
            text-shadow: 0 0 20px rgba(255, 20, 147, 0.8), 0 0 30px rgba(255, 20, 147, 0.6); /* Added glow effect */
        }
        @keyframes float {
            0% { transform: translateY(-20px); }
            50% { transform: translateY(20px); }
            100% { transform: translateY(-20px); }
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>RIYA AI Control Panel</h1>
        <button id="listenBtn">Start Listening</button>
        <div id="response"></div>
    </div>

    <div class="panel" id="system-stats">
        <h2>System Stats</h2>
        <div class="stat-card">
            <h3>CPU Usage</h3>
            <p><span id="cpu-usage">0%</span></p>
        </div>
        <div class="stat-card">
            <h3>Memory Usage</h3>
            <p><span id="memory-usage">0%</span>%</p>
        </div>
        <div class="stat-card">
            <h3>Disk Usage</h3>
            <p><span id="disk-usage">0%</span></p>
        </div>
        <div class="stat-card">
            <h3>Moisture Level</h3>
            <p><span id="moisture-level">N/A</span></p>
        </div>
        <div class="stat-card">
            <h3>Temperature</h3>
            <p><span id="temperature">N/A</span></p>
        </div>
        <div class="stat-card">
            <h3>Humidity</h3>
            <p><span id="humidity">N/A</span></p>
        </div>
    </div>

    <div class="floating-text">RIYA AI</div>

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
pip3 install flask-socketio eventlet RPi.GPIO gTTS playsound
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
User         =$USER
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
