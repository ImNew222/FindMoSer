flk /*  *//*
 * ═══════════════════════════════════════════════════════════════
 *  FindMoSer BLE Beacon — ESP32-C3 + 0.96" OLED Display
 *  Cebu Eastern College — IoT-Powered Faculty Locator
 * ═══════════════════════════════════════════════════════════════
 *
 *  Features:
 *  - BLE beacon broadcasting for faculty locator
 *  - 0.96" I2C OLED display with animations
 *  - Startup logo animation
 *  - Live radar/pulse animation showing BLE broadcast
 *  - Room name, uptime, and broadcast count display
 *
 *  WIRING (I2C OLED to ESP32-C3):
 *  ──────────────────────────────
 *  OLED VCC  →  3.3V
 *  OLED GND  →  GND
 *  OLED SDA  →  GPIO 4
 *  OLED SCL  →  GPIO 5
 *
 *  LIBRARIES NEEDED (install via Arduino Library Manager):
 *  ──────────────────────────────────────────────────────
 *  1. "Adafruit SSD1306" by Adafruit
 *  2. "Adafruit GFX Library" by Adafruit
 *
 *  BEACON NAME — Change line 58 for each room!
 *
 * ═══════════════════════════════════════════════════════════════
 */

#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>

// ─── OLED Configuration ───
#define SCREEN_WIDTH  128
#define SCREEN_HEIGHT 64
#define OLED_RESET    -1      // No reset pin
#define SCREEN_ADDR   0x3C    // I2C address (try 0x3D if not working)
#define SDA_PIN       4       // ESP32-C3 I2C SDA
#define SCL_PIN       5       // ESP32-C3 I2C SCL

// ─── BLE Configuration ───
// ╔═══════════════════════════════════════════════════════════╗
// ║  ⚠️  CHANGE THIS FOR EACH ESP32 BEACON!                  ║
// ║                                                           ║
// ║  Beacon 1: "FindMoSer_Library"                            ║
// ║  Beacon 2: "FindMoSer_DeanOffice"                         ║
// ║  Beacon 3: "FindMoSer_ComputerLab"                        ║
// ╚═══════════════════════════════════════════════════════════╝
#define BEACON_NAME     "FindMoSer_Library"
#define ROOM_LABEL      "Library"            // Short name for OLED display
#define ADV_INTERVAL_MS 500

// ─── LED ───
#define LED_PIN 8

// ─── Global Objects ───
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);
BLEServer* pServer = nullptr;
BLEAdvertising* pAdvertising = nullptr;

// Animation state
unsigned long startTime = 0;
unsigned long broadcastCount = 0;
int radarRadius = 0;
int radarFrame = 0;
unsigned long lastRadarUpdate = 0;
unsigned long lastDisplayUpdate = 0;

// ═══════════════════════════════════════════════════════════
//  BITMAP: FindMoSer Logo (16x16)
// ═══════════════════════════════════════════════════════════
static const unsigned char PROGMEM logo_bmp[] = {
  0b00000110, 0b01100000,
  0b00011111, 0b11111000,
  0b00111111, 0b11111100,
  0b01111111, 0b11111110,
  0b01111100, 0b00111110,
  0b11110000, 0b00001111,
  0b11100001, 0b10000111,
  0b11100011, 0b11000111,
  0b11100011, 0b11000111,
  0b11100001, 0b10000111,
  0b11110000, 0b00001111,
  0b01111100, 0b00111110,
  0b01111111, 0b11111110,
  0b00111111, 0b11111100,
  0b00011111, 0b11111000,
  0b00000110, 0b01100000,
};

// ═══════════════════════════════════════════════════════════
//  STARTUP ANIMATION
// ═══════════════════════════════════════════════════════════
void playStartupAnimation() {
  // Frame 1: Logo fade in (draw expanding circles)
  for (int r = 1; r <= 20; r += 2) {
    display.clearDisplay();
    display.drawCircle(64, 32, r, SSD1306_WHITE);
    display.display();
    delay(30);
  }

  // Frame 2: Show logo
  display.clearDisplay();
  display.drawBitmap(56, 8, logo_bmp, 16, 16, SSD1306_WHITE);
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(28, 30);
  display.print("FindMoSer");
  display.setCursor(10, 42);
  display.setTextSize(1);
  display.print("Faculty Locator");
  display.setCursor(8, 54);
  display.print("Cebu Eastern College");
  display.display();
  delay(2000);

  // Frame 3: Room name reveal
  display.clearDisplay();
  display.setTextSize(1);
  display.setCursor(30, 10);
  display.print("Assigned Room:");
  display.setTextSize(2);

  // Center the room label
  int16_t x, y;
  uint16_t w, h;
  display.getTextBounds(ROOM_LABEL, 0, 0, &x, &y, &w, &h);
  display.setCursor((128 - w) / 2, 28);
  display.print(ROOM_LABEL);

  display.setTextSize(1);
  display.setCursor(20, 52);
  display.print("Initializing BLE...");
  display.display();
  delay(1500);

  // Frame 4: BLE ready
  display.clearDisplay();
  display.setTextSize(1);
  display.setCursor(10, 25);
  display.print("BLE Broadcasting...");
  // Draw expanding signal waves
  for (int i = 0; i < 3; i++) {
    for (int r = 5; r <= 25; r += 5) {
      display.drawCircle(64, 50, r, SSD1306_WHITE);
      display.display();
      delay(50);
    }
    delay(100);
    display.fillRect(0, 40, 128, 24, SSD1306_BLACK);
    display.display();
  }

  delay(500);
}

