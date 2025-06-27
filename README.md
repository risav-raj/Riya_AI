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




### **Connections**

1. **Raspberry Pi GPIO Pins:**
   - Connect the DHT11/DHT22 sensor:
     - VCC to 3.3V or 5V (depending on the sensor)
     - GND to Ground
     - Data pin to a GPIO pin (e.g., GPIO4)
   
   - Connect the Soil Moisture Sensor:
     - VCC to 3.3V or 5V
     - GND to Ground
     - Analog output (or digital output) to a GPIO pin (e.g., GPIO17)

2. **Relay Module:**
   - Connect the relay module to the Raspberry Pi:
     - VCC to 5V
     - GND to Ground
     - IN1 to a GPIO pin (e.g., GPIO18) for Light 1
     - IN2 to a GPIO pin (e.g., GPIO23) for Light 2
     - IN3 to a GPIO pin (e.g., GPIO24) for Light 3
     - IN4 to a GPIO pin (e.g., GPIO25) for Light 4
     - IN5 to a GPIO pin (e.g., GPIO8) for Light 5
     - IN6 to a GPIO pin (e.g., GPIO7) for Light 6
     - IN7 to a GPIO pin (e.g., GPIO12) for Light 7
     - IN8 to a GPIO pin (e.g., GPIO16) for Light 8
     - IN9 to a GPIO pin (e.g., GPIO20) for the Pump

### **Components Required**

1. **Raspberry Pi** (any model with GPIO pins)
2. **DHT11 or DHT22 Sensor** (for temperature and humidity)
3. **Soil Moisture Sensor**
4. **Relay Module** (8-channel relay module recommended)
5. **Jumper Wires** (for connections)
6. **Breadboard** (optional, for easier connections)

### **Wiring Instructions**

- Ensure that all components are powered correctly.
- Use GPIO pins that are not used by other peripherals.
- Make sure to connect the ground of the Raspberry Pi to the ground of the relay module and sensors to avoid floating ground issues.

### **Notes**

- The relay module allows you to control high voltage devices (like lights and pumps) using low voltage GPIO signals from the Raspberry Pi.
- The DHT11/DHT22 sensor provides temperature and humidity readings, while the soil moisture sensor helps monitor the moisture level in the soil.

You can use this information to create a graphical circuit diagram using tools like Fritzing, Tinkercad, or any other circuit design software. If you need a specific format or additional details, please let me know!


