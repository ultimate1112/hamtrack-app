import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

import 'package:flutter_beacon/flutter_beacon.dart';
import 'package:flutter/services.dart';

import 'ble_settings.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// Single BLE Device.
/// Assumed that BLE Device follows the iBeacon Specification.
class BLEDevice {
  int major;        // iBeacon Major Id.
  int minor;        // iBeacon Minor Id.
  int rssi;         // RSSI Strength.
  String macAddr;   // MAC Address of iBeacon.
  double accuracy;  // Accuracy in metres.
  int txPower;      // Transmission Power over 1m.

  BLEDevice(this.major, this.minor, this.rssi, {this.macAddr, this.accuracy, this.txPower});

  Map<String, dynamic> toJson() => {
    'major': this.major.toString(),
    'minor': this.minor.toString(),
    'rssi': this.rssi.toString(),
  };
}

/// Single Scan of BLE Devices.
class BLEData {
  String timestamp;
  List<BLEDevice> data;

  BLEData({timestamp, data}) {
    this.timestamp = timestamp ?? '';
    this.data = data ?? List<BLEDevice>();
  }

  //
  String getTimestamp() {
    return timestamp;
  }

  // Count.
  String getCount() {
    return data.length.toString();
  }

  // Payload.
  // Format List(Map), ie. [{'major':"",'minor':"",'rssi':""},{...},...]
  String getPayload() {
    List<Map> bleDevices = List<Map>();

    for(int i = 0; i < data.length; i++) {
      Map<String, String> d = {
        'major': data[i].major.toString(),
        'minor': data[i].minor.toString(),
        'rssi': data[i].rssi.toString(),
      };
      bleDevices.add(d);
    }

    return jsonEncode(bleDevices);
  }

  Map<String, dynamic> toJSON() {
    // Within 'data', convert BLEDevice objects to JSON objects.
    List<Map> dataJson = (this.data == null) ? null : this.data.map((e) => e.toJson()).toList();
    return {
      'timestamp': this.timestamp,
      'data': dataJson,
    };
  }
}

/// BLE Scanner class.
class Scanner {
  // Input Parameters.
  BLESettingsModel _model = BLESettingsModel();

  // Output Stream Controller.
  StreamController<BLEData> _controller = StreamController<BLEData>();

  bool _isEnabled = false;                // Enable / Disable AutoScan
  Timer _autoScanTimer = Timer(Duration(seconds:0), () => {});  // autoScan Periodic Timer.
  bool _scanLock = false;                 // Lock for scan.
  BLEData _scanData = BLEData();          // Data of scan.


  /// Get stream.
  Stream<BLEData> getStream() {
    return _controller.stream;
  }

  /// Check permissions before scanning.
  void checkBLEPermissions() async {
    try {
      await flutterBeacon.initializeScanning;
      await flutterBeacon.initializeAndCheckScanning;

    } on PlatformException catch(e) {
      // Library failed to initialize, check code and message
      Fluttertoast.showToast(
          msg: "Unable to initialize BLE library.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0
      );
    }
  }

  /// Enable autoScan.
  Future<void> enable() async {
    await checkBLEPermissions();
    _isEnabled = true;
    await refresh();
  }

  /// Disable autoScan.
  Future<void> disable() async {
    _isEnabled = false;
    await refresh();
  }

  /// Refresh with new parameters.
  Future<void> refresh() async {
    await _model.loadModel();         // Pre-emptively load model.

    _autoScanTimer.cancel();          // Kill current timer.
    await startScan(callback: true);  // Restart Scan.
  }

  /// Endpoint to start scan.
  /// If callback is true, will only run if model.autoScan is enabled.
  Future<void> startScan({callback=false}) async {

    if(!await _model.verifyModel()) {
      // Parameters have changed.
      // model.verifyModel will fix internal issues.
      await startScan(callback: callback);   // Recall process.
      return;
    }

    if(!_isEnabled) {
      // BLE is not enabled.
      _autoScanTimer.cancel();
      return;
    }

    if(callback && !_model.autoScan) {
      // AutoScan is not enabled. Skip if executed manually.
      _autoScanTimer.cancel();
      return;
    }

    if(_model.autoScan
        && (_autoScanTimer == null || !_autoScanTimer.isActive)) {
      // Timer is not active. Reactivate.
      _autoScanTimer = Timer.periodic(
          Duration(seconds: _model.autoScanDuration),
          (t) => {startScan(callback: true)});
      // Continue, and run immediately.
    }

    // Execute BLE scan.
    await _process();
  }


