import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'agc_backend.dart';
import 'genesis_language.dart';


class GenesisFounderEmailConfirmation extends StatefulWidget {
  const GenesisFounderEmailConfirmation({super.key, required this.email});
  final String email;

  @override
  State<GenesisFounderEmailConfirmation> createState() =>
      _GenesisFounderEmailConfirmationState();
}

class _GenesisFounderEmailConfirmationState
    extends State<GenesisFounderEmailConfirmation> {
  bool busy = false;
  String? status;

  Future<void> resend() async {
    if (busy) return;
    setState(() { busy = true; status = null; });
    try {
      await AgcBackend.resendConfirmation(widget.email);
      if (mounted) {
        setState(() => status =
          'Żądanie ponownego wysłania zostało przyjęte. '
          'Dostarczenie wiadomości zależy od konfiguracji poczty.');
      }
    } catch (error) {
      if (mounted) setState(() => status = error.toString());
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Potwierdź adres e-mail')),
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: SingleChildScrollView(padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Icon(Icons.mark_email_read_outlined,
            size: 72, color: Color(0xFFD8B66A)),
          const SizedBox(height: 18),
          const Text('Aktywacja konta fundatora',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SelectableText(widget.email, textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFD8B66A))),
          const SizedBox(height: 16),
          const Text(
            'Otwórz wiadomość aktywacyjną i kliknij znajdujący się w niej link. '
            'Po potwierdzeniu adresu wróć do strony GENESIS i zaloguj się. '
            'Sprawdź także Spam, Oferty i inne foldery.\n\n'
            'Jeśli adres jest już przypisany do prywatnego konta Genesis, '
            'do konta firmowego użyj innego adresu e-mail.',
            textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: busy ? null : resend,
            icon: const Icon(Icons.forward_to_inbox_outlined),
            label: Text(busy ? 'Wysyłanie…' : 'Wyślij link ponownie')),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.login_rounded),
            label: const Text('Wróć do logowania')),
          if (status != null) ...[
            const SizedBox(height: 14),
            SelectableText(status!, textAlign: TextAlign.center),
          ],
        ])),
    )),
  );
}

/// Separate organization identity; it never enters Genesis member rankings.
class GenesisFounderAccount extends StatefulWidget {
  const GenesisFounderAccount({super.key, this.startRegistering = false});
  final bool startRegistering;
  @override
  State<GenesisFounderAccount> createState() => _GenesisFounderAccountState();
}

class _GenesisFounderAccountState extends State<GenesisFounderAccount> {
  final email = TextEditingController();
  final password = TextEditingController();
  final repeatPassword = TextEditingController();
  bool showPassword = false;
  bool codeStep = false;
  final code = TextEditingController();
  final organization = TextEditingController();
  late bool registering;
  bool busy = false;
  String? message;

  @override
  void initState() {
    super.initState();
    registering = widget.startRegistering;
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    repeatPassword.dispose();
    code.dispose();
    organization.dispose();
    super.dispose();
  }

