import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'agc_luxury_theme.dart';
import 'genesis_language.dart';
import 'agc_poster_stub.dart' if (dart.library.html) 'agc_poster_web.dart' as poster;

const genesisSiteUrl = 'https://aiglobalcommunity.github.io/ai-global-app/';

String genesisInviteLink(String code) => Uri.parse(genesisSiteUrl)
    .replace(queryParameters: {'ref': code}).toString();

class GenesisInvitePanel extends StatefulWidget {
  const GenesisInvitePanel({super.key, required this.code, required this.confirmedCount});
  final String code;
  final int confirmedCount;

  @override
  State<GenesisInvitePanel> createState() => _GenesisInvitePanelState();
}

class _GenesisInvitePanelState extends State<GenesisInvitePanel> {
  final friendEmail = TextEditingController();
  String? message;
  bool generating = false;

  @override
  void dispose() {
    friendEmail.dispose();
    super.dispose();
  }

  String get link => genesisInviteLink(widget.code);

  Future<void> _open(Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.platformDefault)) {
        _notify('Nie można otworzyć aplikacji. Skopiuj link i udostępnij ręcznie.');
      }
    } catch (_) {
      _notify('Nie można otworzyć aplikacji. Skopiuj link i udostępnij ręcznie.');
    }
  }

  void _notify(String value) {
    if (mounted) setState(() => message = value);
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: link));
    _notify('Skopiowano Twój osobisty link zaproszenia.');
  }

  Future<void> _email() async {
    final address = friendEmail.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(address)) {
      _notify('Wpisz poprawny adres e-mail znajomego.');
      return;
    }
    final subject = Uri.encodeComponent('Zaproszenie do THE GENESIS ERA');
    final body = Uri.encodeComponent(
      'Cześć! Zapraszam Cię do THE GENESIS ERA — globalnej społeczności Genesis.\n\n'
      'Dołącz przez mój osobisty link:\n$link\n\nDo zobaczenia w Genesis!');
    await _open(Uri.parse('mailto:${Uri.encodeComponent(address)}?subject=$subject&body=$body'));
    _notify('Otworzono program pocztowy. Wyślij przygotowaną wiadomość, aby zaprosić znajomego.');
  }

  Future<void> _social(String service) async {
    final encodedLink = Uri.encodeComponent(link);
    final encodedText = Uri.encodeComponent('Dołącz do THE GENESIS ERA ✨');
    final target = switch (service) {
      'Facebook' => 'https://www.facebook.com/sharer/sharer.php?u=$encodedLink',
      'X' => 'https://twitter.com/intent/tweet?url=$encodedLink&text=$encodedText',
      'Instagram' => 'https://www.instagram.com/',
      'TikTok' => 'https://www.tiktok.com/',
      'YouTube' => 'https://www.youtube.com/',
      _ => genesisSiteUrl,
    };
    if (service != 'Facebook' && service != 'X') {
      await _copy();
      _notify('Skopiowano link. Dodaj pobrany obraz i wklej link w opisie/profilu $service.');
    }
    await _open(Uri.parse(target));
  }

  Future<void> _poster() async {
    if (generating) return;
    setState(() => generating = true);
    try {
      final success = await poster.downloadGenesisPoster(link);
      _notify(success
          ? 'Pobrano obraz PNG 1080×1350. Możesz dodać go na Instagram, TikTok, Facebook, X lub YouTube.'
          : 'Pobieranie plakatu jest dostępne w wersji internetowej.');
    } catch (_) {
      _notify('Nie udało się wygenerować obrazu. Spróbuj ponownie.');
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(GenesisLanguage.t('invite').toUpperCase(), style: const TextStyle(
          color: AgcLuxury.champagne, fontSize: 19, fontWeight: FontWeight.bold,
          letterSpacing: 1.2)),
        const SizedBox(height: 7),
        Text(GenesisLanguage.copy(
          'Za każdą nową osobę, która dołączy z Twojego linku '
          'i potwierdzi e-mail, otrzymasz 100 GP. '
          'Punkty są naliczane tylko raz za osobę.',
          'For each new member who joins through your link and '
          'confirms their email, you receive 100 GP, once per person.')),
        const SizedBox(height: 12),
        Text('${GenesisLanguage.copy('Potwierdzone polecenia', 'Verified referrals')}: ${widget.confirmedCount}',
          style: const TextStyle(color: AgcLuxury.champagne, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        SelectableText(link, key: const Key('genesis_invite_link'),
          style: const TextStyle(color: AgcLuxury.ivory)),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _copy,
          icon: const Icon(Icons.copy),
          label: Text(GenesisLanguage.t('copy')),
        ),
        const SizedBox(height: 14),
        TextField(
          key: const Key('invite_friend_email'),
          controller: friendEmail,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: GenesisLanguage.t('email'),
            hintText: 'znajomy@example.com',
            prefixIcon: Icon(Icons.mail_outline)),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _email,
          icon: const Icon(Icons.forward_to_inbox),
          label: Text(GenesisLanguage.copy('Zaproś e-mailem', 'Invite by email')),
        ),
        const SizedBox(height: 8),
        Text(GenesisLanguage.copy(
          'Wiadomość otworzy się w Twojej poczcie — '
          'aplikacja nie wysyła jej bez Twojego potwierdzenia.',
          'Your email app opens with a draft; nothing is sent '
          'without your confirmation.'),
          style: const TextStyle(fontSize: 12, color: Colors.white70)),
        const SizedBox(height: 18),
        FilledButton.tonalIcon(
          onPressed: generating ? null : _poster,
          icon: const Icon(Icons.image_outlined),
          label: Text(generating
            ? GenesisLanguage.copy('Tworzenie grafiki...', 'Creating image...')
            : GenesisLanguage.copy('Generuj grafikę PNG do social mediów', 'Create a PNG social poster')),
        ),
        const SizedBox(height: 10),
        Text(GenesisLanguage.t('share').toUpperCase(), style: const TextStyle(
          color: AgcLuxury.champagne, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Wrap(spacing: 7, runSpacing: 7, children: [
          for (final service in ['Facebook', 'X', 'Instagram', 'TikTok', 'YouTube'])
            OutlinedButton(
              onPressed: () => _social(service),
              child: Text(service),
            ),
        ]),
        const SizedBox(height: 7),
        const Text('Facebook i X otwierają okno udostępniania. '
          'Instagram, TikTok i YouTube wymagają ręcznego dodania grafiki '
          'i linku — te serwisy nie umożliwiają automatycznej publikacji w ten sposób.',
          style: TextStyle(fontSize: 12, color: Colors.white70)),
        if (message != null) ...[
          const SizedBox(height: 10),
          Text(message!, style: const TextStyle(color: AgcLuxury.champagne)),
        ],
      ]),
    ),
  );
}
