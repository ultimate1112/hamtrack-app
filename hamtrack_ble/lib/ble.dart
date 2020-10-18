import 'package:flutter/material.dart';
import 'dart:async';

//import 'package:flutter_beacon/flutter_beacon.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'ble_settings.dart';
import 'scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';


class BLEModel {
  bool isEnabled;
  bool forceBusy;

  BLEModel({this.isEnabled=false, this.forceBusy:false});
}


class BLEScreen extends StatefulWidget {
  BLEScreen({Key key}) : super(key: key);

  @override
  _BLEScreenState createState() => _BLEScreenState();
}

class _BLEScreenState extends State<BLEScreen> {
  BLEModel model = BLEModel();   // Model of View.
  List<BLEDevice> scanData = List<BLEDevice>();
  Scanner scanner = Scanner();
  StreamSubscription<List<BLEDevice>> subscription;


  @override
  void initState() {
    super.initState();
    pullScanner();  // Initialize subscription.
  }

  @override
  void dispose() {
    subscription.cancel();
    super.dispose();
  }

  // Handles the 'Enable BLE' slider.
  void enableBLE(bool state) async {
    setState(() {
      model.isEnabled = state;
    });

    if(model.isEnabled) {
      await scanner.start();
    } else {
      await scanner.stop();
    }
  }

  void forceScan() async {
    setState(() {
      model.forceBusy = true;
    });

    await scanner.scan();

    setState(() {
      model.forceBusy = false;
    });
  }

  // Handles the 'Settings' button.
  void openBLESettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BLESettingsScreen()),
    );

    await scanner.refresh();  // If parameters changed, update scanner.
  }

  void pullScanner() {
    subscription = scanner.getStream().listen((data) {
      setState(() {
        this.scanData = data;
      });
      print("StreamDataReceived: " + data.length.toString());

    }, onDone: () {
      print("Stream FINISHED.");
    }, onError: (error) {
      print("Stream ERROR.");
    });
  }

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
                  value: model.isEnabled,
                  onChanged: enableBLE,
                ),
                title: Text('Enable BLE'),
              ),

              // Settings.
              Container(
                child: !model.isEnabled ? null : Column(
                  children: <Widget>[
                    ListTile(
                      title: RaisedButton(
                        onPressed: model.forceBusy ? null : forceScan,
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
                child: !model.isEnabled ? null : statusWidget(),
              ),

            ],
          ),
        ),
      )
    );
  } // build

}

