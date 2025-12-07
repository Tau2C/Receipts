import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:shopledger/src/card_item.dart';
import 'package:shopledger/src/card_widget.dart';
import 'package:shopledger/src/database_helper.dart';

class CardsPage extends StatefulWidget {
  final DatabaseHelper? dbHelper;
  const CardsPage({super.key, this.dbHelper});

  @override
  State<CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends State<CardsPage> {
  late Future<List<CardItem>> _cards;
  late DatabaseHelper _dbHelper;

  @override
  void initState() {
    super.initState();
    _dbHelper = widget.dbHelper ?? DatabaseHelper.instance;
    refreshCards();
  }

  Future<void> refreshCards() async {
    setState(() {
      _cards = _dbHelper.readAllCards();
    });
  }

  Future<void> _addCard(CardItem card) async {
    await _dbHelper.create(card);
    refreshCards();
  }

  Future<void> _updateCard(CardItem card) async {
    await _dbHelper.update(card);
    refreshCards();
  }

  Future<void> _deleteCard(int id) async {
    await _dbHelper.delete(id);
    refreshCards();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const padding = 20.0;
    const spacing = 20.0;
    final cardWidth = (screenWidth - padding * 2 - spacing) / 2;
    final expandedWidth = cardWidth * 2 + spacing;

    return Scaffold(
      body: FutureBuilder<List<CardItem>>(
        future: _cards,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No cards found.'));
          } else {
            final cards = snapshot.data!;
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(padding),
                child: Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: cards.map((card) {
                    return CardWidget(
                      card: card,
                      expandedWidth: expandedWidth,
                      onDelete: () => _deleteCard(card.id!),
                      onEdit: () => _showEditCardDialog(card),
                    );
                  }).toList(),
                ),
              ),
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCardDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddCardDialog() {
    _showCardDialog();
  }

  void _showEditCardDialog(CardItem card) {
    _showCardDialog(card: card);
  }

  void _showCardDialog({CardItem? card}) {
    final isEditing = card != null;
    final formKey = GlobalKey<FormState>();
    String storeName = isEditing ? card.storeName : '';
    String logoAsset = isEditing ? card.logoAsset : 'assets/images/lidl.png';
    String comment = isEditing
        ? card.comment != null
              ? card.comment!
              : ''
        : '';
    String barcodeData = isEditing ? card.barcodeData : '';
    BarcodeType barcodeType = isEditing ? card.barcodeType : BarcodeType.QrCode;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Card' : 'Add Card'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: storeName,
                    decoration: const InputDecoration(labelText: 'Store Name'),
                    validator: (value) =>
                        value!.isEmpty ? 'Please enter a store name' : null,
                    onSaved: (value) => storeName = value!,
                  ),
                  TextFormField(
                    initialValue: comment,
                    decoration: const InputDecoration(labelText: 'Comment'),
                    onSaved: (value) => comment = value!,
                  ),
                  TextFormField(
                    initialValue: barcodeData,
                    decoration: const InputDecoration(
                      labelText: 'Barcode Data',
                    ),
                    validator: (value) =>
                        value!.isEmpty ? 'Please enter barcode data' : null,
                    onSaved: (value) => barcodeData = value!,
                  ),
                  DropdownButtonFormField<BarcodeType>(
                    value: barcodeType,
                    decoration: const InputDecoration(
                      labelText: 'Barcode Type',
                    ),
                    items: BarcodeType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.toString().split('.').last),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        barcodeType = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  final newCard = CardItem(
                    id: isEditing ? card.id : null,
                    storeName: storeName,
                    logoAsset: logoAsset,
                    comment: comment,
                    barcodeData: barcodeData,
                    barcodeType: barcodeType,
                  );
                  if (isEditing) {
                    _updateCard(newCard);
                  } else {
                    _addCard(newCard);
                  }
                  Navigator.of(context).pop();
                }
              },
              child: Text(isEditing ? 'Update' : 'Add'),
            ),
          ],
        );
      },
    );
  }
}
