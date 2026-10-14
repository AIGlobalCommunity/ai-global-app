import 'package:flutter/material.dart';
import 'agc_social_buttons.dart';
import 'genesis_language.dart';
import 'agc_luxury_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _gold = AgcLuxury.champagne;

String? validateAgcEmail(String? value) {
  final email = (value ?? '').trim();
  if (email.isEmpty) return 'Wpisz adres e-mail.';
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
    return 'Podaj prawidłowy adres e-mail.';
  }
  return null;
}

String? validateAgcNick(String? value) {
  final nick = (value ?? '').trim();
  if (nick.isEmpty) return 'Wymyśl swój nick.';
  if (!RegExp(r'^[A-Za-z0-9_]{3,20}$').hasMatch(nick)) {
    return 'Nick: 3–20 znaków, litery A–Z, cyfry lub _.';
  }
  return null;
}

String? validateAgcPassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return 'Wymyśl hasło.';
  if (password.length < 8) return 'Hasło powinno mieć co najmniej 8 znaków.';
  return null;
}

/// Dedicated signup route: never reuses login fields.
class AgcRegistrationPage extends StatefulWidget {
  const AgcRegistrationPage({super.key, required this.onSignUp, this.onSocialSignIn});
  final Future<void> Function(String email, String password, String nick, bool showNickPublicly) onSignUp;
  // OAuth creates an account and auto-generates the initial Genesis nickname.
  final Future<void> Function(OAuthProvider provider)? onSocialSignIn;

  @override
  State<AgcRegistrationPage> createState() => _AgcRegistrationPageState();
}

class _AgcRegistrationPageState extends State<AgcRegistrationPage> {
  final formKey = GlobalKey<FormState>();
  final nick = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool showNickPublicly = false;
  bool showPassword = false;
  bool showConfirmation = false;
  bool submitting = false;
  bool submitted = false;
  String? error;

