import 'dart:async';
import 'package:flutter/foundation.dart';
import 'genesis_artwork.dart';
import 'agc_countdown.dart';
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

  static Future<void> signUp(String email, String password) async {
    if (!configured) throw StateError('Backend is not configured.');
    await client.auth.signUp(
      email: email.trim(), password: password,
      emailRedirectTo: kIsWeb ? 'https://aiglobalcommunity.github.io/ai-global-app/' : null,
    );
  }

  static Future<void> signIn(String email, String password) async {
    if (!configured) throw StateError('Backend is not configured.');
    await client.auth.signInWithPassword(email: email.trim(), password: password);
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
    } catch (e) {
      if (mounted) setState(() => status = 'Błąd: $e');
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
          const Center(child: GenesisArtwork(size: 210)),
          const SizedBox(height: 10),
          const Text('AI GLOBAL COMMUNITY', textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFD8B66A), letterSpacing: 3,
              fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Text('Zaloguj się, aby wejść do społeczności Genesis.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          const AgcCountdownBanner(),
          const SizedBox(height: 14),
        ],
        const Text('KONTO GENESIS', style: TextStyle(fontSize: 24, color: Color(0xFFD8B66A))),
        const SizedBox(height: 18),
        if (AgcBackend.user == null) ...[
          TextField(controller: email, keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-mail')),
          TextField(controller: password, obscureText: true,
            decoration: const InputDecoration(labelText: 'Hasło (min. 6 znaków)')),
          const SizedBox(height: 16),
          FilledButton(onPressed: busy ? null : () => execute(() => AgcBackend.signIn(email.text, password.text)),
            child: const Text('Zaloguj się')),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: busy ? null : () => execute(() => AgcBackend.signUp(email.text, password.text)),
            child: const Text('Utwórz konto')),
          const SizedBox(height: 8),
          const Text('Po utworzeniu konta potwierdź adres e-mail. Nie udostępniaj nikomu hasła.',
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
      const Text('GENESIS RANKING', style: TextStyle(fontSize: 26, color: Color(0xFFD8B66A))),
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
                leading: CircleAvatar(child: Text('${row['place']}')),
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
