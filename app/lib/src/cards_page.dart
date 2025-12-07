import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:shopledger/src/card_item.dart';
import 'package:shopledger/src/card_widget.dart';

class CardsPage extends StatefulWidget {
  const CardsPage({super.key});

  @override
  State<CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends State<CardsPage> {
  final List<CardItem> _cardItems = [];

  @override
  void initState() {
    super.initState();
    _cardItems.addAll([
      CardItem(
        storeName: 'Biedronka',
        logoAsset: 'assets/images/biedronka.png',
        comment: 'Moja Biedronka',
        barcodeData: '1234567890',
        barcodeType: BarcodeType.Code128,
      ),
      CardItem(
        storeName: 'Lidl',
        logoAsset: 'assets/images/lidl.png',
        comment: 'Lidl Plus',
        barcodeData: '0987654321',
        barcodeType: BarcodeType.QrCode,
      ),
      CardItem(
        storeName: 'Auchan',
        logoAsset: 'assets/images/auchan.png',
        comment: 'Skarbonka',
        barcodeData: '1122334455',
        barcodeType: BarcodeType.Code128,
      ),
    ]);
  }

  void _addCard() {
    setState(() {
      _cardItems.add(
        CardItem(
          storeName: 'New Card',
          logoAsset: 'assets/images/lidl.png',
          comment: 'New Store',
          barcodeData: '0000000000',
          barcodeType: BarcodeType.QrCode,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const padding = 20.0;
    const spacing = 20.0;
    final cardWidth = (screenWidth - padding * 2 - spacing) / 2;
    final expandedWidth = cardWidth * 2 + spacing;

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(padding),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: _cardItems.map((card) {
              return CardWidget(card: card, expandedWidth: expandedWidth);
            }).toList(),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCard,
        child: const Icon(Icons.add),
      ),
    );
  }
}
