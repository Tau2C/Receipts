import 'package:flutter/material.dart';
import 'package:pds_flutter/pds_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _status = 'Disconnected';
  final _client = PdsClient();

  @override
  void initState() {
    super.initState();
    _checkPds();
  }

  Future<void> _checkPds() async {
    try {
      final connected = await _client.connect();
      if (!mounted) return;
      setState(() {
        _status = connected ? 'Connected to PDS Core' : 'Connection failed';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('PDS Plugin Example')),
        body: Center(child: Text('Status: $_status')),
      ),
    );
  }
}
