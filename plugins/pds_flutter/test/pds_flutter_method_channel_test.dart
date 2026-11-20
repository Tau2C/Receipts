import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pds_flutter/pds_flutter_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelPdsFlutter();
  const channel = MethodChannel('top.tau2c.pds/client');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'connect':
          return true;
        case 'disconnect':
          return true;
        case 'isConnected':
          return true;
        case 'isReady':
          return true;
        case 'executeRawRequest':
          return '{"status":"Success"}';
        case 'isPdsInstalled':
          return true;
        case 'installPdsApk':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('connect', () async {
    expect(await platform.connect(), true);
  });

  test('isConnected', () async {
    expect(await platform.isConnected(), true);
  });

  test('executeRawRequest', () async {
    final response = await platform.executeRawRequest('{"action":"ping"}');
    expect(response, '{"status":"Success"}');
  });

  test('isPdsInstalled', () async {
    expect(await platform.isPdsInstalled(), true);
  });

  test('installPdsApk', () async {
    expect(await platform.installPdsApk('content://test.apk'), true);
  });
}
