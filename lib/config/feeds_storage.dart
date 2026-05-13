import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'app_config.dart';

Future<File> getFeedsFile() async {
  final dir = await getStorageDirectory();
  return File('${dir.path}/feeds.json');
}

Future<List<String>> loadFeeds() async {
  try {
    final file = await getFeedsFile();
    if (await file.exists()) {
      final contents = await file.readAsString();
      final List<dynamic> json = jsonDecode(contents);
      return List<String>.from(json);
    }
  } catch (e) {
    debugPrint('Error loading feeds: $e');
  }
  return [];
}

Future<void> saveFeeds(List<String> feeds) async {
  try {
    final file = await getFeedsFile();
    await file.writeAsString(jsonEncode(feeds));
  } catch (e) {
    debugPrint('Error saving feeds: $e');
  }
}
