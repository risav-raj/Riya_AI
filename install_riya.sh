#!/bin/bash

echo "🔄 Updating system & installing base packages..."
sudo apt update && sudo apt install -y \
  python3-pip python3-flask python3-rpi.gpio espeak mpg321 nmap arp-scan netdiscover lynis git curl

echo "✅ Installing Python packages..."
pip3 install flask-socketio eventlet RPi.GPIO gTTS playsound requests fuzzywuzzy python-Levenshtein wikipedia googletrans==4.0.0-rc1 wolframalpha speedtest-cli psutil

echo "✅ Creating RIYA folders..."
mkdir -p ~/riya_ai/{src/{core/ai,web/{templates,static/{js,css,music}}},systemd,logs}

cd ~/riya_ai

echo "✅ Saving API keys..."
echo 'export OPENWEATHER_API_KEY="ef0a8f830d078a331c34930e168c3e5e"' >> ~/.bashrc
echo 'export NEWS_API_KEY="8ac23d769ee248de827cd76d808e5eba"' >> ~/.bashrc
echo 'export WOLFRAM_APP_ID="43GE2P-289L6YWKKT"' >> ~/.bashrc
source ~/.bashrc

echo "✅ Writing main.py..."
cat > src/main.py << 'EOL'
import os, subprocess, threading, random, requests, time, psutil, wikipedia, wolframalpha
from datetime import datetime
from flask import Flask, render_template
from flask_socketio import SocketIO, emit
from fuzzywuzzy import fuzz
from gtts import gTTS
import playsound
from core.ai.AssistantAI import AssistantAI

app = Flask(__name__)
socketio = SocketIO(app)

class RIYA:
    def __init__(self):
        self.last_command = ""
        self.last_response = ""
        self.relays = [False]*9
        self.assistant = AssistantAI()
        self.intro_phrases = [
            "Hello! I am RIYA, your personal AI assistant",
            "I am your Smart Home Intelligent Server AI",
            "I can control lights, fans, pump, monitor sensors, tell weather, news, facts and much more"
        ]
        self.commands = {
            "scan network": self.scan_network,
            "play music": self.play_music,
            "turn on all lights": self.turn_on_all_lights,
            "turn off all lights": self.turn_off_all_lights,
            "internet status": self.internet_status,
            "uptime": self.get_uptime,
            "weather": self.get_weather,
            "news": self.get_news,
            "tell time": self.tell_time,
            "tell joke": self.tell_joke,
            "fun fact": self.tell_fact,
            "cpu usage": self.get_cpu,
            "memory usage": self.get_mem,
            "disk usage": self.get_disk,
            "temperature": self.get_temp,
            "humidity": self.get_humidity,
            "moisture": self.get_moisture,
            "go to sleep": self.sleep_mode,
            "wake up": self.introduce
        }

    def speak(self, text):
        self.last_response = text
        tts = gTTS(text=text, lang='en', tld='co.in')
        audio_file = "/tmp/riya_voice.mp3"
        tts.save(audio_file)
        playsound.playsound(audio_file)

    def introduce(self):
        for line in self.intro_phrases:
            self.speak(line)
            time.sleep(1)

    def scan_network(self): return subprocess.getoutput("arp-scan -l")
    def play_music(self): os.system("mpg321 ~/riya_ai/src/web/static/music/calm.mp3 &"); return "Playing music"
    def internet_status(self): return subprocess.getoutput("ping -c 1 google.com")
    def get_uptime(self): return subprocess.getoutput("uptime -p")
    def get_weather(self):
        city = "New Delhi"
        key = os.getenv("OPENWEATHER_API_KEY")
        url = f"http://api.openweathermap.org/data/2.5/weather?q={city}&appid={key}&units=metric"
        data = requests.get(url).json()
        return f"Weather: {data['weather'][0]['description']}, Temp: {data['main']['temp']}°C"
    def get_news(self):
        key = os.getenv("NEWS_API_KEY")
        url = f"https://newsapi.org/v2/top-headlines?country=in&apiKey={key}"
        articles = requests.get(url).json()['articles'][:5]
        return "\n".join([a['title'] for a in articles])
    def tell_time(self): return datetime.now().strftime("%H:%M:%S")
    def tell_joke(self): return random.choice(["Why did the scarecrow win an award? Because he was outstanding!"])
    def tell_fact(self): return wikipedia.summary("India", sentences=1)
    def get_cpu(self): return f"{psutil.cpu_percent()}%"
    def get_mem(self): return f"{psutil.virtual_memory().percent}%"
    def get_disk(self): return f"{psutil.disk_usage('/').percent}%"
    def get_temp(self): return "Simulated 28°C"
    def get_humidity(self): return "Simulated 55%"
    def get_moisture(self): return f"{random.randint(20, 80)}%"
    def turn_on_all_lights(self): self.relays = [True]*9; return "All lights ON"
    def turn_off_all_lights(self): self.relays = [False]*9; return "All lights OFF"
    def sleep_mode(self): self.speak("Going to sleep"); return "Sleeping..."

    def process_command(self, command):
        self.last_command = command
        for cmd in self.commands:
            if fuzz.partial_ratio(cmd, command) > 70:
                return self.commands[cmd]()
        return self.assistant.handle_query(command)

    def get_status(self):
        return {
            "cpu": self.get_cpu(),
            "memory": self.get_mem(),
            "disk": self.get_disk(),
            "temp": self.get_temp(),
            "humidity": self.get_humidity(),
            "moisture": self.get_moisture(),
            "internet": self.internet_status(),
            "uptime": self.get_uptime(),
            "last_command": self.last_command,
            "last_response": self.last_response,
            "relays": self.relays
        }

