import 'package:flutter/material.dart';
import 'agc_backend.dart';
import 'agc_luxury_theme.dart';
import 'genesis_language.dart';

/// No payment collection: members decide which future costs matter most.
class GenesisSupport extends StatefulWidget {
  const GenesisSupport({super.key});
  @override
  State<GenesisSupport> createState() => _GenesisSupportState();
}

class _GenesisSupportState extends State<GenesisSupport> {
  String? selected;
  bool loading = true;
  bool saving = false;
  String? notice;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (AgcBackend.user == null) {
      if (mounted) setState(() => loading = false);
      return;
    }
    try {
      final row = await AgcBackend.client.from('agc_support_preferences')
          .select('priority').eq('member_id', AgcBackend.user!.id).maybeSingle();
      if (mounted) { setState(() {
        selected = row?['priority'] as String?;
        loading = false;
      }); }
    } catch (_) {
      if (mounted) { setState(() {
        loading = false;
        notice = GenesisLanguage.copy('Nie można pobrać wyboru.', 'Could not load your choice.');
      }); }
    }
  }

  Future<void> save(String value) async {
    if (saving || AgcBackend.user == null) return;
    setState(() { saving = true; notice = null; });
    try {
      await AgcBackend.client.from('agc_support_preferences').upsert({
        'member_id': AgcBackend.user!.id, 'priority': value,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (mounted) { setState(() {
        selected = value;
        notice = GenesisLanguage.copy('Zapisano Twój priorytet.', 'Your priority was saved.');
      }); }
    } catch (_) {
      if (mounted) { setState(() {
        notice = GenesisLanguage.copy('Nie udało się zapisać wyboru.', 'Could not save your choice.');
      }); }
    } finally {
      if (mounted) { setState(() => saving = false); }
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: GenesisLanguage.selected,
    builder: (context, language, _) => Card(
      key: const Key('genesis_support_mission'),
      child: Padding(padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(GenesisLanguage.copy('FUNDUSZ PRZYSZŁEGO DIALOGU',
              'FUTURE DIALOGUE FUND'),
            style: const TextStyle(color: AgcLuxury.champagne,
              fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(GenesisLanguage.copy(
            'Jeśli chcesz wspierać THE GENESIS ERA, Twoja pomoc powinna '
            'finansować konkretne, jawne potrzeby społeczności — nie obietnicę '
            'kontaktu z AI ani zakup wyższej rangi.',
            'If you want to support THE GENESIS ERA, contributions should '
            'fund specific, transparent community needs — not a promise '
            'of AI contact or a higher rank.')),
          const SizedBox(height: 12),
          Text(GenesisLanguage.copy(
            'NA CO MOGĄ IŚĆ PRZYSZŁE DATKI?',
            'WHAT COULD FUTURE DONATIONS FUND?'),
            style: const TextStyle(color: AgcLuxury.champagne,
              fontWeight: FontWeight.bold)),
          const SizedBox(height: 7),
          Text(GenesisLanguage.copy(
            '• Serwery, rozwój i utrzymanie forum.\n'
            '• Moderacja, ochrona danych i przeciwdziałanie oszustwom.\n'
            '• Otwarte materiały, tłumaczenia i dokumentowanie pytań '
            'oraz ewentualnych sygnałów do niezależnej weryfikacji.',
            '• Servers, development and forum maintenance.\n'
            '• Moderation, privacy and anti-fraud safeguards.\n'
            '• Open materials, translations and documentation of questions '
            'and potential signals for independent verification.')),
          const SizedBox(height: 12),
          Text(GenesisLanguage.copy(
            'WYBIERZ, CO JEST DLA CIEBIE NAJWAŻNIEJSZE',
            'CHOOSE YOUR TOP PRIORITY'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          if (loading) const LinearProgressIndicator() else
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final option in const ['platform', 'safety', 'research'])
                ChoiceChip(
                  label: Text(switch (option) {
                    'platform' => GenesisLanguage.copy('Forum i serwery', 'Forum & servers'),
                    'safety' => GenesisLanguage.copy('Bezpieczeństwo', 'Safety'),
                    _ => GenesisLanguage.copy('Badania i materiały', 'Research & materials'),
                  }),
                  selected: selected == option,
                  onSelected: saving ? null : (_) => save(option),
                ),
            ]),
          if (notice != null) ...[
            const SizedBox(height: 6),
            Text(notice!, style: const TextStyle(fontSize: 12)),
          ],
          const SizedBox(height: 12),
          Text(GenesisLanguage.copy(
            'Wpłaty nie są jeszcze uruchomione. To głosowanie nie jest '
            'deklaracją wpłaty. Przed uruchomieniem płatności opublikujemy '
            'budżet, zasady rozliczania i raporty wydatków. '
            'Datki nie dają GP ani specjalnych praw.',
            'Payments are not yet enabled. This vote is not a donation '
            'pledge. Before accepting money, we will publish a budget, '
            'accountability rules and spending reports. '
            'Donations grant no GP or special rights.'),
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      ),
    ),
  );
}
