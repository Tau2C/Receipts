import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:provider/provider.dart';
import 'package:receipts/src/rust/api/database.dart';
import 'package:receipts/src/rust/api/receipts.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';

class IdEanMappingPage extends StatefulWidget {
  const IdEanMappingPage({super.key});

  @override
  State<IdEanMappingPage> createState() => _IdEanMappingPageState();
}

class _IdEanMappingPageState extends State<IdEanMappingPage> {
  late Future<List<ItemIdEanMap>> _mappingsFuture;
  final _formKey = GlobalKey<FormState>();
  final _itemIdController = TextEditingController();
  final _eanController = TextEditingController();
  String? _selectedStore;

  @override
  void initState() {
    super.initState();
    _mappingsFuture = _fetchMappings();
  }

  Future<List<ItemIdEanMap>> _fetchMappings() {
    return context.read<DatabaseService>().getAllMappings();
  }

  void _refreshMappings() {
    setState(() {
      _mappingsFuture = _fetchMappings();
    });
  }

  void _deleteMapping(String store, String itemId) async {
    await context.read<DatabaseService>().deleteItemIdEanMap(
      store: store,
      itemId: itemId,
    );
    _refreshMappings();
  }

  void _addMapping() async {
    if (_formKey.currentState!.validate()) {
      await context.read<DatabaseService>().insertItemIdEanMap(
        store: _selectedStore!,
        itemId: _itemIdController.text,
        ean: _eanController.text,
      );
      _itemIdController.clear();
      _eanController.clear();
      _refreshMappings();
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _scanBarcode() async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SimpleBarcodeScannerPage()),
    );
    setState(() {
      if (res is String && res != '-1') {
        _eanController.text = res;
      }
    });
  }

  void _showAddMappingDialog() {
    _selectedStore = null;
    _itemIdController.clear();
    _eanController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add New Mapping'),
              content: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedStore,
                      decoration: const InputDecoration(labelText: 'Store'),
                      items: ['lidl', 'biedronka', 'spolem']
                          .map(
                            (store) => DropdownMenuItem(
                              value: store,
                              child: Text(store),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          _selectedStore = value;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Please select a store' : null,
                    ),
                    TypeAheadField<String>(
                      controller: _itemIdController,
                      suggestionsCallback: (pattern) async {
                        if (_selectedStore == null) return [];
                        final db = context.read<DatabaseService>();
                        final receipts = await db.receipts;
                        final Set<String> ids = {};
                        for (final r in receipts) {
                          final rStore = r.store.when(
                            other: (name) => name.toLowerCase(),
                            biedronka: (_) => 'biedronka',
                            lidl: (_) => 'lidl',
                            spolem: (_) => 'spolem',
                          );
                          if (rStore == _selectedStore) {
                            for (final item in r.items) {
                              if (item.id != null &&
                                  item.id!.toLowerCase().contains(
                                    pattern.toLowerCase(),
                                  )) {
                                ids.add(item.id!);
                              }
                            }
                          }
                        }
                        return ids.toList();
                      },
                      itemBuilder: (context, suggestion) {
                        return ListTile(title: Text(suggestion));
                      },
                      onSelected: (suggestion) {
                        _itemIdController.text = suggestion;
                      },
                      builder: (context, controller, focusNode) {
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Item ID',
                          ),
                          validator: (value) =>
                              value!.isEmpty ? 'Please enter an item ID' : null,
                        );
                      },
                    ),
                    TextFormField(
                      controller: _eanController,
                      decoration: InputDecoration(
                        labelText: 'EAN',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.camera_alt),
                          onPressed: _scanBarcode,
                        ),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Please enter an EAN' : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(onPressed: _addMapping, child: const Text('Add')),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ID to EAN Mappings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddMappingDialog,
          ),
        ],
      ),
      body: FutureBuilder<List<ItemIdEanMap>>(
        future: _mappingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final mappings = snapshot.data ?? [];
          if (mappings.isEmpty) {
            return const Center(child: Text('No mappings found.'));
          }
          return ListView.builder(
            itemCount: mappings.length,
            itemBuilder: (context, index) {
              final mapping = mappings[index];
              return ListTile(
                title: Text('${mapping.store}: ${mapping.itemId}'),
                subtitle: Text('EAN: ${mapping.ean}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () =>
                      _deleteMapping(mapping.store, mapping.itemId),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