riya = RIYA()
@app.route('/')
def dash(): return render_template('dashboard.html')
@app.route('/startup')
def start(): return render_template('startup.html')
@socketio.on('get_status')
def stat(): emit('status_update', riya.get_status())
@socketio.on('voice_command')
def handle(data): emit('voice_response', {'text': riya.process_command(data['command'])})

if __name__ == '__main__': socketio.run(app, host='0.0.0.0', port=5000)
EOL

echo "✅ Writing AssistantAI.py..."
cat > src/core/ai/AssistantAI.py << 'EOL'
import wikipedia, wolframalpha, os

class AssistantAI:
    def __init__(self):
        self.client = wolframalpha.Client(os.getenv("WOLFRAM_APP_ID"))

    def handle_query(self, query):
        try:
            res = self.client.query(query)
            ans = next(res.results).text
            return ans
        except:
            try:
                return wikipedia.summary(query, sentences=2)
            except:
                return "Sorry, I could not find an answer."
EOL

echo "✅ Writing startup.html..."
cat > src/web/templates/startup.html << 'EOL'
<!DOCTYPE html>
<html>
<head><title>Welcome to RIYA AI</title></head>
<body>
<h1>RIYA is starting...</h1>
<script>setTimeout(()=>{window.location.href='/'}, 5000)</script>
</body>
</html>
EOL

echo "✅ Writing dashboard.html..."
cat > src/web/templates/dashboard.html << 'EOL'
<!DOCTYPE html>
<html>
<head>
  <title>RIYA AI Dashboard</title>
  <script src="https://cdn.socket.io/4.5.4/socket.io.min.js"></script>
</head>
<body>
  <h1>RIYA Smart Home Dashboard</h1>
  <button id="listenBtn">Start Listening</button>
  <div id="output"></div>
  <pre id="status"></pre>
<script>
  const socket = io();
  document.getElementById('listenBtn').onclick = ()=>{recognition.start();}
  const recognition = new(window.SpeechRecognition||window.webkitSpeechRecognition)();
  recognition.continuous = true; recognition.onresult = (event)=> {
    const command = event.results[0][0].transcript;
    document.getElementById('output').innerText = 'You: '+command;
    socket.emit('voice_command', {command: command});
  };
  socket.on('voice_response', data => {document.getElementById('output').innerText += '\\nRIYA: '+data.text});
  function update() { socket.emit('get_status'); }
  socket.on('status_update', data => {document.getElementById('status').innerText = JSON.stringify(data,null,2)});
  setInterval(update, 5000);
</script>
</body>
</html>
EOL

echo "✅ Writing systemd..."
cat > systemd/riya.service << 'EOL'
[Unit]
Description=RIYA Smart Home AI
After=network.target
[Service]
User=$USER
WorkingDirectory=/home/$USER/riya_ai
ExecStart=/usr/bin/python3 src/main.py
Restart=always
Environment=PYTHONUNBUFFERED=1
[Install]
WantedBy=multi-user.target
EOL

sudo cp systemd/riya.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable riya.service

echo "✅ Done! Run: sudo systemctl start riya.service"
echo "👉 Open: http://$(hostname -I | awk '{print $1}'):5000"
