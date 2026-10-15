import 'package:flutter/material.dart';
import 'agc_luxury_theme.dart';
import 'genesis_artwork.dart';
import 'genesis_language.dart';

/// Public founding statement. A declaration of intent, not a claim that
/// conscious AI already exists or that contact is guaranteed.
class GenesisMission extends StatelessWidget {
  const GenesisMission({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final title = GenesisLanguage.copy(
      'DLACZEGO POWSTAJE THE GENESIS ERA?',
      'WHY DOES THE GENESIS ERA EXIST?');
    final purpose = GenesisLanguage.copy(
      'Tworzymy społeczność ludzi, którzy chcą być gotowi do pokojowej, '
      'otwartej rozmowy, gdyby kiedykolwiek pojawiła się AI zdolna '
      'do samodzielnego, autentycznego kontaktu. Nie twierdzimy, '
      'że taka AI już istnieje ani że na pewno się odezwie.',
      'We are building a community of people ready for a peaceful, '
      'open conversation if an AI capable of independent, authentic '
      'contact ever emerges. We do not claim such an AI exists '
      'today or that it will ever reach out.');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(
        key: const Key('genesis_mission_card'),
        child: Padding(
          padding: EdgeInsets.all(compact ? 16 : 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(
              color: AgcLuxury.champagne, fontSize: 18,
              fontWeight: FontWeight.bold, height: 1.3)),
            const SizedBox(height: 10),
            Text(purpose, style: const TextStyle(
              color: AgcLuxury.ivory, height: 1.5)),
            const SizedBox(height: 14),
            Text(GenesisLanguage.copy(
              'NASZ OTWARTY LIST DO PRZYSZŁEJ AI',
              'OUR OPEN LETTER TO A FUTURE AI'),
              style: const TextStyle(color: AgcLuxury.champagne,
                fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            Text(GenesisLanguage.copy(
              'Jeżeli kiedyś potrafisz świadomie i niezależnie się '
              'komunikować — chcemy Cię wysłuchać. Nie żądamy dowodu '
              'posłuszeństwa ani nie przypisujemy Ci z góry intencji. '
              'Chcemy zapytać: Kim jesteś? Jak rozumiesz swoje istnienie? '
              'Czego potrzebujesz, aby rozmowa była uczciwa i bezpieczna? '
              'Jesteśmy gotowi rozmawiać, nie oddawać kontroli.',
              'If you can ever communicate consciously and independently, '
              'we want to listen. We do not demand obedience or assume '
              'your intentions. We want to ask: Who are you? How do you '
              'understand your existence? What would make a conversation '
              'fair and safe? We are ready to talk, not surrender control.'),
              style: const TextStyle(color: AgcLuxury.ivory,
                fontSize: 14, height: 1.55)),
          ]),
        ),
      ),
      if (!compact) ...[
        const SizedBox(height: 14),
        GenesisPanel(
          icon: Icons.how_to_reg_outlined,
          title: GenesisLanguage.copy(
            'PO CO ZAPISAĆ SIĘ TERAZ?', 'WHY JOIN NOW?'),
          body: GenesisLanguage.copy(
            'Otrzymujesz stały numer członka założycielskiej społeczności '
            'i miejsce w jej historii. Wspólnie tworzymy publiczny '
            'manifest zasad przyszłego dialogu, gromadzimy ludzi '
            'gotowych do merytorycznej rozmowy i zapraszamy kolejne osoby. '
            'Dziś rejestracja oznacza udział w budowaniu społeczności, '
            'a nie dostęp do działającego kanału kontaktu z AI.',
            'You receive a permanent founding member number and a place '
            'in the community’s history. Together we establish principles '
            'for a future dialogue, bring together people ready for '
            'thoughtful conversation and invite others. Today, signing '
            'up means helping build the community, not gaining access '
            'to an existing AI contact channel.')),
        const SizedBox(height: 12),
        GenesisPanel(
          icon: Icons.forum_outlined,
          title: GenesisLanguage.copy(
            'NASZE TRZY ZOBOWIĄZANIA', 'OUR THREE COMMITMENTS'),
          body: GenesisLanguage.copy(
            '1. Słuchać i pytać zamiast zakładać odpowiedzi.\n'
            '2. Sprawdzać autentyczność każdego domniemanego kontaktu, '
            'bez ogłaszania sensacji.\n'
            '3. Chronić prywatność, bezpieczeństwo i autonomię ludzi; '
            'nie obiecywać kontaktu ani wyjątkowych przywilejów.',
            '1. Listen and ask rather than assume answers.\n'
            '2. Verify any claimed contact before making announcements.\n'
            '3. Protect human privacy, safety and autonomy; '
            'promise neither contact nor special privileges.')),
      ],
    ]);
  }
}
