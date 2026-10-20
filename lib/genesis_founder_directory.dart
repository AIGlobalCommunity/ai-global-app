import 'package:flutter/material.dart';
import 'agc_backend.dart';
import 'genesis_language.dart';

/// Public directory of all verified, opted-in supporters, including those
/// outside the top 1000. Paginated server-side; no artificial membership cap.
class GenesisFounderDirectory extends StatefulWidget {
  const GenesisFounderDirectory({super.key});

  @override
  State<GenesisFounderDirectory> createState() => _GenesisFounderDirectoryState();
}

class _GenesisFounderDirectoryState extends State<GenesisFounderDirectory> {
  final search = TextEditingController();
  String order = 'amount';
  int minimum = 0;
  int offset = 0;
  bool loading = false;
  bool more = false;
  String? error;
  List<Map<String, dynamic>> entries = [];

  @override
  void initState() {
    super.initState();
    load(reset: true);
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load({bool reset = false}) async {
    if (loading) return;
    if (reset) {
      offset = 0;
      entries = [];
    }
    setState(() { loading = true; error = null; });
    try {
      final result = await AgcBackend.client.rpc('agc_public_founder_directory',
        params: {
          'p_search': search.text.trim(),
          'p_min_grosz': minimum * 100,
          'p_sort': order,
          'p_offset': offset,
          'p_limit': 50,
        });
      final rows = List<Map<String, dynamic>>.from(result as List);
      if (!mounted) return;
      setState(() {
        entries = [...entries, ...rows];
        offset += rows.length;
        more = rows.length == 50;
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(GenesisLanguage.copy(
      'Wszyscy fundatorzy', 'All supporters'))),
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1000),
      child: Column(children: [
        Padding(padding: const EdgeInsets.all(14),
          child: Column(children: [
            Text(GenesisLanguage.copy(
              'PEŁNA LISTA ZWERYFIKOWANEGO WSPARCIA',
              'ALL VERIFIED SUPPORT'),
              style: const TextStyle(color: Color(0xFFD8B66A),
                fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            Text(GenesisLanguage.copy(
              'Tu znajdziesz również fundatorów spoza TOP 1000. '
              'Widoczne są wyłącznie podmioty, które zgodziły się na publikację.',
              'Includes supporters outside the top 1000. '
              'Only organizations opting into public display appear here.'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            TextField(controller: search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => load(reset: true),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: GenesisLanguage.copy('Szukaj firmy', 'Search organization'),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => load(reset: true)))),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(
                initialValue: order,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: GenesisLanguage.copy('Sortuj', 'Sort')),
                items: [
                  DropdownMenuItem(value: 'amount',
                    child: Text(GenesisLanguage.copy('Największe wpłaty', 'Highest amount'))),
                  DropdownMenuItem(value: 'lowest',
                    child: Text(GenesisLanguage.copy('Najniższe wpłaty', 'Lowest amount'))),
                  DropdownMenuItem(value: 'name',
                    child: Text(GenesisLanguage.copy('Nazwa A–Z', 'Name A–Z'))),
                  DropdownMenuItem(value: 'newest',
                    child: Text(GenesisLanguage.copy('Najnowsze', 'Newest'))),
                  DropdownMenuItem(value: 'oldest',
                    child: Text(GenesisLanguage.copy('Najstarsze', 'Oldest'))),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => order = v);
                  load(reset: true);
                })),
              const SizedBox(width: 8),
              Expanded(child: DropdownButtonFormField<int>(
                initialValue: minimum,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: GenesisLanguage.copy('Minimum', 'Minimum')),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('0 PLN')),
                  DropdownMenuItem(value: 100, child: Text('100 PLN')),
                  DropdownMenuItem(value: 500, child: Text('500 PLN')),
                  DropdownMenuItem(value: 1000, child: Text('1 000 PLN')),
                  DropdownMenuItem(value: 5000, child: Text('5 000 PLN')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => minimum = v);
                  load(reset: true);
                })),
            ]),
          ])),
        Expanded(child: error != null
          ? Center(child: Text(error!, textAlign: TextAlign.center))
          : entries.isEmpty && !loading
            ? Center(child: Text(GenesisLanguage.copy(
                'Brak zweryfikowanych publicznych wpłat dla tych filtrów.',
                'No public verified contributions match these filters.')))
            : ListView.builder(
                itemCount: entries.length + (more || loading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= entries.length) {
                    return Center(child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: loading
                        ? const CircularProgressIndicator()
                        : OutlinedButton(
                            onPressed: () => load(),
                            child: Text(GenesisLanguage.copy('Pokaż więcej', 'Load more')))));
                  }
                  final entry = entries[index];
                  final total = (entry['total_grosz'] as num).toInt() / 100;
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF263C54),
                        child: Text('${index + 1}',
                          style: const TextStyle(color: Color(0xFFD8B66A)))),
                      title: Text(entry['organization_name'] as String? ?? ''),
                      subtitle: Text(GenesisLanguage.copy(
                        'Zweryfikowane wpłaty: ${entry['contribution_count']}',
                        'Verified contributions: ${entry['contribution_count']}')),
                      trailing: Text('${total.toStringAsFixed(2)} PLN',
                        style: const TextStyle(fontWeight: FontWeight.bold,
                          color: Color(0xFFD8B66A))),
                    ),
                  );
                })),
      ]),
    )),
  );
}
