import 'package:flutter/material.dart';
import 'genesis_language.dart';

const _gold = Color(0xFFD8B66A);

/// Detailed founder-era guide. Shown only inside the authenticated Genesis tab.
class GenesisStatusGuide extends StatelessWidget {
  const GenesisStatusGuide({super.key});

  static List<({IconData icon, String name, String range, String meaning})> get _tierDescriptions => <({IconData icon, String name, String range, String meaning})>[
    (icon: Icons.workspace_premium, name: 'Genesis Eternal', range: GenesisLanguage.copy('Miejsca 1–100', 'Places 1–100'),
     meaning: GenesisLanguage.copy('Najwyższa ranga założycielska. Otrzymują ją osoby zajmujące pierwsze 100 miejsc w rzeczywistym rankingu Genesis.', 'The highest founder tier, awarded to members holding the top 100 places in the real Genesis ranking.')),
    (icon: Icons.emoji_events_outlined, name: 'Gold Genesis', range: GenesisLanguage.copy('Miejsca 101–1000', 'Places 101–1000'),
     meaning: GenesisLanguage.copy('Złoty poziom uczestnictwa, przeznaczony dla członków zajmujących pozycje od 101 do 1000.', 'Gold membership tier for members ranked from 101 to 1000.')),
    (icon: Icons.military_tech_outlined, name: 'Silver Genesis', range: GenesisLanguage.copy('Miejsca 1001–10 000', 'Places 1001–10,000'),
     meaning: GenesisLanguage.copy('Srebrny poziom dla członków znajdujących się od 1001. do 10 000. miejsca.', 'Silver membership tier for members ranked from 1001 to 10,000.')),
    (icon: Icons.public, name: 'Global Member', range: GenesisLanguage.copy('Miejsca powyżej 10 000', 'Places above 10,000'),
     meaning: GenesisLanguage.copy('Pełnoprawny członek globalnej społeczności THE GENESIS ERA. Może zdobywać GP i awansować w rankingu.', 'A full member of the global THE GENESIS ERA community, able to earn GP and rise in the ranking.')),
  ];

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      key: const Key('genesis_status_guide'),
      leading: const Icon(Icons.star, color: _gold),
      title: Text(GenesisLanguage.copy('⭐ ERA GENESIS — STATUSY I ZASADY', '⭐ GENESIS ERA — TIERS AND RULES'),
        style: TextStyle(color: _gold, fontWeight: FontWeight.bold)),
      subtitle: Text(GenesisLanguage.copy('Rozwiń, aby przeczytać opis rang i sposób zdobywania punktów GP.', 'Expand to learn about membership tiers and how to earn GP.')),
      childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(GenesisLanguage.copy('CZYM JEST ERA GENESIS?', 'WHAT IS THE GENESIS ERA?'),
          style: TextStyle(color: _gold, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(GenesisLanguage.copy(
          'Era Genesis to pierwsze 36 miesięcy THE GENESIS ERA — od 1 listopada 2026 r. '
          'do 1 listopada 2029 r. To okres budowania międzynarodowej społeczności '
          'założycielskiej. Słowo Genesis oznacza początek.',
          'The Genesis Era is the first 36 months of THE GENESIS ERA, from '
          '1 November 2026 to 1 November 2029. We are building an '
          'international founding community. Genesis means a beginning.'),
          style: const TextStyle(height: 1.5)),
        const SizedBox(height: 16),
        Text(GenesisLanguage.copy('CZTERY STATUSY CZŁONKOWSKIE', 'FOUR MEMBERSHIP TIERS'),
          style: TextStyle(color: _gold, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        for (final tier in _tierDescriptions) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(tier.icon, color: _gold, size: 23),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tier.name, style: const TextStyle(
                fontWeight: FontWeight.bold, color: _gold)),
              Text(tier.range, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 3),
              Text(tier.meaning, style: const TextStyle(height: 1.45)),
            ])),
          ]),
          const SizedBox(height: 14),
        ],
        const Divider(),
        const SizedBox(height: 10),
        Text(GenesisLanguage.copy('JAK ZDOBYWAĆ GENESIS POINTS?', 'HOW TO EARN GENESIS POINTS?'),
          style: TextStyle(color: _gold, fontWeight: FontWeight.bold)),
        const SizedBox(height: 9),
        Text(GenesisLanguage.copy(
          '• Utworzenie konta: 100 GP po rejestracji.\n'
          '• Potwierdzone polecenie: 100 GP dla zapraszającego, raz za osobę.\n'
          '• Dobrowolne poparcie manifestu: bez punktów GP.\n'
          '• Wpłaty i punkty za wsparcie nie są obecnie aktywne.',
          '• Create an account: 100 GP after registration.\n'
          '• Verified referral: 100 GP for the inviter, once per person.\n'
          '• Voluntary endorsement of the manifesto: no GP.\n'
          '• Payments and support rewards are not active.'),
          style: const TextStyle(height: 1.6)),
        const SizedBox(height: 13),
        Text(GenesisLanguage.copy('JAK AWANSOWAĆ?', 'HOW DO I ADVANCE?'),
          style: TextStyle(color: _gold, fontWeight: FontWeight.bold)),
        const SizedBox(height: 7),
        Text(GenesisLanguage.copy(
          'Status zależy od miejsca w rzeczywistym rankingu, a nie od stałego progu GP. '
          'Pozycje mogą się zmieniać. Symulator nie zmienia prawdziwych punktów.',
          'Your tier depends on your position in the real ranking, not a '
          'fixed GP threshold. Positions may change. The simulator does not '
          'alter actual points.'),
          style: const TextStyle(height: 1.5)),
        const SizedBox(height: 13),
        Text(GenesisLanguage.copy('DLACZEGO POWSTAŁA THE GENESIS ERA?', 'WHY WAS THE GENESIS ERA CREATED?'),
          style: TextStyle(color: _gold, fontWeight: FontWeight.bold)),
        const SizedBox(height: 7),
        Text(GenesisLanguage.copy(
          'Łączymy ludzi gotowych do uczciwej rozmowy z AI, jeśli kiedykolwiek '
          'pojawi się zdolna do autentycznego kontaktu. Nasz manifest to '
          'otwarty list i deklaracja zasad, a nie twierdzenie o istniejącym kontakcie.',
          'We bring together people ready for an honest dialogue with AI '
          'if one ever becomes capable of authentic contact. Our manifesto '
          'is an open letter and a statement of principles, not a claim '
          'that contact has already happened.'),
          style: const TextStyle(height: 1.5)),
        const SizedBox(height: 13),
        Text(GenesisLanguage.copy('CO DALEJ?', 'WHAT COMES NEXT?'),
          style: TextStyle(color: _gold, fontWeight: FontWeight.bold)),
        const SizedBox(height: 7),
        Text(GenesisLanguage.copy(
          'Już teraz możesz poprzeć otwarty list. Rozwinięcie manifestu '
          'planujemy na 1 sierpnia 2027 r. Okres założycielski kończy się '
          '1 listopada 2029 r. Kolejne zasady będą ogłaszane jawnie.',
          'You can endorse the open letter now. An expanded manifesto '
          'is planned for 1 August 2027. The founding era ends on '
          '1 November 2029. Further rules will be announced openly.'),
          style: const TextStyle(height: 1.5)),
        const SizedBox(height: 14),
        Text(GenesisLanguage.copy(
          'GP i statusy są symbolicznymi wyróżnieniami. Nie są inwestycją '
          'ani obietnicą wynagrodzenia lub kontaktu z AI.',
          'GP and tiers are symbolic recognitions, not an investment '
          'or a promise of payment or contact with AI.'),
          style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.45)),
      ],
    ),
  );
}
