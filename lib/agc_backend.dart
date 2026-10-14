import 'dart:async';
import 'package:flutter/foundation.dart';
import 'genesis_artwork.dart';
import 'agc_countdown.dart';
import 'agc_registration.dart';
import 'agc_social_buttons.dart';
import 'agc_luxury_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase is optional in development. Without credentials the app remains a demo.
class AgcBackend {
  // Project URL and publishable key are intentionally public client credentials.
  // Never add a service role / secret key to the app.
  static const projectUrl = String.fromEnvironment('SUPABASE_URL',
    defaultValue: 'https://gjnddmurmegbklvedhnp.supabase.co');
  static const projectPublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_Ty3Beae5ztODv0MM3Z_HDA_WEGwOyLP');
  static bool _initialized = false;
  static bool get configured => _initialized;

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    if (projectUrl.isEmpty || projectPublishableKey.isEmpty) return;
    await Supabase.initialize(
      url: projectUrl,
      publishableKey: projectPublishableKey,
    );
    _initialized = true;
  }

  static User? get user => configured ? client.auth.currentUser : null;

  static Future<void> signUp(String email, String password, String nick) async {
    if (!configured) throw StateError('Backend is not configured.');
    final validatedEmail = email.trim();
    if (validatedEmail.isEmpty || !validatedEmail.contains('@') || !validatedEmail.split('@').last.contains('.')) {
      throw const FormatException('Wpisz poprawny adres e-mail przed utworzeniem konta.');
    }
    if (validateAgcNick(nick) != null) {
      throw FormatException(validateAgcNick(nick)!);
    }
    if (password.length < 8) {
      throw const FormatException('Hasło musi mieć co najmniej 8 znaków.');
    }
    await client.auth.signUp(
      email: validatedEmail, password: password,
      data: {'handle': nick.trim()},
      emailRedirectTo: kIsWeb ? 'https://aiglobalcommunity.github.io/ai-global-app/' : null,
    );
  }

  static Future<void> signIn(String email, String password) async {
    if (!configured) throw StateError('Backend is not configured.');
    if (email.trim().isEmpty || password.isEmpty) {
      throw const FormatException('Wpisz e-mail i hasło.');
    }
    await client.auth.signInWithPassword(email: email.trim(), password: password);
  }

  static Future<void> signInWithSocial(OAuthProvider provider) async {
    if (!configured) throw StateError('Backend is not configured.');
    if (!kIsWeb) {
      throw UnsupportedError(
        'Logowanie Google/Facebook jest na razie przygotowane dla strony internetowej AGC.');
    }
    await client.auth.signInWithOAuth(
      provider,
      redirectTo: 'https://aiglobalcommunity.github.io/ai-global-app/',
    );
  }

  static Future<void> signOut() async {
    if (configured) await client.auth.signOut();
  }

  static Future<bool> claimInvite(String code) async {
    if (!configured) throw StateError('Backend is not configured.');
    final result = await client.rpc('agc_claim_invite', params: {'code': code.trim()});
    return result == true;
  }

  static Future<List<Map<String, dynamic>>> leaderboard({bool demo = true}) async {
    if (!configured) return const [];
    final table = demo ? 'agc_demo_leaderboard' : 'agc_leaderboard';
    final rows = await client.from(table).select().order('place').limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<Map<String, dynamic>?> myProfile() async {
    final current = user;
    if (current == null) return null;
    final data = await client.from('agc_profiles')
        .select('handle,referral_code,country_code')
        .eq('id', current.id).maybeSingle();
    return data;
  }
}

class AgcAccountPage extends StatefulWidget {
  const AgcAccountPage({super.key});

  @override
  State<AgcAccountPage> createState() => _AgcAccountPageState();
}

