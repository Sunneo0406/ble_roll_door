#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <string>

#define SERVICE_UUID        "4faf59a6-976e-67a2-c044-869700000000" 
#define CHARACTERISTIC_UUID "a0329f59-700a-ae2e-5a3d-030600000000" 

#define relayPin1 12
#define relayPin2 14
//#define relayPin3 27
#define relayCount 2

byte arryRelay[relayCount]={relayPin1,relayPin2};

void relayAction(int pin){
                    digitalWrite(pin, HIGH);
                    delay(100);
                    digitalWrite(pin, LOW);
                    delay(300);
                    digitalWrite(pin, HIGH);
                    delay(100);
                    digitalWrite(pin, LOW);
}

// 處理客戶端連線/斷線事件的回呼函式 (Callback)
class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
        // 讀取從手機寫入的資料
        // 步驟 1: 取得 Arduino String (這是 getValue() 的回傳類型)
        String arduinoValue = pCharacteristic->getValue(); 
        
        // 步驟 2: 將 Arduino String 轉換為 C-Style 字串 (const char*)
        const char* c_str = arduinoValue.c_str();

        // 步驟 3: 使用 C-Style 字串來建構 std::string
        std::string value(c_str);
        
        if (value.length() > 0) {
            // 假設您只傳送單一個字元，取第一個字元進行判斷
            char incomingChar = value[0]; 
            Serial.print("BLE 接收到指令: ");
            Serial.println(incomingChar);

            // 使用 switch 語句來判斷字元
            switch (incomingChar) {
                case '1':
                    Serial.println("執行動作 1:開啟 鐵門");
                    relayAction(relayPin1);
                    break;

                case '2':
                    Serial.println("執行動作 2:關閉 鐵門");
                    relayAction(relayPin2);
                    break;

                /*case '3':
                    Serial.println("執行動作 3:停止 動作");
                    digitalWrite(relayPin3, HIGH);
                    delay(3000);
                    digitalWrite(relayPin3, LOW);
                    break;*/

                default:
                    Serial.println("未知的 BLE 指令"+incomingChar);
                    break;
            }
        }
    }
};

// **新增：處理伺服器連線/斷線事件的回呼函式**
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      Serial.println("客戶端已連線");
    }

    void onDisconnect(BLEServer* pServer) {
      Serial.println("客戶端已斷線，重新開始廣播...");
      // **關鍵：重新啟動廣播，讓手機可以再次掃描到**
      pServer->getAdvertising()->start();
    }
};

void relaySet(int count){
  for(int x = 0 ; x < count ; x++){
    //Serial.println(arryRelay[x]);
    pinMode(arryRelay[x],OUTPUT);
    digitalWrite(arryRelay[x], LOW);
    Serial.print(x+1);
    Serial.println("號繼電器已初始化...");
  }
  
}

void setup() {
  Serial.begin(115200);
  relaySet(relayCount);
  Serial.println("初始化中.....");

  BLEDevice::init("MyESP32");

    // 2. 建立 BLE 伺服器
    BLEServer *pServer = BLEDevice::createServer();

    pServer->setCallbacks(new MyServerCallbacks());
    
    // 3. 建立服務
    BLEService *pService = pServer->createService(SERVICE_UUID);

    // 4. 建立特徵值 (設定為可讀和可寫)
    BLECharacteristic *pCharacteristic = pService->createCharacteristic(
                                          CHARACTERISTIC_UUID,
                                          BLECharacteristic::PROPERTY_READ |
                                          BLECharacteristic::PROPERTY_WRITE
                                        );

    // 5. 設定回呼函數
    pCharacteristic->setCallbacks(new MyCallbacks());

    // 6. 啟動服務
    pService->start();

    // 7. 啟動廣播 (讓手機可以發現)
    BLEAdvertising *pAdvertising = pServer->getAdvertising();
    // *** 關鍵修正：強制廣播服務 UUID ***
    pAdvertising->addServiceUUID(SERVICE_UUID); 
    pAdvertising->start();
    Serial.println("等待手機連線並寫入 BLE 特徵值...");
}

void loop() {
  // put your main code here, to run repeatedly:

}