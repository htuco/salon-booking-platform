import 'package:client/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('A build without a tenant identifies missing configuration', (
    tester,
  ) async {
    await tester.pumpWidget(const TenantPreviewApp());
    expect(find.text('Nedostaje SALON_ID konfiguracija.'), findsOneWidget);
  });
}
