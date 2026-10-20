import 'package:flutter/material.dart';
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

  Future<Map<String, int>> _load() async {
    final response = await AgcBackend.client.rpc('agc_community_stats');
    final data = Map<String, dynamic>.from(response as Map);
    return {
      'members': (data['members'] as num?)?.toInt() ?? 0,
      'countries': (data['countries'] as num?)?.toInt() ?? 0,
      'questions': (data['questions'] as num?)?.toInt() ?? 0,
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
            ];
            return Column(children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in labels)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(children: [
                          Icon(item.$3, color: const Color(0xFFD8B66A), size: 19),
                          Text('${data[item.$1] ?? 0}', style: const TextStyle(
                            fontSize: 27, fontWeight: FontWeight.bold)),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(item.$2, textAlign: TextAlign.center),
                          ),
                        ]),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(GenesisLanguage.copy(
                'Dane z bazy • kraje z profili członków • pytania z tematów dyskusji',
                'Database totals • countries from member profiles • questions from discussion prompts'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.white60)),
            ]);
          }),
      ]),
    ),
  );
}
