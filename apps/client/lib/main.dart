import 'package:flutter/material.dart';

void main() => runApp(const TenantPreviewApp());

/// Sprint 0 proves that the same entrypoint accepts each generated tenant build.
class TenantPreviewApp extends StatelessWidget {
  const TenantPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    const salonId = String.fromEnvironment('SALON_ID');
    const appName = String.fromEnvironment('APP_NAME', defaultValue: 'Salon');
    const theme = String.fromEnvironment(
      'THEME',
      defaultValue: 'modern_barber',
    );
    const primary = String.fromEnvironment(
      'PRIMARY_COLOR',
      defaultValue: '#C9A227',
    );
    final seed = Color(int.parse(primary.replaceFirst('#', 'FF'), radix: 16));
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: appName,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: theme == 'modern_barber'
              ? Brightness.dark
              : Brightness.light,
        ),
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text(appName)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.content_cut, size: 72),
                const SizedBox(height: 24),
                const Text(appName),
                const SizedBox(height: 12),
                Text(
                  salonId.isEmpty
                      ? 'Nedostaje SALON_ID konfiguracija.'
                      : 'Hello, $salonId',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
