import 'package:flutter/material.dart';

import 'color_picker_dialog.dart';

class SettingsDialog extends StatefulWidget {
  final double initialSpeed;
  final Color initialForegroundColor;
  final Color initialBackgroundColor;
  final String initialSeparator;
  final int initialRefreshInterval;
  final bool initialShowFeedTitle;
  final void Function({
    required double speed,
    required Color foregroundColor,
    required Color backgroundColor,
    required String separator,
    required int refreshIntervalMinutes,
    required bool showFeedTitle,
  })
  onSettingsChanged;

  const SettingsDialog({
    super.key,
    required this.initialSpeed,
    required this.initialForegroundColor,
    required this.initialBackgroundColor,
    required this.initialSeparator,
    required this.initialRefreshInterval,
    required this.initialShowFeedTitle,
    required this.onSettingsChanged,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late double _speed;
  late Color _foregroundColor;
  late Color _backgroundColor;
  late TextEditingController _separatorController;
  late int _refreshIntervalMinutes;
  late bool _showFeedTitle;

  @override
  void initState() {
    super.initState();
    _speed = widget.initialSpeed;
    _foregroundColor = widget.initialForegroundColor;
    _backgroundColor = widget.initialBackgroundColor;
    _separatorController = TextEditingController(text: widget.initialSeparator);
    _refreshIntervalMinutes = widget.initialRefreshInterval;
    _showFeedTitle = widget.initialShowFeedTitle;
  }

  @override
  void dispose() {
    _separatorController.dispose();
    super.dispose();
  }

  void _emitSettingsChanged() {
    final separator = _separatorController.text.trim().isEmpty
        ? '+++'
        : _separatorController.text.trim();

    widget.onSettingsChanged(
      speed: _speed,
      foregroundColor: _foregroundColor,
      backgroundColor: _backgroundColor,
      separator: separator,
      refreshIntervalMinutes: _refreshIntervalMinutes,
      showFeedTitle: _showFeedTitle,
    );
  }

  Future<void> _pickForegroundColor() async {
    final selected = await showDialog<Color>(
      context: context,
      builder: (context) => ColorPickerDialog(initialColor: _foregroundColor),
    );
    if (selected != null) {
      setState(() {
        _foregroundColor = selected;
      });
      _emitSettingsChanged();
    }
  }

  Future<void> _pickBackgroundColor() async {
    final selected = await showDialog<Color>(
      context: context,
      builder: (context) => ColorPickerDialog(initialColor: _backgroundColor),
    );
    if (selected != null) {
      setState(() {
        _backgroundColor = selected;
      });
      _emitSettingsChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final availableHeight = screenSize.height - 48;
    final targetHeight = availableHeight.clamp(520.0, 620.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SizedBox(
        width: 700,
        height: targetHeight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: screenSize.width * 0.92,
            minHeight: targetHeight,
            maxHeight: targetHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Appearance',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Text('Textgeschwindigkeit: ${_speed.toStringAsFixed(0)} px/s'),
                Slider(
                  value: _speed,
                  min: 10,
                  max: 300,
                  divisions: 58,
                  label: _speed.toStringAsFixed(0),
                  onChanged: (value) {
                    setState(() {
                      _speed = value;
                    });
                    _emitSettingsChanged();
                  },
                ),
                const SizedBox(height: 8),
                _buildColorChooser(
                  label: 'Textfarbe Vordergrund',
                  color: _foregroundColor,
                  onPressed: _pickForegroundColor,
                ),
                const SizedBox(height: 8),
                _buildColorChooser(
                  label: 'Textfarbe Hintergrund',
                  color: _backgroundColor,
                  onPressed: _pickBackgroundColor,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _separatorController,
                  decoration: const InputDecoration(
                    labelText: 'Trennzeichen zwischen den Entries',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _emitSettingsChanged(),
                ),
                const SizedBox(height: 16),
                Text(
                  'Feed-Aktualisierungsintervall: $_refreshIntervalMinutes min',
                ),
                Slider(
                  value: _refreshIntervalMinutes.toDouble(),
                  min: 1,
                  max: 60,
                  divisions: 59,
                  label: '$_refreshIntervalMinutes min',
                  onChanged: (value) {
                    setState(() {
                      _refreshIntervalMinutes = value.round();
                    });
                    _emitSettingsChanged();
                  },
                ),
                const Spacer(),
                SwitchListTile(
                  title: const Text('Show feed title'),
                  subtitle: const Text(
                    'Display the feed source name before each headline',
                  ),
                  value: _showFeedTitle,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (value) {
                    setState(() => _showFeedTitle = value);
                    _emitSettingsChanged();
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorChooser({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 8),
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.black26),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: onPressed, child: const Text('Choose')),
      ],
    );
  }
}
