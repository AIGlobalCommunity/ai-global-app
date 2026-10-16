import 'package:flutter_test/flutter_test.dart';
import 'package:ai_global_community/social.dart';

void main() {
 test('community date formatting is available', () {
  expect(niceDate('2026-10-16T00:00:00Z'),isNotEmpty);
 });
}
