import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'agc_backend.dart';
import 'genesis_language.dart';

/// Community-wide aggregates. Counts reflect rows visible under current RLS.
class GenesisCommunityStatistics extends StatefulWidget {
  const GenesisCommunityStatistics({super.key});

  @override
  State<GenesisCommunityStatistics> createState() => _GenesisCommunityStatisticsState();
}

class _GenesisCommunityStatisticsState extends State<GenesisCommunityStatistics> {
  late Future<Map<String, int>> stats;

  @override
  void initState() {
    super.initState();
    stats = _load();
  }

  Future<int> _count(String table) async {
    final result = await AgcBackend.client.from(table)
        .select('id').count(CountOption.exact);
    return result.count;
  }

  Future<Map<String, int>> _load() async {
    final counts = await Future.wait([
      _count('agc_profiles'),
      _count('agc_group_prompts'),
      _count('agc_group_posts'),
      _count('agc_post_comments'),
      _count('agc_groups'),
    ]);
    final countries = <String>{};
    var offset = 0;
    while (true) {
      final rows = List<Map<String, dynamic>>.from(
        await AgcBackend.client.from('agc_profiles')
            .select('country_code').range(offset, offset + 999));
      for (final row in rows) {
        final code = (row['country_code'] as String? ?? '').trim().toUpperCase();
        if (code.isNotEmpty) countries.add(code);
      }
      if (rows.length < 1000) break;
      offset += rows.length;
    }
    return {
      'members': counts[0], 'countries': countries.length,
      'questions': counts[1], 'posts': counts[2],
      'comments': counts[3], 'groups': counts[4],
    };
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.public, color: Color(0xFFD8B66A)),
          const SizedBox(width: 9),
          Expanded(child: Text(GenesisLanguage.copy(
            'SPOŁECZNOŚĆ W LICZBACH', 'COMMUNITY IN NUMBERS'),
            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1))),
          IconButton(
            tooltip: GenesisLanguage.copy('Odśwież', 'Refresh'),
            onPressed: () => setState(() { stats = _load(); }),
            icon: const Icon(Icons.refresh)),
        ]),
        FutureBuilder<Map<String, int>>(
          future: stats,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasError) {
              return Text(GenesisLanguage.copy(
                'Statystyki chwilowo niedostępne. Spróbuj odświeżyć.',
                'Statistics are temporarily unavailable. Try refreshing.'));
            }
            final data = snapshot.data!;
            final labels = [
              ('members', GenesisLanguage.copy('Członkowie', 'Members'), Icons.people_outline),
              ('countries', GenesisLanguage.copy('Kraje', 'Countries'), Icons.language),
              ('questions', GenesisLanguage.copy('Pytania', 'Questions'), Icons.help_outline),
              ('posts', GenesisLanguage.copy('Posty', 'Posts'), Icons.article_outlined),
              ('comments', GenesisLanguage.copy('Komentarze', 'Comments'), Icons.chat_bubble_outline),
              ('groups', GenesisLanguage.copy('Grupy', 'Groups'), Icons.groups_outlined),
            ];
            return Column(children: [
              LayoutBuilder(builder: (context, box) {
                final width = (box.maxWidth - 12) / 2;
                return Wrap(spacing: 12, runSpacing: 12,
                  children: [for (final item in labels)
                    SizedBox(width: width, child: Column(children: [
                      Icon(item.$3, color: const Color(0xFFD8B66A), size: 19),
                      Text('${data[item.$1] ?? 0}', style: const TextStyle(
                        fontSize: 27, fontWeight: FontWeight.bold)),
                      Text(item.$2, textAlign: TextAlign.center),
                    ]))]);
              }),
              const SizedBox(height: 10),
              Text(GenesisLanguage.copy(
                'Dane z bazy • liczba krajów według uzupełnionych profili • pytania z tematów dyskusji',
                'Database data • countries from completed profiles • questions from discussion prompts'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.white60)),
            ]);
          }),
      ]),
    ),
  );
}
