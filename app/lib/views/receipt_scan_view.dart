import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/vision_service.dart';
import '../src/rust/api.dart';
import '../viewmodels/receipts_viewmodel.dart';
import 'add_receipt_view.dart';

class ReceiptScanView extends StatefulWidget {
  final ReceiptsViewModel viewModel;

  const ReceiptScanView({super.key, required this.viewModel});

  @override
  State<ReceiptScanView> createState() => _ReceiptScanViewState();
}

class _ReceiptScanViewState extends State<ReceiptScanView> {
  final ImagePicker _picker = ImagePicker();

  Uint8List? _rawImageBytes;
  Uint8List? _rgbaBytes;
  int _imageWidth = 0;
  int _imageHeight = 0;

  BridgePoint2D? _tl;
  BridgePoint2D? _tr;
  BridgePoint2D? _br;
  BridgePoint2D? _bl;

  double _confidence = 0.0;
  bool _isMl = false;
  bool _isProcessing = false;
  String? _statusMessage;

  Uint8List? _rectifiedJpeg;

  @override
  void initState() {
    super.initState();
    // Prompt image capture or picker automatically on opening
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pickImage(ImageSource.camera);
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked == null) return;

      setState(() {
        _isProcessing = true;
        _statusMessage = 'Analyzing receipt corners...';
        _rectifiedJpeg = null;
      });

