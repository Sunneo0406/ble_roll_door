#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <string>
#include <esp_task_wdt.h> // 引入看門狗函式庫

#define SERVICE_UUID        "4faf59a6-976e-67a2-c044-869700000000" 
#define CHARACTERISTIC_UUID "a0329f59-700a-ae2e-5a3d-030600000000" 

#define relayPin1 1
#define relayPin2 2
//#define relayPin3 27
#define relayCount 2
// --- 補上缺失的看門狗時間定義 (10秒) ---
#define WDT_TIMEOUT 10

unsigned long lastActionTime = 0;
const unsigned long debounceDelay = 1000;

byte arryRelay[relayCount]={relayPin1,relayPin2};

// --- 1. 新增全域變數：用來追蹤藍牙連線狀態 ---
bool deviceConnected = false;

void relayAction(int pin){
    digitalWrite(pin, HIGH);
    delay(100);
    digitalWrite(pin, LOW);
    delay(300);
    digitalWrite(pin, HIGH);
    delay(100);
    digitalWrite(pin, LOW);
}

class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
        unsigned long currentTime = millis();
        if (currentTime - lastActionTime > debounceDelay) {
            String arduinoValue = pCharacteristic->getValue();
            std::string value = arduinoValue.c_str();
            
            if (value.length() > 0) {
                lastActionTime = currentTime;
                char incomingChar = value[0]; 
                Serial.print("BLE 接收到指令: ");
                Serial.println(incomingChar);

                switch (incomingChar) {
                    case '1':
                        Serial.println("執行動作 1: 開啟 鐵門");
                        relayAction(relayPin1); 
                        break;

                    case '2':
                        Serial.println("執行動作 2: 關閉 鐵門");
                        relayAction(relayPin2); 
                        break;

                    default:
                        Serial.println("未知的 BLE 指令: " + String(incomingChar));
                        break; 
                }
            }
        } else {
            Serial.println("指令在冷卻時間內，已過濾");
        }
    }
};

// --- 2. 修改伺服器回呼：更新連線狀態旗標 ---
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      Serial.println("客戶端已連線");
      // 新增：更新旗標為已連線
      deviceConnected = true;
    }

    void onDisconnect(BLEServer* pServer) {
      Serial.println("客戶端已斷線，重新開始廣播...");
      // 新增：更新旗標為已斷線
      deviceConnected = false;
      delay(100);
      // 關鍵：重新啟動廣播，讓手機可以再次掃描到並重新連線喚醒
      pServer->getAdvertising()->start(); 
    }
};

void relaySet(int count){
  for(int x = 0 ; x < count ; x++){
    pinMode(arryRelay[x],OUTPUT); 
    digitalWrite(arryRelay[x], LOW);
    Serial.print(x+1);
    Serial.println("號繼電器已初始化...");
  }
}

void setup() {
  Serial.begin(115200);
  // --- [修正點] 新版看門狗初始化語法 ---
  esp_task_wdt_config_t wdt_config = {
      .timeout_ms = WDT_TIMEOUT * 1000, // 將秒轉換為毫秒
      .idle_core_mask = (1 << 0),       // 監控核心 0 (適用於大多數 ESP32/C3/S3)
      .trigger_panic = true             // 超時觸發重啟
  };
  esp_task_wdt_init(&wdt_config);
  
  esp_task_wdt_add(NULL); // 將當前 Loop 加入監控
  // ------------------------------------

  relaySet(relayCount);
  Serial.println("初始化中.....");

  BLEDevice::init("MyESP32");
  BLEServer *pServer = BLEDevice::createServer(); 
  pServer->setCallbacks(new MyServerCallbacks());
  BLEService *pService = pServer->createService(SERVICE_UUID); 
  BLECharacteristic *pCharacteristic = pService->createCharacteristic(
                                          CHARACTERISTIC_UUID,
                                          BLECharacteristic::PROPERTY_READ |
                                          BLECharacteristic::PROPERTY_WRITE 
                                        );
  pCharacteristic->setCallbacks(new MyCallbacks()); 
  pService->start();
  BLEAdvertising *pAdvertising = pServer->getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->start(); 
  Serial.println("等待手機連線並寫入 BLE 特徵值...");

  // --- 3. 新增設定：啟用藍牙作為輕度睡眠的喚醒源 ---
  
}

void loop() {

  esp_task_wdt_reset();
  // --- 4. 修改主迴圈：這是實現睡眠與喚醒的關鍵 ---

  if (!deviceConnected) {
      // 可以在這裡閃爍 LED 表示待機中，或是什麼都不做
      // 絕對不要呼叫 delay 太久，也不要 sleep
      delay(20); // 給 CPU 一點喘息空間處理背景 Wi-Fi/BT 任務
  } else {
      delay(20);
  }
}