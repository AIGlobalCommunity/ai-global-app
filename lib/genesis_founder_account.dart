import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'agc_backend.dart';
import 'genesis_language.dart';

/// Separate organization identity; it never enters Genesis member rankings.
class GenesisFounderAccount extends StatefulWidget {
  const GenesisFounderAccount({super.key});
  @override
  State<GenesisFounderAccount> createState() => _GenesisFounderAccountState();
}

class _GenesisFounderAccountState extends State<GenesisFounderAccount> {
  final email = TextEditingController();
  final password = TextEditingController();
  final organization = TextEditingController();
  bool registering = false;
  bool busy = false;
  String? message;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    organization.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    setState(() { busy = true; message = null; });
    try {
      if (registering) {
        final name = organization.text.trim();
        if (name.length < 2 || name.length > 120) {
          throw const FormatException('Podaj nazwę firmy (2–120 znaków).');
        }
        if (password.text.length < 8) {
          throw const FormatException('Hasło musi mieć co najmniej 8 znaków.');
        }
        await AgcBackend.client.auth.signUp(
          email: email.text.trim(),
          password: password.text,
          data: {'account_type': 'founder', 'organization_name': name},
          emailRedirectTo: kIsWeb ? 'https://thegenesisera.com/' : null,
        );
        if (mounted) setState(() => message =
          'Konto fundatora zgłoszone. Sprawdź pocztę i potwierdź e-mail. '
          'Wpłaty nie są jeszcze aktywne.');
      } else {
        await AgcBackend.signIn(email.text, password.text);
        final current = AgcBackend.user;
        if (current != null) {
          final account = await AgcBackend.client
            .from('agc_founder_accounts')
            .select('user_id').eq('user_id', current.id).maybeSingle();
          if (account == null) {
            await AgcBackend.signOut();
            throw const FormatException(
              'To konto prywatne Genesis. Zaloguj się przez panel społeczności.');
          }
        }
      }
    } catch (error) {
      if (mounted) setState(() => message = error.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: SingleChildScrollView(padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(GenesisLanguage.copy('KONTO FUNDATORA', 'FOUNDER ACCOUNT'),
            textAlign: TextAlign.center, style: const TextStyle(
              fontSize: 22, color: Color(0xFFD8B66A),
              fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(GenesisLanguage.copy(
            'Konto firmy jest oddzielne od prywatnego konta Genesis. '
            'Nie otrzymuje GP ani praw głosu.',
            'Company accounts are separate from personal Genesis accounts. '
            'They do not earn GP or voting rights.'),
            textAlign: TextAlign.center),
          const SizedBox(height: 20),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(GenesisLanguage.copy(
                'Logowanie', 'Sign in'))),
              ButtonSegment(value: true, label: Text(GenesisLanguage.copy(
                'Rejestracja', 'Register'))),
            ],
            selected: {registering},
            onSelectionChanged: (value) =>
              setState(() { registering = value.first; message = null; }),
          ),
          const SizedBox(height: 16),
          if (registering) ...[
            TextField(controller: organization,
              decoration: InputDecoration(labelText: GenesisLanguage.copy(
                'Nazwa firmy lub instytucji', 'Organization name'))),
            const SizedBox(height: 10),
          ],
          TextField(controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-mail')),
          const SizedBox(height: 10),
          TextField(controller: password, obscureText: true,
            decoration: InputDecoration(labelText: GenesisLanguage.copy(
              'Hasło', 'Password'))),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy ? null : submit,
            child: Text(busy ? '...' : registering
              ? GenesisLanguage.copy('Załóż konto fundatora', 'Create founder account')
              : GenesisLanguage.copy('Zaloguj fundatora', 'Founder sign in')),
          ),
          if (message != null) ...[
            const SizedBox(height: 14),
            SelectableText(message!, textAlign: TextAlign.center),
          ],
        ]),
      ),
    ),
  );
}
