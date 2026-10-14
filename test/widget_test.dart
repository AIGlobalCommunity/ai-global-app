import 'package:ai_global_community/agc_countdown.dart';
import 'package:ai_global_community/main.dart';
import 'package:ai_global_community/agc_registration.dart';
import 'package:ai_global_community/genesis_status_guide.dart';
import 'package:ai_global_community/genesis_artwork.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  agcCountdownUnitTests();
  group('Formularz rejestracji', () {
    test('Email, nick and password require valid values', () {
      expect(validateAgcEmail(''), isNotNull);
      expect(validateAgcEmail('brak-malpy'), isNotNull);
      expect(validateAgcEmail('user@example.com'), isNull);
      expect(validateAgcNick(''), isNotNull);
      expect(validateAgcNick('nick ze spacją'), isNotNull);
      expect(validateAgcNick('Genesis_123'), isNull);
      expect(validateAgcPassword('12345'), isNotNull);
      expect(validateAgcPassword('longpassword123'), isNull);
    });

    testWidgets('Sign-up is a separate page with all fields', (tester) async {
      await tester.pumpWidget(MaterialApp(home: AgcRegistrationPage(
        onSignUp: (email, password, nick, showNickPublicly) async {},
      )));
      expect(find.text('UTWÓRZ KONTO GENESIS'), findsOneWidget);
      expect(find.byKey(const Key('signup_nick')), findsOneWidget);
      expect(find.byKey(const Key('signup_show_nick_publicly')), findsOneWidget);
      expect(find.byKey(const Key('signup_email')), findsOneWidget);
      expect(find.byKey(const Key('signup_password')), findsOneWidget);
      expect(find.byKey(const Key('signup_confirm_password')), findsOneWidget);
    });
  });
  testWidgets('Without initialized authentication, community is not accessible',
      (tester) async {
    await tester.pumpWidget(const AgcApp());
    expect(find.textContaining('Połączenie z Supabase jest niedostępne'), findsOneWidget);
    expect(find.text('GENESIS RANKING'), findsNothing);
  });

  testWidgets('Genesis tiers and GP rules expand on demand', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: GenesisStatusGuide(),
    ))));
    expect(find.textContaining('CZTERY STATUSY CZŁONKOWSKIE'), findsNothing);
    await tester.tap(find.textContaining('ERA GENESIS — STATUSY I ZASADY'));
    await tester.pumpAndSettle();
    expect(find.text('Genesis Eternal'), findsOneWidget);
    expect(find.text('Gold Genesis'), findsOneWidget);
    expect(find.text('Silver Genesis'), findsOneWidget);
    expect(find.text('Global Member'), findsOneWidget);
  });

  testWidgets('Genesis vector illustration renders across screen sizes',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: GenesisArtwork(size: 230)),
    ));
    expect(find.byType(SvgPicture), findsOneWidget);
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
