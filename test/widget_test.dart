import 'package:ai_global_community/main.dart';
import 'package:ai_global_community/genesis_artwork.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Without initialized authentication, community is not accessible',
      (tester) async {
    await tester.pumpWidget(const AgcApp());
    expect(find.textContaining('Połączenie z Supabase jest niedostępne'), findsOneWidget);
    expect(find.text('GENESIS RANKING'), findsNothing);
  });

  testWidgets('Genesis vector illustration renders across screen sizes',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: GenesisArtwork(size: 230)),
    ));
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byType(GenesisArtwork), findsOneWidget);
  });
}
