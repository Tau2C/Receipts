import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receipts/src/rust/api/database.dart';

class RunCustomSqlPage extends StatefulWidget {
  const RunCustomSqlPage({super.key});

  @override
  State<RunCustomSqlPage> createState() => _RunCustomSqlPageState();
}

class _RunCustomSqlPageState extends State<RunCustomSqlPage> {
  final _sqlController = TextEditingController();
  String _sqlResult = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _sqlController.dispose();
    super.dispose();
  }

  Future<void> _executeSql() async {
    setState(() {
      _isLoading = true;
      _sqlResult = 'Executing SQL...';
    });

    final db = context.read<DatabaseService>();
    try {
      final result = await db.executeCustomSql(sql: _sqlController.text);
      if (!mounted) return;

      setState(() {
        if (result is SqlExecutionResult_RowsAffected) {
          _sqlResult = 'Rows Affected: ${result.field0}';
        } else if (result is SqlExecutionResult_Select) {
          if (result.field0.isEmpty) {
            _sqlResult = 'No rows returned.';
          } else {
            // Format the result nicely
            final columnNames = result.field1;
            final rows = result.field0;

            final buffer = StringBuffer();
            buffer.writeln(columnNames.join('\t|\t'));
            buffer.writeln('-----------------------------------');
            for (final row in rows) {
              buffer.writeln(row.join('\t|\t'));
            }
            _sqlResult = buffer.toString();
          }
        } else {
          _sqlResult = 'Unknown result type.';
        }
      });
    } catch (e) {
      _sqlResult = 'Error: $e';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Run Custom SQL')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _sqlController,
                maxLines: null, // Allow unlimited lines
                expands: true, // Make it expand to fill available height
                decoration: const InputDecoration(
                  hintText: 'Enter SQL query here...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _isLoading ? null : _executeSql,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Execute SQL'),
            ),
            const SizedBox(height: 16.0),
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(5.0),
                  ),
                  child: Text(
                    _sqlResult,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
