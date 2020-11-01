import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

import 'package:flutter_blue/flutter_blue.dart';
import 'ble_settings.dart';
import 'package:fluttertoast/fluttertoast.dart';


/// Model of a BLE Device.
class BLEDevice {
  //TODO:Add major and minor.
  String addr;
  int rssi;
  int major;
  int minor;

  BLEDevice({this.addr="", this.rssi=0});
}

class BLEData {
  String timestamp;
  List<BLEDevice> data;
}

/// BLE Scanner class.
class Scanner {
  bool isEnabled = false;
  bool scanLock = false;

  BLESettingsModel model = BLESettingsModel();                                          // Input Parameters.
  Timer autoScanTimer = Timer(Duration(seconds:0), () => {});                           // autoScan Periodic Timer.
  List<ScanResult> rawData = List<ScanResult>();                                       // Raw BLE Scan Data.
  DateTime scanTime = DateTime.now();                                                   // Timestamp of scan.
  StreamController<BLEData> controller = StreamController<BLEData>();   // Output Stream Controller.
  BLEData scanData = BLEData();

Scanner() {

}

  /// Get stream.
  getStream() {
    return controller.stream;
  }

  // Enable autoScan.
  Future<void> enable() async {
    isEnabled = true;
    await refresh();
  }

  /// Disable autoScan.
  Future<void> disable() async {
    isEnabled = false;
    await refresh();
  }

  /// Refresh with new parameters.
  Future<void> refresh() async {
    await model.loadModel();  // Pre-emptively load model.
    autoScanTimer.cancel();
    await startScan(callback: true);
  }

  /// Endpoint to start scan.
  /// If callback is true, will only run if model.autoScan is enabled.
  Future<void> startScan({callback=false}) async {

    if(!await model.verifyModel()) {
      // Parameters have changed.
      // model.verifyModel will fix internal issues.
      await startScan(callback: callback);   // Recall process.
      return;
    }

    if(!isEnabled) {
      // BLE is not enabled.
      autoScanTimer.cancel();
      return;
    }

    if(callback && !model.autoScan) {
      // AutoScan is not enabled. Skip if executed manually.
      autoScanTimer.cancel();
      return;
    }

    if(model.autoScan && (autoScanTimer == null || !autoScanTimer.isActive)) {
      // Timer is not active. Reactivate.
      autoScanTimer = Timer.periodic(
          Duration(seconds: model.autoScanDuration),
          (t) => {startScan(callback: true)});
      // Continue, and run immediately.
    }

    // Execute BLE scan.
    await scan();
  }


