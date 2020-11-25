import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info/device_info.dart';


/// Class to modify / read parameters for app.
///
/// This contains 2 states,
///   1. Only the local variables are initialized.
///        Data can only be accessed by the local instance.
///   2. local variables are equal to SharedPreferences.
///        Data can be accessed by any call to this model. Requires loadModel()
///        to initially be called.
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

    return (prefs.getInt('checksum') == this.checksum
        && prefs.getString('devId') == this.devId
        && prefs.getString('url') == this.url
        && prefs.getBool('autoScan') == this.autoScan
        && prefs.getInt('autoScanDuration') == this.autoScanDuration
        && prefs.getInt('temp') == this.temp);
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
  BLESettingsModel _model = BLESettingsModel();    // Data for Screen.
  Future<bool> _isLoaded;    // Don't resolve until model is fetched.
  TextEditingController _urlController = TextEditingController();

  /// Initialize Widget State.
  @override
  void initState() {
    super.initState();
    _isLoaded = load();
  }

  // Load required variables into State.
  Future<bool> load() async {
    bool status = await _model.loadModel();   // Initialize model.
    _urlController.text = _model.url;         // Retrieve url field.

    return status;
  }

  /// Handle 'AutoScan Slider'.
  void _enableAutoScan(bool state) {
    setState(() {
      _model.autoScan = state;
    });
  }

  /// Handle 'AutoScan Dropdown'.
  /// Will also turn on AutoScan functionality.
  void _changeAutoScan(int value) {
    setState(() {
      _model.autoScanDuration = value;
      _model.autoScan = true;
    });
  }

  /// Edit url in AlertDialog.
  Future<bool> _editUrl(BuildContext context) async {
    return showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: Text('Edit url'),
            content: TextField(
              controller: _urlController,
              decoration: InputDecoration(hintText: "url"),
            ),
            actions: <Widget>[
              new FlatButton(
                child: new Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
              ),
              new FlatButton(
                  child: Text('Save'),
                  onPressed: () {
                    _model.url = _urlController.text;
                    Navigator.of(context).pop(true);
                  }
              ),
            ],
          );
        });
  }


  /// Close settings.
  void _closeSettings({bool save=false}) async {
    if(save) {
      await _model.saveModel();

      if(await _model.verifyModel()) {
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
    Navigator.pop(context);   // Exit BLE screen.
  }

  @override
  Widget build(BuildContext context) {
    // On first build, load preferences and resolve isLoaded.
    return FutureBuilder<bool>(
      future: _isLoaded,
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
        onPressed: () => _closeSettings(save: true),
        icon: Icon(Icons.save),
        label: Text("Save"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: Center(
          child: Column(
            children: <Widget>[

              ListTile(
                leading: IconButton(
                    icon: Icon(Icons.person),
                    onPressed: () => null,
                ),
                title: Text(_model.devId),
              ),

              ListTile(
                leading: Switch(
                  value: _model.autoScan,
                  onChanged: (value) => _enableAutoScan(value),
                ),
                title: DropdownButton(
                  isExpanded: true,
                  value: _model.autoScanDuration,
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
                  onChanged: (value) => _changeAutoScan(value),
                ),
              ),

              ListTile(
                leading: IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () async {
                    await _editUrl(context);
                    setState(() {});
                  },
                ),
                title: Text(_model.url),
              ),

            ],
          ),
        ),
      ),
    );
  }

}