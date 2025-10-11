ble 有兩個id一定要有

1.SERVICE\_UUID                       4faf59a6-976e-67a2-c044-869900000000

2.CHARACTERISTIC\_UUID     a0329f59-700a-ae2e-5a3d-030610000000   範例



BLEDevice::init("MyESP32"); =>幫藍芽初始並命名



BLEServer \*pServer = BLEDevice::createServer();  =>建立伺服器



BLEService \*pService = pServer->createService(SERVICE\_UUID);



&nbsp;   //  建立特徵值 (設定為可讀和可寫)

&nbsp; BLECharacteristic \*pCharacteristic = pService->createCharacteristic(

&nbsp;                                         CHARACTERISTIC\_UUID,

&nbsp;                                         BLECharacteristic::PROPERTY\_READ |

&nbsp;                                         BLECharacteristic::PROPERTY\_WRITE

&nbsp;                                       );



//  啟動服務

&nbsp;   pService->start();

//強制廣播服務 UUID

&nbsp;         pAdvertising->addServiceUUID(SERVICE\_UUID); 

&nbsp;   



藍芽重點回乎模式



1\.處理寫入讀出訊號



&nbsp;                     // 步驟 1: 取得 Arduino String (這是 getValue() 的回傳類型)

&nbsp;       String arduinoValue = pCharacteristic->getValue(); 

&nbsp;       

&nbsp;       // 步驟 2: 將 Arduino String 轉換為 C-Style 字串 (const char\*)

&nbsp;       const char\* c\_str = arduinoValue.c\_str();



&nbsp;       // 步驟 3: 使用 C-Style 字串來建構 std::string

&nbsp;       std::string value(c\_str);



使用std::string好處就是不會記憶體破碎崩潰



2\.處理連線及斷線   詳細看程式碼







------------------------------------------------------------------------------------------------------------------------------

簡單來說，SUUID 和 CUUID 就像是一個藍牙設備中資料的地址，讓您的手機 App 知道要去哪裡讀取或寫入資料。



我用一個生活化的比喻來解釋，您會更容易理解。



🏢 比喻：一棟資料大樓

想像您的 ESP32 就像一棟功能大樓，裡面有不同的部門，每個部門都有特定的窗口可以辦理業務。



ESP32 設備 = 整棟資料大樓



SUUID (Service UUID) = 部門門牌號碼 (例如，「心率監測部」、「電池管理部」)



CUUID (Characteristic UUID) = 業務窗口號碼 (例如，「讀取心率」、「寫入指令」、「讀取電量」)



特徵值 (Value) = 窗口實際處理的資料 (例如，心率是 "80 bpm"，指令是 "1"，電量是 "95%")



📜 詳細解釋

1\. SUUID (Service UUID - 服務通用唯一辨識碼)



用意：功能的集合與分類 

SUUID 用來定義一個「服務 (Service)」。服務是一組相關「特徵 (Characteristics)」的集合，代表了設備的一項主要功能。





就像是部門門牌：

您的手機 App 連上 ESP32 後，第一件事就是看這棟大樓有哪些「部門」(Services)。它會根據 SUUID 來識別。例如，一個藍牙溫度計可能有「環境感測服務」和「設備資訊服務」。



在您的程式碼中：

您的 SERVICE\_UUID "4faf...0000"  就定義了一個您自創的「繼電器控制服務」。手機 App 會先找到這個服務，才能進行下一步操作。





2\. CUUID (Characteristic UUID - 特徵通用唯一辨識碼)



用意：實際的資料讀寫點 

CUUID 用來定義一個「特徵 (Characteristic)」。特徵是最小的資料單元，也是您手機 App 最終進行讀取 (Read)、寫入 (Write) 或 訂閱通知 (Notify) 的地方。





就像是業務窗口：

找到「繼電器控制服務」這個部門後，App 需要知道該去哪個「窗口」下指令。CUUID 就是這個窗口的號碼。一個服務底下可以有多個不同的特徵（窗口）。



在您的程式碼中：

您的 CHARACTERISTIC\_UUID "a032...0000" 定義了一個「指令寫入特徵」。您的 App 將字元 '1' 或 '2' 寫入到這個特徵，ESP32 接收到後就會去觸發對應的繼電器 。





🔄 整個運作流程

手機 App 掃描：App 尋找正在廣播特定 SUUID（繼電器控制服務）的 BLE 設備。





連線與尋找服務：連上 ESP32 後，App 在設備中尋找 SUUID 為 4faf...0000 的服務 。









尋找特徵：成功找到服務後，App 在該服務底下尋找 CUUID 為 a032...0000 的特徵 。







寫入資料：當您按下按鈕，App 將指令（例如 '1'）寫入到這個特徵 。





ESP32 觸發動作：ESP32 的 onWrite 回呼函式被觸發，程式碼根據收到的值 '1' 去執行對應的 relayAction 函式 。



所以，SUUID 和 CUUID 共同構成了一套清晰的、有層次的地址系統，確保您的 App 能夠準確無誤地找到並操作 ESP32 上的特定功能。







