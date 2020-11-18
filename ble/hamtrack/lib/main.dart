import 'package:flutter/material.dart';
import 'ble.dart';
import 'ble_settings.dart';
import 'dart:io';

// Handle HTTP Connections Bad Certificate without failing.
class MyHttpOverrides extends HttpOverrides{
  @override
  HttpClient createHttpClient(SecurityContext context){
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port)=> true;
  }
}

// Root of application.
void main() {
  HttpOverrides.global = new MyHttpOverrides();

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
