import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/vertical_provider.dart';

/// Privremeno tijelo svake rute — postoji dok taskovi 10 i 11 ne napišu prave ekrane.
///
/// Prikazuje putanju da bi se na webu vidjelo da URL zaista prati ekran, i CTA iz
/// `vertical.terms` da lanac uspostavljen u tasku 06 ostane dokazan i nakon uvođenja routera.
class PlaceholderScreen extends ConsumerWidget {
  const PlaceholderScreen({required this.title, required this.path, super.key});

  final String title;
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final vertical = verticalOf(ref);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(path, style: theme.textTheme.bodySmall),
              const SizedBox(height: 24),
              Text(vertical.terms.bookCta, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
