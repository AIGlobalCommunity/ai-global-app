import 'package:ai_global_community/agc_countdown.dart';
import 'package:ai_global_community/agc_backend.dart';
import 'package:ai_global_community/genesis_language.dart';
import 'package:ai_global_community/genesis_currency.dart';
import 'package:ai_global_community/genesis_rank_simulator.dart';
import 'package:ai_global_community/genesis_invites.dart';
import 'package:ai_global_community/main.dart';
import 'package:ai_global_community/agc_registration.dart';
import 'package:ai_global_community/genesis_status_guide.dart';
import 'package:ai_global_community/genesis_artwork.dart';
import 'package:ai_global_community/genesis_mission.dart';
import 'package:ai_global_community/genesis_support.dart';
import 'package:ai_global_community/genesis_discussions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  agcCountdownUnitTests();
  test('Real leaderboard sorting options use stable database columns', () {
    expect(AgcRankingSort.pointsHigh.column, 'genesis_points');
    expect(AgcRankingSort.pointsHigh.ascending, false);
    expect(AgcRankingSort.newest.column, 'created_at');
    expect(AgcRankingSort.oldest.ascending, true);
    expect(AgcRankingSort.numberLow.column, 'member_number');
    expect(AgcRankingSort.numberHigh.ascending, false);
    expect(AgcRankingSort.nickname.column, 'handle');
  });
  test('Registration date formats and invalid dates safely', () {
    expect(agcRegistrationDate('2026-10-14'), '14.10.2026');
    expect(agcRegistrationDate(null), '—');
    expect(agcRegistrationDate('not a date'), '—');
  });

  test('Real simulator baseline sums only recorded GP', () {
    const snapshot = GenesisActualSnapshot(
      handle: 'Member',
      pointsByReason: {'signup': 100, 'verified_referral': 200, 'contribution': 30},
      actualRank: 2,
      rankingScores: [450, 120, 100],
    );
    expect(snapshot.total, 330);
    expect(snapshot.pointsFor('verified_referral'), 200);
    expect(snapshot.pointsFor('contribution'), 30);
    expect(snapshot.actualRank, 2);
    expect(snapshot.projectedRank(330), 2);
    expect(snapshot.projectedRank(480), 1);
  });

  test('Currency routing follows country, not selected app language', () {
    expect(GenesisCurrency.currencyForCountry('PL'), 'PLN');
    expect(GenesisCurrency.currencyForCountry('GB'), 'GBP');
    expect(GenesisCurrency.currencyForCountry('UK'), 'GBP');
    expect(GenesisCurrency.currencyForCountry('DE'), 'EUR');
    expect(GenesisCurrency.currencyForCountry('FR'), 'EUR');
    expect(GenesisCurrency.currencyForCountry('CH'), 'EUR');
    expect(GenesisCurrency.currencyForCountry('US'), 'USD');
    expect(GenesisCurrency.currencyForCountry('CA'), 'USD');
    expect(GenesisCurrency.currencyForCountry('BR'), 'USD');
    expect(GenesisCurrency.currencyForCountry('JP'), 'USD');
    expect(GenesisCurrency.currencyForCountry(null), 'USD');
  });
  test('Language fallback selects a currency when device region is absent', () {
    expect(GenesisCurrency.currencyForLanguage('pl'), 'PLN');
    expect(GenesisCurrency.currencyForLanguage('de'), 'EUR');
    expect(GenesisCurrency.currencyForLanguage('en'), 'USD');
    expect(GenesisCurrency.currencyForLanguage('zh'), 'USD');
  });
  testWidgets('Automatic currency panel offers no manual selector', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: GenesisCurrencyPanel())));
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
  });

  test('Language picker exposes only Polish and English', () {
    expect(GenesisLanguage.translations.length, 2);
    expect(GenesisLanguage.translations['pl']?['login'], 'Zaloguj się');
    expect(GenesisLanguage.translations['en']?['signup'], 'Create account');
    expect(GenesisLanguage.translations.keys.toSet(), {'pl', 'en'});
  });
  testWidgets('Language menu can select English', (tester) async {
    GenesisLanguage.selected.value = 'pl';
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: GenesisLanguagePicker())));
    await tester.tap(find.byType(GenesisLanguagePicker));
    await tester.pumpAndSettle();
    expect(find.textContaining('English'), findsWidgets);
    await tester.tap(find.textContaining('English').last);
    await tester.pumpAndSettle();
    expect(GenesisLanguage.selected.value, 'en');
    GenesisLanguage.selected.value = 'pl';
  });
  testWidgets('Mission copy updates immediately when switching languages',
      (tester) async {
    GenesisLanguage.selected.value = 'pl';
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: ValueListenableBuilder<String>(
        valueListenable: GenesisLanguage.selected,
        builder: (context, language, _) => const SingleChildScrollView(
          child: GenesisMission(compact: true)),
      ),
    )));
    expect(find.text('DLACZEGO POWSTAJE THE GENESIS ERA?'), findsOneWidget);
    GenesisLanguage.selected.value = 'en';
    await tester.pump();
    expect(find.text('WHY DOES THE GENESIS ERA EXIST?'), findsOneWidget);
    GenesisLanguage.selected.value = 'pl';
  });

  testWidgets('Genesis cards do not overflow on narrow phones', (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: SingleChildScrollView(child: Padding(
        padding: EdgeInsets.all(10),
        child: GenesisPanel(
          icon: Icons.forum,
          title: 'A VERY LONG GENESIS COMMUNITY HEADING FOR SMALL PHONES',
          body: 'An unusually long paragraph should wrap without horizontal overflow.',
        ),
      )),
    )));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Support describes platform development and inactive payments',
      (tester) async {
    GenesisLanguage.selected.value = 'pl';
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: SingleChildScrollView(child: GenesisSupport()))));
    await tester.pump();
    expect(find.text('WSPARCIE ROZWOJU PLATFORMY'), findsOneWidget);
    expect(find.textContaining('Wpłaty nie są jeszcze uruchomione'), findsOneWidget);
    expect(find.textContaining('pomaga rozwijać platformę'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
  });
  test('Forum accepts safe HTTPS article and video links', () {
    expect(genesisExternalUrl('https://example.org/ai')?.host, 'example.org');
    expect(genesisExternalUrl('http://example.org'), isNull);
    expect(genesisExternalUrl('javascript:alert(1)'), isNull);
    expect(genesisExternalUrl('https://user:pass@example.org'), isNull);
    expect(genesisYoutubeId(Uri.parse(
      'https://www.youtube.com/watch?v=dQw4w9WgXcQ')), 'dQw4w9WgXcQ');
    expect(genesisYoutubeId(Uri.parse(
      'https://youtu.be/dQw4w9WgXcQ')), 'dQw4w9WgXcQ');
    expect(genesisYoutubeId(Uri.parse('https://example.org/watch')), isNull);
  });
  test('Discussion and support pages are available as dedicated widgets', () {
    expect(const GenesisDiscussions(), isA<StatefulWidget>());
    expect(const GenesisSupport(), isA<StatelessWidget>());
  });
  test('Referral links use the registered website and encode the invite code', () {
    final link = Uri.parse(genesisInviteLink('ABC123DEF0'));
    expect(link.scheme, 'https');
    expect(link.host, 'aiglobalcommunity.github.io');
    expect(link.queryParameters['ref'], 'ABC123DEF0');
  });
  testWidgets('Invite panel displays a personal link and sharing controls', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: SingleChildScrollView(child: GenesisInvitePanel(
        code: 'ABC123DEF0', confirmedCount: 2)),
    )));
    expect(find.byKey(const Key('genesis_invite_link')), findsOneWidget);
    expect(find.textContaining('Potwierdzone polecenia: 2'), findsOneWidget);
    expect(find.text('Zaproś e-mailem'), findsOneWidget);
    expect(find.text('Facebook'), findsOneWidget);
  });
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
      // ListView builds only visible children. Scroll to the final field
      // rather than assuming every form element is mounted at once.
      await tester.scrollUntilVisible(
        find.byKey(const Key('signup_confirm_password')),
        180,
        scrollable: find.byType(Scrollable).first,
      );
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