// ═══════════════════════════════════════════════════════════
//  DRAW RADAR PULSE ANIMATION
// ═══════════════════════════════════════════════════════════
void drawRadarPulse(int centerX, int centerY) {
  // Draw 3 expanding arcs to simulate a radar/BLE signal pulse
  for (int i = 0; i < 3; i++) {
    int r = (radarFrame + i * 8) % 24;
    if (r > 0) {
      // Draw arc (top-right quadrant only for signal wave look)
      for (int angle = -60; angle <= 60; angle += 5) {
        float rad = angle * 3.14159 / 180.0;
        int px = centerX + (int)(r * sin(rad));
        int py = centerY - (int)(r * cos(rad));
        if (px >= 0 && px < 128 && py >= 0 && py < 64) {
          display.drawPixel(px, py, SSD1306_WHITE);
        }
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════
//  DRAW MAIN DISPLAY
// ═══════════════════════════════════════════════════════════
void drawMainDisplay() {
  display.clearDisplay();

  // ─── Top bar: "FindMoSer" + signal icon ───
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.print("FindMoSer");

  // Signal strength bars (top right)
  for (int i = 0; i < 4; i++) {
    int barHeight = 3 + i * 2;
    int barX = 108 + i * 5;
    display.fillRect(barX, 9 - barHeight, 3, barHeight, SSD1306_WHITE);
  }

  // Separator line
  display.drawLine(0, 11, 127, 11, SSD1306_WHITE);

  // ─── Room name (large) ───
  display.setTextSize(2);
  int16_t x, y;
  uint16_t w, h;
  display.getTextBounds(ROOM_LABEL, 0, 0, &x, &y, &w, &h);
  display.setCursor((128 - w) / 2, 16);
  display.print(ROOM_LABEL);

  // ─── BLE Radar animation (center area) ───
  drawRadarPulse(100, 38);

  // BLE icon dot (center of radar)
  display.fillCircle(100, 38, 2, SSD1306_WHITE);

  // ─── Bottom info bar ───
  display.drawLine(0, 50, 127, 50, SSD1306_WHITE);

  // Uptime
  unsigned long upSec = (millis() - startTime) / 1000;
  unsigned long hours = upSec / 3600;
  unsigned long mins = (upSec % 3600) / 60;
  unsigned long secs = upSec % 60;

  display.setTextSize(1);
  display.setCursor(0, 54);
  display.print("UP ");
  if (hours > 0) {
    display.print(hours);
    display.print("h ");
  }
  if (hours > 0 || mins > 0) {
    display.print(mins);
    display.print("m ");
  }
  display.print(secs);
  display.print("s");

  // Broadcast count (bottom right)
  display.setCursor(80, 54);
  display.print("TX:");
  display.print(broadcastCount);

  display.display();
}

// ═══════════════════════════════════════════════════════════
//  SETUP
// ═══════════════════════════════════════════════════════════
void setup() {
  Serial.begin(115200);
  delay(500);

  // Setup LED
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  // Initialize I2C for OLED
  Wire.begin(SDA_PIN, SCL_PIN);

  // Initialize OLED
  if (!display.begin(SSD1306_SWITCHCAPVCC, SCREEN_ADDR)) {
    Serial.println("[OLED] ❌ SSD1306 not found! Check wiring.");
    // Continue without display — BLE still works
  } else {
    Serial.println("[OLED] ✅ Display initialized");
    display.clearDisplay();
    display.display();
  }

  // Play startup animation
  playStartupAnimation();

  // Initialize BLE
  Serial.println("[BLE] Initializing...");
  Serial.print("[BLE] Beacon Name: ");
  Serial.println(BEACON_NAME);

  BLEDevice::init(BEACON_NAME);
  pServer = BLEDevice::createServer();
  BLEDevice::setPower(ESP_PWR_LVL_P9);

  pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMinPreferred(0x12);

  uint16_t advInterval = (uint16_t)(ADV_INTERVAL_MS / 0.625);
  pAdvertising->setMinInterval(advInterval);
  pAdvertising->setMaxInterval(advInterval);

  BLEDevice::startAdvertising();
  Serial.println("[BLE] ✅ Beacon is broadcasting!");

  startTime = millis();

  // Flash LED 3 times
  for (int i = 0; i < 3; i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(150);
    digitalWrite(LED_PIN, LOW);
    delay(150);
  }
}

// ═══════════════════════════════════════════════════════════
//  LOOP
// ═══════════════════════════════════════════════════════════
void loop() {
  unsigned long now = millis();

  // Update radar animation every 80ms
  if (now - lastRadarUpdate >= 80) {
    radarFrame = (radarFrame + 1) % 24;
    lastRadarUpdate = now;
  }

  // Refresh OLED display every 100ms
  if (now - lastDisplayUpdate >= 100) {
    drawMainDisplay();
    lastDisplayUpdate = now;
  }

  // LED heartbeat blink (quick flash every 3 seconds)
  static unsigned long lastBlink = 0;
  static bool ledOn = false;
  if (!ledOn && (now - lastBlink >= 2900)) {
    digitalWrite(LED_PIN, HIGH);
    ledOn = true;
    lastBlink = now;
  } else if (ledOn && (now - lastBlink >= 100)) {
    digitalWrite(LED_PIN, LOW);
    ledOn = false;
    lastBlink = now;
  }

  // Re-start advertising every 30 seconds + count broadcasts
  static unsigned long lastRestart = 0;
  if (now - lastRestart >= 30000) {
    BLEDevice::startAdvertising();
    broadcastCount++;
    lastRestart = now;

    Serial.print("[");
    Serial.print(now / 1000);
    Serial.print("s] Beacon '");
    Serial.print(BEACON_NAME);
    Serial.print("' broadcasting... (TX #");
    Serial.print(broadcastCount);
    Serial.println(")");
  }
}
