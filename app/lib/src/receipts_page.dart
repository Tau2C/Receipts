import 'package:flutter/material.dart';
import 'package:animate_icons/animate_icons.dart';

class ReceiptsPage extends StatefulWidget {
  const ReceiptsPage({super.key});

  @override
  State<ReceiptsPage> createState() => _ReceiptsPageState();
}

class _ReceiptsPageState extends State<ReceiptsPage> {
  late AnimateIconController _animationController;

  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimateIconController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const Center(child: Text('Receipts Page')),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isExpanded)
            FloatingActionButton(
              onPressed: () {},
              mini: true,
              child: const Icon(Icons.add_a_photo),
            ),
          const SizedBox(height: 8),
          if (_isExpanded)
            FloatingActionButton(
              onPressed: () {},
              mini: true,
              child: const Icon(Icons.add),
            ),
          const SizedBox(height: 8),
          FloatingActionButton(
            onPressed: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: AnimateIcons(
              controller: _animationController,
              startIcon: Icons.add,
              endIcon: Icons.close,
              onStartIconPress: () {
                setState(() {
                  _isExpanded = true;
                });
                return true;
              },
              onEndIconPress: () {
                setState(() {
                  _isExpanded = false;
                });
                return true;
              },
              duration: Duration(milliseconds: 200),
              clockwise: false,
            ),
          ),
        ],
      ),
    );
  }
}