      final bytes = await picked.readAsBytes();
      final decoded = VisionService.decodeToRgba(bytes);
      if (decoded == null) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Failed to decode image';
        });
        return;
      }

      _rawImageBytes = bytes;
      _rgbaBytes = decoded.rgba;
      _imageWidth = decoded.width;
      _imageHeight = decoded.height;

      final result = await VisionService.detectCorners(
        rgbaBytes: decoded.rgba,
        width: decoded.width,
        height: decoded.height,
      );

      if (result != null) {
        _tl = result.quad.topLeft;
        _tr = result.quad.topRight;
        _br = result.quad.bottomRight;
        _bl = result.quad.bottomLeft;
        _confidence = result.confidence;
        _isMl = result.isMl;
        _statusMessage = _isMl
            ? 'ML Corner Detection (${(_confidence * 100).toInt()}% confidence)'
            : 'Contour Heuristic Detection';
      } else {
        // Fallback default bounds
        _tl = const BridgePoint2D(x: 20, y: 20);
        _tr = BridgePoint2D(x: _imageWidth.toDouble() - 20, y: 20);
        _br = BridgePoint2D(
          x: _imageWidth.toDouble() - 20,
          y: _imageHeight.toDouble() - 20,
        );
        _bl = BridgePoint2D(x: 20, y: _imageHeight.toDouble() - 20);
        _statusMessage = 'Adjust corner handles to fit receipt';
      }
    } catch (e) {
      _statusMessage = 'Error: $e';
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _rectifyPerspective() async {
    if (_rgbaBytes == null ||
        _tl == null ||
        _tr == null ||
        _br == null ||
        _bl == null) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Rectifying perspective...';
    });

    try {
      final quad = BridgeQuad(
        topLeft: _tl!,
        topRight: _tr!,
        bottomRight: _br!,
        bottomLeft: _bl!,
      );

      final warpResult = await VisionService.warpPerspective(
        rgbaBytes: _rgbaBytes!,
        width: _imageWidth,
        height: _imageHeight,
        corners: quad,
      );

      final jpegBytes = await VisionService.encodeJpeg(
        rgbaBytes: warpResult.rgbaBytes,
        width: warpResult.width,
        height: warpResult.height,
        quality: 85,
      );

      setState(() {
        _rectifiedJpeg = jpegBytes;
        _statusMessage = 'Receipt rectified successfully';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Rectification error: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _confirmAndProceed() async {
    if (_rectifiedJpeg == null) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Uploading to PDS blob storage...';
    });

    try {
      final blobHash = await widget.viewModel.uploadReceiptImage(_rectifiedJpeg!);
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AddReceiptView(
            viewModel: widget.viewModel,
            initialImageBlobHash: blobHash,
            imagePreviewBytes: _rectifiedJpeg,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to upload blob: $e';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Receipt'),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: _isProcessing ? null : () => _pickImage(ImageSource.camera),
          ),
          IconButton(
            icon: const Icon(Icons.photo_library),
            onPressed: _isProcessing ? null : () => _pickImage(ImageSource.gallery),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_statusMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceVariant,
              child: Text(
                _statusMessage!,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: _isProcessing
                ? const Center(child: CircularProgressIndicator())
                : _rectifiedJpeg != null
                    ? _buildRectifiedPreview()
                    : _rawImageBytes != null
                        ? _buildCornerAdjuster()
                        : const Center(
                            child: Text(
                              'Take photo or choose receipt image',
                              textAlign: TextAlign.center,
                            ),
                          ),
          ),
          _buildBottomActionButtons(),
        ],
      ),
    );
  }

  Widget _buildRectifiedPreview() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Image.memory(
                _rectifiedJpeg!,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Perspective rectified. Confirm to link to receipt.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCornerAdjuster() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewW = constraints.maxWidth;
        final viewH = constraints.maxHeight;

        // Compute aspect fit scale
        final scaleX = viewW / _imageWidth;
        final scaleY = viewH / _imageHeight;
        final scale = scaleX < scaleY ? scaleX : scaleY;

        final renderedW = _imageWidth * scale;
        final renderedH = _imageHeight * scale;
        final offsetX = (viewW - renderedW) / 2;
        final offsetY = (viewH - renderedH) / 2;

        Offset toScreen(BridgePoint2D pt) =>
            Offset(offsetX + pt.x * scale, offsetY + pt.y * scale);

        BridgePoint2D toImage(Offset screenPt) {
          final x = ((screenPt.dx - offsetX) / scale).clamp(0.0, _imageWidth.toDouble());
          final y = ((screenPt.dy - offsetY) / scale).clamp(0.0, _imageHeight.toDouble());
          return BridgePoint2D(x: x, y: y);
        }

        final pTL = toScreen(_tl!);
        final pTR = toScreen(_tr!);
        final pBR = toScreen(_br!);
        final pBL = toScreen(_bl!);

        return Stack(
          children: [
            Positioned(
              left: offsetX,
              top: offsetY,
              width: renderedW,
              height: renderedH,
              child: Image.memory(
                _rawImageBytes!,
                fit: BoxFit.fill,
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _QuadPainter(
                  tl: pTL,
                  tr: pTR,
                  br: pBR,
                  bl: pBL,
                ),
              ),
            ),
            _buildDraggableHandle(pTL, (newPt) => setState(() => _tl = toImage(newPt))),
            _buildDraggableHandle(pTR, (newPt) => setState(() => _tr = toImage(newPt))),
            _buildDraggableHandle(pBR, (newPt) => setState(() => _br = toImage(newPt))),
            _buildDraggableHandle(pBL, (newPt) => setState(() => _bl = toImage(newPt))),
          ],
        );
      },
    );
  }

  Widget _buildDraggableHandle(Offset pos, ValueChanged<Offset> onDrag) {
    const double radius = 18.0;
    return Positioned(
      left: pos.dx - radius,
      top: pos.dy - radius,
      child: GestureDetector(
        onPanUpdate: (details) {
          onDrag(pos + details.delta);
        },
        child: Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.8),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.adjust,
            size: 18,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (_rectifiedJpeg != null) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _rectifiedJpeg = null),
                child: const Text('Re-adjust'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _isProcessing ? null : _confirmAndProceed,
                icon: const Icon(Icons.check),
                label: const Text('Use Image'),
              ),
            ),
          ] else if (_rawImageBytes != null) ...[
            Expanded(
              child: FilledButton.icon(
                onPressed: _isProcessing ? null : _rectifyPerspective,
                icon: const Icon(Icons.crop),
                label: const Text('Rectify Perspective'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuadPainter extends CustomPainter {
  final Offset tl;
  final Offset tr;
  final Offset br;
  final Offset bl;

  _QuadPainter({
    required this.tl,
    required this.tr,
    required this.br,
    required this.bl,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = Colors.blue.withOpacity(0.18)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(tl.dx, tl.dy)
      ..lineTo(tr.dx, tr.dy)
      ..lineTo(br.dx, br.dy)
      ..lineTo(bl.dx, bl.dy)
      ..close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _QuadPainter oldDelegate) {
    return oldDelegate.tl != tl ||
        oldDelegate.tr != tr ||
        oldDelegate.br != br ||
        oldDelegate.bl != bl;
  }
}
