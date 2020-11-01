import 'package:flutter/material.dart';
import 'dart:async';
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
  bool isEnabled = false;         // Is BLE enabled?
  bool forceScanBusy = false;     // Is the forceScan button busy?

  Scanner scanner = Scanner();    // Scanner instance.
  List<BLEDevice> scanData = List<BLEDevice>(); // Current list of BLE Devices.
  StreamSubscription<List<BLEDevice>> scanSub;

  /// Initializer.
  @override
  void initState() {
    super.initState();
    initScanSub();      // Initialize subscription.
  }

  // Handles the 'Enable BLE' slider.
  void enableBLE(bool state) async {
    setState(() {
      isEnabled = state;
    });

    if(this.isEnabled) {
      await scanner.enable();
    } else {
      await scanner.disable();
    }
  }

  /// Handle forceScan button.
  void forceScan() async {
    setState(() {
      forceScanBusy = true;
    });

    await scanner.startScan();

    setState(() {
      forceScanBusy = false;
    });
  }

  // Handles the 'Settings' button.
  void openBLESettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BLESettingsScreen()),
    );

    await scanner.refresh();
  }

  /// Initialize scanner subscription.
  void initScanSub() {
    scanSub = scanner.getStream().listen((data) {
      setState(() {
        this.scanData = data;
      });
//TODO: Remove
      //      print("StreamDataReceived: " + data.length.toString());

    }, onDone: () {
      print("Stream FINISHED.");
    }, onError: (error) {
      print("Stream ERROR.");
    });
  }


  /// Colors for scanData.
  Color statusColor(int position) {
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
    if((scanData.length ?? 0) <= 0) {
      return Expanded(
        child: Center(
          child: Text('No data.'),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        itemCount: scanData.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(scanData[index].addr),
            leading: CircleAvatar(
              backgroundColor: statusColor(scanData[index].rssi),
              child: Text(scanData[index].rssi.toString()),
            ),
          );
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('HamTrack BLE'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: Center(
          child: Column(
            children: <Widget>[

              // Enable Switch.
              ListTile(
                leading: Switch(
                  value: isEnabled,
                  onChanged: enableBLE,
                ),
                title: Text('Enable BLE'),
              ),

              // Settings.
              Container(
                child: !isEnabled ? null : Column(
                  children: <Widget>[
                    ListTile(
                      title: RaisedButton(
                        onPressed: forceScanBusy ? null : forceScan,
                        child: Text('Force Update'),
                      ),
                    ),
                    ListTile(
                      title: Text('BLE Settings'),
                      trailing: Icon(Icons.keyboard_arrow_right),
                      onTap: openBLESettings,
                    ),
                  ],
                ),
              ),

              // Status Window
              Container(
                child: !isEnabled ? null : statusWidget(),
              ),

            ],
          ),
        ),
      )
    );
  } // build

}