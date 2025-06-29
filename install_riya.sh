#!/bin/bash

echo "🔄 [RIYA AI] Updating system..."
sudo apt update && sudo apt upgrade -y

echo "🔧 [RIYA AI] Installing OS dependencies..."
sudo apt install -y python3-pip python3-flask python3-rpi.gpio espeak mpg321 nmap arp-scan netdiscover lynis git arecord ffmpeg sox x11vnc rclone twilio-cli

echo "📦 [RIYA AI] Installing Python packages..."
pip3 install flask-socketio eventlet RPi.GPIO gTTS playsound requests fuzzywuzzy python-Levenshtein beautifulsoup4 paramiko twilio wolframalpha

echo "📂 [RIYA AI] Creating project structure..."
mkdir -p ~/riya_ai/{src/{core/{ai,hardware},web/{templates,static/{js,css,music,screenshots}}},systemd,logs,config}

echo "🎶 [RIYA AI] Downloading sample music..."
wget -O ~/riya_ai/src/web/static/music/calm.mp3 https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3

echo "📝 [RIYA AI] Creating main.py..."
cat > ~/riya_ai/src/main.py << 'EOF'
import os, subprocess, random, time, requests, smtplib
from datetime import datetime
from flask import Flask, render_template, request, redirect
from flask_socketio import SocketIO, emit
from gtts import gTTS
import playsound
from fuzzywuzzy import fuzz
from bs4 import BeautifulSoup
import wolframalpha
import RPi.GPIO as GPIO

WOLFRAM_APP_ID = "43GE2P-289L6YWKKT"
app = Flask(__name__)
socketio = SocketIO(app)

USER = "admin"
PASS = "riya123"

# Setup GPIO for 9 relays
GPIO.setmode(GPIO.BCM)
relays = {i: (i+2) for i in range(1, 10)}
for pin in relays.values():
    GPIO.setup(pin, GPIO.OUT)
    GPIO.output(pin, GPIO.LOW)

class RIYA:
    def __init__(self):
        self.intro = [
            "Hello! I am RIYA, your unstoppable Smart AI Assistant.",
            "Made by ATL members — your personal home Jarvis!",
            "I control lights, motor, sensors, network, emails, calls, answers, and more.",
            "Say: Turn on light, scan network, take photo, update, or ask me anything!"
        ]
        self.commands = {
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
            "search google": self.google_search,
            "send email": self.send_email,
            "sync data": self.sync_data,
            "update yourself": self.self_update,
            "weather": self.get_weather,
            "news": self.get_news
        }
        self.client = wolframalpha.Client(WOLFRAM_APP_ID)

    def introduce(self):
        for line in self.intro:
            self.speak(line)
            time.sleep(1)
        emit('start_listening')

    def speak(self, text):
        tts = gTTS(text=text, lang='en')
        audio = "/tmp/riya.mp3"
        tts.save(audio)
        playsound.playsound(audio)

    def relay_control(self, num, state):
        pin = relays.get(num)
        if not pin:
            return f"Relay {num} not found."
        if state == "TOGGLE":
            GPIO.output(pin, not GPIO.input(pin))
        else:
            GPIO.output(pin, GPIO.HIGH if state else GPIO.LOW)
        return f"Relay {num} {'ON' if state else 'OFF'}."

    def handle_light(self, cmd):
        words = cmd.split()
        for i in range(1, 10):
            if str(i) in words:
                if "on" in words:
                    return self.relay_control(i, True)
                elif "off" in words:
                    return self.relay_control(i, False)
                elif "toggle" in words:
                    return self.relay_control(i, "TOGGLE")
        return "Say light number and action."

    def turn_on_all(self):
        for i in relays:
            self.relay_control(i, True)
        return "All lights turned ON."

    def turn_off_all(self):
        for i in relays:
            self.relay_control(i, False)
        return "All lights turned OFF."

    def scan_network(self):
        return subprocess.getoutput("nmap -sn 192.168.1.0/24")

    def moisture_sensor(self):
        return f"Soil Moisture: {random.randint(20,80)}%"

    def temperature_sensor(self):
        return f"Temperature: {random.uniform(22, 32):.1f}°C"

    def humidity_sensor(self):
        return f"Humidity: {random.uniform(40, 70):.1f}%"

    def record_audio(self):
        subprocess.call("arecord -d 5 /tmp/voice.wav", shell=True)
        return "Recorded 5 sec audio."

    def take_picture(self):
        subprocess.call("raspistill -o ~/riya_ai/src/web/static/screenshots/photo.jpg", shell=True)
        return "Picture captured."

    def google_search(self):
        html = requests.get("https://www.google.com/search?q=AI+news").text
        soup = BeautifulSoup(html, 'html.parser')
        return f"Top Google result: {soup.title.string}"

    def send_email(self):
        server = smtplib.SMTP('smtp.gmail.com', 587)
        server.starttls()
        server.login("YOUR_EMAIL@gmail.com", "YOUR_PASSWORD")
        server.sendmail("YOUR_EMAIL@gmail.com", "TARGET_EMAIL@gmail.com", "Hello from RIYA!")
        server.quit()
        return "Email sent."

    def make_call_dynamic(self, number):
        if len(number) < 8:
            return "Invalid number."
        os.system(f"twilio api:core:calls:create --from +YOUR_TWILIO --to +{number} --url http://demo.twilio.com/docs/voice.xml")
        return f"Calling {number}..."

    def sync_data(self):
        os.system("rclone sync ~/riya_ai/logs remote:riya_backup")
        return "Logs synced."

    def self_update(self):
        os.system("git pull origin main")
        return "Codebase updated."

    def get_weather(self):
        r = requests.get("http://api.openweathermap.org/data/2.5/weather?q=Delhi&appid=ef0a8f830d078a331c34930e168c3e5e&units=metric").json()
        return f"Delhi: {r['main']['temp']}°C, {r['weather'][0]['description']}"

    def get_news(self):
        r = requests.get("https://newsapi.org/v2/top-headlines?country=in&apiKey=8ac23d769ee248de827cd76d808e5eba").json()
        return "\n".join([a['title'] for a in r['articles'][:5]])

    def answer_general(self, question):
        try:
            res = self.client.query(question)
            return next(res.results).text
        except:
            return "Sorry, I couldn't answer that."

    def process_command(self, cmd):
        cmd = cmd.lower()
        if cmd.startswith("say "):
            text = cmd.replace("say ", "", 1).strip()
            self.speak(text)
            return f"Saying: {text}"
        if "call" in cmd:
            number = ''.join(filter(str.isdigit, cmd))
            return self.make_call_dynamic(number)
        if "light" in cmd:
            return self.handle_light(cmd)
        for k, action in self.commands.items():
            if fuzz.partial_ratio(k, cmd) > 70:
                return action()
        return self.answer_general(cmd)