class _AgcAccountPageState extends State<AgcAccountPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  final invite = TextEditingController();
  String status = '';
  bool busy = false;
  StreamSubscription<AuthState>? authListener;

  @override
  void initState() {
    super.initState();
    if (AgcBackend.configured) {
      authListener = AgcBackend.client.auth.onAuthStateChange.listen((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    invite.dispose();
    authListener?.cancel();
    super.dispose();
  }

  Future<void> execute(Future<void> Function() action) async {
    setState(() { busy = true; status = ''; });
    try {
      await action();
      if (mounted) setState(() => status = 'Operacja zakończona. Jeżeli utworzono konto, potwierdź adres e-mail.');
    } on AuthException catch (e) {
      final hint = e.code == 'anonymous_provider_disabled'
          ? 'Podaj adres e-mail i hasło; rejestracja anonimowa w AGC jest wyłączona.'
          : e.code == 'email_exists' || e.code == 'user_already_exists'
              ? 'Ten adres może już mieć konto. Spróbuj się zalogować.'
              : e.code == 'over_email_send_rate_limit' || e.code == 'over_request_rate_limit'
                  ? 'Zbyt wiele prób. Spróbuj ponownie później.'
                  : e.message;
      if (mounted) setState(() => status = 'Błąd rejestracji/logowania: $hint');
    } on FormatException catch (e) {
      if (mounted) setState(() => status = e.message);
    } catch (_) {
      if (mounted) setState(() => status = 'Nie udało się połączyć z kontem. Sprawdź internet i spróbuj ponownie.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AgcBackend.configured) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('BRAK POŁĄCZENIA\n\nNie można nawiązać połączenia z systemem logowania. Spróbuj ponownie później.',
          textAlign: TextAlign.center),
      ));
    }
    return Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 540),
      child: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      children: [
        if (AgcBackend.user == null) ...[
          const AgcCountdownBanner(),
          const SizedBox(height: 8),
          const Center(child: GenesisArtwork(size: 208)),
          const SizedBox(height: 10),
          const Text('A I   G L O B A L   C O M M U N I T Y',
            textAlign: TextAlign.center,
            style: TextStyle(color: AgcLuxury.champagne, letterSpacing: 1.4,
              fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Text('WE ARE WAITING FOR AN ANSWER.',
            textAlign: TextAlign.center,
            style: TextStyle(letterSpacing: 1.5,
              color: AgcLuxury.mutedText, fontSize: 11)),
          const SizedBox(height: 11),
          const Text('Zaloguj się, aby wejść do społeczności Genesis.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 14),
        ],
        const AgcLuxuryHeading(title: 'KONTO GENESIS',
          subtitle: 'Ekskluzywna przestrzeń członków AGC'),
        const SizedBox(height: 18),
        if (AgcBackend.user == null) ...[
          TextField(controller: email, keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next, autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'E-mail')),
          TextField(controller: password, obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(labelText: 'Hasło')),
          const SizedBox(height: 16),
          FilledButton(onPressed: busy ? null : () => execute(() => AgcBackend.signIn(email.text, password.text)),
            child: const Text('Zaloguj się')),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: busy ? null : () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => AgcRegistrationPage(
                onSignUp: AgcBackend.signUp,
                onSocialSignIn: AgcBackend.signInWithSocial,
              )),
            ),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Utwórz konto'),
          ),
          AgcSocialButtons(onSignIn: AgcBackend.signInWithSocial),
          const SizedBox(height: 8),
          const Text('Nowe konto? Naciśnij „Utwórz konto”, aby otworzyć osobny formularz rejestracji.',
            style: TextStyle(color: Colors.white60, fontSize: 12), textAlign: TextAlign.center),
        ] else ...[
          Text('Zalogowano: ${AgcBackend.user!.email ?? 'członek'}'),
          FutureBuilder<Map<String, dynamic>?>(
            future: AgcBackend.myProfile(),
            builder: (context, snapshot) => Text(
              snapshot.hasData
                ? 'Pseudonim: ${snapshot.data?['handle']}\nTwój kod polecenia: ${snapshot.data?['referral_code']}'
                : 'Wczytywanie profilu...',
            ),
          ),
          TextField(controller: invite, textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Kod polecającego')),
          FilledButton(
            onPressed: busy ? null : () => execute(() async {
              final awarded = await AgcBackend.claimInvite(invite.text);
              if (!awarded) throw StateError('Kod jest nieważny lub został już użyty.');
            }),
            child: const Text('Zatwierdź kod polecenia'),
          ),
          OutlinedButton(onPressed: busy ? null : () => execute(AgcBackend.signOut),
            child: const Text('Wyloguj')),
        ],
        if (status.isNotEmpty) Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(status),
        ),
        const SizedBox(height: 12),
        const Text('Punkty i zaproszenia podlegają weryfikacji. Brak rzeczywistych wpłat w tej wersji.',
          style: TextStyle(color: Colors.white70)),
      ],
    )));
  }
}

String agcTier(int place) {
  if (place <= 100) return 'Genesis Eternal';
  if (place <= 1000) return 'Gold Genesis';
  if (place <= 10000) return 'Silver Genesis';
  return 'Global Member';
}

class AgcDatabaseRanking extends StatefulWidget {
  const AgcDatabaseRanking({super.key});

  @override
  State<AgcDatabaseRanking> createState() => _AgcDatabaseRankingState();
}

class _AgcDatabaseRankingState extends State<AgcDatabaseRanking> {
  bool demo = true;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const AgcLuxuryHeading(title: 'GENESIS RANKING',
        subtitle: 'Twoje miejsce w społeczności założycieli'),
      const SizedBox(height: 12),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: true, label: Text('DEMO')),
          ButtonSegment(value: false, label: Text('Prawdziwy')),
        ],
        selected: {demo},
        onSelectionChanged: (value) => setState(() => demo = value.first),
      ),
      const SizedBox(height: 12),
      Text(demo
        ? 'SYMULACJA • fikcyjne profile, brak rzeczywistych użytkowników lub wpłat'
        : 'RZECZYWISTE konta zweryfikowane w bazie; dane mogą być jeszcze puste.',
        style: const TextStyle(color: Colors.amber)),
      const SizedBox(height: 12),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: AgcBackend.leaderboard(demo: demo),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Text('Błąd połączenia: ${snapshot.error}');
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final rows = snapshot.data!;
          if (rows.isEmpty) return const Text('Brak danych. Uruchom migrację i seed lub zarejestruj członków.');
          return Column(children: [
            for (final row in rows)
              Card(child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AgcLuxury.champagne.withValues(alpha: .12),
                  foregroundColor: AgcLuxury.champagne,
                  child: Text('${row['place']}')),
                title: Text('${row['handle']}'),
                subtitle: Text(demo ? 'DEMO • ${agcTier((row['place'] as num).toInt())}' : agcTier((row['place'] as num).toInt())),
                trailing: Text('${row['genesis_points']} GP'),
              )),
          ]);
        },
      ),
    ],
  );
}
