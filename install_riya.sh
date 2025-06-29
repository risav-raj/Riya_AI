#!/bin/bash

echo "🔄 Updating system..."
sudo apt update && sudo apt upgrade -y

echo "🔧 Installing core dependencies..."
sudo apt install -y python3-pip python3-flask python3-rpi.gpio espeak mpg321 nmap arp-scan netdiscover lynis git arecord ffmpeg sox

echo "📦 Installing Python packages..."
pip3 install flask-socketio eventlet RPi.GPIO gTTS playsound requests fuzzywuzzy python-Levenshtein

echo "📂 Creating project structure..."
mkdir -p ~/riya_ai/{src/{core/{ai,hardware},web/{templates,static/{js,css,music,screenshots}}},systemd,logs}

echo "🎶 Downloading sample music..."
wget -O ~/riya_ai/src/web/static/music/calm.mp3 https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3

echo "📝 Creating main.py..."
cat > ~/riya_ai/src/main.py << 'EOF'
import os, subprocess, random, time, threading, requests
from datetime import datetime
from flask import Flask, render_template
from flask_socketio import SocketIO, emit
from gtts import gTTS
import playsound
from fuzzywuzzy import fuzz

app = Flask(__name__)
socketio = SocketIO(app)

class RIYA:
    def __init__(self):
        self.intro = [
            "Hello! I am RIYA, your personal Smart AI Assistant.",
            "I have been created by ATL members to help you do everything smarter.",
            "I can control your lights, motor, sensors, files, network and more!",
            "Just say: Turn on light, scan network, take photo, or Update yourself!"
        ]
        self.commands = {
            "turn on light": self.turn_on_light,
            "turn off light": self.turn_off_light,
            "turn on all lights": self.turn_on_all,
            "turn off all lights": self.turn_off_all,
            "turn on motor": lambda: self.relay_control(9, True),
            "turn off motor": lambda: self.relay_control(9, False),
            "scan network": self.scan_network,
            "check moisture": self.moisture_sensor,
            "temperature": self.temperature_sensor,
            "humidity": self.humidity_sensor,
            "record audio": self.record_audio,
            "take picture": self.take_picture,
            "say in hindi": self.speak_hindi,
            "run command": self.run_shell,
            "update yourself": self.self_update,
            "weather": self.get_weather,
            "news": self.get_news
        }

    def introduce(self):
        for line in self.intro:
            self.speak(line)
            time.sleep(1)
        emit('start_listening')

    def speak(self, text):
        tts = gTTS(text=text, lang='en', slow=False)
        audio = "/tmp/riya.mp3"
        tts.save(audio)
        playsound.playsound(audio)

    def speak_hindi(self):
        tts = gTTS(text="नमस्ते, मैं रिया हूँ। मैं आपकी मदद करूँगी।", lang='hi')
        tts.save("/tmp/riya_hi.mp3")
        playsound.playsound("/tmp/riya_hi.mp3")
        return "Speaking in Hindi"

    def relay_control(self, num, state):
        return f"Relay {num} {'ON' if state else 'OFF'}."

    def turn_on_light(self):
        return self.relay_control(1, True)

    def turn_off_light(self):
        return self.relay_control(1, False)

    def turn_on_all(self):
        return "All lights ON."

    def turn_off_all(self):
        return "All lights OFF."

    def scan_network(self):
        return subprocess.getoutput("nmap -sn 192.168.1.0/24")

    def moisture_sensor(self):
        level = random.randint(20, 80)
        return f"Soil Moisture: {level}%"

    def temperature_sensor(self):
        temp = random.uniform(22, 32)
        return f"Temperature: {temp:.1f}°C"

    def humidity_sensor(self):
        humidity = random.uniform(40, 70)
        return f"Humidity: {humidity:.1f}%"

    def record_audio(self):
        subprocess.call("arecord -d 5 /tmp/voice.wav", shell=True)
        return "Recorded 5 seconds."

    def take_picture(self):
        subprocess.call("raspistill -o ~/riya_ai/src/web/static/screenshots/photo.jpg", shell=True)
        return "Photo taken."

    def run_shell(self):
        return subprocess.getoutput("uptime")

    def self_update(self):
        return "Updating... (stub)"

    def get_weather(self):
        api_key = "ef0a8f830d078a331c34930e168c3e5e"
        city = "Delhi"
        url = f"http://api.openweathermap.org/data/2.5/weather?q={city}&appid={api_key}&units=metric"
        r = requests.get(url).json()
        temp = r['main']['temp']
        desc = r['weather'][0]['description']
        return f"{city} weather: {temp}°C, {desc}"

    def get_news(self):
        api_key = "8ac23d769ee248de827cd76d808e5eba"
        url = f"https://newsapi.org/v2/top-headlines?country=in&apiKey={api_key}"
        r = requests.get(url).json()
        headlines = [a['title'] for a in r['articles'][:5]]
        return "\n".join(headlines)

    def process_command(self, cmd):
        for k, action in self.commands.items():
            if fuzz.partial_ratio(k, cmd.lower()) > 70:
                return action()
        return "Sorry, didn't get that."

@app.route("/")
def home():
    return render_template('dashboard.html')

@socketio.on("request_intro")
def intro():
    riya = RIYA()
    riya.introduce()

@socketio.on("voice_command")
def command(data):
    riya = RIYA()
    response = riya.process_command(data['command'])
    emit("voice_response", {"text": response})

if __name__ == "__main__":
    socketio.run(app, host="0.0.0.0", port=5000)
EOF

echo "📑 Creating dashboard.html..."
cat > ~/riya_ai/src/web/templates/dashboard.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><title>RIYA Dashboard</title>
<script src="https://cdn.socket.io/4.5.4/socket.io.min.js"></script>
</head>
<body style="background:#121212;color:white;">
<h1>RIYA AI Control Panel</h1>
<button onclick="startListen()">Start Listening</button>
<pre id="response"></pre>
<script>
const socket = io();
function startListen(){ socket.emit("request_intro"); }
socket.on("start_listening",()=>{ document.getElementById("response").textContent="Listening..."; });
socket.on("voice_response",(data)=>{ document.getElementById("response").textContent=data.text; });
</script>
</body></html>
EOF

echo "🗂️ Creating systemd service..."
cat > ~/riya_ai/systemd/riya.service << 'EOF'
[Unit]
Description=RIYA Smart AI
After=network.target

[Service]
ExecStart=/usr/bin/python3 /home/$USER/riya_ai/src/main.py
WorkingDirectory=/home/$USER/riya_ai/src
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "🔗 Enabling service..."
sudo cp ~/riya_ai/systemd/riya.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable riya.service

echo "✅ RIYA installed. Start with: sudo systemctl start riya"
echo "👉 Dashboard: http://$(hostname -I | awk '{print $1}'):5000"
