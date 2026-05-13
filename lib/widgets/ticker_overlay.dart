import 'package:flutter/material.dart';

import 'app_theme.dart';

class TickerOverlay extends StatelessWidget {
  final void Function(String) onMenuSelected;

  const TickerOverlay({super.key, required this.onMenuSelected});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMenuItem('Refresh', 'refresh'),
          _buildMenuItem('Manage Feeds', 'manage_feeds'),
          const Divider(height: 1),
          _buildMenuItem('Settings', 'settings'),
          _buildMenuItem('Help', 'help'),
          const Divider(height: 1),
          _buildMenuItem('Exit', 'exit'),
        ],
      ),
    );
  }

  Widget _buildMenuItem(String label, String value) {
    return InkWell(
      onTap: () => onMenuSelected(value),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Text(label, style: TickerTheme.menuItemText),
      ),
    );
  }
}
