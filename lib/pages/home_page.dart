import 'package:flutter/material.dart';
import 'package:receipts/pages/cards.dart';
import 'package:receipts/pages/receipts_page.dart';
import 'package:receipts/pages/settings_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _HomeCardData(
        title: 'Cards',
        subtitle: 'Manage loyalty cards and barcodes',
        icon: Icons.credit_card_rounded,
        color: const Color(0xFF0C7D69),
        builder: (_) => const CardsPage(),
      ),
      _HomeCardData(
        title: 'Receipts',
        subtitle: 'Browse saved receipts and totals',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFFE67E22),
        builder: (_) => const ReceiptsPage(),
      ),
      _HomeCardData(
        title: 'Settings',
        subtitle: 'Adjust preferences and app behavior',
        icon: Icons.settings_rounded,
        color: const Color(0xFF2C3E50),
        builder: (_) => const SettingsPage(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Receipts')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Main page', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Open the area you want to manage.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.8,
                ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _DashboardCard(item: item);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.item});

  final _HomeCardData item;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(builder: item.builder));
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                item.color,
                Color.lerp(item.color, Colors.white, 0.35) ?? item.color,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.18),
                foregroundColor: Colors.white,
                child: Icon(item.icon),
              ),
              const Spacer(),
              Text(
                item.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeCardData {
  const _HomeCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.builder,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final WidgetBuilder builder;
}
