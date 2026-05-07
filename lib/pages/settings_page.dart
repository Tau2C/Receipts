import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receipts/pages/Spolem_login_page.dart';
import 'package:receipts/pages/biedronka_login_page.dart';
import 'package:receipts/pages/id_ean_mapping_page.dart';
import 'package:receipts/pages/lidl_login_page.dart';
import 'package:receipts/pages/run_custom_sql_page.dart';
import 'package:receipts/retailer_manager.dart';
import 'package:receipts/src/rust/api/database.dart';
import 'package:receipts/src/rust/api/receipts.dart';
import 'package:receipts/src/rust/api/retailers/biedronka.dart';
import 'package:receipts/src/rust/api/retailers/lidl.dart';
import 'package:receipts/src/rust/api/retailers/spolem.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const bool enableBiedronka = true;
const bool enableLidl = true;
const bool enableSpolem = true;

class SettingsPage extends StatefulWidget {
  final String dbUrl;

  const SettingsPage({super.key, required this.dbUrl});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _retailerManager = RetailerManager();

  void _logout(String retailer) async {
    await _retailerManager.logout(retailer);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _purgeRetailerReceipts(String retailer) async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Purging $retailer receipts...')));
    final db = context.read<DatabaseService>();
    try {
      await db.deleteReceiptsByRetailer(retailer: retailer);
      await db.updateLastFetchDateTime(
        retailer: retailer,
        dateTime: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully purged $retailer receipts.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to purge $retailer receipts: $e')),
      );
    }
  }

  void _login(String retailer) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          if (retailer == SpolemClient.dbKey) {
            return const SpolemLoginPage();
          } else if (retailer == BiedronkaClient.dbKey) {
            return const BiedronkaLoginPage();
          } else if (retailer == LidlClient.dbKey) {
            return const LidlLoginPage();
          }

