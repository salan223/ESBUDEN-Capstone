import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BleService {
  Future<void> ensurePermissions() async {
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.locationWhenInUse.request();
  }

  Stream<BluetoothAdapterState> adapterState() => FlutterBluePlus.adapterState;

  Future<bool> isSupported() => FlutterBluePlus.isSupported;

  Future<void> turnOn() async {
    await FlutterBluePlus.turnOn();
  }

  Future<void> startScan({Duration timeout = const Duration(seconds: 6)}) async {
    await FlutterBluePlus.startScan(timeout: timeout);
  }

  Future<void> stopScan() => FlutterBluePlus.stopScan();

  Stream<List<ScanResult>> scanResults() => FlutterBluePlus.scanResults;
}