  Future<void> resendConfirmation() async {
    if (busy) return;
    setState(() { busy = true; message = null; });
    try {
      await AgcBackend.resendConfirmation(email.text.trim());
      if (mounted) {
        setState(() => message =
          'Poproszono o ponowny e-mail aktywacyjny. Sprawdź folder spam.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => message = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> verifyCode() async {
    final token = code.text.trim();
    if (token.length != 6 || int.tryParse(token) == null) {
      setState(() => message = 'Wpisz 6 cyfr z wiadomości e-mail.');
      return;
    }
    setState(() { busy = true; message = null; });
    try {
      await AgcBackend.client.auth.verifyOTP(
        email: email.text.trim(), token: token, type: OtpType.email);
      final current = AgcBackend.user;
      if (current == null) throw StateError('Kod nie został potwierdzony.');
      final account = await AgcBackend.client.from('agc_founder_accounts')
        .select('user_id').eq('user_id', current.id).maybeSingle();
      if (account == null) {
        await AgcBackend.signOut();
        throw const FormatException('To nie jest konto fundatora.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => message = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
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
        if (password.text != repeatPassword.text) {
          throw const FormatException('Hasła nie są identyczne. Sprawdź oba pola.');
        }
        final address = email.text.trim();
        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
            .hasMatch(address)) {
          throw const FormatException('Wpisz poprawny adres e-mail.');
        }
        if (AgcBackend.user != null) {
          throw const FormatException(
            'Jesteś zalogowany. Wyloguj się, aby zarejestrować oddzielne konto fundatora.');
        }
        final response = await AgcBackend.client.auth.signUp(
          email: address,
          password: password.text,
          data: {'account_type': 'founder', 'organization_name': name},
          emailRedirectTo: kIsWeb ? 'https://thegenesisera.com/' : null,
        );
        if (!mounted) {
          return;
        }
        if (response.user?.identities?.isEmpty == true) {
          setState(() => message =
            'Ten adres e-mail jest już zarejestrowany. '
            'Podaj inny adres, aby utworzyć oddzielne konto fundatora.');
          return;
        }
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => GenesisFounderEmailConfirmation(
            email: email.text.trim())));
        if (mounted) {
          setState(() {
            registering = false;
            message = 'Po aktywacji adresu możesz zalogować się jako fundator.';
          });
        }
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
          await AgcBackend.signOut();
          await AgcBackend.client.auth.signInWithOtp(
            email: email.text.trim(), shouldCreateUser: false,
            emailRedirectTo: kIsWeb ? 'https://thegenesisera.com/' : null);
          if (mounted) {
            setState(() {
            codeStep = true;
            message = 'Wysłano kod e-mail. Wpisz 6 cyfr.';
          });
          }
        }
      }
    } on AuthException catch (error) {
      final duplicate = error.code == 'email_exists' ||
          error.code == 'user_already_exists' ||
          error.message.toLowerCase().contains('already registered');
      if (mounted) {
        setState(() => message = duplicate
          ? 'Ten adres e-mail jest już zarejestrowany. Podaj inny adres.'
          : error.message);
      }
    } catch (error) {
      if (mounted) {
        setState(() => message = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
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
          Row(children: [
            Expanded(child: registering
              ? OutlinedButton.icon(
                  onPressed: () => setState(() { registering = false; message = null; }),
                  icon: const Icon(Icons.login_rounded),
                  label: Text(GenesisLanguage.copy('Logowanie', 'Sign in')))
              : FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.login_rounded),
                  label: Text(GenesisLanguage.copy('Logowanie', 'Sign in')))),
            const SizedBox(width: 10),
            Expanded(child: registering
              ? FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: Text(GenesisLanguage.copy('Rejestracja', 'Register')))
              : OutlinedButton.icon(
                  onPressed: () => setState(() { registering = true; message = null; }),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: Text(GenesisLanguage.copy('Rejestracja', 'Register')))),
          ]),
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
          TextField(controller: password, obscureText: !showPassword,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              labelText: GenesisLanguage.copy('Hasło', 'Password'),
              suffixIcon: IconButton(
                tooltip: GenesisLanguage.copy('Pokaż lub ukryj hasło', 'Show or hide password'),
                onPressed: () => setState(() => showPassword = !showPassword),
                icon: Icon(showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined)))),
          if (registering) ...[
            const SizedBox(height: 10),
            TextField(controller: repeatPassword, obscureText: !showPassword,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.verified_user_outlined),
                labelText: GenesisLanguage.copy('Powtórz hasło', 'Confirm password'),
                helperText: GenesisLanguage.copy(
                  'Hasła muszą być identyczne', 'Passwords must match'))),
          ],
          if (codeStep && !registering) ...[
            const SizedBox(height: 10),
            TextField(controller: code, maxLength: 6,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.mark_email_read_outlined),
                labelText: '6-cyfrowy kod e-mail')),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 17),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: busy ? null : (codeStep && !registering ? verifyCode : submit),
            icon: Icon(registering ? Icons.how_to_reg_rounded : Icons.login_rounded),
            label: Text(busy ? '...' : codeStep && !registering
              ? GenesisLanguage.copy('Potwierdź kod', 'Verify code') : registering
              ? GenesisLanguage.copy('Załóż konto fundatora', 'Create founder account')
              : GenesisLanguage.copy('Zaloguj fundatora', 'Founder sign in')),
          ),
          if (registering) TextButton.icon(
            onPressed: busy ? null : resendConfirmation,
            icon: const Icon(Icons.mark_email_unread_outlined),
            label: Text(GenesisLanguage.copy(
              'Nie otrzymałem linku aktywacyjnego – wyślij ponownie',
              'Activation email missing – resend'))),
          if (message != null) ...[
            const SizedBox(height: 14),
            SelectableText(message!, textAlign: TextAlign.center),
          ],
        ]),
      ),
    ),
  );
}
)
            .hasMatch(address)) {
          throw const FormatException('Wpisz poprawny adres e-mail.');
        }
        if (AgcBackend.user != null) {
          throw const FormatException(
            'Jesteś zalogowany. Wyloguj się, aby zarejestrować oddzielne konto fundatora.');
        }
        final response = await AgcBackend.client.auth.signUp(
          email: address,
          password: password.text,
          data: {'account_type': 'founder', 'organization_name': name},
          emailRedirectTo: kIsWeb ? 'https://thegenesisera.com/' : null,
        );
        if (!mounted) {
          return;
        }
        if (response.user?.identities?.isEmpty == true) {
          setState(() => message =
            'Ten adres e-mail jest już zarejestrowany. '
            'Podaj inny adres, aby utworzyć oddzielne konto fundatora.');
          return;
        }
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => GenesisFounderEmailConfirmation(
            email: email.text.trim())));
        if (mounted) {
          setState(() {
            registering = false;
            message = 'Po aktywacji adresu możesz zalogować się jako fundator.';
          });
        }
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
          await AgcBackend.signOut();
          await AgcBackend.client.auth.signInWithOtp(
            email: email.text.trim(), shouldCreateUser: false,
            emailRedirectTo: kIsWeb ? 'https://thegenesisera.com/' : null);
          if (mounted) {
            setState(() {
            codeStep = true;
            message = 'Wysłano kod e-mail. Wpisz 6 cyfr.';
          });
          }
        }
      }
    } on AuthException catch (error) {
      final duplicate = error.code == 'email_exists' ||
          error.code == 'user_already_exists' ||
          error.message.toLowerCase().contains('already registered');
      if (mounted) {
        setState(() => message = duplicate
          ? 'Ten adres e-mail jest już zarejestrowany. Podaj inny adres.'
          : error.message);
      }
    } catch (error) {
      if (mounted) {
        setState(() => message = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
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
          Row(children: [
            Expanded(child: registering
              ? OutlinedButton.icon(
                  onPressed: () => setState(() { registering = false; message = null; }),
                  icon: const Icon(Icons.login_rounded),
                  label: Text(GenesisLanguage.copy('Logowanie', 'Sign in')))
              : FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.login_rounded),
                  label: Text(GenesisLanguage.copy('Logowanie', 'Sign in')))),
            const SizedBox(width: 10),
            Expanded(child: registering
              ? FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: Text(GenesisLanguage.copy('Rejestracja', 'Register')))
              : OutlinedButton.icon(
                  onPressed: () => setState(() { registering = true; message = null; }),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: Text(GenesisLanguage.copy('Rejestracja', 'Register')))),
          ]),
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
          TextField(controller: password, obscureText: !showPassword,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              labelText: GenesisLanguage.copy('Hasło', 'Password'),
              suffixIcon: IconButton(
                tooltip: GenesisLanguage.copy('Pokaż lub ukryj hasło', 'Show or hide password'),
                onPressed: () => setState(() => showPassword = !showPassword),
                icon: Icon(showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined)))),
          if (registering) ...[
            const SizedBox(height: 10),
            TextField(controller: repeatPassword, obscureText: !showPassword,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.verified_user_outlined),
                labelText: GenesisLanguage.copy('Powtórz hasło', 'Confirm password'),
                helperText: GenesisLanguage.copy(
                  'Hasła muszą być identyczne', 'Passwords must match'))),
          ],
          if (codeStep && !registering) ...[
            const SizedBox(height: 10),
            TextField(controller: code, maxLength: 6,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.mark_email_read_outlined),
                labelText: '6-cyfrowy kod e-mail')),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 17),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: busy ? null : (codeStep && !registering ? verifyCode : submit),
            icon: Icon(registering ? Icons.how_to_reg_rounded : Icons.login_rounded),
            label: Text(busy ? '...' : codeStep && !registering
              ? GenesisLanguage.copy('Potwierdź kod', 'Verify code') : registering
              ? GenesisLanguage.copy('Załóż konto fundatora', 'Create founder account')
              : GenesisLanguage.copy('Zaloguj fundatora', 'Founder sign in')),
          ),
          if (registering) TextButton.icon(
            onPressed: busy ? null : resendConfirmation,
            icon: const Icon(Icons.mark_email_unread_outlined),
            label: Text(GenesisLanguage.copy(
              'Nie otrzymałem linku aktywacyjnego – wyślij ponownie',
              'Activation email missing – resend'))),
          if (message != null) ...[
            const SizedBox(height: 14),
            SelectableText(message!, textAlign: TextAlign.center),
          ],
        ]),
      ),
    ),
  );
}