  /// Scan.
  Future<void> scan() async {
    if(!await queryBLE()) {
      return;
    }
    processBLE();
    if(!await sendToServer()) {
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

  }

  /// Perform a BLE query.
  /// returns false if could not scan, true if successfully scanned.
  Future<bool> queryBLE() async {
    if(scanLock) {
      // Existing scan is already running. Skip.
      print('SKIPPPPPPPPPPPPPPPPPPPPPPPPP');
      return false;   // Unable to scan.
    }
    scanLock = true;  // Lock.

    // Initialize required variables.
    final FlutterBlue flutterBlue = FlutterBlue.instance;
    scanTime = new DateTime.now();

    // Start Scan. Will stop scan after timeout.
    Future scanResult = flutterBlue.startScan(
        scanMode: ScanMode.lowLatency,
        timeout: Duration(seconds: 2));

    // Collect Results.
    rawData = await scanResult;

    scanLock = false; // Unlock
    return true;      // Successfully scanned.
  } /* END: queryBLE */

  bool processBLE() {
    scanData = new BLEData();

    scanData.timestamp = scanTime.toString(); // Timestamp of Data.
    scanData.data = new List<BLEDevice>();    // BLE Data.
    BLEDevice dev;
    for(ScanResult r in rawData) {
      dev = new BLEDevice();
      dev.addr = r.device.id.toString();
      dev.rssi = r.rssi;
//TODO: Build data from here.

      scanData.data.add(dev);
    }
    scanData.data.sort((a, b) => a.rssi.compareTo(b.rssi)); // Sort by rssi.

    controller.add(scanData);
    return true;
  }

  Future<bool> sendToServer() async {

    // Process scanData into timestamp & string payload.
    //TODO: FIX jsonEncode(scanData.data);
    var data = {
      'tracker': model.devId,
      'timestamp': scanData.timestamp,
      'count': scanData.data.length.toString(),
      'payload': '',
    };

    // Send POST packet to server.
    http.Response response = await http.post(model.url, body: data);

    // Check if request was successful.
    if(response.statusCode != 200) {
      print("Error sending to server. [HTTP Code "+ response.statusCode.toString() +"]");
      return false;
    }

    return true;
  }






  /*
  String constructPayload(Map<int, Beacon> beaconData) {
    Map<String, int> payload = {};
    String payloadEncoded = "";
    String id = "";
    int rssi = 0;

    beaconData.forEach((k,v) {
      id = "${v.major},${v.minor}";
      rssi = v.rssi;
      payload.addAll({id: rssi});
    });

    payloadEncoded = jsonEncode(payload);

    return payloadEncoded;
  }

  /// Scan for BLE Beacons
  Future<Map<int, Beacon>> scanBeacons() async {
    Map<int, Beacon> beaconData = {};
    int beaconNumber = 0;

    // Just in case permissions aren't granted yet.
    await flutterBeacon.initializeAndCheckScanning;

    final regions = <Region>[];
    /*
    if (Platform.isIOS) {
      // iOS platform, at least set identifier and proximityUUID for region scanning
      regions.add(Region(
          identifier: 'Kontakt',
          proximityUUID: 'F7826DA6-4FA2-4E98-8024-BC5B71E0893E'));
    } else {
      // android platform, it can ranging out of beacon that filter all of Proximity UUID
      regions.add(Region(identifier: 'com.beacon'));
    }
    */
    regions.add(Region(identifier: 'com.beacon'));

    print("BLE: Start Scan");

    // Initialize scan as Ranging mode.
    _beaconStream = flutterBeacon.ranging(regions);

    // Timeout for scanning.
    bool timeout = false;
    Future<void> to = Future.delayed(const Duration(seconds: 5))
        .whenComplete(() {
      timeout = true;
    });

    // Scan and process beacons. Stream should run every 1 second.
    await for(RangingResult result in _beaconStream) {

      // Collect iBeacon data.
      if(result.beacons.isNotEmpty) {

        for(Beacon x in result.beacons) {

          // Beacon.hashCode is region + major + minor
          if(beaconData.containsKey(x.hashCode)) {
            // Data already exists, so update.
            beaconData.update(x.hashCode, (v) => x);
            beaconNumber++;
          } else {
            // Data doesn't exist, so add.
            beaconData.addAll({x.hashCode: x});
            print("${x.major},${x.minor}=${x.rssi}");
          }

        }

        // Check if we have too much data.
        if(beaconNumber >= 15) {
          break;
        }

      } /* END: if(result.beacons.isNotEmpty) */

      // Check if timeout.
      if(timeout == true) {
        break;
      }

    } // END: await for

    print("BLE: Scan Finished");

    return beaconData;
  } // scanBeacons
*/

  /// Send a BLE datapoint (string) to the server,
  ///   then returns a http.Response as a Future.
  Future<int> sendBLEDatapoint(String url, String deviceCode, String payload
      ) async {
    int status = 0;

    // Construct POST packet.
    var data = {
      'tracker': deviceCode,
      'payload': payload,
    };

    // Send POST packet.
    http.Response response = await http.post(url, body: data);

    // Check if request was successful.
    if(response.statusCode != 200) {
      status = response.statusCode;
    } else {
      status = 0;
    }

    return status;
  } /* END: sendBLEDatapoint */





}