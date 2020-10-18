import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'ble_settings.dart';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
//import 'package:flutter_beacon/flutter_beacon.dart';
import 'package:flutter_blue/flutter_blue.dart';

class BLEDevice {
  String addr;
  int rssi;

  BLEDevice({this.addr="", this.rssi=0});
}

class Scanner {
  BLESettingsModel model = BLESettingsModel();
  List<BLEDevice> scanData = List<BLEDevice>();
  Timer autoScanTimer;
  StreamController<List<BLEDevice>> controller = StreamController<List<BLEDevice>>();

  // Constructor.
  Scanner() {
    // Initialize List with 10 entries.
    for(int i = 0; i < 10; i++) {
      scanData.add(BLEDevice());
    }
  }

  getStream() {
    return controller.stream;
  }

  // Start AutoSend.
  Future<void> start() async {

    await model.loadModel();
    autoScanTimer = Timer.periodic(Duration(seconds: model.autoSendDuration), _startAutoSend);
  }

  // Stop AutoSend.
  Future<void> stop() async {
    autoScanTimer.cancel();
  }

  Future<void> refresh() async {
    await _startAutoSend(autoScanTimer);
  }

  // Run checks on parameters before starting scan.
  Future<void> _startAutoSend(Timer t) async {
    // Check if parameters have changed.
    if(!await model.verifyModel()) {
      t.cancel();
      start();
      return;
    }

    if(!model.autoSend) {
      t.cancel();
      return;
    }
    await scan();
  }

  // Execute a single scan.
  Future<void> scan() async {
    // Check preferences.'
    await queryBLE();

    /*
    var random = new Random();
    scanData[0] = new BLEDevice(addr: "MM:MM:MM:SS:SS:SS", rssi: -random.nextInt(100));
    scanData[1] = new BLEDevice(addr: "22:22:22:22:22:22", rssi: -random.nextInt(100));
    scanData[2] = new BLEDevice(addr: "33:33:33:33:33:33", rssi: -random.nextInt(100));
    scanData[3] = new BLEDevice(addr: "44:44:44:44:44:44", rssi: -random.nextInt(100));
    scanData[4] = new BLEDevice(addr: "55:55:55:55:55:55", rssi: -random.nextInt(100));
    scanData[5] = new BLEDevice(addr: "66:66:66:66:66:66", rssi: -random.nextInt(100));
    scanData[6] = new BLEDevice(addr: "12:34:56:78:AB:CD", rssi: -random.nextInt(100));
    scanData[7] = new BLEDevice(addr: "77:77:77:77:77:77", rssi: -random.nextInt(100));
    scanData[8] = new BLEDevice(addr: "88:88:88:88:88:88", rssi: -random.nextInt(100));
    scanData[9] = new BLEDevice(addr: "99:99:99:99:99:99", rssi: -random.nextInt(100));
    */
    //scanData.sort((a, b) => a.rssi.compareTo(b.rssi));
    //controller.add(scanData);

    return;
  }


  /// Perform a BLE query.
  Future<int> queryBLE() async {
    int status = -1; // Return Status
    int response = 0;
    print("Query BLE...");

    // Configure payload
    //Map<int, Beacon> beaconData = await scanBeacons();
    //String payload = constructPayload(beaconData);

    FlutterBlue flutterBlue = FlutterBlue.instance;

    // Start scanning
    print('Start scan!');

    // Listen to scan results
    scanData = List<BLEDevice>();

    flutterBlue.startScan(timeout: Duration(seconds: 2));
    flutterBlue.scanResults.listen((results) {
      // do something with scan results
      for (ScanResult r in results) {
        //r.advertisementData.manufacturerData[0x004C];
        print('${r.device.name} found! rssi: ${r.rssi}');
        scanData.add(BLEDevice(addr: "${r.device.id.toString()}", rssi: r.rssi));
        //TODO: Figure out blocking here...
      }
    });
    // Stop scanning
    //flutterBlue.stopScan();

    print('Finished scan!');
    // Send data to screen.
    scanData.sort((a, b) => a.rssi.compareTo(b.rssi));
    controller.add(scanData);


    //TODO: Fix BLE Code here...

    //beaconData.forEach((k,v) => scanData.add(BLEDevice(addr: "${v.major}+${v.minor}", rssi: v.rssi)));







    // Send the position to the server.
    String payload = "ABC";
    response = await sendBLEDatapoint(model.url, model.devId, payload);

    // Check response.
    if(response != 0) {
      print("BLE: Failed to send.");
      status = response; // Return http statusCode.

    } else {
      print("BLE: Successfully sent packet.");
      status = 0;
    }

    return status;
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