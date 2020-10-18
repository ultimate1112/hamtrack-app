import 'package:flutter/material.dart';
import 'ble.dart';
import 'ble_settings.dart';

// Root of application.
void main() {
  runApp(MaterialApp(
    title: 'HamTrack BLE',
    theme: ThemeData(
      primarySwatch: Colors.blue,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    ),
    // Start the app with the "/" named route.
    initialRoute: '/',
    routes: {
      // When navigating to the "/" route, build the FirstScreen widget.
      '/': (context) => BLEScreen(),
    },
  ));
}
