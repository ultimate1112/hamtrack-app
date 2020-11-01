import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info/device_info.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// Class to modify / read parameters for app.
class BLESettingsModel {
  int checksum;         // to check if sharedPreferences is enabled.
  String devId;         // Unique Device Identifier.
  String url;           // URL to send requests to.
  bool autoScan;        // is autoScan enabled?
  int autoScanDuration; // Duration of autoScan (seconds).
  int temp;             // Temporary Value, multi-use.

  /// Constructor, with default options.
  BLESettingsModel({
    this.checksum=9,
    this.devId="",
    this.url="https://app.hamtrack.xyz",
    this.autoScan=false,
    this.autoScanDuration=5,
    this.temp=0,
  });

  /// Get Unique Device Identifier. Also saves result into parameters.
  /// Function is only compatible with Android and iOS.
  Future<String> getDeviceCode() async {
    final DeviceInfoPlugin deviceInfoPlugin = new DeviceInfoPlugin();
    if (Platform.isAndroid) {
      // Android - Android_ID.
      AndroidDeviceInfo androidDeviceInfo = await deviceInfoPlugin.androidInfo;
      this.devId = androidDeviceInfo.androidId;
    } else if (Platform.isIOS) {
      // iOS - developer-specific UUID.
      IosDeviceInfo iosDeviceInfo = await deviceInfoPlugin.iosInfo;
      this.devId = iosDeviceInfo.identifierForVendor;
    } else {
      // Invalid device.
      print('Cannot detect platform.');
      this.devId = "";
    }

    return this.devId;
  }

  /// Save parameters into storage.
  Future<void> saveModel() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('checksum', this.checksum);
    await prefs.setString('devId', this.devId);
    await prefs.setString('url', this.url);
    await prefs.setBool('autoScan', this.autoScan);
    await prefs.setInt('autoScanDuration', this.autoScanDuration);
    await prefs.setInt('temp', this.temp);
  }

  /// Load parameters from storage.
  /// If sharedPreferences isn't initialized, use defaults.
  Future<bool> loadModel() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if(!prefs.containsKey('checksum')
        || prefs.getInt('checksum') != this.checksum) {
      // Initialize Shared Preferences.
      print('Initialize Shared Preferences');
      await getDeviceCode();
      await saveModel();      // Save with current parameters.
      return false;
    } else {
      // Pull from Shared Preferences.
      this.checksum = prefs.getInt('checksum');
      this.devId = prefs.getString('devId');
      this.url = prefs.getString('url');
      this.autoScan = prefs.getBool('autoScan');
      this.autoScanDuration = prefs.getInt('autoScanDuration');
      this.temp = prefs.getInt('temp');
      return true;
    }
  }

  /// Verify parameters with sharedPreferences.
  Future<bool> verifyModel() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if(prefs.getInt('checksum') == this.checksum
        && prefs.getString('devId') == this.devId
        && prefs.getString('url') == this.url
        && prefs.getBool('autoScan') == this.autoScan
        && prefs.getInt('autoScanDuration') == this.autoScanDuration
        && prefs.getInt('temp') == this.temp
    ) {
      return true;
    }
    return false;
  }
}


/// Screen to edit BLE parameters.
class BLESettingsScreen extends StatefulWidget {
  BLESettingsScreen({Key key}) : super(key: key);

  @override
  _BLESettingsScreenState createState() => _BLESettingsScreenState();
}

/// Screen state to edit BLE parameters.
class _BLESettingsScreenState extends State<BLESettingsScreen> {
  BLESettingsModel model = BLESettingsModel();    // Data for Screen.
  Future<bool> isLoaded;    // Don't resolve until model is fetched.
  // For TextField.
  final GlobalKey<FormState> _formKey  = GlobalKey<FormState>();
  TextEditingController _controller = new TextEditingController();
  bool editAPI = false;     // State of URL.


  /// Load model on state initialization.
  void initState() {
    super.initState();
    isLoaded = model.loadModel();
  }

  /// Handle 'AutoSend Slider'.
  void enableAutoSend(bool state) {
    setState(() {
      model.autoScan = state;
    });
  }

  /// Handle 'AutoSend Dropdown'.
  void changeAutoSend(int value) {
    setState(() {
      model.autoScanDuration = value;
      model.autoScan = true;    // Turn on autoScan.
    });
  }

  /// Close settings.
  void closeSettings({bool save=false}) async {
    if(save) {
      await model.saveModel();
      if(await model.verifyModel()) {
        Fluttertoast.showToast(
            msg: "Saved preferences.",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.green,
            textColor: Colors.white,
            fontSize: 16.0
        );
      } else {
        Fluttertoast.showToast(
            msg: "Failed to save preferences.",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0
        );
      }
    }

    Navigator.pop(context);   // Exit screen.
  }

  @override
  Widget build(BuildContext context) {
    // On first build, load preferences and resolve isLoaded.
    return FutureBuilder<bool>(
      future: isLoaded,
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return configScreen();
        } else {
          return loadingScreen();
        }
      },
    );
  }

  /// Loading Screen Widget.
  /// Displays loading-spinner until isLoaded is resolved.
  Widget loadingScreen() {
    return Scaffold(
      appBar: AppBar(
        title: Text('BLE Settings'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              child: CircularProgressIndicator(),
              width: 60,
              height: 60,
            ),
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text('Loading...'),
            )
          ],
        ),
      ),
    );
  }

  /// Config screen.
  /// View and edit various app parameters.
  Widget configScreen() {
    return Scaffold(
      appBar: AppBar(
        title: Text('BLE Settings'),
      ),
      floatingActionButton:FloatingActionButton.extended(
        onPressed: () {
          closeSettings(save: true);
        },
        icon: Icon(Icons.save),
        label: Text("Save"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: Center(
          child: Column(
            children: <Widget>[

              ListTile(
                leading: Icon(Icons.person),
                title: Text(model.devId),
              ),

              ListTile(
                leading: Switch(
                  value: model.autoScan,
                  onChanged: enableAutoSend,
                ),
                title: DropdownButton(
                  isExpanded: true,
                  value: model.autoScanDuration,
                  items: [
                    DropdownMenuItem(
                      child: Text("2 seconds"),
                      value: 2,
                    ),
                    DropdownMenuItem(
                      child: Text("5 seconds"),
                      value: 5,
                    ),
                    DropdownMenuItem(
                      child: Text("10 seconds"),
                      value: 10,
                    ),
                    DropdownMenuItem(
                      child: Text("30 seconds"),
                      value: 30,
                    ),
                    DropdownMenuItem(
                      child: Text("60 seconds"),
                      value: 60,
                    ),
                  ],
                  onChanged: changeAutoSend,
                ),
              ),

              Form(
                key: _formKey,
                child: ListTile(
                    title: TextFormField(
                      enabled: editAPI,
                      decoration: InputDecoration(
                        filled: true,
                        labelText: 'URL',
                      ),
                      initialValue: model.url,
                      keyboardType: TextInputType.url,
                      validator: (String value) {
                        if(value.isEmpty){
                          return 'URL is required';
                        }
                      },
                      onSaved: (String value){
                        model.url = value;
                      },
                    ),
                    leading: !editAPI
                        ? IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: () {
                        setState(() {
                          editAPI = true;
                        });
                      },
                    )
                        : IconButton(
                      icon: Icon(Icons.assignment_turned_in),
                      onPressed: () {
                        if(!_formKey.currentState.validate()) {
                          return;
                        }
                        _formKey.currentState.save();
                        print(model.url);

                        setState(() {
                          editAPI = false;
                        });
                      },
                    )
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }

}