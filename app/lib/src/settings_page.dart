import 'package:flutter/material.dart';
import 'package:shopledger/src/database_helper.dart';

class SettingsPage extends StatelessWidget {
  final VoidCallback onDatabaseReset;
  const SettingsPage({super.key, required this.onDatabaseReset});

  Future<void> _resetDatabase(BuildContext context, String? table) async {
    final dbHelper = DatabaseHelper.instance;
    await dbHelper.close();
    if (table == null) {
      await dbHelper.deleteDatabase();
    } else {
      await dbHelper.resetTable(table);
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Database has been reset.')));
    onDatabaseReset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Reset Database'),
                content: const Text(
                  'Are you sure you want to reset the database? All data will be lost.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      _resetDatabase(context, "cards");
                      Navigator.of(context).pop();
                    },
                    child: const Text('Reset cards'),
                  ),
                  TextButton(
                    onPressed: () {
                      _resetDatabase(context, "receipts");
                      Navigator.of(context).pop();
                    },
                    child: const Text('Reset receipts'),
                  ),
                  TextButton(
                    onPressed: () {
                      _resetDatabase(context, null);
                      Navigator.of(context).pop();
                    },
                    child: const Text('Reset all'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            );
          },
          child: const Text('Reset Database'),
        ),
      ),
    );
  }
}
