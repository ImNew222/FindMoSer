# FindMoSer ESP32 BLE Beacons
## Cebu Eastern College — IoT-Powered Faculty Locator

This folder contains the Arduino sketch for your 3 ESP32-C3 beacons.

---

## 🔧 Setup Checklist

### Step 1: Install Arduino IDE
Download from: https://www.arduino.cc/en/software

### Step 2: Add ESP32 Board Support
1. Open Arduino IDE
2. Go to **File → Preferences**
3. In "Additional Board Manager URLs", paste:
   ```
   https://espressif.github.io/arduino-esp32/package_esp32_index.json
   ```
4. Click OK
5. Go to **Tools → Board → Boards Manager**
6. Search **"ESP32"** → Click **Install** on "esp32 by Espressif Systems"

### Step 3: Select Board
- Go to **Tools → Board → esp32 → ESP32C3 Dev Module**

### Step 4: Flash Each Beacon
You need to flash the same sketch **3 times**, changing `BEACON_NAME` each time:

| Beacon # | Room           | Change `BEACON_NAME` to:       |
|----------|----------------|--------------------------------|
| 1        | 📚 Library      | `"FindMoSer_Library"`          |
| 2        | 🏢 Dean's Office | `"FindMoSer_DeanOffice"`       |
| 3        | 💻 Computer Lab  | `"FindMoSer_ComputerLab"`      |

#### For each ESP32:
1. Connect ESP32-C3 to your laptop via USB cable
2. Open `findmoser_beacon.ino` in Arduino IDE
3. **Change line 44** to the correct `BEACON_NAME` for this room
4. Select the correct Port: **Tools → Port → (your USB port)**
5. Click **Upload** (→ button)
6. Open **Serial Monitor** (🔍 button, set to 115200 baud)
7. You should see:
   ```
   ═══════════════════════════════════════
     FindMoSer BLE Beacon
     Cebu Eastern College
   ═══════════════════════════════════════
     Beacon Name: FindMoSer_Library
   ═══════════════════════════════════════
   [BLE] Initializing...
   [BLE] ✅ Beacon is now broadcasting!
   ```
8. The built-in LED will blink slowly (once every 3 seconds) to confirm it's running
9. **Unplug** the ESP32 and move to the next one

### Step 5: Place Beacons
- Plug each ESP32 into a **USB power source** (phone charger, power bank, or USB wall plug) in its assigned room
- The beacon starts broadcasting automatically when powered on
- No WiFi or internet connection needed!

---

## 🧪 Testing
1. Power on all 3 beacons in their rooms
2. Open the FindMoSer app on a **faculty** phone
3. Walk near each beacon — the app should detect which room you're in
4. Check that the **closest beacon** (strongest signal) is correctly identified

## ⚡ Power
- Each ESP32-C3 draws about **70-100mA** when broadcasting BLE
- A standard 5V/1A phone charger works perfectly
- A 10,000mAh power bank will last ~4-5 days continuously

## 🔴 Troubleshooting
| Problem | Solution |
|---------|----------|
| Upload fails | Hold the **BOOT** button on the ESP32 while uploading |
| No serial output | Set Serial Monitor to **115200 baud** |
| LED not blinking | Check if your ESP32-C3 LED is on a different GPIO (try 2 or 10) |
| App doesn't detect | Make sure Bluetooth & Location are enabled on the phone |