  /// Scan.
  Future<void> _process() async {

    // Execute Scan for BLE Devices..
    if(!await _queryBLE()) {
      // Failed to scan. Exit Scan.
      return;
    }

    if(_scanData.data.length <= 0) {
      return;
    }

    // Send Scan Data to Server.
    if(!await _queryServer()) {
      // Failed to send to server. Alert user.
      Fluttertoast.showToast(
          msg: "Failed to send to server.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0
      );
      return;
    }

    // Finished Scan.
    return;
  }

  /// Perform a BLE query.
  /// Also sends scan data onto scan stream.
  ///   Returns false if could not scan, true if successful.
  Future<bool> _queryBLE() async {
    if(_scanLock) {
      // Existing scan is already running. Skip.
      print('Existing Scan Process. Skip.');
      return false;   // Unable to scan.
    }
    _scanLock = true;   // Lock.

    // init variables.
    _scanData = BLEData();

    // Setup iBeacon Regions. Required for iOS.
    final regions = <Region>[];
    if (Platform.isIOS) {
      // Default iBeacon Regions.
      regions.add(Region(
          identifier: 'Radius Networks 2F234454',
          proximityUUID: '2F234454-CF6D-4A0F-ADF2-F4911BA9FFA6'));
      regions.add(Region(
          identifier: 'Apple AirLocate E2C56DB5',
          proximityUUID: 'E2C56DB5-DFFB-48D2-B060-D0F5A71096E0'));
      regions.add(Region(
          identifier: 'Apple AirLocate 5A4BCFCE',
          proximityUUID: '5A4BCFCE-174E-4BAC-A814-092E77F6B7E5'));
      regions.add(Region(
          identifier: 'Apple AirLocate 74278BDA',
          proximityUUID: '74278BDA-B644-4520-8f0C-720EAF059935'));
      regions.add(Region(
          identifier: 'Null iBeacon',
          proximityUUID: '00000000-0000-0000-0000-000000000000'));
      regions.add(Region(
          identifier: 'RedBear Labs AFFFFFF',
          proximityUUID: '5AFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF'));
      regions.add(Region(
          identifier: 'TwoCanoes 92AB49BE',
          proximityUUID: '92AB49BE-4127-42F4-B532-90FAF1E26491'));
      regions.add(Region(
          identifier: 'Estimote B9407F30',
          proximityUUID: 'B9407F30-F5F8-466E-AFF9-25556B57FE6D'));
      regions.add(Region(
          identifier: 'Radius Networks 52414449',
          proximityUUID: '52414449-5553-4E45-5457-4F524B53434F'));
      regions.add(Region(
          identifier: 'Kontakt',
          proximityUUID: 'F7826DA6-4FA2-4E98-8024-BC5B71E0893E'));
    } else {
      regions.add(Region(identifier: 'com.beacon'));  // Catch all iBeacons.
    }

    // Start BLE Scan.
    RangingResult res = await flutterBeacon.ranging(regions).first;

    _scanData.timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round().toString(); // Record timestamp.

    res.beacons.forEach((device) {
      _scanData.data.add(
          BLEDevice(device.major, device.minor, device.rssi,
              macAddr: device.macAddress, accuracy: device.accuracy, txPower: device.txPower)
      );
    });
    _scanData.data.sort((a, b) => b.rssi.compareTo(a.rssi));  // Sort by RSSI.

    // Send onto Stream
    _controller.add(_scanData);       // Send onto Stream.

    _scanLock = false;    // Unlock
    return true;      // Successfully scanned.
  } /* END: queryBLE */


  Future<bool> _queryServer() async {

    var data = {
      'tracker': _model.devId,
      'timestamp': _scanData.getTimestamp(),
      'count': _scanData.getCount(),
      'payload': _scanData.getPayload(),
    };

    // Send POST packet to server.
    //TODO: Catch Exception Properly.
    try {
      http.Response response = await http.post(_model.url, body: data);

      // Check if request was successful.
      if(response.statusCode != 200) {
        print("Error sending to server. [HTTP Code "+ response.statusCode.toString() +"]");
        return false;
      }
    } catch(e) {
      return false;
    }

    return true;
  }


}