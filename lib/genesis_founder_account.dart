import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'genesis_language.dart';

/// Independent founder authentication. No Genesis personal account is reused.
class FounderBackend {
  static const url = 'https://xhzxoqbfqdttkvgxogse.supabase.co';
  static const publishableKey = 'sb_publishable_dZGtqstR0cBLqqpr0Cde1Q_Mmzg7NW6';
  static final SupabaseClient client = SupabaseClient(
    url, publishableKey,
    authOptions: const AuthClientOptions(
      authFlowType: AuthFlowType.implicit,
      autoRefreshToken: false,
    ),
  );
  // Founder auth uses a standalone client without an unconfigured
  // session storage adapter. It never shares Genesis member sessions.
  static Future<void> ensureInitialized() async {}
}

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
  String? message;

  Future<void> resend() async {
    if (busy) return;
    setState(() { busy = true; message = null; });
    try {
      await FounderBackend.ensureInitialized();
      await FounderBackend.client.auth.resend(
        type: OtpType.signup,
        email: widget.email,
        emailRedirectTo: 'https://thegenesisera.com/',
      );
      if (mounted) {
        setState(() => message =
          'Przyjęto prośbę o wysłanie wiadomości. Sprawdź także spam.');
      }
    } on AuthException catch (error) {
      if (mounted) {
        setState(() => message = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Aktywacja fundatora')),
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.mark_email_read_outlined, size: 64),
          const SizedBox(height: 18),
          const Text('Potwierdź adres e-mail',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SelectableText(widget.email),
          const SizedBox(height: 12),
          const Text('Kliknij link aktywacyjny z wiadomości, '
            'a następnie wróć do logowania fundatora.',
            textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: busy ? null : resend,
            child: Text(busy ? 'Wysyłanie…' : 'Wyślij link ponownie')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Wróć do logowania')),
          if (message != null) SelectableText(message!),
        ]),
      ),
    )),
  );
}

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
  final organization = TextEditingController();
  late bool registering;
  bool busy = false;
  bool signedIn = false;
  bool showPassword = false;
  bool showRepeatPassword = false;
  String? message;
  String? organizationName;
  String? emailError;
  String? organizationError;
  String? passwordError;
  String? repeatPasswordError;

  void clearFieldErrors() {
    setState(() {
      emailError = null;
      organizationError = null;
      passwordError = null;
      repeatPasswordError = null;
      message = null;
    });
  }

  @override
  void initState() {
    super.initState();
    registering = widget.startRegistering;
    initializeFounderSession();
  }

  Future<void> initializeFounderSession() async {
    try {
      await FounderBackend.ensureInitialized();
      if (!mounted) {
        return;
      }
      final hasSession = FounderBackend.client.auth.currentSession != null;
      setState(() => signedIn = hasSession);
      if (hasSession) await loadProfile();
    } catch (error) {
      if (mounted) {
        setState(() => message =
          'Nie udało się uruchomić logowania fundatora: $error');
      }
    }
  }

  Future<void> loadProfile() async {
    final user = FounderBackend.client.auth.currentUser;
    if (user == null) return;
    try {
      final row = await FounderBackend.client.from('founder_profiles')
        .select('organization_name').eq('user_id', user.id).maybeSingle();
      if (mounted) {
        setState(() => organizationName =
          row?['organization_name'] as String? ?? 'Fundator');
      }
    } catch (error) {
      if (mounted) {
        setState(() => message = error.toString());
      }
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    repeatPassword.dispose();
    organization.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    setState(() { busy = true; message = null;
      emailError = null; organizationError = null;
      passwordError = null; repeatPasswordError = null; });
    try {
      await FounderBackend.ensureInitialized();
      final address = email.text.trim().toLowerCase();
      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(address)) {
        setState(() => emailError = 'Wpisz poprawny adres e-mail.');
        return;
      }
      if (registering) {
        final name = organization.text.trim();
        if (name.length < 2 || name.length > 120) {
          setState(() => organizationError = 'Podaj nazwę firmy (2–120 znaków).');
          return;
        }
        if (password.text.length < 8) {
          setState(() => passwordError = 'Hasło musi mieć co najmniej 8 znaków.');
          return;
        }
        if (password.text != repeatPassword.text) {
          setState(() => repeatPasswordError = 'Hasła muszą być identyczne.');
          return;
        }
        final response = await FounderBackend.client.auth.signUp(
          email: address,
          password: password.text,
          data: {'organization_name': name},
          emailRedirectTo: 'https://thegenesisera.com/',
        );
        if (!mounted) {
          return;
        }
        if (response.user?.identities?.isEmpty == true) {
          setState(() => message =
            'Ten adres jest już zarejestrowany jako fundator.');
          return;
        }
        if (response.session != null) {
          setState(() { signedIn = true; organizationName = name; });
        } else {
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => GenesisFounderEmailConfirmation(email: address)));
          if (mounted) {
            setState(() { registering = false; message =
              'Po aktywacji e-maila zaloguj się na konto fundatora.'; });
          }
        }
      } else {
        await FounderBackend.client.auth.signInWithPassword(
          email: address, password: password.text);
        if (mounted) {
          setState(() { signedIn = true; message = null; });
          await loadProfile();
        }
      }
    } on AuthException catch (error) {
      final duplicate = error.code == 'email_exists' ||
          error.code == 'user_already_exists' ||
          error.message.toLowerCase().contains('already registered');
      if (mounted) {
        setState(() => message = duplicate
          ? 'Ten adres e-mail jest już zarejestrowany jako fundator.'
          : error.message);
      }
    } catch (error) {
      debugPrint('Founder authentication failed: $error');
      if (mounted) {
        setState(() => message =
          'Nie udało się wykonać operacji. Sprawdź dane i spróbuj ponownie.');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> signOut() async {
    await FounderBackend.ensureInitialized();
    await FounderBackend.client.auth.signOut();
    if (mounted) {
      setState(() {
        signedIn = false;
        organizationName = null;
        message = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (signedIn) {
      return Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.verified_user_outlined, size: 54),
          const SizedBox(height: 12),
          Text('Konto fundatora: ${organizationName ?? "Fundator"}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 10),
          Text(FounderBackend.client.auth.currentUser?.email ?? ''),
          const SizedBox(height: 12),
          const Text('To niezależne konto firmowe. Nie przyznaje GP '
            'ani uprawnień prywatnego konta Genesis.',
            textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: signOut,
            child: const Text('Wyloguj fundatora')),
          if (message != null) SelectableText(message!),
        ]),
      ));
    }
    return Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: SingleChildScrollView(padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('KONTO FUNDATORA', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(GenesisLanguage.copy(
            'Oddzielne konto i hasło. Możesz użyć tego samego e-maila '
            'co w prywatnym koncie Genesis.',
            'Separate founder account and password. You may use the '
            'same email as your personal Genesis account.'),
            textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: busy ? null : () => setState(() {
                registering = false; message = null;
              }), child: const Text('Logowanie'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(
              onPressed: busy ? null : () => setState(() {
                registering = true; message = null;
              }), child: const Text('Rejestracja'))),
          ]),
          const SizedBox(height: 16),
          TextField(controller: email,
            onChanged: (_) => clearFieldErrors(),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(labelText: 'E-mail', errorText: emailError)),
          const SizedBox(height: 12),
          if (registering) ...[
            TextField(controller: organization,
              onChanged: (_) => clearFieldErrors(),
              decoration: InputDecoration(labelText: 'Nazwa firmy',
                errorText: organizationError)),
            const SizedBox(height: 12),
          ],
          TextField(controller: password, obscureText: !showPassword,
            enableSuggestions: false,
            autocorrect: false,
            onChanged: (_) => clearFieldErrors(),
            decoration: InputDecoration(
              errorText: passwordError,
              labelText: 'Hasło fundatora',
              suffixIcon: IconButton(
                tooltip: showPassword ? 'Ukryj hasło' : 'Pokaż hasło',
                icon: Icon(showPassword
                  ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => showPassword = !showPassword),
              ),
            )),
          if (registering) ...[
            const SizedBox(height: 12),
            TextField(controller: repeatPassword,
              obscureText: !showRepeatPassword,
              enableSuggestions: false,
              autocorrect: false,
              onChanged: (_) => clearFieldErrors(),
              decoration: InputDecoration(
                errorText: repeatPasswordError,
                labelText: 'Powtórz hasło',
                suffixIcon: IconButton(
                  tooltip: showRepeatPassword ? 'Ukryj hasło' : 'Pokaż hasło',
                  icon: Icon(showRepeatPassword
                    ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(
                    () => showRepeatPassword = !showRepeatPassword),
                ),
              )),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: busy ? null : submit,
            child: Text(busy ? 'Proszę czekać…' :
              registering ? 'Załóż konto fundatora' : 'Zaloguj fundatora')),
          if (message != null) ...[
            const SizedBox(height: 14),
            SelectableText(message!, textAlign: TextAlign.center),
          ],
        ]),
      ),
    ));
  }
}
