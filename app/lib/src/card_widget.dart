import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:shopledger/src/card_item.dart';

class CardWidget extends StatefulWidget {
  final CardItem card;
  final double expandedWidth;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const CardWidget({
    super.key,
    required this.card,
    required this.expandedWidth,
    required this.onDelete,
    required this.onEdit,
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
      onLongPress: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Card'),
            content: const Text('Are you sure you want to delete this card?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  widget.onDelete();
                  Navigator.of(context).pop();
                },
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
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
        if (widget.card.comment != null) const SizedBox(height: 10),
        if (widget.card.comment != null)
          Text(widget.card.comment!, style: const TextStyle(fontSize: 16)),
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
        Align(
          alignment: Alignment.topRight,
          child: IconButton(
            icon: const Icon(Icons.edit),
            onPressed: widget.onEdit,
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
