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
  bool adminEnabled = false;
  final adminEmail = TextEditingController();
  final issueEmail = TextEditingController();
  final issueAmount = TextEditingController();
  final issueReference = TextEditingController();
  final issueDetails = TextEditingController();
  String issueProvider = 'PayPal';
  List<Map<String, dynamic>> issues = [];
  final adminAmount = TextEditingController();
  final adminReference = TextEditingController();

  @override
  void initState() {
    super.initState();
    refresh();
    checkAdmin();
    loadIssues();
  }

  Future<void> checkAdmin() async {
    final user = FounderBackend.client.auth.currentUser;
    if (user == null) return;
    try {
      final row = await FounderBackend.client.from('founder_admins')
          .select('user_id').eq('user_id', user.id).maybeSingle();
      if (mounted) setState(() => adminEnabled = row != null);
      if (row != null) await loadIssues();
    } catch (_) {
      // Admin backend is not configured yet; never expose privileged controls.
    }
  }

  Future<void> approvePayment() async {
    if (!adminEnabled || busy) return;
    final amount = double.tryParse(adminAmount.text.trim().replaceAll(',', '.'));
    final grosz = amount == null ? 0 : (amount * 100).round();
    final email = adminEmail.text.trim();
    if (grosz <= 0 || !email.contains('@') || adminReference.text.trim().length < 4) {
      setState(() => notice = 'Podaj e-mail fundatora, kwotę i numer transakcji.');
      return;
    }
    setState(() { busy = true; notice = null; });
    try {
      await FounderBackend.client.rpc('admin_approve_founder_payment_by_email', params: {
        'p_email': email,
        'p_amount_grosz': grosz,
        'p_reference': adminReference.text.trim(),
      });
      adminAmount.clear();
      adminReference.clear();
      await refresh();
      if (mounted) setState(() => notice = 'Wpłata została zatwierdzona.');
    } catch (_) {
      if (mounted) {
        setState(() => notice = 'Nie udało się zatwierdzić wpłaty. Sprawdź uprawnienia i numer transakcji.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> loadIssues() async {
    final user = FounderBackend.client.auth.currentUser;
    if (user == null) return;
    try {
      final rows = await FounderBackend.client.from('founder_payment_issues')
          .select('id,founder_id,payment_email,provider,transaction_reference,amount_grosz,details,status,created_at')
          .order('created_at', ascending: false).limit(100);
      if (mounted) setState(() => issues = List<Map<String, dynamic>>.from(rows));
    } catch (_) {
      // Only authorized users may access these reports.
    }
  }

  Future<void> submitIssue() async {
    final user = FounderBackend.client.auth.currentUser;
    if (user == null || busy) return;
    final amount = double.tryParse(issueAmount.text.trim().replaceAll(',', '.'));
    final grosz = amount == null ? 0 : (amount * 100).round();
    if (!issueEmail.text.contains('@') || grosz <= 0 ||
        issueReference.text.trim().length < 4 || issueDetails.text.trim().length < 10) {
      setState(() => notice = 'Podaj e-mail płatności, kwotę, numer transakcji i opis (min. 10 znaków).');
      return;
    }
    setState(() { busy = true; notice = null; });
    try {
      await FounderBackend.client.from('founder_payment_issues').insert({
        'founder_id': user.id,
        'payment_email': issueEmail.text.trim(),
        'provider': issueProvider,
        'transaction_reference': issueReference.text.trim(),
        'amount_grosz': grosz,
        'details': issueDetails.text.trim(),
      });
      issueReference.clear();
      issueAmount.clear();
      issueDetails.clear();
      await loadIssues();
      if (mounted) setState(() => notice = 'Zgłoszenie zapisane. Administrator je zweryfikuje.');
    } catch (_) {
      if (mounted) setState(() => notice = 'Nie udało się wysłać zgłoszenia.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    website.dispose();
    adminEmail.dispose();
    issueEmail.dispose();
    issueAmount.dispose();
    issueReference.dispose();
    issueDetails.dispose();
    adminAmount.dispose();
    adminReference.dispose();
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
          SegmentedButton<int>(segments: [
            const ButtonSegment(value: 0, icon: Icon(Icons.favorite_outline),
              label: Text('Wsparcie')),
            const ButtonSegment(value: 1, icon: Icon(Icons.rule_outlined), label: Text('Zasady')),
            const ButtonSegment(value: 2, icon: Icon(Icons.payments_outlined), label: Text('Suma wpłat')),
            const ButtonSegment(value: 3, icon: Icon(Icons.report_problem_outlined), label: Text('Zgłoś problem')),
            if (adminEnabled) const ButtonSegment(value: 4, icon: Icon(Icons.admin_panel_settings_outlined), label: Text('Admin')),
          ], selected: {tab}, onSelectionChanged: (v) =>
              setState(() => tab = v.first)),
          const SizedBox(height: 14),
          if (tab == 0) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('WESPRZYJ THE GENESIS ERA',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: () => launchUrl(
                      Uri.parse('https://buycoffee.to/thegenesisera.com'),
                      webOnlyWindowName: '_blank'),
                    icon: const Icon(Icons.local_cafe_outlined, size: 20),
                    label: const Text('BuyCoffee', maxLines: 1, overflow: TextOverflow.ellipsis))),
                  const SizedBox(width: 10),
                  Expanded(child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: () => launchUrl(
                      Uri.parse('https://www.paypal.com/biz/profile/thegenesisera'),
                      webOnlyWindowName: '_blank'),
                    icon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
                    label: const Text('PayPal', maxLines: 1, overflow: TextOverflow.ellipsis))),
                ]),
                const SizedBox(height: 14),
                const Text('Wsparcie jest całkowicie dobrowolne. Tablica fundatorów stanowi formę podziękowania.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                const Text('WAŻNE: Użyj przy wpłacie adresu e-mail zgodnego z kontem fundatora. Wpłaty są weryfikowane ręcznie po potwierdzeniu w PayPal lub BuyCoffee; dopiero potem pojawiają się w panelu i rankingu.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 20),
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
          ] else if (tab == 1) ...[
            const Text('ZASADY WYŚWIETLANIA FUNDATORÓW', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const SizedBox(height: 12),
            ExpansionTile(initiallyExpanded: true,
              leading: const Icon(Icons.rule_outlined),
              title: const Text('Zasady wyświetlania fundatorów',
                style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Widoczność, ranking i kolejność na tablicy'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              children: const [
                Text('1. Fundator sam decyduje, czy jego profil będzie publiczny. Aby pojawić się na tablicy, włącz opcję publikacji i zapisz dane.'),
                SizedBox(height: 8),
                Text('2. Profil publiczny wymaga nazwy (2–120 znaków), opisu (minimum 20 znaków) oraz zdjęcia lub logo (JPG, PNG, WebP, do 5 MB). Strona internetowa jest opcjonalna.'),
                SizedBox(height: 8),
                Text('3. Na tablicy widoczne są nazwa, opis, zdjęcie lub logo, opcjonalny link do strony oraz suma zweryfikowanych wpłat. Adres e-mail i identyfikatory transakcji nie są publikowane.'),
                SizedBox(height: 8),
                Text('4. Publiczny profil może być widoczny także przy sumie 0 PLN. Wpłaty zwiększają wynik dopiero po ręcznej weryfikacji przez administratora.'),
                SizedBox(height: 8),
                Text('5. Domyślny ranking pokazuje najwyższą łączną sumę wpłat jako pierwszą. Przy jednakowej kwocie wyżej znajduje się fundator, który dołączył wcześniej.'),
                SizedBox(height: 8),
                Text('6. Odwiedzający mogą wyszukiwać fundatorów i sortować listę według kwoty, nazwy lub daty dołączenia.'),
                SizedBox(height: 8),
                Text('7. Wyłączenie publikacji ukrywa profil z publicznej tablicy, ale nie usuwa historii zweryfikowanych wpłat z konta fundatora.'),
              ],
            ),
            const SizedBox(height: 10),
          ] else if (tab == 2) ...[
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
          ] else if (tab == 3) ...[
            const Text('Zgłoś problem z wpłatą', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Zgłoszenie nie księguje wpłaty automatycznie. Administrator sprawdzi ją w PayPal lub BuyCoffee.'),
            TextField(controller: issueEmail, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail użyty przy wpłacie')),
            DropdownButtonFormField<String>(initialValue: issueProvider,
              items: const [DropdownMenuItem(value: 'PayPal', child: Text('PayPal')), DropdownMenuItem(value: 'BuyCoffee', child: Text('BuyCoffee'))],
              onChanged: (v) => setState(() => issueProvider = v ?? 'PayPal'),
              decoration: const InputDecoration(labelText: 'Metoda wpłaty')),
            TextField(controller: issueAmount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Kwota wpłaty PLN')),
            TextField(controller: issueReference, decoration: const InputDecoration(labelText: 'Numer transakcji z potwierdzenia')),
            const Text('Numer transakcji to identyfikator płatności widoczny w szczegółach PayPal lub BuyCoffee. Nie jest to numer karty ani hasło.'),
            TextField(controller: issueDetails, maxLines: 3, maxLength: 2000, decoration: const InputDecoration(labelText: 'Opis problemu')),
            FilledButton.icon(onPressed: busy ? null : submitIssue, icon: const Icon(Icons.send_outlined), label: const Text('Wyślij zgłoszenie')),
            const SizedBox(height: 12),
            const Text('Historia zgłoszeń', style: TextStyle(fontWeight: FontWeight.bold)),
            for (final issue in issues.where((e) => e['founder_id'] == FounderBackend.client.auth.currentUser?.id))
              ListTile(title: Text('${issue['provider']} — ${issue['transaction_reference']}'),
                subtitle: Text('Status: ${issue['status']}')),
          ] else if (tab == 4 && adminEnabled) ...[
            const Text('ADMINISTRATOR — WERYFIKACJA WPŁAT', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
            const Text('Sprawdź rzeczywistą wpłatę u operatora przed zatwierdzeniem. E-mail musi odpowiadać kontu fundatora.'),
            TextField(controller: adminEmail, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail konta fundatora')),
            TextField(controller: adminAmount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Kwota PLN')),
            TextField(controller: adminReference, decoration: const InputDecoration(labelText: 'Unikalny numer transakcji')),
            const Text('UUID to wewnętrzny identyfikator konta fundatora. Nie musisz go wpisywać — system znajdzie konto po e-mailu. Unikalny numer transakcji to ID płatności nadane przez PayPal lub BuyCoffee; zapobiega podwójnemu zaksięgowaniu.'),
            FilledButton.icon(onPressed: busy ? null : approvePayment, icon: const Icon(Icons.verified_user_outlined), label: const Text('Zatwierdź zweryfikowaną wpłatę')),
            const SizedBox(height: 14),
            const Text('Zgłoszenia wpłat', style: TextStyle(fontWeight: FontWeight.bold)),
            OutlinedButton.icon(onPressed: loadIssues, icon: const Icon(Icons.refresh), label: const Text('Odśwież zgłoszenia')),
            for (final issue in issues)
              ListTile(
                title: Text('${issue['provider']} — ${issue['payment_email']}'),
                subtitle: Text('${issue['transaction_reference']} • ${((issue['amount_grosz'] as num).toInt() / 100).toStringAsFixed(2)} PLN\n${issue['details']}'),
                isThreeLine: true),
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
