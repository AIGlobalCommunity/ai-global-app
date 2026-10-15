import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'agc_luxury_theme.dart';

/// Two supported interface languages: Polish and English.
class GenesisLanguage {
  static final selected = ValueNotifier<String>('pl');
  static const storageKey = 'genesis_language_v1';
  static const translations = {
  'en': {
    'name': 'English',
    'login': 'Log in',
    'signup': 'Create account',
    'language': 'Language',
    'account': 'Account',
    'ranking': 'Ranking',
    'simulator': 'Simulator',
    'invite': 'Invite friends',
    'email': 'Email',
    'password': 'Password',
    'share': 'Share',
    'logout': 'Log out',
    'copy': 'Copy my link',
    'confirm': 'Confirm referral code',
    'welcome': 'Welcome to THE GENESIS ERA'
  },
  'pl': {
    'name': 'Polski',
    'login': 'Zaloguj się',
    'signup': 'Utwórz konto',
    'language': 'Język',
    'account': 'Konto',
    'ranking': 'Ranking',
    'simulator': 'Symulator',
    'invite': 'Zaproś znajomych',
    'email': 'E-mail',
    'password': 'Hasło',
    'share': 'Udostępnij',
    'logout': 'Wyloguj',
    'copy': 'Kopiuj mój link',
    'confirm': 'Zatwierdź kod polecenia',
    'welcome': 'Witaj w THE GENESIS ERA'
  }
  };  /// Polish source and English fallback for long-form copy until each locale is reviewed.
  static String copy(String polish, String english) =>
      selected.value == 'pl' ? polish : english;

  static String t(String key) =>
      translations[selected.value]?[key] ??
      translations['en']?[key] ?? key;
  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(storageKey);
      if (saved != null && translations.containsKey(saved)) selected.value = saved;
    } catch (_) { /* local storage may be unavailable in private browsing */ }
  }
  static Future<void> setLanguage(String code) async {
    if (!translations.containsKey(code)) return;
    selected.value = code;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, code);
    } catch (_) { /* choice still applies to current session */ }
  }
}

class GenesisLanguagePicker extends StatelessWidget {
  const GenesisLanguagePicker({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: GenesisLanguage.selected,
    builder: (context, code, _) => PopupMenuButton<String>(
      tooltip: GenesisLanguage.t('language'),
      onSelected: GenesisLanguage.setLanguage,
      constraints: const BoxConstraints(maxHeight: 440, minWidth: 240),
      initialValue: code,
      itemBuilder: (context) => [
        for (final entry in GenesisLanguage.translations.entries)
          PopupMenuItem<String>(
            value: entry.key,
            child: Row(children: [
              if (entry.key == code) const Icon(Icons.check, color: AgcLuxury.champagne, size: 18)
              else const SizedBox(width: 18),
              const SizedBox(width: 10),
              Expanded(child: Text('${entry.value['name']} (${entry.key.toUpperCase()})')),
            ]),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.language, color: AgcLuxury.champagne, size: 20),
          const SizedBox(width: 6),
          Text(code.toUpperCase(), style: const TextStyle(
            color: AgcLuxury.champagne, fontWeight: FontWeight.bold)),
          const Icon(Icons.arrow_drop_down, color: AgcLuxury.champagne),
        ]),
      ),
    ),
  );
}
