import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'pds_flutter_platform_interface.dart';

/// Implementation of [PdsFlutterPlatform] using MethodChannel and EventChannel
class MethodChannelPdsFlutter extends PdsFlutterPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('top.tau2c.pds/client');

  @visibleForTesting
  final eventChannel = const EventChannel('top.tau2c.pds/events');

  @override
  Future<bool> connect() async {
    final connected = await methodChannel.invokeMethod<bool>('connect');
    return connected ?? false;
  }

  @override
  Future<bool> disconnect() async {
    final disconnected = await methodChannel.invokeMethod<bool>('disconnect');
    return disconnected ?? false;
  }

  @override
  Future<bool> isConnected() async {
    final connected = await methodChannel.invokeMethod<bool>('isConnected');
    return connected ?? false;
  }

  @override
  Future<bool> isReady() async {
    final ready = await methodChannel.invokeMethod<bool>('isReady');
    return ready ?? false;
  }

  @override
  Future<String> executeRawRequest(String requestJson) async {
    final response = await methodChannel.invokeMethod<String>(
      'executeRawRequest',
      {'requestJson': requestJson},
    );
    return response ?? '';
  }

  @override
  Future<String> registerClient(String clientName, Uint8List publicKey) async {
    final clientId = await methodChannel.invokeMethod<String>(
      'register',
      {'clientName': clientName, 'publicKey': publicKey},
    );
    return clientId ?? '';
  }

  @override
  Future<String> getPendingChanges(String sessionId, {int? limit}) async {
    final result = await methodChannel.invokeMethod<String>(
      'getPendingChanges',
      {'sessionId': sessionId, 'limit': ?limit},
    );
    return result ?? '';
  }

  @override
  Future<String> acknowledgeChanges(String sessionId, String changeId) async {
    final result = await methodChannel.invokeMethod<String>(
      'acknowledgeChanges',
      {'sessionId': sessionId, 'changeId': changeId},
    );
    return result ?? '';
  }

  @override
  Future<String> getClientCursor(String sessionId) async {
    final result = await methodChannel.invokeMethod<String>(
      'getClientCursor',
      {'sessionId': sessionId},
    );
    return result ?? '';
  }

  @override
  Stream<String> watchChanges({String entityType = '*'}) {
    return eventChannel
        .receiveBroadcastStream({'entityType': entityType})
        .map((event) => event.toString());
  }
}
