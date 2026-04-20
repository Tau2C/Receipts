import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receipts/pages/Spolem_login_page.dart';
import 'package:receipts/retailer_manager.dart';
import 'package:receipts/src/rust/api/database.dart';

const bool enableBiedronka = false; // Disabled for now as not implemented
const bool enableLidl = false; // Disabled for now as not implemented
const bool enableSpolem = true;

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

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

  void _login(String retailer) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          if (retailer == 'Społem') {
            return const SpolemLoginPage();
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

  void _fetchReceipts(String retailer) async {
    final client = _retailerManager.getClient(retailer);
    if (client == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Not logged in.')));
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Fetching receipts...')));

    final db = context.read<DatabaseService>();

    try {
      final lastFetch = client.lastFetch;
      final receipts = lastFetch != null
          ? await client.fetchReceiptsOlderThan(date: lastFetch)
          : await client.fetchReceipts();

      final now = DateTime.now().toUtc();
      client.lastFetch = now;

      await db.updateLastFetchDateTime(retailer: retailer, dateTime: now);

      await db.insertReceipts(receipts: receipts);

      if (!mounted) return; // Guard the async gap
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fetched and saved ${receipts.length} receipts.'),
        ),
      );
    } catch (e) {
      if (!mounted) return; // Guard the async gap
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to fetch receipts: $e')));
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
              'Accounts',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),
          if (enableBiedronka)
            Card(
              child: ListTile(
                leading: const Icon(Icons.store),
                title: const Text('Biedronka'),
                trailing: const Icon(Icons.login),
                onTap: () {
                  // _login('Biedronka');
                },
              ),
            ),
          if (enableLidl)
            Card(
              child: ListTile(
                leading: const Icon(Icons.store),
                title: const Text('Lidl'),
                trailing: const Icon(Icons.login),
                onTap: () {
                  // _login('Lidl');
                },
              ),
            ),
          if (enableSpolem)
            Card(
              child: _retailerManager.isLoggedIn('spolem')
                  ? Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.store),
                          title: const Text('Społem'),
                          subtitle: const Text('Logged In'),
                          trailing: TextButton(
                            child: const Text('LOGOUT'),
                            onPressed: () => _logout('spolem'),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.receipt_long),
                          title: const Text('Fetch Receipts'),
                          onTap: () => _fetchReceipts('spolem'),
                        ),
                      ],
                    )
                  : ListTile(
                      leading: const Icon(Icons.store),
                      title: const Text('Społem'),
                      subtitle: const Text('Not logged in'),
                      trailing: const Icon(Icons.login),
                      onTap: () => _login('Społem'),
                    ),
            ),
        ],
      ),
    );
  }
}
