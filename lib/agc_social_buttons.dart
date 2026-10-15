import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Social sign-in is enabled by the website operator after setting up
/// the corresponding OAuth application in Google/Meta and Supabase Auth.
/// No OAuth client secrets are ever stored in Flutter or GitHub.
class AgcSocialButtons extends StatefulWidget {
  const AgcSocialButtons({super.key, required this.onSignIn});
  final Future<void> Function(OAuthProvider provider) onSignIn;

  @override
  State<AgcSocialButtons> createState() => _AgcSocialButtonsState();
}

class _AgcSocialButtonsState extends State<AgcSocialButtons> {
  OAuthProvider? pending;
  String? error;

  Future<void> _login(OAuthProvider provider) async {
    if (pending != null) return;
    setState(() { pending = provider; error = null; });
    try {
      await widget.onSignIn(provider);
      // On Flutter web, Supabase redirects away from this page.
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => error =
          'Nie udało się zalogować: ${e.message}. '
          'Jeśli używasz Google/Facebook, administrator AGC musi włączyć ten sposób logowania.');
      }
    } on UnsupportedError catch (e) {
      if (mounted) {
        setState(() => error = e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => error =
          'Logowanie przez ten serwis jest jeszcze niedostępne. '
          'Możesz użyć adresu e-mail i hasła.');
      }
    } finally {
      if (mounted) {
        setState(() => pending = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    const Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Row(children: [
        Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('LUB KONTY ZEWNĘTRZNE',
            style: TextStyle(color: Colors.white70, fontSize: 11)),
        ),
        Expanded(child: Divider()),
      ]),
    ),
    OutlinedButton.icon(
      key: const Key('oauth_google'),
      onPressed: pending == null ? () => _login(OAuthProvider.google) : null,
      icon: const Icon(Icons.g_mobiledata, size: 29),
      label: const Text('Kontynuuj przez Google'),
    ),
    const SizedBox(height: 9),
    OutlinedButton.icon(
      key: const Key('oauth_facebook'),
      onPressed: pending == null ? () => _login(OAuthProvider.facebook) : null,
      icon: const Icon(Icons.facebook, size: 24),
      label: const Text('Kontynuuj przez Facebook'),
    ),
    if (pending != null) const Padding(
      padding: EdgeInsets.all(10),
      child: LinearProgressIndicator(),
    ),
    if (error != null) Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Text(error!, style: const TextStyle(color: Colors.orangeAccent),
        textAlign: TextAlign.center),
    ),
    const Padding(
      padding: EdgeInsets.only(top: 8),
      child: Text('Dostępność Google i Facebook wymaga włączenia dostawców przez AGC. '
        'Przy pierwszym logowaniu profil Genesis powstanie automatycznie.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white54, fontSize: 11)),
    ),
  ]);
}
