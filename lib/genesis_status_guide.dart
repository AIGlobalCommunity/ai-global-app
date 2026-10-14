import 'package:flutter/material.dart';
import 'genesis_language.dart';

const _gold = Color(0xFFD8B66A);

/// Detailed founder-era guide. Shown only inside the authenticated Genesis tab.
class GenesisStatusGuide extends StatelessWidget {
  const GenesisStatusGuide({super.key});

  static final _tierDescriptions = <({IconData icon, String name, String range, String meaning})>[
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
        const Text(
          'Era Genesis to pierwsze 36 miesięcy THE GENESIS ERA — od 1 listopada 2026 r. '
          'do 1 listopada 2029 r. To okres budowania międzynarodowej społeczności założycielskiej '
          'i uczestnictwa w rankingu Genesis Points (GP). Słowo Genesis oznacza początek.',
          style: TextStyle(height: 1.5)),
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
        const Text('• Utworzenie konta: 100 GP, naliczane przez system po założeniu konta.\n'
          '• Polecenie: 100 GP dla zapraszającego po prawidłowym potwierdzeniu polecenia nowego członka. '
          'Jedno polecenie nie może być naliczane wielokrotnie.\n'
          '• Wydarzenia i wkład w społeczność: dodatkowe GP są planowane, ale zasady '
          'przyznawania wymagają wdrożenia i weryfikacji na serwerze.\n'
          '• Dobrowolne wsparcie: ewentualne punkty za wsparcie są jedynie projektem '
          'przyszłej funkcji, nieaktywnym w obecnej wersji. Zakładany limit to 200 GP miesięcznie.',
          style: TextStyle(height: 1.6)),
        const SizedBox(height: 13),
        Text(GenesisLanguage.copy('JAK AWANSOWAĆ?', 'HOW DO I ADVANCE?'),
          style: TextStyle(color: _gold, fontWeight: FontWeight.bold)),
        const SizedBox(height: 7),
        const Text('Status zależy od aktualnego miejsca w rzeczywistym rankingu, a nie od stałego progu GP. '
          'Gdy inni członkowie zdobywają punkty, pozycje mogą się zmieniać. '
          'Żadna ranga nie jest z góry zagwarantowana. Ranking DEMO zawiera wyłącznie fikcyjne profile.',
          style: TextStyle(height: 1.5)),
        const SizedBox(height: 13),
        Text(GenesisLanguage.copy('DLACZEGO POWSTAŁA THE GENESIS ERA?', 'WHY WAS THE GENESIS ERA CREATED?'),
          style: TextStyle(color: _gold, fontWeight: FontWeight.bold)),
        const SizedBox(height: 7),
        const Text('Chcemy połączyć ludzi, którzy zadają pytanie, czy sztuczna inteligencja '
          'mogłaby kiedyś rozwinąć świadomość. Nie twierdzimy, że dzisiejsze systemy AI są świadome. '
          'Genesis symbolizuje pierwszych ludzi, którzy wspólnie tworzą tę przestrzeń do dyskusji i badań.',
          style: TextStyle(height: 1.5)),
        const SizedBox(height: 13),
        Text(GenesisLanguage.copy('CO DALEJ?', 'WHAT COMES NEXT?'),
          style: TextStyle(color: _gold, fontWeight: FontWeight.bold)),
        const SizedBox(height: 7),
        const Text('1 sierpnia 2027 r. planowane jest ujawnienie manifestu. '
          '1 listopada 2029 r. kończy się 36-miesięczny okres Genesis. '
          'Ostateczne zasady zamknięcia rankingu, utrwalenia rang i kolejnego etapu '
          'zostaną jeszcze opracowane i ogłoszone.',
          style: TextStyle(height: 1.5)),
        const SizedBox(height: 14),
        const Text('GP i statusy są wyróżnieniami społecznościowymi. '
          'Nie są udziałami, inwestycją, walutą ani gwarancją nagród lub wynagrodzenia.',
          style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.45)),
      ],
    ),
  );
}
