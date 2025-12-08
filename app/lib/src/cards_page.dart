import 'dart:math';
import 'dart:ui';

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

class _CardsPageState extends State<CardsPage>
    with SingleTickerProviderStateMixin {
  List<CardItem>? _cards;
  late DatabaseHelper _dbHelper;
  int? _expandedCardId;

  final ScrollController _scrollController = ScrollController();
  late AnimationController _heightController;
  double _currentHeight = 0;
  double _targetHeight = 0;

  @override
  void initState() {
    super.initState();
    _dbHelper = widget.dbHelper ?? DatabaseHelper.instance;
    _heightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addListener(() {
        setState(() {});
      });
    refreshCards();
  }

  @override
  void dispose() {
    _heightController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> refreshCards() async {
    final cards = await _dbHelper.readAllCards();
    setState(() {
      _cards = cards;
      final layout = _calculateLayout(cards, _expandedCardId);
      _currentHeight = layout['height']!;
      _targetHeight = layout['height']!;
      _heightController.value = 1.0;
    });
  }

  Future<void> _addCard(CardItem card) async {
    await _dbHelper.create(card);
    await refreshCards();
  }

  Future<void> _updateCard(CardItem card) async {
    await _dbHelper.update(card);
    await refreshCards();
  }

  Future<void> _deleteCard(int id) async {
    await _dbHelper.delete(id);
    await refreshCards();
  }

  Map<String, dynamic> _calculateLayout(
      List<CardItem> cards, int? expandedCardId) {
    final screenWidth = MediaQuery.of(context).size.width;
    const padding = 20.0;
    const spacing = 20.0;
    final cardWidth = (screenWidth - padding * 2 - spacing) / 2;
    final expandedWidth = cardWidth * 2 + spacing;

    var reorderedCards = List<CardItem>.from(cards);
    if (expandedCardId != null) {
      final expandedCardIndex =
          reorderedCards.indexWhere((card) => card.id == expandedCardId);
      if (expandedCardIndex != -1) {
        final expandedCard = reorderedCards.removeAt(expandedCardIndex);
        reorderedCards.insert(0, expandedCard);
      }
    }

    final availableWidth = screenWidth - padding * 2;
    double currentX = 0.0;
    double currentY = padding;
    double rowMaxHeight = 0.0;
    List<Map<String, dynamic>> cardPositions = [];

    for (final card in reorderedCards) {
      final bool isExpanded = card.id == expandedCardId;
      final double currentCardWidth = isExpanded ? expandedWidth : cardWidth;
      final double currentCardHeight = isExpanded ? expandedWidth : cardWidth;

      if (currentX + currentCardWidth > availableWidth + 0.1) {
        currentX = 0;
        currentY += rowMaxHeight + spacing;
        rowMaxHeight = 0;
      }

      cardPositions.add({
        'card': card,
        'left': currentX,
        'top': currentY,
        'width': currentCardWidth,
        'height': currentCardHeight,
      });

      rowMaxHeight = max(rowMaxHeight, currentCardHeight);
      currentX += currentCardWidth + spacing;
    }

    double maxBottom = 0.0;
    for (final pos in cardPositions) {
      maxBottom = max(maxBottom, pos['top'] + pos['height']);
    }
    final totalHeight = maxBottom + padding;

    return {'positions': cardPositions, 'height': totalHeight};
  }

  void _handleCardPress(int cardId) {
    if (_cards == null) return;

    final oldHeight = _calculateLayout(_cards!, _expandedCardId)['height']!;
    final newExpandedCardId = (_expandedCardId == cardId) ? null : cardId;
    final newHeight = _calculateLayout(_cards!, newExpandedCardId)['height']!;

    setState(() {
      _expandedCardId = newExpandedCardId;
      _currentHeight = oldHeight;
      _targetHeight = newHeight;
      _heightController.forward(from: 0.0);

      if (newExpandedCardId != null) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cards == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final layoutData = _calculateLayout(_cards!, _expandedCardId);
    final cardPositions = layoutData['positions']! as List<Map<String, dynamic>>;
    final animatedHeight =
        lerpDouble(_currentHeight, _targetHeight, _heightController.value)!;

    return Scaffold(
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: SizedBox(
            height: animatedHeight,
            child: Stack(
              children: cardPositions.map((pos) {
                final CardItem card = pos['card'];
                final bool isExpanded = card.id == _expandedCardId;
                return AnimatedPositioned(
                  key: ValueKey(card.id),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  left: pos['left'],
                  top: pos['top'],
                  width: pos['width'],
                  height: pos['height'],
                  child: CardWidget(
                    card: card,
                    isExpanded: isExpanded,
                    onDelete: () => _deleteCard(card.id!),
                    onEdit: () => _showEditCardDialog(card),
                    onPress: () => _handleCardPress(card.id!),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
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
    String comment = isEditing ? card.comment != null ? card.comment! : '' : '';
    String barcodeData = isEditing ? card.barcodeData : '';
    BarcodeType barcodeType =
        isEditing ? card.barcodeType : BarcodeType.QrCode;

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
