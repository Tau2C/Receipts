import 'package:flutter/material.dart';
import 'package:shopledger/src/database_helper.dart';

class SettingsPage extends StatelessWidget {
  final VoidCallback onDatabaseReset;
  const SettingsPage({super.key, required this.onDatabaseReset});

  Future<void> _resetDatabase(BuildContext context) async {
    final dbHelper = DatabaseHelper.instance;
    await dbHelper.close();
    await dbHelper.deleteDatabase();
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
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      _resetDatabase(context);
                      Navigator.of(context).pop();
                    },
                    child: const Text('Reset'),
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
