/// BLE Functionality for Activity Tracker App.
/// Provides all the necessary functions for scanning BLE Beacons,
///   processing and sending to hamTrack DPS.

// Libraries.
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_beacon/flutter_beacon.dart';

/// BLEClass.
/// Contains all the necessary methods for processing BLE.
class BLEClass {

  String _deviceCode = "";                // Unique ID for device.
  Stream<RangingResult> _beaconStream;

  /// Constructor.
  BLEClass(String deviceCode) {

    // Retrieve ID.
    _deviceCode = deviceCode;

    // Check BLE permissions.
    checkPermission();
  }

  void checkPermission() async {

    // Check BLE Permissions.
    await flutterBeacon.initializeAndCheckScanning;
  }


  /// Perform a BLE query.
  Future<int> queryBLE() async {
    int status = -1; // Return Status
    int response = 0;

    print("Query BLE...");

    // Configure payload
    Map<int, Beacon> beaconData = await scanBeacons();
    String payload = constructPayload(beaconData);

    //beaconData.forEach((k,v) => print('${k}: ${v.major}+${v.minor} = ${v.rssi}'));

    // Send the position to the server.
    response = await sendBLEDatapoint(this._deviceCode, payload);

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

    } /* END: await for */

    print("BLE: Scan Finished");

    return beaconData;
  } /* END: scanBeacons */


  /// Send a BLE datapoint (string) to the server,
  ///   then returns a http.Response as a Future.
  Future<int> sendBLEDatapoint(String deviceCode, String payload
      ) async {
    int status = 0;

    // Construct POST packet.
    var url = 'https://en7iiixtu15y3.x.pipedream.net';
    var data = {
      'tracker': deviceCode,
      'payload': payload,
    };


    String geturl = 'http://dps.hamtrack.xyz/add_ble_dp.php?tracker=${deviceCode}&payload=${payload}';
    print(geturl);

    // Send GET packet.
    http.Response response = await http.get(geturl);

    // Send POST packet.
    // http.Response response = await http.post(url, body: data);

    // Check if request was successful.
    if(response.statusCode != 200) {
      status = response.statusCode;
    } else {
      status = 0;
    }

    return status;
  } /* END: sendBLEDatapoint */

} /* END:class BLEClass */
