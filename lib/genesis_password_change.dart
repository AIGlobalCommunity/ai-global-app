import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'agc_backend.dart';
import 'agc_luxury_theme.dart';
import 'genesis_language.dart';

/// Signed-in password change. Passwords are sent only to Supabase Auth.
class GenesisPasswordChange extends StatefulWidget {
  const GenesisPasswordChange({super.key});

  @override
  State<GenesisPasswordChange> createState() => _GenesisPasswordChangeState();
}

class _GenesisPasswordChangeState extends State<GenesisPasswordChange> {
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool busy = false;
  bool showPassword = false;
  String? notice;
  bool success = false;

  @override
  void dispose() {
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> changePassword() async {
    if (busy) {
      return;
    }
    final next = password.text;
    if (next.length < 8) {
      setState(() {
        success = false;
        notice = GenesisLanguage.copy(
          'Hasło musi mieć co najmniej 8 znaków.',
          'Password must contain at least 8 characters.');
      });
      return;
    }
    if (next != confirmation.text) {
      setState(() {
        success = false;
        notice = GenesisLanguage.copy(
          'Podane hasła są różne.',
          'Passwords do not match.');
      });
      return;
    }
    setState(() { busy = true; notice = null; });
    try {
      final result = await AgcBackend.client.auth.updateUser(
        UserAttributes(password: next));
      if (result.user == null) {
        throw StateError('Password update did not return a user');
      }
      password.clear();
      confirmation.clear();
      if (mounted) {
        setState(() {
          success = true;
          notice = GenesisLanguage.copy(
            'Hasło zostało zmienione. Użyj nowego hasła przy kolejnym logowaniu.',
            'Password changed. Use your new password next time you sign in.');
        });
      }
    } on AuthException catch (error) {
      if (mounted) {
        final requiresReauth =
          error.message.toLowerCase().contains('reauth') ||
          error.message.toLowerCase().contains('nonce');
        setState(() {
          success = false;
          notice = requiresReauth
            ? GenesisLanguage.copy(
                'Ze względów bezpieczeństwa wymagane jest ponowne '
                'uwierzytelnienie. Zaloguj się ponownie i spróbuj.',
                'For security, you need to reauthenticate. '
                'Sign in again and retry.')
            : error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          success = false;
          notice = GenesisLanguage.copy(
            'Nie udało się zmienić hasła. Spróbuj ponownie.',
            'Could not change password. Please try again.');
        });
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 16),
      Text(GenesisLanguage.copy('Zmień hasło', 'Change password'),
        style: const TextStyle(
          color: AgcLuxury.champagne, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Text(GenesisLanguage.copy(
        'Wpisz nowe hasło i potwierdź je. '
        'Dla bezpieczeństwa użyj unikalnego hasła.',
        'Enter and confirm your new password. '
        'For security, use a unique password.'),
        style: const TextStyle(color: Colors.white70, fontSize: 12)),
      const SizedBox(height: 12),
      TextField(
        key: const Key('account_new_password'),
        controller: password,
        obscureText: !showPassword,
        enableSuggestions: false,
        autocorrect: false,
        autofillHints: const [AutofillHints.newPassword],
        decoration: InputDecoration(
          labelText: GenesisLanguage.copy('Nowe hasło', 'New password'),
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            tooltip: GenesisLanguage.copy(
              'Pokaż lub ukryj hasło', 'Show or hide password'),
            icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => showPassword = !showPassword),
          ),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        key: const Key('account_confirm_password'),
        controller: confirmation,
        obscureText: !showPassword,
        enableSuggestions: false,
        autocorrect: false,
        autofillHints: const [AutofillHints.newPassword],
        decoration: InputDecoration(
          labelText: GenesisLanguage.copy(
            'Potwierdź nowe hasło', 'Confirm new password'),
          border: const OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        key: const Key('account_change_password'),
        onPressed: busy ? null : changePassword,
        icon: const Icon(Icons.lock_reset),
        label: Text(busy
          ? GenesisLanguage.copy('Zmieniam hasło…', 'Changing password…')
          : GenesisLanguage.copy('Zmień hasło', 'Change password')),
      ),
      if (notice != null) ...[
        const SizedBox(height: 10),
        Text(notice!, style: TextStyle(
          color: success ? AgcLuxury.champagne : Colors.orangeAccent)),
      ],
      const SizedBox(height: 8),
    ],
  );
}
