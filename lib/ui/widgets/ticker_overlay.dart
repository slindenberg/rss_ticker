import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Floating dropdown menu shown when the user clicks the menu button.
///
/// Emits string action keys (e.g. `'refresh'`, `'settings'`, `'exit'`)
/// via [onMenuSelected], keeping the overlay itself free of business logic.
class TickerOverlay extends StatelessWidget {
  /// Callback invoked with the action key of the selected menu item.
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
