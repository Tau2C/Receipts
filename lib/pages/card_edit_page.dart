import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receipts/src/rust/api/card.dart' as c;
import 'package:receipts/src/rust/api/database.dart';

class CardEditPage extends StatefulWidget {
  final c.Card? card;

  const CardEditPage({super.key, this.card});

  @override
  State<CardEditPage> createState() => _CardEditPageState();
}

class _CardEditPageState extends State<CardEditPage> {
  final _formKey = GlobalKey<FormState>();
  late String _number;
  late String _store;

  @override
  void initState() {
    super.initState();
    if (widget.card != null) {
      _store = widget.card!.name;
      _number = widget.card!.number;
    } else {
      _store = 'Lidl';
      _number = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.card == null ? 'New Card' : 'Edit Card'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveForm),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _store,
                items: ['Lidl', 'Biedronka', 'Other']
                    .map(
                      (label) =>
                          DropdownMenuItem(value: label, child: Text(label)),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _store = value!;
                  });
                },
                decoration: const InputDecoration(labelText: 'Store'),
              ),
              TextFormField(
                initialValue: _number,
                decoration: const InputDecoration(labelText: 'Card Number'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a card number';
                  }
                  return null;
                },
                onSaved: (value) {
                  _number = value!;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final newCard = c.Card(
        id: widget.card?.id,
        name: _store,
        number: _number,
        enabled: true,
      );

      final db = context.read<DatabaseService>();

      try {
        if (widget.card == null) {
          await db.insertCard(card: newCard);
        } else {
          await db.updateCard(card: newCard);
        }

        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to save card: $e')));
        }
      }
    }
  }
}
