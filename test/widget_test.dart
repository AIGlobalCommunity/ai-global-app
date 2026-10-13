import 'package:ai_global_community/agc_countdown.dart';
import 'package:ai_global_community/main.dart';
import 'package:ai_global_community/genesis_artwork.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  agcCountdownUnitTests();
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

void agcCountdownUnitTests() {
  test('Launch is not announced when Supabase has no date', () {
    expect(officialLaunchFromRow({'official_launch_at': null}), isNull);
    expect(officialLaunchFromRow(null), isNull);
  });

  test('Manifest date uses calendar months, including February', () {
    final start = DateTime.utc(2028, 5, 31, 12, 45);
    expect(agcAddCalendarMonths(start, 9), DateTime.utc(2029, 2, 28, 12, 45));
    expect(agcAddCalendarMonths(start, 36), DateTime.utc(2031, 5, 31, 12, 45));
  });

  test('Countdown avoids negative time', () {
    expect(agcDurationLabel(const Duration(seconds: -1)), '00d 00h 00m 00s');
    expect(agcDurationLabel(const Duration(days: 3, hours: 2, minutes: 1, seconds: 9)),
      '3d 02h 01m 09s');
  });
}
