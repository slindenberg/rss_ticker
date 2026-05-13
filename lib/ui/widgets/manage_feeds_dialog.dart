import 'package:flutter/material.dart';

class ManageFeedsDialog extends StatefulWidget {
  final List<String> feeds;
  final ValueChanged<List<String>> onFeedsChanged;

  const ManageFeedsDialog({
    super.key,
    required this.feeds,
    required this.onFeedsChanged,
  });

  @override
  State<ManageFeedsDialog> createState() => _ManageFeedsDialogState();
}

class _ManageFeedsDialogState extends State<ManageFeedsDialog> {
  late List<String> _feeds;
  final Set<int> _selectedIndices = {};
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _feeds = List.from(widget.feeds);
  }

  void _addFeed() {
    final normalizedInput = _urlController.text.trim();
    if (normalizedInput.isNotEmpty) {
      setState(() {
        _feeds.add(normalizedInput);
        _urlController.clear();
        _selectedIndices.clear();
      });
      widget.onFeedsChanged(_feeds);
    }
  }

  void _removeSelected() {
    setState(() {
      _feeds = _feeds
          .asMap()
          .entries
          .where((entry) => !_selectedIndices.contains(entry.key))
          .map((entry) => entry.value)
          .toList();
      _selectedIndices.clear();
    });
    widget.onFeedsChanged(_feeds);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        height: 400,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Manage Feeds',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Select')),
                    DataColumn(label: Text('Nr.')),
                    DataColumn(label: Text('URL')),
                  ],
                  rows: _feeds.asMap().entries.map((entry) {
                    final index = entry.key;
                    final url = entry.value;
                    return DataRow(
                      cells: [
                        DataCell(
                          Checkbox(
                            value: _selectedIndices.contains(index),
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  _selectedIndices.add(index);
                                } else {
                                  _selectedIndices.remove(index);
                                }
                              });
                            },
                          ),
                        ),
                        DataCell(Text('${index + 1}')),
                        DataCell(
                          SizedBox(
                            width: 400,
                            child: Text(url, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'New Feed URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _addFeed, child: const Text('+')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _removeSelected,
                  child: const Text('-'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
