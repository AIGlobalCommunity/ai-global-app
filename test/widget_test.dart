import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_global_community/main.dart';
import 'package:ai_global_community/feed.dart';
import 'package:ai_global_community/social.dart';

void main() {
 test('community date formatting is available', () {
  expect(niceDate('2026-10-16T00:00:00Z'),isNotEmpty);
 });
 testWidgets('landing shows graphics and direct login call to action',(tester) async {
  var tapped=false;
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(child:AGCHero(
   loggedIn:false,onPost:(){},onJoin:(){tapped=true;},
  )))));
  expect(find.text('Zaloguj się / Dołącz'),findsOneWidget);
  expect(find.byIcon(Icons.public_rounded),findsOneWidget);
  await tester.tap(find.text('Zaloguj się / Dołącz'));
  expect(tapped,isTrue);
 });
 testWidgets('login form shows email, password and registration',(tester) async {
  await tester.pumpWidget(const MaterialApp(home:Scaffold(body:AuthScreen())));
  expect(find.text('Adres e-mail'),findsOneWidget);
  expect(find.text('Hasło'),findsOneWidget);
  expect(find.text('Nie masz konta? Zarejestruj się'),findsOneWidget);
 });
}
