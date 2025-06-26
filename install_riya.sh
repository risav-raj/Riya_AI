# Single-Command RIYA Installation for Kali Linux
sudo apt update && sudo apt install -y python3-pip arp-scan python3-flask python3-netifaces git && \
mkdir -p ~/riya_ai/{src/{core/network,hardware,web/{templates,static/{js,css}}},systemd,docs} && cd ~/riya_ai && \
cat > src/main.py << 'EOL'
import threading
import time
from core.riya import RIYA
from web.app import create_app

def run_background_tasks():
    while True:
        current_app.riya.network_scanner.arp_scan()
        current_app.riya.update_sensors()
        time.sleep(3600)

if __name__ == '__main__':
    app = create_app()
    current_app = app
    threading.Thread(target=run_background_tasks, daemon=True).start()
    app.run(host='0.0.0.0', port=5000)
EOL && \
cat > src/core/network/scanner.py << 'EOL'
import subprocess, netifaces
from datetime import datetime

class NetworkScanner:
    def __init__(self):
        self.devices = []
        self.interface = [iface for iface in netifaces.interfaces() 
                         if iface.startswith(('eth','wlan'))][0] or 'eth0'
    
    def arp_scan(self):
        try:
            result = subprocess.run(['sudo','arp-scan','-I',self.interface,'--localnet','--quiet'],
                                  capture_output=True, text=True)
            self.devices = [{
                'ip': parts[0], 'mac': parts[1], 'vendor': parts[2],
                'last_seen': datetime.now().isoformat(), 'status': 'online'
            } for line in result.stdout.splitlines() 
             if line and not line.startswith('Interface') 
             for parts in [line.split('\t')] if len(parts) >= 3]
            return True
        except Exception as e:
            print(f"Scan error: {str(e)}")
            return False
    
    def get_connected_devices(self):
        return {'count': len(self.devices), 'devices': self.devices}
EOL && \
cat > src/core/riya.py << 'EOL'
from core.network.scanner import NetworkScanner
import threading

class RIYA:
    def __init__(self):
        self.network_scanner = NetworkScanner()
        self.setup_commands()

    def setup_commands(self):
        self.commands = {
            'scan network': self.scan_network,
            'devices': lambda: f"Found {self.network_scanner.get_connected_devices()['count']} devices"
        }

    def scan_network(self):
        return "Network scan started" if self.network_scanner.arp_scan() else "Scan failed"

    def process_command(self, cmd):
        return self.commands.get(cmd.lower(), lambda: "Unknown command")()
EOL && \
cat > src/web/app.py << 'EOL'
from flask import Flask, render_template
from flask_socketio import SocketIO

app = Flask(__name__)
socketio = SocketIO(app)

@app.route('/')
def dashboard():
    return render_template('dashboard.html')
EOL && \
cat > src/web/templates/dashboard.html << 'EOL'
<!DOCTYPE html>
<html>
<head>
    <title>RIYA Network Dashboard</title>
    <script src="https://cdn.socket.io/4.5.4/socket.io.min.js"></script>
    <style>
        body{font-family: sans-serif; margin: 20px}
        .device-table {width: 100%; border-collapse: collapse}
        .device-table th, .device-table td {padding: 8px; text-align: left; border: 1px solid #ddd}
    </style>
</head>
<body>
    <h1>Network Devices</h1>
    <button onclick="scan()">Scan Network</button>
    <div id="results"></div>

    <script>
        const socket = io();
        socket.on('network_update', data => {
            let html = `<table class="device-table">
                        <tr><th>IP</th><th>MAC</th><th>Vendor</th></tr>`;
            data.devices.forEach(device => {
                html += `<tr><td>${device.ip}</td><td>${device.mac}</td><td>${device.vendor}</td></tr>`;
            });
            document.getElementById('results').innerHTML = html + `</table><p>Total: ${data.count} devices</p>`;
        });

        function scan() {
            socket.emit('network_scan');
        }
    </script>
</body>
</html>
EOL && \
cat > src/web/sockets.py << 'EOL'
from flask_socketio import emit
from main import socketio, current_app

@socketio.on('network_scan')
def handle_scan():
    if current_app.riya.network_scanner.arp_scan():
        emit('network_update', current_app.riya.network_scanner.get_connected_devices())
EOL && \
cat > setup.sh << 'EOL'
#!/bin/bash
pip3 install flask-socketio eventlet
sudo chmod +x /usr/sbin/arp-scan
echo "$USER ALL=(ALL) NOPASSWD: /usr/sbin/arp-scan" | sudo tee -a /etc/sudoers
sudo cp systemd/riya.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable riya.service
EOL && \
chmod +x setup.sh && \
cat > systemd/riya.service << 'EOL'
[Unit]
Description=RIYA Virtual Assistant
After=network.target

[Service]
User=root
WorkingDirectory=/root/riya_ai
ExecStart=/usr/bin/python3 src/main.py
Restart=always

[Install]
WantedBy=multi-user.target
EOL && \
./setup.sh && \
echo -e "\n\033[1;32mInstallation complete!\033[0m\nAccess dashboard at: \033[1;34mhttp://$(hostname -I | awk '{print $1}'):5000\033[0m\nRun: 'sudo systemctl start riya'"
