import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shopledger/src/card_item.dart';

const Map<String, String> logos = {
  'Biedronka': 'assets/images/biedronka.png',
  'Lidl': 'assets/images/lidl.svg',
  'Auchan': 'assets/images/auchan.png',
};

class CardWidget extends StatelessWidget {
  final CardItem card;
  final bool isExpanded;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onPress;

  const CardWidget({
    super.key,
    required this.card,
    required this.isExpanded,
    required this.onDelete,
    required this.onEdit,
    required this.onPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPress,
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
                  onDelete();
                  Navigator.of(context).pop();
                },
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
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
            child: isExpanded
                ? _buildExpanded()
                : _buildCollapsed(constraints.maxWidth),
          );
        },
      ),
    );
  }

  Widget _buildCollapsed(double cardWidth) {
    Widget image = Text(card.storeName[0]);
    if (logos.containsKey(card.storeName)) {
      if (logos[card.storeName]!.split(".").last == "svg") {
        image = SvgPicture.asset(
          logos[card.storeName]!,
          width: cardWidth - 35 - 15,
          height: cardWidth - 35 - 15,
        );
      } else {
        image = Image.asset(
          logos[card.storeName]!,
          width: cardWidth - 35,
          height: cardWidth - 35,
        );
      }
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAliasWithSaveLayer,
          child: image,
        ),
        if (card.comment != null) const SizedBox(height: 10),
        if (card.comment != null)
          Text(card.comment!, style: const TextStyle(fontSize: 16)),
      ],
    );
  }

  Widget _buildExpanded() {
    Widget image = Text(card.storeName[0]);
    if (logos.containsKey(card.storeName)) {
      if (logos[card.storeName]!.split(".").last == "svg") {
        image = SvgPicture.asset(logos[card.storeName]!, width: 50, height: 50);
      } else {
        image = Image.asset(logos[card.storeName]!, width: 50, height: 50);
      }
    }

    double widthFactor;
    if (card.barcodeType == BarcodeType.QrCode) {
      widthFactor = 1.2;
    } else {
      widthFactor = 0.7;
    }

    return Stack(
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              clipBehavior: Clip.antiAliasWithSaveLayer,
              child: image,
            ),
          ),
        ),
        Align(
          alignment: Alignment.topRight,
          child: IconButton(icon: const Icon(Icons.edit), onPressed: onEdit),
        ),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FractionallySizedBox(
                widthFactor: widthFactor,
                child: BarcodeWidget(
                  barcode: Barcode.fromType(card.barcodeType),
                  data: card.barcodeData,
                  drawText: false,
                ),
              ),
              const SizedBox(height: 10),
              Text(card.barcodeData),
            ],
          ),
        ),
      ],
    );
  }
}
