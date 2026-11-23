import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../src/rust/api.dart';

/// Service wrapping image loading, corner detection, and perspective warping.
class VisionService {
  /// Decodes image bytes to raw RGBA buffer and dimensions.
  static ({Uint8List rgba, int width, int height})? decodeToRgba(Uint8List rawBytes) {
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) return null;

    final rgbaImg = decoded.convert(numChannels: 4);
    final rgbaBytes = Uint8List.fromList(rgbaImg.toUint8List());

    return (
      rgba: rgbaBytes,
      width: rgbaImg.width,
      height: rgbaImg.height,
    );
  }

  /// Detects 4 receipt corners using ML model with heuristic fallback.
  static Future<BridgeCornerDetectionResult?> detectCorners({
    required Uint8List rgbaBytes,
    required int width,
    required int height,
  }) async {
    return detectReceiptCornersMl(
      rgbaBytes: rgbaBytes,
      width: width,
      height: height,
    );
  }

  /// Warps receipt quadrilateral to rectified perspective image.
  static Future<BridgeWarpResult> warpPerspective({
    required Uint8List rgbaBytes,
    required int width,
    required int height,
    required BridgeQuad corners,
  }) async {
    return warpReceiptPerspective(
      rgbaBytes: rgbaBytes,
      width: width,
      height: height,
      corners: corners,
    );
  }

  /// Encodes rectified RGBA buffer into JPEG bytes.
  static Future<Uint8List> encodeJpeg({
    required Uint8List rgbaBytes,
    required int width,
    required int height,
    int quality = 85,
  }) async {
    return encodeReceiptJpeg(
      rgbaBytes: rgbaBytes,
      width: width,
      height: height,
      quality: quality,
    );
  }
}
