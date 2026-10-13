import 'package:ai_global_community/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Genesis home and navigation render', (tester) async {
    await tester.pumpWidget(const AgcApp());
    expect(find.text('THE GENESIS'), findsOneWidget);
    await tester.tap(find.text('Ranking'));
    await tester.pumpAndSettle();
    expect(find.text('GENESIS RANKING'), findsOneWidget);
  });
}
