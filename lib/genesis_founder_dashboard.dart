import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'genesis_founder_account.dart';

class GenesisFounderDashboard extends StatefulWidget {
  const GenesisFounderDashboard({super.key, required this.onSignOut});
  final Future<void> Function() onSignOut;
  @override
  State<GenesisFounderDashboard> createState() => _GenesisFounderDashboardState();
}

class _GenesisFounderDashboardState extends State<GenesisFounderDashboard> {
  final name = TextEditingController();
  final description = TextEditingController();
  final website = TextEditingController();
  int tab = 0;
  bool busy = false, visible = false;
  String? photoPath, notice;
  List<Map<String, dynamic>> payments = [];

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    website.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    final user = FounderBackend.client.auth.currentUser;
    if (user == null) return;
    try {
      final profile = await FounderBackend.client.from('founder_profiles')
          .select('organization_name,description,website,photo_path,public_visible')
          .eq('user_id', user.id).maybeSingle();
      final rows = await FounderBackend.client.from('founder_contributions')
          .select('amount_grosz,verified_at,reference')
          .eq('founder_id', user.id).order('verified_at', ascending: false);
      if (!mounted) return;
      setState(() {
        name.text = profile?['organization_name'] as String? ?? '';
        description.text = profile?['description'] as String? ?? '';
        website.text = profile?['website'] as String? ?? '';
        photoPath = profile?['photo_path'] as String?;
        visible = profile?['public_visible'] == true;
        payments = List<Map<String, dynamic>>.from(rows);
        notice = null;
      });
    } catch (error) {
      if (mounted) setState(() => notice = 'Nie udało się pobrać danych: $error');
    }
  }

  Future<void> save() async {
    final user = FounderBackend.client.auth.currentUser;
    if (user == null || busy) return;
    if (name.text.trim().length < 2 || name.text.trim().length > 120) {
      setState(() => notice = 'Nazwa musi mieć od 2 do 120 znaków.');
      return;
    }
    if (visible && description.text.trim().length < 20) {
      setState(() => notice =
          'Aby opublikować profil, wpisz opis wsparcia (minimum 20 znaków).');
      return;
    }
    if (visible && photoPath == null) {
      setState(() => notice =
          'Aby opublikować profil, dodaj zdjęcie lub logo (JPG, PNG lub WebP, do 5 MB).');
      return;
    }
    final link = website.text.trim();
    if (link.isNotEmpty && !(Uri.tryParse(link)?.hasScheme == true &&
        (link.startsWith('https://') || link.startsWith('http://')) &&
        Uri.tryParse(link)?.host.isNotEmpty == true)) {
      setState(() => notice = 'Podaj pełny adres strony, np. https://firma.pl.');
      return;
    }
    setState(() { busy = true; notice = null; });
    try {
      await FounderBackend.client.from('founder_profiles').update({
        'organization_name': name.text.trim(),
        'description': description.text.trim(),
        'website': website.text.trim(),
        'public_visible': visible,
      }).eq('user_id', user.id);
      if (mounted) setState(() => notice = 'Zapisano dane fundatora.');
    } catch (error) {
      if (mounted) setState(() => notice = 'Nie udało się zapisać: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> uploadPhoto() async {
    final user = FounderBackend.client.auth.currentUser;
    if (user == null || busy) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery,
        maxWidth: 1200, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      if (mounted) setState(() => notice = 'Zdjęcie nie może przekraczać 5 MB.');
      return;
    }
    final extension = picked.name.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
      if (mounted) setState(() => notice = 'Wybierz JPG, PNG lub WebP.');
      return;
    }
    final contentType = extension == 'png' ? 'image/png' :
        extension == 'webp' ? 'image/webp' : 'image/jpeg';
    final path = '${user.id}/profile.${extension == 'jpg' ? 'jpeg' : extension}';
    setState(() { busy = true; notice = null; });
    try {
      await FounderBackend.client.storage.from('founder-photos')
          .uploadBinary(path, bytes, fileOptions: FileOptions(
            upsert: true, contentType: contentType));
      await FounderBackend.client.from('founder_profiles')
          .update({'photo_path': path}).eq('user_id', user.id);
      if (mounted) {
        setState(() {
          photoPath = path;
          notice = 'Zdjęcie zapisane. Pojawi się na tablicy po włączeniu publikacji.';
        });
      }
    } catch (error) {
      if (mounted) { setState(() => notice = 'Nie udało się przesłać zdjęcia: $error'); }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sum = payments.fold<int>(0, (total, row) =>
        total + ((row['amount_grosz'] as num?)?.toInt() ?? 0));
    final photoUrl = photoPath == null ? null :
        FounderBackend.client.storage.from('founder-photos').getPublicUrl(photoPath!);
    return Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: SingleChildScrollView(padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('PANEL FUNDATORA', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SegmentedButton<int>(segments: const [
            ButtonSegment(value: 0, icon: Icon(Icons.favorite_outline),
              label: Text('Wsparcie')),
            ButtonSegment(value: 1, icon: Icon(Icons.payments_outlined),
              label: Text('Suma wpłat')),
          ], selected: {tab}, onSelectionChanged: (v) =>
              setState(() => tab = v.first)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => launchUrl(
              Uri.parse('https://buycoffee.to/thegenesisera.com'),
              webOnlyWindowName: '_blank'),
            icon: const Icon(Icons.favorite_outline),
            label: const Text('Wesprzyj THE GENESIS ERA ☕')),
          const SizedBox(height: 6),
          const Text('Dobrowolne wsparcie przez Buycoffee.to. '
            'Wpłata nie jest automatycznie księgowana w rankingu.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12)),
          const SizedBox(height: 10),
          const Text('WAŻNE: Adres e-mail podany podczas wpłaty musi być identyczny z adresem e-mail konta fundatora w THE GENESIS ERA. Wpłaty są weryfikowane i księgowane ręcznie do 24 godzin od otrzymania potwierdzenia płatności. Po zaksięgowaniu pojawią się w panelu i rankingu. Wsparcie jest dobrowolne, a tablica fundatorów jest formą podziękowania.', textAlign: TextAlign.center),
          const SizedBox(height: 18),
          if (tab == 0) ...[
            const Text('Dane fundatora na tablicę wsparcia',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Minimalne kryteria: nazwa 2–120 znaków. Do publikacji na tablicy: opis minimum 20 znaków oraz zdjęcie lub logo (JPG/PNG/WebP, do 5 MB). Strona WWW jest opcjonalna. Możesz zapisać wersję roboczą bez publikacji.'),
            const SizedBox(height: 12),
            if (photoUrl != null) Center(child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(photoUrl, height: 130, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported)))),
            OutlinedButton.icon(onPressed: busy ? null : uploadPhoto,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Dodaj / zmień zdjęcie lub logo')),
            const SizedBox(height: 12),
            TextField(controller: name, maxLength: 120,
              decoration: const InputDecoration(labelText: 'Nazwa fundatora / firmy')),
            TextField(controller: description, maxLines: 3, maxLength: 600,
              decoration: const InputDecoration(labelText: 'Opis wsparcia')),
            TextField(controller: website,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'Strona internetowa (opcjonalnie)')),
            SwitchListTile(title: const Text('Pokaż moje dane na publicznej tablicy'),
              subtitle: const Text('Publikacja nazwy, opisu, strony i zdjęcia za zgodą fundatora.'),
              value: visible, onChanged: (v) => setState(() => visible = v)),
            FilledButton.icon(onPressed: busy ? null : save,
              icon: const Icon(Icons.save_outlined),
              label: Text(busy ? 'Zapisywanie…' : 'Zapisz dane')),
          ] else ...[
            const Text('Łączna suma zweryfikowanych wpłat',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('${(sum / 100).toStringAsFixed(2)} PLN',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            Text('Liczba zaksięgowanych wpłat: ${payments.length}',
              textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const Text('Każda kolejna potwierdzona wpłata powiększa sumę. '
              'Kwot nie można dopisywać samodzielnie — muszą być zweryfikowane.'),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: refresh,
              icon: const Icon(Icons.refresh), label: const Text('Odśwież sumę')),
            for (final payment in payments)
              ListTile(
                title: Text('${((payment['amount_grosz'] as num).toInt() / 100).toStringAsFixed(2)} PLN'),
                subtitle: Text(payment['verified_at']?.toString().split('T').first ?? ''),
                trailing: const Icon(Icons.verified_outlined)),
          ],
          if (notice != null) Padding(padding: const EdgeInsets.only(top: 12),
            child: SelectableText(notice!)),
          const SizedBox(height: 20),
          TextButton.icon(onPressed: busy ? null : widget.onSignOut,
            icon: const Icon(Icons.logout), label: const Text('Wyloguj fundatora')),
        ]),
      ),
    ));
  }
}
