#!/bin/bash

echo "🔄 Updating system & installing packages..."
sudo apt update && sudo apt install -y \
  python3-pip python3-flask python3-rpi.gpio espeak mpg321 nmap arp-scan netdiscover lynis git

echo "✅ Installing Python libraries..."
pip3 install flask-socketio eventlet RPi.GPIO gTTS playsound requests Adafruit_DHT fuzzywuzzy python-Levenshtein wolframalpha

echo "✅ Creating RIYA AI project structure..."
mkdir -p ~/riya_ai/{src/{core/{ai,Backend},web/{templates,static/{js,css,music}}},systemd,logs}

cd ~/riya_ai

echo "✅ Saving API keys to .bashrc..."
echo 'export OPENWEATHER_API_KEY="ef0a8f830d078a331c34930e168c3e5e"' >> ~/.bashrc
echo 'export NEWS_API_KEY="8ac23d769ee248de827cd76d808e5eba"' >> ~/.bashrc
echo 'export WOLFRAM_API_KEY="43GE2P-289L6YWKKT"' >> ~/.bashrc
source ~/.bashrc

echo "✅ Writing main.py with relays, sensors, fuzzy matching..."
cat > src/main.py << 'EOL'
import os
import time
import random
import subprocess
import requests
from datetime import datetime
from flask import Flask, render_template
from flask_socketio import SocketIO, emit
from gtts import gTTS
import playsound
from fuzzywuzzy import fuzz
import Adafruit_DHT

import RPi.GPIO as GPIO

OPENWEATHER_KEY = "ef0a8f830d078a331c34930e168c3e5e"
NEWS_KEY = "8ac23d769ee248de827cd76d808e5eba"
WOLFRAM_KEY = "43GE2P-289L6YWKKT"

GPIO.setmode(GPIO.BCM)
relay_pins = [17,18,27,22,23,24,25,5,6]
for pin in relay_pins:
    GPIO.setup(pin, GPIO.OUT)
    GPIO.output(pin, GPIO.HIGH)

DHT_SENSOR = Adafruit_DHT.DHT22
DHT_PIN = 4
MOISTURE_PIN = 21

app = Flask(__name__)
socketio = SocketIO(app)

class RIYA:
    def __init__(self):
        self.reminders = []
        self.alarms = []
        self.commands = [
            {"intents": ["turn on all lights"], "action": self.turn_on_all_lights},
            {"intents": ["turn off all lights"], "action": self.turn_off_all_lights},
            {"intents": ["turn on pump"], "action": lambda: self.control_relay(9, True)},
            {"intents": ["turn off pump"], "action": lambda: self.control_relay(9, False)},
            {"intents": ["check moisture"], "action": self.check_moisture},
            {"intents": ["check temperature"], "action": self.check_temperature},
            {"intents": ["check humidity"], "action": self.check_humidity},
            {"intents": ["system stats"], "action": self.system_stats},
            {"intents": ["tell me a joke"], "action": self.tell_joke},
            {"intents": ["get weather"], "action": lambda: self.get_weather("Delhi")},
            {"intents": ["get news"], "action": self.get_news},
        ]
        for i in range(1,9):
            self.commands.append({"intents": [f"turn on light {i}", f"switch on bulb {i}"], "action": lambda i=i: self.control_relay(i, True)})
            self.commands.append({"intents": [f"turn off light {i}", f"switch off bulb {i}"], "action": lambda i=i: self.control_relay(i, False)})

    def speak(self, text):
        tts = gTTS(text=text, lang="en", tld="co.in")
        filename = "/tmp/riya_say.mp3"
        tts.save(filename)
        playsound.playsound(filename)

    def control_relay(self, relay, state):
        pin = relay_pins[relay-1]
        GPIO.output(pin, GPIO.LOW if state else GPIO.HIGH)
        return f"Relay {relay} {'ON' if state else 'OFF'}."

    def turn_on_all_lights(self):
        for i in range(8):
            GPIO.output(relay_pins[i], GPIO.LOW)
        return "All lights turned ON."

    def turn_off_all_lights(self):
        for i in range(8):
            GPIO.output(relay_pins[i], GPIO.HIGH)
        return "All lights turned OFF."

    def check_moisture(self):
        level = random.randint(30, 80) # simulate for now
        return f"Soil moisture is {level}%."

    def check_temperature(self):
        humidity, temperature = Adafruit_DHT.read_retry(DHT_SENSOR, DHT_PIN)
        return f"Temperature: {temperature:.2f}°C"

    def check_humidity(self):
        humidity, temperature = Adafruit_DHT.read_retry(DHT_SENSOR, DHT_PIN)
        return f"Humidity: {humidity:.2f}%"

    def system_stats(self):
        cpu = subprocess.getoutput("top -bn1 | grep 'Cpu(s)'").strip()
        mem = subprocess.getoutput("free -h | grep Mem").strip()
        return f"CPU: {cpu}\nMemory: {mem}"

    def tell_joke(self):
        jokes = ["Why don't scientists trust atoms? Because they make up everything!"]
        return random.choice(jokes)

    def get_weather(self, city):
        url = f"http://api.openweathermap.org/data/2.5/weather?q={city}&appid={OPENWEATHER_KEY}&units=metric"
        res = requests.get(url)
        if res.status_code == 200:
            data = res.json()
            desc = data['weather'][0]['description']
            temp = data['main']['temp']
            return f"{city} weather: {desc}, {temp}°C."
        return "Failed to get weather."

    def get_news(self):
        url = f"https://newsapi.org/v2/top-headlines?country=in&apiKey={NEWS_KEY}"
        res = requests.get(url)
        if res.status_code == 200:
            articles = res.json()['articles'][:5]
            return "\n".join([f"{i+1}. {a['title']}" for i,a in enumerate(articles)])
        return "Failed to get news."

    def process_command(self, text):
        text = text.lower()
        for cmd in self.commands:
            for intent in cmd["intents"]:
                if fuzz.partial_ratio(intent, text) > 80:
                    return cmd["action"]()
        if text.startswith("say "):
            to_say = text[4:]
            self.speak(to_say)
            return f"Saying: {to_say}"
        return "❌ I did not understand."

@app.route('/')
def index():
    return "RIYA Smart Home AI Server is active."

@socketio.on('voice_command')
def handle_command(data):
    riya = RIYA()
    response = riya.process_command(data['command'])
    emit('voice_response', {'text': response})

if __name__ == "__main__":
    socketio.run(app, host="0.0.0.0", port=5000)
EOL

echo "✅ Creating systemd service..."
cat > systemd/riya.service << 'EOL'
[Unit]
Description=RIYA Smart Home AI Server
After=network.target

[Service]
User='$USER'
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

echo -e "\n✅✅✅ \033[1;32mRIYA Smart Intelligent Home Automation Server installed!\033[0m"
echo -e "Start with: \033[1;33msudo systemctl start riya.service\033[0m"
echo -e "Stop with: \033[1;33msudo systemctl stop riya.service\033[0m"
echo -e "Open dashboard: \033[1;34mhttp://$(hostname -I | awk '{print $1}'):5000\033[0m"
