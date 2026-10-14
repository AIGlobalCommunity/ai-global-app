import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'genesis_language.dart';

/// Automatically chooses a currency using the browser/device country.
/// Device locale is a region hint, not precise GPS geolocation.
class GenesisCurrency {
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

  static const _languageCountry = <String, String>{
    'pl': 'PL', 'de': 'DE', 'fr': 'FR', 'es': 'ES', 'pt': 'PT',
    'ru': 'RU', 'zh': 'CN', 'hi': 'IN', 'ar': 'SA',
  };

  static String currencyForLanguage(String language) =>
      currencyForCountry(_languageCountry[language]);

  static String get deviceCountry =>
      PlatformDispatcher.instance.locale.countryCode?.toUpperCase() ?? '';

  static String get currency {
    final country = deviceCountry;
    if (country.isNotEmpty) return currencyForCountry(country);
    return currencyForLanguage(GenesisLanguage.selected.value);
  }

  static String get symbol => switch (currency) {
    'PLN' => 'zł', 'EUR' => '€', 'GBP' => '£', _ => '\$',
  };
}

/// Display only: currency is never manually selectable.
class GenesisCurrencyPanel extends StatelessWidget {
  const GenesisCurrencyPanel({super.key});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(GenesisLanguage.copy('WALUTA WSPARCIA', 'SUPPORT CURRENCY'),
          style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('${GenesisLanguage.copy('Waluta wybrana automatycznie', 'Automatically selected currency')}: '
          '${GenesisCurrency.currency} (${GenesisCurrency.symbol})',
          style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(GenesisLanguage.copy(
          'Polska — PLN · Wielka Brytania — GBP · pozostała Europa — EUR · '
          'Ameryki i reszta świata — USD. Wykrywanie opiera się na regionie '
          'urządzenia, a gdy go brak — na języku aplikacji. Nie korzysta z GPS.',
          'Poland — PLN · UK — GBP · rest of Europe — EUR · '
          'Americas and other countries — USD. Detection uses the device '
          'region, or the app language if no region is available. No GPS is used.'),
          style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ]),
    ),
  );
}
