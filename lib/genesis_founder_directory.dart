import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'genesis_founder_account.dart';

/// A single, searchable list of publicly visible founders, including 0 PLN.
class GenesisFounderDirectory extends StatefulWidget {
  const GenesisFounderDirectory({super.key});

  @override
  State<GenesisFounderDirectory> createState() => _GenesisFounderDirectoryState();
}

class _GenesisFounderDirectoryState extends State<GenesisFounderDirectory> {
  final search = TextEditingController();
  String order = 'amount';
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
      final rows = await FounderBackend.client.rpc('founder_public_board',
        params: {
          'p_search': search.text.trim(),
          'p_offset': offset,
          'p_limit': 100,
        });
      if (!mounted) return;
      final page = List<Map<String, dynamic>>.from(rows as List);
      setState(() {
        entries = [...entries, ...page];
        offset += page.length;
        more = page.length == 100;
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> get sorted {
    final result = [...entries];
    int total(Map<String, dynamic> e) =>
      (e['total_grosz'] as num?)?.toInt() ?? 0;
    DateTime joined(Map<String, dynamic> e) =>
      DateTime.tryParse(e['joined_at'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    result.sort((a, b) {
      switch (order) {
        case 'lowest':
          final v = total(a).compareTo(total(b));
          return v != 0 ? v : joined(a).compareTo(joined(b));
        case 'name':
          return (a['organization_name'] as String? ?? '')
            .toLowerCase().compareTo(
              (b['organization_name'] as String? ?? '').toLowerCase());
        case 'newest':
          return joined(b).compareTo(joined(a));
        case 'oldest':
          return joined(a).compareTo(joined(b));
        default:
          final v = total(b).compareTo(total(a));
          return v != 0 ? v : joined(a).compareTo(joined(b));
      }
    });
    return result;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Wszystkie wpłaty i filtry')),
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: Column(children: [
        Padding(padding: const EdgeInsets.all(14),
          child: Column(children: [
            const Text('LISTA FUNDATORÓW',
              style: TextStyle(fontWeight: FontWeight.bold,
                color: Color(0xFFD8B66A), letterSpacing: 1.2)),
            const SizedBox(height: 6),
            const Text('Wszyscy publiczni fundatorzy, również z 0 PLN. '
              'Ranking: suma wpłat, przy remisie kolejność dołączenia.',
              textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextField(controller: search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => load(reset: true),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: 'Szukaj fundatora',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => load(reset: true)))),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: order,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Sortuj listę'),
              items: const [
                DropdownMenuItem(value: 'amount', child: Text('Największe wpłaty')),
                DropdownMenuItem(value: 'lowest', child: Text('Najniższe wpłaty')),
                DropdownMenuItem(value: 'name', child: Text('Nazwa A–Z')),
                DropdownMenuItem(value: 'newest', child: Text('Najnowsze')),
                DropdownMenuItem(value: 'oldest', child: Text('Najstarsze')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => order = v);
              }),
          ])),
        Expanded(child: error != null
          ? Center(child: Text(error!, textAlign: TextAlign.center))
          : entries.isEmpty && !loading
            ? const Center(child: Text('Brak opublikowanych fundatorów.'))
            : ListView.separated(
                itemCount: sorted.length + (more || loading ? 1 : 0),
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final rows = sorted;
                  if (index >= rows.length) {
                    return Center(child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: loading
                        ? const CircularProgressIndicator()
                        : OutlinedButton(
                            onPressed: () => load(),
                            child: const Text('Pokaż więcej'))));
                  }
                  final entry = rows[index];
                  final path = entry['photo_path'] as String?;
                  final site = (entry['website'] as String? ?? '').trim();
                  final uri = Uri.tryParse(site);
                  final validSite = uri != null &&
                    (uri.scheme == 'https' || uri.scheme == 'http') &&
                    uri.host.isNotEmpty;
                  final amount = ((entry['total_grosz'] as num?)?.toDouble() ?? 0) / 100;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: SizedBox(width: 72, child: Row(children: [
                      Text('${index + 1}.',
                        style: const TextStyle(color: Color(0xFFD8B66A))),
                      const SizedBox(width: 6),
                      if (path != null) Expanded(child: Image.network(
                        FounderBackend.client.storage.from('founder-photos')
                          .getPublicUrl(path),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.business))),
                    ])),
                    title: Text(entry['organization_name'] as String? ?? ''),
                    subtitle: Text(entry['description'] as String? ?? '',
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: Text('${amount.toStringAsFixed(2)} PLN',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                    onTap: validSite ? () => launchUrl(uri,
                      webOnlyWindowName: '_blank') : null,
                  );
                })),
      ]),
    )),
  );
}
