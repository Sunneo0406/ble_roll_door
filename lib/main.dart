import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:convert';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';

// 定義您的 ESP32 BLE UUIDs
// 請確保這些 UUID 與您的 ESP32 程式碼 (sketch_oct11a.ino) 中的定義一致
const String SERVICE_UUID = "4faf59a6-976e-67a2-c044-869700000000";
const String CHARACTERISTIC_UUID = "a0329f59-700a-ae2e-5a3d-030600000000";
const String DEVICE_NAME = "MyESP32"; // 您的 ESP32 廣播名稱

void main() {
  // 確保 Flutter Widgets 初始化
  WidgetsFlutterBinding.ensureInitialized();
  // 調整日誌級別以更好地調試
  FlutterBluePlus.setLogLevel(LogLevel.info, color: true);
  runApp(const GateControllerApp());
}

class GateControllerApp extends StatelessWidget {
  const GateControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '造粒廠鐵門控制器',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Inter',
      ),
      home: const BleControlScreen(),
    );
  }
}

class BleControlScreen extends StatefulWidget {
  const BleControlScreen({super.key});

  @override
  State<BleControlScreen> createState() => _BleControlScreenState();
}

class _BleControlScreenState extends State<BleControlScreen> {
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _controlCharacteristic;
  bool _isScanning = false;
  String _connectionStatus = '未連線';
  // 用來儲存連線狀態的訂閱
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  
  // 儲存實際連線到的裝置名稱
  String _actualDeviceName = DEVICE_NAME; 

