import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:shopledger/src/card_item.dart';

class CardWidget extends StatefulWidget {
  final CardItem card;
  final double expandedWidth;

  const CardWidget({
    super.key,
    required this.card,
    required this.expandedWidth,
  });

  @override
  State<CardWidget> createState() => _CardWidgetState();
}

class _CardWidgetState extends State<CardWidget> {
  bool _isExpanded = false;

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 60) / 2;

    return GestureDetector(
      onTap: _toggleExpanded,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: _isExpanded ? widget.expandedWidth : cardWidth,
        height: _isExpanded ? widget.expandedWidth : cardWidth,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: _isExpanded ? _buildExpanded() : _buildCollapsed(),
      ),
    );
  }

  Widget _buildCollapsed() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(widget.card.logoAsset, width: 80, height: 80),
        const SizedBox(height: 10),
        Text(widget.card.comment, style: const TextStyle(fontSize: 16)),
      ],
    );
  }

  Widget _buildExpanded() {
    return Stack(
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Image.asset(widget.card.logoAsset, width: 40, height: 40),
          ),
        ),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.card.barcodeType == BarcodeType.QrCode)
                FractionallySizedBox(
                  widthFactor: 1.2,
                  child: BarcodeWidget(
                    barcode: Barcode.fromType(widget.card.barcodeType),
                    data: widget.card.barcodeData,
                    drawText: false,
                  ),
                ),
              if (widget.card.barcodeType == BarcodeType.Code128)
                FractionallySizedBox(
                  widthFactor: 0.7,
                  child: BarcodeWidget(
                    barcode: Barcode.fromType(widget.card.barcodeType),
                    data: widget.card.barcodeData,
                    drawText: false,
                  ),
                ),
              const SizedBox(height: 10),
              Text(widget.card.barcodeData),
            ],
          ),
        ),
      ],
    );
  }
}
