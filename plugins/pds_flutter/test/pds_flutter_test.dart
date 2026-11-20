import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pds_flutter/pds_flutter.dart';
import 'package:pds_flutter/pds_flutter_platform_interface.dart';
import 'package:pds_flutter/pds_flutter_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPdsFlutterPlatform
    with MockPlatformInterfaceMixin
    implements PdsFlutterPlatform {
  @override
  Future<bool> connect() => Future.value(true);

  @override
  Future<bool> disconnect() => Future.value(true);

  @override
  Future<bool> isConnected() => Future.value(true);

  @override
  Future<bool> isReady() => Future.value(true);

  @override
  Future<String> executeRawRequest(String requestJson) =>
      Future.value('{"status":"Success"}');

  @override
  Future<String> registerClient(String clientName, Uint8List publicKey) =>
      Future.value('01J00000000000000000000000');

  @override
  Future<String> getPendingChanges(String sessionId, {int? limit}) =>
      Future.value('[]');

  @override
  Future<String> acknowledgeChanges(String sessionId, String changeId) =>
      Future.value('{"status":"Success"}');

  @override
  Future<String> getClientCursor(String sessionId) =>
      Future.value('{"cursor":0}');

  @override
  Future<bool> isPdsInstalled() => Future.value(true);

  @override
  Future<bool> installPdsApk(String apkUriString) => Future.value(true);

  @override
  Stream<String> watchChanges({String entityType = '*'}) =>
      Stream.value('[{"action":"put"}]');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final PdsFlutterPlatform initialPlatform = PdsFlutterPlatform.instance;

  test('$MethodChannelPdsFlutter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelPdsFlutter>());
  });

  test('connect calls platform connect', () async {
    final fakePlatform = MockPdsFlutterPlatform();
    PdsFlutterPlatform.instance = fakePlatform;
    final client = PdsClient(platform: fakePlatform);

    expect(await client.connect(), true);
    expect(await client.isConnected(), true);
    expect(await client.isReady(), true);
  });
}
