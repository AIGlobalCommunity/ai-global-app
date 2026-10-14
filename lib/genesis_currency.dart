import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'genesis_language.dart';

/// Currency selection uses the device/browser locale as a suggestion, NOT GPS.
/// Users can override the region when their actual country differs.
class GenesisCurrency {
  static const key = 'genesis_currency_region_v1';
  static final region = ValueNotifier<String>('auto');
  static const europe = <String>{
    'AL','AD','AT','BE','BA','BG','BY','CH','CY','CZ','DE','DK','EE',
    'ES','FI','FR','GR','HR','HU','IE','IS','IT','LI','LT','LU','LV',
    'MC','MD','ME','MK','MT','NL','NO','PL','PT','RO','RS','SE','SI',
    'SK','SM','UA','VA','XK',
  };

  static String currencyForCountry(String? countryCode) {
    final code = (countryCode ?? '').trim().toUpperCase();
    if (code == 'PL') return 'PLN';
    if (code == 'GB' || code == 'UK') return 'GBP';
    if (europe.contains(code)) return 'EUR';
    return 'USD';
  }

  static String currencyForLanguage(String language) {
    if (language == 'pl') return 'PLN';
    if (language == 'en') return 'USD';
    if (europe.contains(_languageCountry[language])) return 'EUR';
    return 'USD';
  }

  static const _languageCountry = <String, String>{
    'de':'DE','fr':'FR','es':'ES','pt':'PT','ru':'RU',
    'zh':'CN','hi':'IN','ar':'SA',
  };

  static String get deviceCountry =>
      PlatformDispatcher.instance.locale.countryCode?.toUpperCase() ?? '';

  static String get currency {
    if (region.value == 'PL') return 'PLN';
    if (region.value == 'GB') return 'GBP';
    if (region.value == 'EU') return 'EUR';
    if (region.value == 'WORLD') return 'USD';
    final country = deviceCountry;
    if (country.isNotEmpty) return currencyForCountry(country);
    return currencyForLanguage(GenesisLanguage.selected.value);
  }

  static String get symbol => switch (currency) {
    'PLN' => 'zł', 'EUR' => '€', 'GBP' => '£', _ => '\$',
  };

  static String get regionLabel => switch (region.value) {
    'PL' => 'Polska',
    'GB' => 'United Kingdom',
    'EU' => 'Europa poza Polską i UK',
    'WORLD' => 'Ameryki i pozostałe kraje',
    _ => 'Automatycznie (język urządzenia)',
  };

  static Future<void> initialize() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(key);
      if (saved != null && {'auto','PL','GB','EU','WORLD'}.contains(saved)) {
        region.value = saved;
      }
    } catch (_) { /* private browsing can disable storage */ }
  }

  static Future<void> choose(String value) async {
    if (!{'auto','PL','GB','EU','WORLD'}.contains(value)) return;
    region.value = value;
    try {
      await (await SharedPreferences.getInstance()).setString(key, value);
    } catch (_) { /* selection remains active this session */ }
  }
}

class GenesisCurrencyPanel extends StatelessWidget {
  const GenesisCurrencyPanel({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: GenesisCurrency.region,
    builder: (context, selected, _) => ValueListenableBuilder<String>(
      valueListenable: GenesisLanguage.selected,
      builder: (context, lang, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(GenesisLanguage.copy('WALUTA WSPARCIA', 'SUPPORT CURRENCY'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(GenesisLanguage.copy(
              'Waluta według regionu: Polska — PLN, Wielka Brytania — GBP, '
              'pozostała Europa — EUR, Ameryki i reszta świata — USD.',
              'Currency by region: Poland — PLN, United Kingdom — GBP, '
              'rest of Europe — EUR, Americas and other countries — USD.')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selected,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: GenesisLanguage.copy('Twój region', 'Your region')),
              items: const [
                DropdownMenuItem(value: 'auto', child: Text('Auto (device locale)')),
                DropdownMenuItem(value: 'PL', child: Text('Polska · PLN')),
                DropdownMenuItem(value: 'GB', child: Text('United Kingdom · GBP')),
                DropdownMenuItem(value: 'EU', child: Text('Europa / Europe · EUR')),
                DropdownMenuItem(value: 'WORLD', child: Text('Americas / Rest of world · USD')),
              ],
              onChanged: (value) { if (value != null) GenesisCurrency.choose(value); },
            ),
            const SizedBox(height: 10),
            Text('${GenesisLanguage.copy('Wybrana waluta', 'Selected currency')}: '
              '${GenesisCurrency.currency} (${GenesisCurrency.symbol})',
              style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 7),
            Text(GenesisLanguage.copy(
              'Wykrywanie automatyczne korzysta z języka i regionu urządzenia, '
              'nie z lokalizacji GPS. Jeśli jest błędne, wybierz region ręcznie.',
              'Automatic detection uses your device language/region, not GPS. '
              'If it is incorrect, select your region manually.'),
              style: const TextStyle(fontSize: 12)),
          ]),
        ),
      ),
    ),
  );
}
