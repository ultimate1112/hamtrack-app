import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
//import 'package:flutter_beacon/flutter_beacon.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'ble_settings.dart';

/// Model of a BLE Device.
class BLEDevice {
  //TODO:Add major and minor.
  String addr;
  int rssi;

  BLEDevice({this.addr="", this.rssi=0});
}

/// BLE Scanner class.
class Scanner {
  bool isEnabled = false;
  bool scanLock = false;

  BLESettingsModel model = BLESettingsModel();
  StreamController<List<BLEDevice>> controller = StreamController<List<BLEDevice>>();
  List<BLEDevice> scanData = List<BLEDevice>();
  Timer autoScanTimer = Timer(Duration(seconds:0), () => {});

  //TODO: Verify timer is actually cancelling.

  /// Constructor.
  Scanner() {
    // Initialize List with 10 entries.
    for(int i = 0; i < 10; i++) {
      scanData.add(BLEDevice());
    }
  }

  /// Get stream.
  getStream() {
    return controller.stream;
  }

  // Start autoSend.
  Future<void> enable() async {
    isEnabled = true;
    refresh();
  }

  Future<void> disable() async {
    isEnabled = false;
    refresh();
  }

  Future<void> refresh() async {
    await model.loadModel();  // Pre-emptively load model.
    startScan(callback: true);
  }

  /// Endpoint to start scan.
  /// If callback is true, will only run if model.autoScan is enabled.
  Future<void> startScan({callback=false}) async {

    if(!await model.verifyModel()) {
      // Parameters have changed.
      // model.verifyModel will fix internal issues.
      startScan(callback: callback);   // Recall process.
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

  /// Execute Scan.
  Future<void> scan() async {
    await queryBLE();   // Populate scanData.
    //await sendResults();  // Send to server.
  }


  /// Perform a BLE query.
  Future<bool> queryBLE() async {

    // If locked, wait until lock is released.
    // Timeout after 1 second.
    if(scanLock) {
      print("BLE Query is locked.");
      bool timeout = false;
      Timer(Duration(seconds: 1), () => {timeout = true});

      while(scanLock) {
        if(timeout) {
          print("BLE Query has timed out.");
          return false;
        }
      }
      print("BLE Query is released.");
    }

    // Lock.
    scanLock = true;

    final FlutterBlue flutterBlue = FlutterBlue.instance;
    scanData = List<BLEDevice>();   // New list for scanData.

    // Start Scan.
    print('Start Scan: ' + new DateTime.now().toString());
    Future scanResult = flutterBlue.startScan(
        scanMode: ScanMode.lowLatency,
        timeout: Duration(seconds: 2));

    // Collect Results.
    List<ScanResult> res = await scanResult;
    //TODO: Remove: flutterBlue.stopScan();

    // Parse
    for (ScanResult r in res) {
      //r.advertisementData.manufacturerData[0x004C];
      //print('${r.device.id.toString()} found! rssi: ${r.rssi}');
      scanData.add(BLEDevice(addr: "${r.device.id.toString()}", rssi: r.rssi));
    }

    // Send data to screen.
    scanData.sort((a, b) => a.rssi.compareTo(b.rssi));
    controller.add(scanData);

    // Unlock.
    scanLock = false;

    return true;
  } /* END: queryBLE */

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