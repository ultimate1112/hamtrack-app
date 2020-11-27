import 'package:flutter/material.dart';
import 'dart:async';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock/wakelock.dart';
import 'ble_settings.dart';
import 'scanner.dart';


/// Screen for BLE Functionality.
class BLEScreen extends StatefulWidget {
  BLEScreen({Key key}) : super(key: key);

  @override
  _BLEScreenState createState() => _BLEScreenState();
}

/// Screen State for BLE Functionality.
class _BLEScreenState extends State<BLEScreen> {
  bool _isEnabled = false;         // Is BLE enabled?
  bool _forceScanBusy = false;     // Is the forceScan button busy?

  // List of BLEDevices.
  Scanner _scanner = Scanner();         // Scanner instance.
  BLEData _scanData = BLEData();
  String _scanTime = "none";            // Last timestamp for BLEData.


  /// Initialize Widget State.
  @override
  void initState() {
    super.initState();
    _initScanSub();      // Initialize subscription.
  }

  // Handles the 'Enable BLE' slider.
  void _enableBLE(bool state) async {
    setState(() {
      _isEnabled = state;
    });

    // Enable / Disable Scanner instance.
    if(_isEnabled) {
      await _scanner.enable();
      Wakelock.enable();
    } else {
      await _scanner.disable();
      Wakelock.disable();
    }
  }

  /// Handle forceScan button.
  void _forceScan() async {
    setState(() {
      _forceScanBusy = true;
    });

    // Wait for Scanner instance to complete.
    await _scanner.startScan();

    setState(() {
      _forceScanBusy = false;
    });
  }

  // Handles the 'Settings' button.
  void _openBLESettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BLESettingsScreen()),
    );

    // Refresh Scanner with new model (stored in SharedPreferences).
    await _scanner.refresh();
  }

  /// Initialize scanner subscription.
  void _initScanSub() {
    _scanner.getStream().listen((data) {
      setState(() {
        _scanData = data;

        var time = DateTime.fromMillisecondsSinceEpoch(int.parse(data.timestamp) * 1000);
        _scanTime = time.toString();
        
      });
    }, onDone: () {
      Fluttertoast.showToast(
          msg: "Something bad has happened. Please Restart App.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0
      );
    }, onError: (error) {
      Fluttertoast.showToast(
          msg: "Something bad has happened. Please Restart App.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0
      );
    });
  }


  /// Colors for scanData.
  Color _statusColor(int position) {
    Color c;
    if (position < -80) {
      c = Colors.orange;
    } else if (position < -50) {
      c = Colors.yellow;
    } else if (position < -20) {
      c = Colors.green;
    } else {
      c = Colors.blue;
    }
    return c;
  }

  // Visualise the data via the status widget.
  Widget statusWidget() {
    if((_scanData.data.length ?? 0) > 0) {
      return Expanded(
        child: ListView.builder(
          itemCount: _scanData.data.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text("Major: " + _scanData.data[index].major.toString() + " "
                  + "Minor: " + _scanData.data[index].minor.toString()),
              leading: CircleAvatar(
                backgroundColor: _statusColor(_scanData.data[index].rssi),
                child: Text(_scanData.data[index].rssi.toString()),
              ),
              trailing: Text(_scanData.data[index].accuracy.toStringAsFixed(2) + "m"),
            );
          },
        ),
      );
    } else {
      return Expanded(
        child: Center(
          child: Text('No data.'),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('hamTrack BLE'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(8),
          child: Center(
            child: Column(
              children: <Widget>[

                // Enable Switch.
                ListTile(
                  leading: Switch(
                    value: _isEnabled,
                    onChanged: _enableBLE,
                  ),
                  title: Text('Enable BLE'),
                ),

                // Settings.
                Container(
                  child: !_isEnabled ? null : Column(
                    children: <Widget>[
                      ListTile(
                        title: RaisedButton(
                          onPressed: _forceScanBusy ? null : _forceScan,
                          child: Text('Force Update'),
                        ),
                      ),
                      ListTile(
                        title: Text('BLE Settings'),
                        trailing: Icon(Icons.keyboard_arrow_right),
                        onTap: _openBLESettings,
                      ),
                    ],
                  ),
                ),


                Container(
                  child: !_isEnabled ? null : Text("Last Scan: " + _scanTime),
                ),

                // Status Window
                Container(
                  child: !_isEnabled ? null : statusWidget(),
                ),

              ],
            ),
          ),
        )
    );
  } // build

}