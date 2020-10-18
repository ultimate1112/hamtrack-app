import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info/device_info.dart';
import 'dart:io';


class BLESettingsModel {
  int checkKey;
  bool autoSend;
  int autoSendDuration;
  String devId;
  String url;

  // Constructor with default options.
  BLESettingsModel({
    this.checkKey=9,
    this.autoSend=false,
    this.autoSendDuration=5,
    this.devId="",
    this.url="https://hamtrack.xyz",
  });

  Future<String> getDeviceCode() async {
    final DeviceInfoPlugin deviceInfoPlugin = new DeviceInfoPlugin();
    print('Fetching devID');

    if (Platform.isAndroid) {
      AndroidDeviceInfo androidDeviceInfo = await deviceInfoPlugin.androidInfo;
      return androidDeviceInfo.androidId;
    } else if (Platform.isIOS) {
      IosDeviceInfo iosDeviceInfo = await deviceInfoPlugin.iosInfo;
      return iosDeviceInfo.identifierForVendor;
    } else {
      print('Cannot detect platform.');
      return "";
    }
  }

  Future<void> saveModel() async {
    SharedPreferences _prefs = await SharedPreferences.getInstance();
    await _prefs.setInt('checkKey', checkKey);
    await _prefs.setBool('autoSend', autoSend);
    await _prefs.setInt('autoSendDuration', autoSendDuration);
    await _prefs.setString('devId', devId);
    await _prefs.setString('url', url);
  }

  Future<bool> loadModel() async {
    SharedPreferences _prefs = await SharedPreferences.getInstance();
    if(!_prefs.containsKey('checkKey')
        || _prefs.getInt('checkKey') != checkKey) {
      // Initialize Shared Preferences.
      print('Initializing shared_preferences...');
      devId = await getDeviceCode();
      await saveModel();

      return false;
    } else {
      // Pull from Shared Preferences.
      checkKey = _prefs.getInt('checkKey');
      autoSend = _prefs.getBool('autoSend');
      autoSendDuration = _prefs.getInt('autoSendDuration');
      devId = _prefs.getString('devId');
      url = _prefs.getString('url');

      return true;
    }
  }

  Future<bool> verifyModel() async {
    SharedPreferences _prefs = await SharedPreferences.getInstance();
    if(_prefs.getInt('checkKey') == checkKey
        && _prefs.getBool('autoSend') == autoSend
        && _prefs.getInt('autoSendDuration') == autoSendDuration
        && _prefs.getString('devId') == devId
        && _prefs.getString('url') == url
    ) {
      return true;
    }
    return false;
  }
}


class BLESettingsScreen extends StatefulWidget {
  BLESettingsScreen({Key key}) : super(key: key);

  @override
  _BLESettingsScreenState createState() => _BLESettingsScreenState();
}

class _BLESettingsScreenState extends State<BLESettingsScreen> {
  BLESettingsModel model = BLESettingsModel();  // Data for Screen.
  Future<bool> isLoaded;  // Don't resolve until model is fetched.
  // TextField.
  final GlobalKey<FormState> _formKey  = GlobalKey<FormState>();
  TextEditingController _controller = new TextEditingController();
  bool editAPI = false;

  void initState() {
    super.initState();

    // Load the model.
    isLoaded = model.loadModel();
  }

  // Handle 'AutoSend Slider'.
  void enableAutoSend(bool state) {
    setState(() {
      model.autoSend = state;
    });
  }

  // Handle 'AutoSend Dropdown'.
  void changeAutoSend(int value) {
    setState(() {
      model.autoSendDuration = value;
      model.autoSend = true;  // Turn on autoScan.
    });
  }

  void closeSettings({bool save=false}) async {
    if(save) {
      await model.saveModel();
      if(await model.verifyModel()) {
        print('Saved to preferences.');
      } else {
        print('Failed to save to preferences.');
      }
    }

    Navigator.pop(context);
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
                  value: model.autoSend,
                  onChanged: enableAutoSend,
                ),
                title: DropdownButton(
                  isExpanded: true,
                  value: model.autoSendDuration,
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