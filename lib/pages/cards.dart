import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Added for context.read()
import 'package:receipts/pages/card_edit_page.dart';
import 'package:receipts/src/rust/api/card.dart' as c;
import 'package:receipts/src/rust/api/database.dart'; // Import DatabaseService

class CardsPage extends StatefulWidget {
  const CardsPage({super.key});

  @override
  State<CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends State<CardsPage> {
  late Future<List<c.Card>> _cardsFuture;
  c.Card? _selectedCard;

  @override
  void initState() {
    super.initState();
    _refreshCards();
  }

  void _refreshCards() {
    // Read the database service from the widget tree
    final db = context.read<DatabaseService>();
    setState(() {
      _cardsFuture = db.getCards();
    });
  }

  void _selectCard(c.Card card) {
    setState(() {
      _selectedCard = card;
    });
  }

  void _unselectCard() {
    setState(() {
      _selectedCard = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Cards')),
      body: Stack(
        children: [
          FutureBuilder<List<c.Card>>(
            future: _cardsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No cards found.'));
              } else {
                final cards = snapshot.data!
                    .where(
                      (card) =>
                          _selectedCard == null || card.id != _selectedCard!.id,
                    )
                    .toList();
                return GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: cards.length,
                  itemBuilder: (context, index) {
                    final cardItem = cards[index];
                    return CardGridItem(
                      card: cardItem,
                      onTapped: () => _selectCard(cardItem),
                    );
                  },
                );
              }
            },
          ),
          if (_selectedCard != null)
            EnlargedCardView(
              card: _selectedCard!,
              onClose: _unselectCard,
              onDelete: () async {
                final db = context.read<DatabaseService>();
                try {
                  // Await the Rust Future and use the named 'id' parameter
                  await db.deleteCard(id: _selectedCard!.id as int);
                  if (mounted) {
                    _unselectCard();
                    _refreshCards();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to delete card: $e')),
                    );
                  }
                }
              },
              onEdit: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => CardEditPage(card: _selectedCard),
                  ),
                );
                if (mounted) {
                  _unselectCard();
                  _refreshCards();
                }
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (context) => const CardEditPage()));
          if (mounted) {
            _refreshCards();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class CardGridItem extends StatelessWidget {
  final c.Card card;
  final VoidCallback onTapped;

  const CardGridItem({super.key, required this.card, required this.onTapped});

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'card-${card.id}',
      child: Material(
        child: InkWell(
          onTap: onTapped,
          child: Card(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(card.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  card.number,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EnlargedCardView extends StatelessWidget {
  final c.Card card;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const EnlargedCardView({
    super.key,
    required this.card,
    required this.onClose,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final side = size.width < size.height ? size.width : size.height;

    final barcodeType = card.name == 'Biedronka'
        ? BarcodeType.PDF417
        : BarcodeType.QrCode;

    Widget barcodeWidget = BarcodeWidget(
      barcode: Barcode.fromType(barcodeType),
      data: card.number,
      color: Theme.of(context).colorScheme.onSurface,
    );

    if (barcodeType == BarcodeType.PDF417) {
      barcodeWidget = Transform.scale(scaleY: 1.2, child: barcodeWidget);
    }

    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: Hero(
            tag: 'card-${card.id}',
            child: Material(
              child: SizedBox(
                width: side * 0.9,
                height: side * 0.9,
                child: Card(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        card.name,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: barcodeWidget,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: onEdit,
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Card'),
                                  content: const Text(
                                    'Are you sure you want to delete this card?',
                                  ),
                                  actions: [
                                    TextButton(
                                      child: const Text('Cancel'),
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                    ),
                                    TextButton(
                                      child: const Text('Delete'),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        onDelete();
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