  @override
  void initState() {
    super.initState();
    // 監聽藍牙狀態 (如：藍牙是否開啟)
    FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
      if (mounted) {
        if (state == BluetoothAdapterState.off) {
          // 如果手機藍牙關閉，則重置狀態
          _disconnect(isIntentional: false);
          setState(() {
            _connectionStatus = '請開啟手機藍牙';
          });
        } else if (state == BluetoothAdapterState.on) {
          setState(() {
            _connectionStatus = '藍牙已開啟，準備掃描';
          });
        }
      }
    });
  }
  
  @override
  void dispose() {
    // 確保在 Widget 被銷毀時取消訂閱
    _connectionSubscription?.cancel();
    _scanSubscription?.cancel();
    super.dispose();
  }
  
  void _showSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  // 掃描並連線到 ESP32 (使用 withNames 策略，模擬 main1 的成功邏輯)
  void _scanAndConnect() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _connectionStatus = '正在請求權限...';
    });

    try {
      // 請求藍牙權限
      if (await Permission.bluetoothScan.request().isDenied ||
          await Permission.bluetoothConnect.request().isDenied ||
          await Permission.location.request().isDenied 
          ) {
        _showSnackbar('藍牙/定位權限被拒絕，無法繼續。');
        setState(() => _connectionStatus = '連線失敗：缺少權限');
        return;
      }
      
      // 檢查藍牙是否開啟
      if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
        _showSnackbar('藍牙未開啟，請手動開啟。');
        setState(() => _connectionStatus = '連線失敗：藍牙未開啟');
        return;
      }

      // 停止任何先前的掃描
      await FlutterBluePlus.stopScan();

      setState(() {
        _connectionStatus = '正在掃描裝置：$DEVICE_NAME...';
      });

      BluetoothDevice? targetDevice;
      Completer<void> scanComplete = Completer<void>();
      
      // 1. 執行帶有名稱過濾的掃描 (與 main1.dart 相同，適用於廣播名稱的裝置)
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        withNames: [DEVICE_NAME], // 只找特定名稱的裝置
      );
      
      // 2. 監聽掃描結果串流
      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          // 由於我們已經使用 withNames 過濾，這裡只需找到第一個符合的裝置
          if (result.device.platformName == DEVICE_NAME) {
            targetDevice = result.device;
            
            setState(() {
              _actualDeviceName = DEVICE_NAME;
            });

            FlutterBluePlus.stopScan(); 
            if (!scanComplete.isCompleted) {
              scanComplete.complete(); 
            }
            break; 
          }
        }
      });
      
      // 3. 等待掃描結束 (10 秒超時) 或找到裝置
      await Future.any([
        FlutterBluePlus.isScanning.where((isScanning) => isScanning == false).first,
        scanComplete.future
      ]);
      _scanSubscription?.cancel(); // 停止監聽


      if (targetDevice != null) {
        setState(() {
          _connectionStatus = '找到裝置：$_actualDeviceName，嘗試連線...';
        });

        // 連線到裝置
        await targetDevice!.connect();
        _connectedDevice = targetDevice;
        
        // **整合自 main1.dart：監聽連線狀態以處理意外斷線**
        _connectionSubscription?.cancel(); // 先取消舊的訂閱
        _connectionSubscription = _connectedDevice!.connectionState.listen((state) {
            if (state == BluetoothConnectionState.disconnected) {
                // 如果是意外斷線，則通知用戶
                _disconnect(isIntentional: false);
            }
        });


        // 發現服務
        List<BluetoothService> services = await targetDevice!.discoverServices();
        
        // 找到控制用的 Characteristic
        BluetoothCharacteristic? discoveredCharacteristic;
        for (var service in services) {
          if (service.uuid.toString().toUpperCase() == SERVICE_UUID.toUpperCase()) {
            for (var characteristic in service.characteristics) {
              if (characteristic.uuid.toString().toUpperCase() == CHARACTERISTIC_UUID.toUpperCase()) {
                discoveredCharacteristic = characteristic;
                break;
              }
            }
          }
        }
        _controlCharacteristic = discoveredCharacteristic;

        if (_controlCharacteristic != null) {
          setState(() {
            _connectionStatus = '連線成功！裝置：$_actualDeviceName';
          });
        } else {
          _disconnect(isIntentional: true); // 服務/特徵找不到，視為手動斷線
          setState(() {
            _connectionStatus = '錯誤：找不到控制特徵值 (${CHARACTERISTIC_UUID.substring(0, 4)}...)';
          });
        }
      } else {
        setState(() {
          _connectionStatus = '掃描完成，未找到裝置名稱為 "$DEVICE_NAME" 的裝置。';
        });
      }
    } catch (e) {
      // 如果不是權限錯誤，則顯示詳細錯誤
      if (!_connectionStatus.contains('缺少權限')) {
        setState(() {
          _connectionStatus = '連線/掃描失敗: ${e.toString()}';
        });
      }
      _connectedDevice = null;
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  // 中斷連線 (新增參數：isIntentional - 是否為用戶主動點擊斷線)
  void _disconnect({bool isIntentional = true}) async {
    // 先取消連線狀態的監聽
    _connectionSubscription?.cancel();
    _connectionSubscription = null;

    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
      } catch (e) {
        // 即使斷線失敗，仍強制更新 UI 狀態
      }
    }
    
    // 根據是否為意外斷線來設定狀態訊息
    String statusMessage = isIntentional ? '已成功中斷連線' : '裝置斷線！請重新連線。';
    
    setState(() {
      _connectedDevice = null;
      _controlCharacteristic = null;
      _connectionStatus = statusMessage;
      _actualDeviceName = DEVICE_NAME;
    });
    
    if (!isIntentional) {
      _showSnackbar('裝置斷線！請重新連線。');
    }
  }

  // 發送 BLE 指令 (字元 '1' 或 '2')
  void _sendCommand(String command) async {
    if (_controlCharacteristic == null || _connectedDevice == null) {
      setState(() {
        _connectionStatus = '請先連線到裝置！';
      });
      _disconnect(isIntentional: true); // 沒有特徵值或裝置，執行中斷連線流程
      return;
    }

    try {
      // 將字元 (例如 '1' 或 '2') 轉換為 UTF-8 bytes
      List<int> bytes = utf8.encode(command);
      // **關鍵：使用 write 進行發送**
      await _controlCharacteristic!.write(bytes, withoutResponse: false);
      
      String action = command == '1' ? '上 (開)' : '下 (關)';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已發送指令：$action ($command)'),
          duration: const Duration(milliseconds: 800),
        ),
      );

    } catch (e) {
      setState(() {
        _connectionStatus = '發送指令失敗: ${e.toString()}';
      });
      // 發送失敗通常代表連線已斷開，執行斷線流程
      _disconnect(isIntentional: false);
    }
  }

  // 門控制按鈕的通用樣式
  Widget _buildControlButtons() {
    bool isConnected = _connectedDevice != null;
    return Column(
      children: [
        const Text(
          '鐵門控制',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        // 上 (開) 按鈕 - 發送 '1'
        _buildActionButton(
          text: '上 (開啟)',
          command: '1',
          color: Colors.green.shade700,
          icon: Icons.arrow_upward_rounded,
          enabled: isConnected,
        ),
        const SizedBox(height: 32),
        // 下 (關) 按鈕 - 發送 '2'
        _buildActionButton(
          text: '下 (關閉)',
          command: '2',
          color: Colors.red.shade700,
          icon: Icons.arrow_downward_rounded,
          enabled: isConnected,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String text,
    required String command,
    required Color color,
    required IconData icon,
    required bool enabled,
  }) {
    return ElevatedButton.icon(
      onPressed: enabled ? () => _sendCommand(command) : null,
      icon: Icon(icon, size: 36),
      label: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 10),
        child: Text(
          text,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: enabled ? color : Colors.grey.shade400, // 變更禁用時的顏色
        minimumSize: const Size(280, 80),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: enabled ? 10 : 0,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    bool isConnected = _connectedDevice != null;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('造粒廠鐵門控制器'),
        elevation: 4,
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // 顯示連線狀態
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isConnected ? Colors.green.shade100 : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isConnected ? Colors.green.shade400 : Colors.red.shade400,
                  ),
                ),
                child: Text(
                  '狀態: $_connectionStatus',
                  style: TextStyle(
                    fontSize: 16,
                    color: isConnected ? Colors.green.shade900 : Colors.red.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              
              // 掃描與連線/中斷連線按鈕
              if (!isConnected)
                ElevatedButton.icon(
                  onPressed: _isScanning ? null : _scanAndConnect,
                  icon: _isScanning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Icon(Icons.bluetooth_searching),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Text(
                      _isScanning ? '掃描中...' : '掃描並連線 $DEVICE_NAME',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.blue.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 8,
                  ),
                )
              else
                // 中斷連線按鈕
                ElevatedButton.icon(
                  onPressed: () => _disconnect(isIntentional: true), // 主動中斷連線
                  icon: const Icon(Icons.bluetooth_disabled),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Text('中斷連線', style: TextStyle(fontSize: 18)),
                  ),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.orange.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 8,
                  ),
                ),
              
              const SizedBox(height: 48),

              // 門控制區
              _buildControlButtons(),

              const SizedBox(height: 48),
              
              // 裝置資訊
              const Text(
                '裝置資訊',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                // 顯示實際連線到的裝置名稱
                'BLE 裝置名稱: $_actualDeviceName\n服務 UUID: ${SERVICE_UUID.substring(0, 8)}...\n特徵 UUID: ${CHARACTERISTIC_UUID.substring(0, 8)}...',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}