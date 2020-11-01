import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class ForegroundNotification extends StatefulWidget {
  @override
  _ForegroundNotificationState createState() => _ForegroundNotificationState();
}

class _ForegroundNotificationState extends State<ForegroundNotification> {
  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  new FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    initNotifications();
  }

  _onTap() async {
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        '1', 'inducesmile', 'inducesmile flutter snippets',
        playSound: false, importance: Importance.max, priority: Priority.high);
    var iOSPlatformChannelSpecifics = IOSNotificationDetails(presentSound: false);
    var platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics, iOS: iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
        0,
        'Inducesmile.com',
        'For Android & Flutter source code',
        platformChannelSpecifics,
        payload: 'item x');
  }

  _onCancel() async {
    await flutterLocalNotificationsPlugin.cancel(0);
  }

  initNotifications() async {
// initialise the plugin. app_icon needs to be a added as a drawable resource to the Android head project
    var initializationSettingsAndroid = new AndroidInitializationSettings('app_icon');
    var initializationSettingsIOS = new IOSInitializationSettings(
        onDidReceiveLocalNotification: (i, string1, string2, string3) {
          print("received notifications");
        });
    var initializationSettings = new InitializationSettings(
        android: initializationSettingsAndroid, iOS: initializationSettingsIOS);
    flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onSelectNotification: (string) {
          //print("selected notification");
          //_onTap();

        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(title: Text('Foreground Local Notification Example')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            RaisedButton(
              child: Text('Fire Notification'),
              onPressed: _onTap,
              color: Colors.red,
            ),

            RaisedButton(
              child: Text('Cancel'),
              onPressed: _onCancel,
              color: Colors.blue,
            )

          ],
        ),
      ),





    );
  }
}