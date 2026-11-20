import 'package:flutter/material.dart';
import 'src/rust/frb_generated.dart';
import 'viewmodels/receipts_viewmodel.dart';
import 'views/receipts_list_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await RustLib.init();
  } catch (e) {
    debugPrint('RustLib.init() skipped or failed in test/dev environment: $e');
  }
  runApp(const ReceiptsApp());
}

class ReceiptsApp extends StatefulWidget {
  const ReceiptsApp({super.key});

  @override
  State<ReceiptsApp> createState() => _ReceiptsAppState();
}

class _ReceiptsAppState extends State<ReceiptsApp> {
  final _viewModel = ReceiptsViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.initialize();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDS Receipts',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: ReceiptsListView(viewModel: _viewModel),
    );
  }
}
