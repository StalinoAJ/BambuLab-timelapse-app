/*
 * BambuLab Timelapse Trigger - ESP32 Firmware
 *
 * Reads a digital trigger input (e.g., limit switch / optocoupler on Bambu Lab
 * toolhead or printer output) and sends "0" or "1" to the Flutter app via:
 *   - BLE GATT Notifications (default, no Wi-Fi required)
 *   - Wi-Fi WebSocket Server (optional, set USE_WIFI_WEBSOCKET to true)
 *
 * Libraries required (Arduino IDE Library Manager):
 *   - Built-in ESP32 BLE libraries (BLEDevice, BLEServer, BLEUtils, BLE2902)
 *   - If using Wi-Fi WebSocket: "WebSockets" by Markus Sattler
 */

#include <Arduino.h>

// Set to true for Wi-Fi WebSocket mode, false for BLE mode
#define USE_WIFI_WEBSOCKET false

// GPIO connected to your trigger switch (active LOW with INPUT_PULLUP, or active HIGH)
const int TRIGGER_PIN = 4;
const bool ACTIVE_LOW = true; // true if switch connects pin to GND when triggered

int lastSentValue = -1;
unsigned long lastSampleMs = 0;
const unsigned long SAMPLE_INTERVAL_MS = 50; // 20 Hz polling

#if USE_WIFI_WEBSOCKET
#include <WiFi.h>
#include <WebSocketsServer.h>

const char* AP_SSID = "BambuTimelapse-ESP32";
const char* AP_PASS = "12345678";
WebSocketsServer webSocket = WebSocketsServer(81);

void onWebSocketEvent(uint8_t num, WStype_t type, uint8_t* payload, size_t length) {
  if (type == WStype_CONNECTED) {
    Serial.printf("Client %u connected\n", num);
    String val = String(lastSentValue == 1 ? 1 : 0);
    webSocket.sendTXT(num, val);
  }
}
#else
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

BLECharacteristic* pCharacteristic = nullptr;
bool deviceConnected = false;

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) override {
    deviceConnected = true;
    Serial.println("BLE client connected");
  }
  void onDisconnect(BLEServer* pServer) override {
    deviceConnected = false;
    Serial.println("BLE client disconnected, restarting advertising");
    pServer->startAdvertising();
  }
};
#endif

int readTriggerValue() {
  int raw = digitalRead(TRIGGER_PIN);
  if (ACTIVE_LOW) {
    return (raw == LOW) ? 1 : 0;
  }
  return (raw == HIGH) ? 1 : 0;
}

void sendValue(int value) {
  String msg = String(value);
  Serial.printf("Sending: %s\n", msg.c_str());

#if USE_WIFI_WEBSOCKET
  webSocket.broadcastTXT(msg);
#else
  if (deviceConnected && pCharacteristic != nullptr) {
    pCharacteristic->setValue(msg.c_str());
    pCharacteristic->notify();
  }
#endif
}

void setup() {
  Serial.begin(115200);
  pinMode(TRIGGER_PIN, ACTIVE_LOW ? INPUT_PULLUP : INPUT_PULLDOWN);

#if USE_WIFI_WEBSOCKET
  WiFi.softAP(AP_SSID, AP_PASS);
  Serial.print("AP IP address: ");
  Serial.println(WiFi.softAPIP()); // Connect Flutter app to ws://192.168.4.1:81
  webSocket.begin();
  webSocket.onEvent(onWebSocketEvent);
#else
  BLEDevice::init("BambuTimelapse-ESP32");
  BLEServer* pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  BLEService* pService = pServer->createService(SERVICE_UUID);
  pCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  pCharacteristic->addDescriptor(new BLE2902());
  pCharacteristic->setValue("0");

  pService->start();
  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  BLEDevice::startAdvertising();
  Serial.println("BLE advertising started as BambuTimelapse-ESP32");
#endif
}

void loop() {
#if USE_WIFI_WEBSOCKET
  webSocket.loop();
#endif

  unsigned long now = millis();
  if (now - lastSampleMs >= SAMPLE_INTERVAL_MS) {
    lastSampleMs = now;
    int current = readTriggerValue();
    if (current != lastSentValue) {
      lastSentValue = current;
      sendValue(current);
    }
  }
}
