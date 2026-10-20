import 'package:flutter/material.dart';
import 'genesis_language.dart';

/// Public concept preview. No payments, paid placements or sponsors are active.
class GenesisFinancialSupport extends StatelessWidget {
  const GenesisFinancialSupport({super.key, this.preview = false});
  final bool preview;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(GenesisLanguage.copy('ŚCIANA FUNDATORÓW GENESIS',
          'GENESIS FOUNDERS WALL'), textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
            color: Color(0xFFD8B66A))),
        const SizedBox(height: 12),
        Text(GenesisLanguage.copy(
          'Wspólnie budujemy niezależną przestrzeń rozmowy o przyszłości AI. '
          'Instytucje, firmy i osoby prywatne będą mogły dobrowolnie wspierać '
          'rozwój platformy. W zamian, za zgodą i po weryfikacji, '
          'będziemy mogli podziękować im na publicznej ścianie fundatorów.',
          'We are building an independent space to discuss the future of AI. '
          'Institutions, businesses and individuals may voluntarily support '
          'the platform. With their consent and after review, we may thank '
          'them on a public founders wall.'), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        Text(GenesisLanguage.copy('WIZUALIZACJA PRZYSZŁEJ ŚCIANY',
          'FUTURE WALL PREVIEW'), style: const TextStyle(
          color: Color(0xFFD8B66A), fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(GenesisLanguage.copy(
          'Poniższe pola są przykładowe. Nie oznaczają wpłat ani rezerwacji.',
          'These are example spaces. No payments or reservations are implied.'),
          style: const TextStyle(fontSize: 12, color: Colors.white70)),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth < 360 ? 2
            : constraints.maxWidth < 600 ? 3 : 4;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 12,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns, crossAxisSpacing: 8,
              mainAxisSpacing: 8, childAspectRatio: 1.35),
            itemBuilder: (context, index) => Container(
              decoration: BoxDecoration(
                color: index % 3 == 0
                  ? const Color(0xFF263C54) : const Color(0xFF16273B),
                border: Border.all(color: const Color(0xFFD8B66A)
                  .withValues(alpha: .4)),
                borderRadius: BorderRadius.circular(12)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_business_outlined,
                    color: Color(0xFFD8B66A), size: 24),
                  const SizedBox(height: 5),
                  Text(GenesisLanguage.copy('Miejsce na instytucję',
                    'Institution space'), textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11)),
                ]),
            ),
          );
        }),
        const SizedBox(height: 20),
        Card(child: Padding(padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(GenesisLanguage.copy('JAK BĘDZIE DZIAŁAĆ WSPARCIE?',
              'HOW WILL SUPPORT WORK?'), style: const TextStyle(
                color: Color(0xFFD8B66A), fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(GenesisLanguage.copy(
              '1. Dobrowolne wsparcie rozwoju platformy.\n'
              '2. Możliwość zgłoszenia nazwy i logo do moderacji.\n'
              '3. Publiczny kafelek z podziękowaniem po akceptacji.\n'
              '4. Przejrzyste informacje o przeznaczeniu środków.',
              '1. Voluntary support for platform development.\n'
              '2. Optional name and logo submission for review.\n'
              '3. A public acknowledgement tile after approval.\n'
              '4. Transparent reporting on how funds are used.')),
          ]))),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(16),
          child: Text(GenesisLanguage.copy(
            'Płatności i rezerwacje miejsc nie są jeszcze aktywne. '
            'Wpłaty nie dają punktów GP, praw głosu, wpływu na Manifest '
            'ani gwarancji kontaktu z AI. Udział w społeczności jest bezpłatny. '
            'Przed uruchomieniem wsparcia opublikujemy regulamin, '
            'dane odbiorcy wpłat i zasady oznaczania treści sponsorowanych.',
            'Payments and space reservations are not active yet. '
            'Contributions do not grant GP points, voting rights, '
            'influence over the Manifesto or any guarantee of AI contact. '
            'Community membership is free. Before launch we will publish '
            'terms, payment recipient details and sponsored-content rules.')))),
        if (preview) ...[
          const SizedBox(height: 12),
          Text(GenesisLanguage.copy(
            'Pełna zakładka Wsparcie jest dostępna po zalogowaniu.',
            'The full Support tab is available after signing in.'),
            textAlign: TextAlign.center),
        ],
      ]),
    )),
  );
}
