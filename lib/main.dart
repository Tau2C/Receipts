import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'package:receipts/pages/home_page.dart';
import 'package:receipts/retailer_manager.dart';
import 'package:receipts/src/rust/api/database.dart';
import 'package:receipts/src/rust/frb_generated.dart';
import 'package:system_date_time_format/system_date_time_format.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await RustLib.init();

  final appDocDir = await getApplicationDocumentsDirectory();

  final dbPath = p.join(appDocDir.path, 'receipts_app.db');

  // Ensure the database file exists before SQLx tries to open it.
  // SQLite handles empty 0-byte files perfectly well.
  final dbFile = File(dbPath);
  if (!await dbFile.exists()) {
    await dbFile.create(recursive: true);
  }

  try {
    // SQLx expects a valid connection URI. Prepend 'sqlite://' and
    // normalize any Windows backslashes to forward slashes.
    final dbUrl = 'sqlite://${dbPath.replaceAll('\\', '/')}';

    final databaseService = DatabaseService(path: dbUrl);

    debugPrint("DatabaseService $dbUrl");

    await databaseService.runDbMigrations();

    debugPrint("databaseService.runDbMigrations");

    await RetailerManager().init(databaseService);

    debugPrint("RetailerManager.init");

    runApp(
      MultiProvider(
        providers: [Provider<DatabaseService>.value(value: databaseService)],
        child: const SDTFScope(child: MyApp()),
      ),
    );
  } catch (e) {
    debugPrint("$e");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0C7D69)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
