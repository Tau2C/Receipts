import 'dart:typed_data';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'pds_flutter_method_channel.dart';

abstract class PdsFlutterPlatform extends PlatformInterface {
  PdsFlutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static PdsFlutterPlatform _instance = MethodChannelPdsFlutter();

  static PdsFlutterPlatform get instance => _instance;

  static set instance(PdsFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<bool> connect() {
    throw UnimplementedError('connect() has not been implemented.');
  }

  Future<bool> disconnect() {
    throw UnimplementedError('disconnect() has not been implemented.');
  }

  Future<bool> isConnected() {
    throw UnimplementedError('isConnected() has not been implemented.');
  }

  Future<bool> isReady() {
    throw UnimplementedError('isReady() has not been implemented.');
  }

  Future<String> executeRawRequest(String requestJson) {
    throw UnimplementedError('executeRawRequest() has not been implemented.');
  }

  Future<String> registerClient(String clientName, Uint8List publicKey) {
    throw UnimplementedError('registerClient() has not been implemented.');
  }

  Future<String> getPendingChanges(String sessionId, {int? limit}) {
    throw UnimplementedError('getPendingChanges() has not been implemented.');
  }

  Future<String> acknowledgeChanges(String sessionId, String changeId) {
    throw UnimplementedError('acknowledgeChanges() has not been implemented.');
  }

  Future<String> getClientCursor(String sessionId) {
    throw UnimplementedError('getClientCursor() has not been implemented.');
  }

  Future<bool> isPdsInstalled() {
    throw UnimplementedError('isPdsInstalled() has not been implemented.');
  }

  Future<bool> installPdsApk(String apkUriString) {
    throw UnimplementedError('installPdsApk() has not been implemented.');
  }

  Stream<String> watchChanges({String entityType = '*'}) {
    throw UnimplementedError('watchChanges() has not been implemented.');
  }
}