@app.route("/", methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        if request.form['username'] == USER and request.form['password'] == PASS:
            return redirect('/dashboard')
    return '<form method="POST">User:<input name="username"> Password:<input name="password" type="password"> <input type="submit" value="Login"></form>'

@app.route("/dashboard")
def dashboard():
    return render_template('dashboard.html')

@socketio.on("request_intro")
def intro():
    RIYA().introduce()

@socketio.on("voice_command")
def command(data):
    response = RIYA().process_command(data['command'])
    emit("voice_response", {"text": response})

if __name__ == "__main__":
    socketio.run(app, host="0.0.0.0", port=5000)
EOF

echo "📑 [RIYA AI] Creating dashboard.html..."
cat > ~/riya_ai/src/web/templates/dashboard.html << 'EOF'
<!DOCTYPE html><html><head><meta charset="UTF-8"><title>RIYA Dashboard</title>
<script src="https://cdn.socket.io/4.5.4/socket.io.min.js"></script></head>
<body style="background:#111;color:#eee;"><h1>RIYA AI Control Panel</h1>
<button onclick="listen()">Start Listening</button><pre id="res"></pre><h3>Live Feed:</h3>
<img src="/static/screenshots/photo.jpg" id="pic" style="width:100%;border:2px solid #0ff;">
<script>
const s = io();
function listen(){ s.emit("request_intro"); }
s.on("start_listening", ()=>{document.getElementById("res").textContent = "Listening...";});
s.on("voice_response", d => {
  document.getElementById("res").textContent = d.text;
  document.getElementById("pic").src = "/static/screenshots/photo.jpg?x=" + Math.random();
});
</script></body></html>
EOF

echo "🗂️ [RIYA AI] Creating systemd service..."
cat > ~/riya_ai/systemd/riya.service << 'EOF'
[Unit]
Description=RIYA Smart AI Service
After=network.target

[Service]
ExecStart=/usr/bin/python3 /home/$USER/riya_ai/src/main.py
WorkingDirectory=/home/$USER/riya_ai/src
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "🔗 [RIYA AI] Enabling service..."
sudo cp ~/riya_ai/systemd/riya.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable riya.service

echo "✅✅✅ RIYA FINAL AI is READY! Use: sudo systemctl start riya"
echo "👉 Access your Dashboard: http://$(hostname -I | awk '{print $1}'):5000"
