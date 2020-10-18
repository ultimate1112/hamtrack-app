import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_beacon/flutter_beacon.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';





class BLEModel {
  bool isEnabled;

  bool autoSend;
  int autoSendDuration;

  String url;
  String devId;

  Timer t;

  BLEModel({this.isEnabled, this.autoSend, this.autoSendDuration, this.url, this.devId});

  void start() {

    this.t = new Timer.periodic(Duration(seconds: 2), (Timer t) => scan(t));
  }

  void stop() {

    this.t.cancel();
  }

  void scan(Timer t) async {
    print('Scan Executed.' + DateTime.now().second.toString());
  }

}

class BLEPage extends StatefulWidget {
  BLEPage({Key key}) : super(key: key);

  @override
  _BLEPageState createState() => _BLEPageState();
}

class _BLEPageState extends State<BLEPage> {

  BLEModel model;

  @override
  initState() {
    super.initState();

    model = BLEModel(
        isEnabled: false,
        autoSend: false,
        autoSendDuration: 5,
        url: "https://hamtrack.xyz",
        devId: "",
    );

  }



  bool forceBusy = false;



  void enableWidget(bool state) async {
    // Check Bluetooth Permissions.
    await flutterBeacon.initializeAndCheckScanning;

    setState(() {
      model.isEnabled = state;
    });
  }

  void enableAutoSend(bool state) {
    setState(() {
      model.autoSend = true;

      if(state) {
        model.start();
      } else {
        model.stop();
      }

    });
  }

  void changeAutoSend(int value) {
    setState(() {
      model.autoSend = true;

      model.autoSendDuration = value;
      print('Changing duration to: '+ value.toString());
    });
  }

  void sendButton() async {
    setState(() {
      forceBusy = true;
    });

    await Future.delayed(new Duration(seconds: 5));

    setState(() {
      forceBusy = false;
      print('YES!');
    });
  }

  void openBLESettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BLESettings()),
    );
  }

  Widget lister() {
    return               Expanded(
        child: ListView(
          scrollDirection: Axis.vertical,
          shrinkWrap: true,
          padding: const EdgeInsets.all(8),
          children: <Widget>[
            ListTile(
              tileColor: Colors.lightBlueAccent[100],
              title: Text('12:34:56:78:9A'),
              leading: Text('30dB'),
              trailing: Text('+1'),
            ),
            ListTile(
              tileColor: Colors.lightBlueAccent[200],
              title: Text('12:34:56:78:9A'),
              leading: Text('30dB'),
              trailing: Text('+1'),
            ),
            ListTile(
              tileColor: Colors.lightBlueAccent[300],
              title: Text('12:34:56:78:9A'),
              leading: Text('30dB'),
              trailing: Text('+1'),
            ),
            ListTile(
              tileColor: Colors.lightBlueAccent[400],
              title: Text('12:34:56:78:9A'),
              leading: Text('30dB'),
              trailing: Text('+1'),
            ),

          ],
        )
    );
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[

        // Enable Switch.
        ListTile(
          leading: Switch(
            value: model.isEnabled,
            onChanged: enableWidget,
          ),
          title: Text('Enable BLE'),
        ),

        // Config Elements.
        Container(
          child: !model.isEnabled ? null : Column(
            children: <Widget>[

              ListTile(
                title: RaisedButton(
                  onPressed: forceBusy ? null : sendButton,
                  child: Text('Force Update'),
                ),
              ),

              ListTile(
                leading: Switch(
                  value: model.autoSend,
                  onChanged: enableAutoSend,
                ),
                title: DropdownButton(
                  value: model.autoSendDuration,
                  items: [
                    DropdownMenuItem(
                      child: Text("1 second"),
                      value: 1,
                    ),
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
                  ],
                  onChanged: changeAutoSend,
                ),
              ),

              ListTile(
                title: Text('Other Settings...'),
                trailing: Icon(Icons.keyboard_arrow_right),
                onTap: openBLESettings,
              ),

            ],
          ),
        ),

        // Status Window
        Container(
          child: !model.isEnabled ? null : lister(),
        ),

      ],
    );
  }

}

class BLESettings extends StatefulWidget {

  BLESettings({Key key}) : super(key: key);

  @override
  _BLESettingsState createState() => _BLESettingsState();
}

class _BLESettingsState extends State<BLESettings> {
  bool editAPI = false;
  String api = "";

  final GlobalKey<FormState> _formKey  = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("BLE Settings"),
      ),
      body: Container(
        child: Column(
          children: [
            Form(
                key: _formKey,
                child: ListTile(
                  title: TextFormField(
                    enabled: editAPI,
                    decoration: InputDecoration(
                        labelText: 'URL'
                    ),
                    initialValue: "https://hamtrack.xyz/callback",
                    keyboardType: TextInputType.url,
                    validator: (String value) {
                      if(value.isEmpty){
                        return 'URL is required';
                      }

                    },
                    onSaved: (String value){
                      api = value;
                    },
                  ),
                  trailing: !editAPI
                    ? RaisedButton(
                      child: Text('Edit'),
                      onPressed: () {
                        setState(() {
                          editAPI = true;
                        });
                      },
                    )
                    : RaisedButton(
                      child: Text('Save'),
                      onPressed: () {
                        if(!_formKey.currentState.validate()) {
                          return;
                        }
                        _formKey.currentState.save();
                        print(api);

                        setState(() {
                          editAPI = false;
                        });
                      },
                    ),




                ),


            ),



          ],
        ),
      ),
    );
  }
}