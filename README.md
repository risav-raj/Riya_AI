# Riya_AI




use commands:-

  chmod +x install_riya.sh && ./install_riya.sh


for starting use:-

  sudo systemctl start riya

for troubleshooting:-

  
  journalctl -u riya -f  # View live logs







# Raspberry Pi GPIO Pinout
 ┌─────────────────────────────────────────┐
 │ Raspberry Pi 3 (GPIO - BCM Mode)        │
 ├──────┬──────┬───────────────────────────┤
 │ 3.3V │ 5V   │ Ground                    │
 │ GPIO2│ GPIO3│ GPIO4 (Relay 4)           │
 │ GPIO14│ GND  │ GPIO15                   │
 │ GPIO17│ GPIO27│ GPIO22 (Relay 3)        │
 │ GPIO10│ GPIO9 │ GPIO11 (Relay 5)        │
 │ GPIO5 │ GPIO6 │ GPIO13 (Relay 6)        │
 │ GPIO19│ GPIO26│ GPIO12 (Relay 7)        │
 │ GPIO16│ GPIO20│ GPIO21 (Relay 8)        │
 │ GPIO18│ GPIO24│ GPIO25 (Relay 9)        │
 └──────┴──────┴───────────────────────────┘

Soil Moisture Sensor Wiring:
• VCC → 3.3V
• GND → Ground
• SIG → GPIO Pin (e.g., GPIO18)
