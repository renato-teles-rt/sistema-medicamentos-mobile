import 'package:flutter_test/flutter_test.dart';
import 'package:cuidamed_mobile/main.dart';

void main() {
  testWidgets('Renderiza a tela inicial do CuidaMed 50+', (WidgetTester tester) async {
    await tester.pumpWidget(const CuidaMedApp());
    expect(find.text('CuidaMed 50+'), findsOneWidget);
  });
}