          return const Scaffold(
            body: Center(
              child: Text('Login not implemented for this retailer'),
            ),
          );
        },
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<String?> _fetchReceipts(String retailer, DatabaseService db) async {
    final client = _retailerManager.getClient(retailer);
    if (client == null) {
      return 'Not logged in.';
    }

    try {
      final lastFetch = client.lastFetch;
      final receipts = lastFetch != null
          ? await client.fetchReceiptsAfter(date: lastFetch)
          : await client.fetchReceipts();

      if (retailer == "spolem") {
        for (Receipt r in receipts) {
          var items = r.items;
          for (ReceiptItem i in items) {
            const none = "--brak nazwy--";
            if (i.name == none && i.ean != null) {
              var itemHistory = await db.getItem(ean: i.ean!);
              for (ReceiptItemSummary s in itemHistory) {
                if (s.item.name != none) {
                  i.name = s.item.name;
                  break;
                }
              }
            }
          }
          r.items = items;
        }
      }

      final now = DateTime.now().toUtc();
      client.lastFetch = now;

      await db.updateLastFetchDateTime(retailer: retailer, dateTime: now);

      await db.insertReceipts(receipts: receipts);

      return 'Fetched and saved ${receipts.length} receipts.';
    } catch (e) {
      return 'Failed to fetch receipts: $e';
    }
  }

  Future<void> _exportDatabase() async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Exporting database...')));
    try {
      final db = context.read<DatabaseService>();
      final downloadDir =
          await getApplicationDocumentsDirectory(); // Using documents for simplicity/cross-platform
      final exportedPath = await db.exportDatabase(
        dbPath: widget.dbUrl.replaceFirst(
          'sqlite://',
          '',
        ), // Pass actual file path
        destinationDir: downloadDir.path,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Database exported to $exportedPath')),
      );

      // Offer to share the file
      await Share.shareXFiles([XFile(exportedPath)]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to export database: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.palette_outlined),
              title: Text('Appearance'),
              subtitle: Text('Theme and visual preferences'),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.notifications_outlined),
              title: Text('Notifications'),
              subtitle: Text('Receipt reminders and app alerts'),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.lock_outline_rounded),
              title: Text('Privacy'),
              subtitle: Text('Storage and local data preferences'),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Data Management',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.link),
              title: const Text('ID to EAN Mappings'),
              subtitle: const Text('Manage item ID to EAN mappings'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const IdEanMappingPage(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Accounts',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),
          if (enableSpolem)
            Card(
              child: _retailerManager.isLoggedIn(BiedronkaClient.dbKey)
                  ? Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.store),
                          title: const Text('Biedronka'),
                          subtitle: const Text('Logged In'),
                          trailing: TextButton(
                            child: const Text('LOGOUT'),
                            onPressed: () => _logout(BiedronkaClient.dbKey),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.receipt_long),
                          title: const Text('Fetch Receipts'),
                          onTap: () async {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Fetching receipts...'),
                              ),
                            );
                            final db = context.read<DatabaseService>();
                            final message = await _fetchReceipts(
                              BiedronkaClient.dbKey,
                              db,
                            );
                            if (!mounted) return;
                            if (message != null) {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(message)));
                            }
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.dangerous),
                          title: const Text(
                            'Clear last fetch time (next fetch is FULL)',
                          ),
                          onTap: () async => {
                            await context
                                .read<DatabaseService>()
                                .updateLastFetchDateTime(
                                  retailer: BiedronkaClient.dbKey,
                                  dateTime: DateTime.fromMillisecondsSinceEpoch(
                                    0,
                                    isUtc: true,
                                  ),
                                ),
                            _retailerManager
                                    .getClient(BiedronkaClient.dbKey)
                                    ?.lastFetch =
                                DateTime.fromMillisecondsSinceEpoch(
                                  0,
                                  isUtc: true,
                                ),
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.delete_forever),
                          title: const Text('Purge Biedronka Receipts'),
                          onTap: () =>
                              _purgeRetailerReceipts(BiedronkaClient.dbKey),
                        ),
                      ],
                    )
                  : ListTile(
                      leading: const Icon(Icons.store),
                      title: const Text('Biedronka'),
                      subtitle: const Text('Not logged in'),
                      trailing: const Icon(Icons.login),
                      onTap: () => _login(BiedronkaClient.dbKey),
                    ),
            ),
          if (enableLidl)
            Card(
              child: _retailerManager.isLoggedIn(LidlClient.dbKey)
                  ? Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.store),
                          title: const Text('Lidl'),
                          subtitle: const Text('Logged In'),
                          trailing: TextButton(
                            child: const Text('LOGOUT'),
                            onPressed: () => _logout(LidlClient.dbKey),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.receipt_long),
                          title: const Text('Fetch Receipts'),
                          onTap: () async {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Fetching receipts...'),
                              ),
                            );
                            final db = context.read<DatabaseService>();
                            final message = await _fetchReceipts(
                              LidlClient.dbKey,
                              db,
                            );
                            if (!mounted) return;
                            if (message != null) {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(message)));
                            }
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.dangerous),
                          title: const Text(
                            'Clear last fetch time (next fetch is FULL)',
                          ),
                          onTap: () async => {
                            await context
                                .read<DatabaseService>()
                                .updateLastFetchDateTime(
                                  retailer: LidlClient.dbKey,
                                  dateTime: DateTime.fromMillisecondsSinceEpoch(
                                    0,
                                    isUtc: true,
                                  ),
                                ),
                            _retailerManager
                                    .getClient(LidlClient.dbKey)
                                    ?.lastFetch =
                                DateTime.fromMillisecondsSinceEpoch(
                                  0,
                                  isUtc: true,
                                ),
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.delete_forever),
                          title: const Text('Purge Lidl Receipts'),
                          onTap: () => _purgeRetailerReceipts(LidlClient.dbKey),
                        ),
                      ],
                    )
                  : ListTile(
                      leading: const Icon(Icons.store),
                      title: const Text('Lidl'),
                      subtitle: const Text('Not logged in'),
                      trailing: const Icon(Icons.login),
                      onTap: () => _login(LidlClient.dbKey),
                    ),
            ),
          if (enableSpolem)
            Card(
              child: _retailerManager.isLoggedIn(SpolemClient.dbKey)
                  ? Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.store),
                          title: const Text('Społem'),
                          subtitle: const Text('Logged In'),
                          trailing: TextButton(
                            child: const Text('LOGOUT'),
                            onPressed: () => _logout(SpolemClient.dbKey),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.receipt_long),
                          title: const Text('Fetch Receipts'),
                          onTap: () async {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Fetching receipts...'),
                              ),
                            );
                            final db = context.read<DatabaseService>();
                            final message = await _fetchReceipts(
                              SpolemClient.dbKey,
                              db,
                            );
                            if (!mounted) return;
                            if (message != null) {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(message)));
                            }
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.dangerous),
                          title: const Text(
                            'Clear last fetch time (next fetch is FULL)',
                          ),
                          onTap: () async => {
                            await context
                                .read<DatabaseService>()
                                .updateLastFetchDateTime(
                                  retailer: SpolemClient.dbKey,
                                  dateTime: DateTime.fromMillisecondsSinceEpoch(
                                    0,
                                    isUtc: true,
                                  ),
                                ),
                            _retailerManager
                                    .getClient(SpolemClient.dbKey)
                                    ?.lastFetch =
                                DateTime.fromMillisecondsSinceEpoch(
                                  0,
                                  isUtc: true,
                                ),
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.delete_forever),
                          title: const Text('Purge Społem Receipts'),
                          onTap: () =>
                              _purgeRetailerReceipts(SpolemClient.dbKey),
                        ),
                      ],
                    )
                  : ListTile(
                      leading: const Icon(Icons.store),
                      title: const Text('Społem'),
                      subtitle: const Text('Not logged in'),
                      trailing: const Icon(Icons.login),
                      onTap: () => _login(SpolemClient.dbKey),
                    ),
            ),
          if (kDebugMode) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Developer Options',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.code),
                title: const Text('Run Custom SQL'),
                subtitle: const Text('Execute arbitrary SQL queries'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const RunCustomSqlPage(),
                    ),
                  );
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Export Database'),
                subtitle: const Text('Backup database to device storage'),
                onTap: _exportDatabase,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