  @override
  void dispose() {
    nick.dispose();
    email.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (submitting || !formKey.currentState!.validate()) return;
    setState(() { submitting = true; error = null; });
    try {
      await widget.onSignUp(email.text.trim(), password.text, nick.text.trim(), showNickPublicly);
      if (mounted) setState(() { submitted = true; });
    } on AuthException catch (e) {
      final code = e.code;
      String message;
      if (code == 'user_already_exists' || code == 'email_exists') {
        message = 'Ten e-mail ma już konto. Wróć do logowania.';
      } else if (code == 'weak_password') {
        message = 'Hasło jest za słabe. Użyj dłuższego, trudniejszego hasła.';
      } else if (code == 'email_address_invalid') {
        message = 'Sprawdź poprawność adresu e-mail.';
      } else if (code == 'over_email_send_rate_limit' || code == 'over_request_rate_limit') {
        message = 'Za dużo prób. Spróbuj później.';
      } else if (code == 'unexpected_failure' || code == 'database_error') {
        message = 'Nie udało się zapisać profilu. Spróbuj użyć innego nicku.';
      } else {
        message = e.message;
      }
      if (mounted) {
        setState(() => error = message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => error =
          'Nie udało się utworzyć konta. Sprawdź połączenie i spróbuj ponownie.');
      }
    } finally {
      if (mounted) {
        setState(() => submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (submitted) {
      return Scaffold(
        appBar: AppBar(title: const Text('Prawie gotowe!')),
        body: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(padding: const EdgeInsets.all(24), child: Column(
            mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.mark_email_read_outlined, color: _gold, size: 78),
              const SizedBox(height: 18),
              const Text('Sprawdź swoją skrzynkę e-mail',
                textAlign: TextAlign.center, style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('Wysłaliśmy prośbę o potwierdzenie adresu ${email.text.trim()}. '
                'Kliknij link z wiadomości, a następnie zaloguj się do THE GENESIS ERA.',
                textAlign: TextAlign.center),
              const SizedBox(height: 12),
              const Text('Jeżeli wiadomości nie ma, sprawdź folder SPAM.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.login),
                label: const Text('Przejdź do logowania'),
              ),
            ],
          )),
        )),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rejestracja THE GENESIS ERA'),
        foregroundColor: _gold,
        actions: const [GenesisLanguagePicker()],
      ),
      body: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Form(key: formKey, child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.diamond_outlined, color: _gold, size: 50),
            const SizedBox(height: 14),
            const Center(child: Text('✦   G E N E S I S   M E M B E R S H I P   ✦',
              style: TextStyle(fontSize: 10,
                color: AgcLuxury.mutedText, letterSpacing: 1))),
            const SizedBox(height: 15),
            const Text('UTWÓRZ KONTO GENESIS', textAlign: TextAlign.center,
              style: TextStyle(color: _gold, fontSize: 22,
                fontWeight: FontWeight.bold, letterSpacing: 1.4)),
            const SizedBox(height: 6),
            const Text('Wypełnij dane konta. Widoczność nicku wybierasz samodzielnie.',
              textAlign: TextAlign.center),
            if (Uri.base.queryParameters['ref'] != null) ...[
              const Text('✦ Rejestrujesz się z linku polecającego. '
                'Po potwierdzeniu e-maila polecenie zostanie zapisane automatycznie.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _gold)),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 24),
            TextFormField(
              key: const Key('signup_nick'),
              controller: nick, textInputAction: TextInputAction.next,
              maxLength: 20, autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: const InputDecoration(
                labelText: 'Twój nick',
                hintText: 'np. GenesisExplorer',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
                helperText: '3–20 znaków: litery, cyfry i _',
              ),
              validator: validateAgcNick,
            ),
            CheckboxListTile(
              key: const Key('signup_show_nick_publicly'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: _gold,
              value: showNickPublicly,
              onChanged: submitting ? null : (value) =>
                setState(() => showNickPublicly = value ?? false),
              title: const Text('Pokazuj mój nick publicznie'),
              subtitle: Text(showNickPublicly
                ? 'Twój nick będzie widoczny w rankingu THE GENESIS ERA.'
                : 'Twój nick pozostanie prywatny. W rankingu pojawi się anonimowy identyfikator.'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('signup_email'),
              controller: email, textInputAction: TextInputAction.next,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: const InputDecoration(
                labelText: GenesisLanguage.t('email'),
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder()),
              validator: validateAgcEmail,
            ),
            const SizedBox(height: 18),
            TextFormField(
              key: const Key('signup_password'),
              controller: password, textInputAction: TextInputAction.next,
              obscureText: !showPassword,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: InputDecoration(
                labelText: 'Wymyśl hasło (minimum 8 znaków)',
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: showPassword ? 'Ukryj hasło' : 'Pokaż hasło',
                  icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => showPassword = !showPassword),
                ),
              ),
              validator: validateAgcPassword,
            ),
            const SizedBox(height: 18),
            TextFormField(
              key: const Key('signup_confirm_password'),
              controller: confirmation, textInputAction: TextInputAction.done,
              obscureText: !showConfirmation,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: InputDecoration(
                labelText: 'Powtórz hasło',
                prefixIcon: const Icon(Icons.verified_user_outlined),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: showConfirmation ? 'Ukryj potwierdzenie' : 'Pokaż potwierdzenie',
                  icon: Icon(showConfirmation ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => showConfirmation = !showConfirmation),
                ),
              ),
              validator: (value) {
                if ((value ?? '').isEmpty) return 'Powtórz hasło.';
                if (value != password.text) return 'Hasła muszą być identyczne.';
                return null;
              },
            ),
            const SizedBox(height: 20),
            if (error != null) ...[
              Text(error!, key: const Key('signup_error'),
                style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              key: const Key('signup_submit'),
              onPressed: submitting ? null : _submit,
              icon: submitting
                ? const SizedBox(height: 18, width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.person_add),
              label: Text(submitting ? 'Tworzenie konta...' : GenesisLanguage.t('signup')),
            ),
            if (widget.onSocialSignIn != null)
              AgcSocialButtons(onSignIn: widget.onSocialSignIn!),
            const SizedBox(height: 14),
            const Text('Po rejestracji potwierdź adres e-mail. '
              'Nie udostępniaj nikomu swojego hasła.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
            TextButton(
              onPressed: submitting ? null : () => Navigator.of(context).pop(),
              child: const Text('Mam już konto — wróć do logowania'),
            ),
          ],
        )),
      )),
    );
  }
}
