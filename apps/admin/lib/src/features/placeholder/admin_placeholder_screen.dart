import 'package:flutter/material.dart';

/// Privremeno tijelo svake admin rute — ekrane pise Sprint 2.
class AdminPlaceholderScreen extends StatelessWidget {
  const AdminPlaceholderScreen({
    required this.title,
    required this.path,
    super.key,
  });

  final String title;
  final String path;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(path, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
