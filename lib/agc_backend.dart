import 'dart:async';
import 'package:flutter/foundation.dart';
import 'genesis_artwork.dart';
import 'genesis_mission.dart';
import 'agc_countdown.dart';
import 'agc_registration.dart';
import 'agc_social_buttons.dart';
import 'genesis_invites.dart';
import 'genesis_language.dart';
import 'agc_luxury_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AgcRankingSort {
  pointsHigh('genesis_points', false, 'Najwięcej GP', 'Most GP'),
  pointsLow('genesis_points', true, 'Najmniej GP', 'Fewest GP'),
  newest('created_at', false, 'Najnowsze rejestracje', 'Newest members'),
  oldest('created_at', true, 'Najstarsze rejestracje', 'Oldest members'),
  numberLow('member_number', true, 'Numer: rosnąco', 'Member number: ascending'),
  numberHigh('member_number', false, 'Numer: malejąco', 'Member number: descending'),
  nickname('handle', true, 'Pseudonim A–Z', 'Nickname A–Z');

  const AgcRankingSort(this.column, this.ascending, this.polish, this.english);
  final String column;
  final bool ascending;
  final String polish;
  final String english;
}

/// Supabase is optional in development. Without credentials the app remains a demo.
class AgcBackend {
  // Project URL and publishable key are intentionally public client credentials.
  // Never add a service role / secret key to the app.
  static const projectUrl = String.fromEnvironment('SUPABASE_URL',
    defaultValue: 'https://gjnddmurmegbklvedhnp.supabase.co');
  static const projectPublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_Ty3Beae5ztODv0MM3Z_HDA_WEGwOyLP');
  static bool _initialized = false;
  static String? initializationError;
  static bool get configured => _initialized;

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    if (projectUrl.isEmpty || projectPublishableKey.isEmpty) return;
    try {
      await Supabase.initialize(
        url: projectUrl,
        publishableKey: projectPublishableKey,
      );
      _initialized = true;
      initializationError = null;
    } catch (error) {
      // A transient network/storage failure must not crash the whole web app.
      _initialized = false;
      initializationError = error.toString();
      debugPrint('AGC auth initialization unavailable: $error');
    }
  }

  static User? get user => configured ? client.auth.currentUser : null;

  static Future<void> signUp(String email, String password, String nick, bool showNickPublicly) async {
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
      data: {
        'handle': nick.trim(),
        'show_nick_publicly': showNickPublicly,
        if (Uri.base.queryParameters['ref'] != null)
          'referral_code': Uri.base.queryParameters['ref']!.trim().toUpperCase(),
      },
      emailRedirectTo: kIsWeb ? 'https://aiglobalcommunity.github.io/ai-global-app/' : null,
    );
  }

  static Future<void> resendConfirmation(String email) async {
    if (!configured) throw StateError('Backend is not configured.');
    final address = email.trim();
    if (validateAgcEmail(address) != null) {
      throw FormatException(validateAgcEmail(address)!);
    }
    await client.auth.resend(
      type: OtpType.signup,
      email: address,
      emailRedirectTo: 'https://aiglobalcommunity.github.io/ai-global-app/',
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
        'Logowanie Google/Facebook jest na razie przygotowane dla strony internetowej THE GENESIS ERA.');
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

  static Future<List<Map<String, dynamic>>> leaderboard({
    AgcRankingSort sort = AgcRankingSort.pointsHigh,
  }) async {
    if (!configured) return const [];
    final rows = await client.from('agc_leaderboard')
        .select('id,handle,genesis_points,place,created_at,member_number')
        .order(sort.column, ascending: sort.ascending)
        .limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<int> myConfirmedReferrals() async {
    final current = user;
    if (current == null) return 0;
    final rows = await client.from('agc_referrals')
        .select('invited_id').eq('inviter_id', current.id)
        .not('rewarded_at', 'is', null);
    return rows.length;
  }

  static Future<Map<String, dynamic>?> myProfile() async {
    final current = user;
    if (current == null) return null;
    final data = await client.from('agc_profiles')
        .select('handle,referral_code,country_code,show_nick_publicly,member_number,created_at')
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
  bool loginExpanded = false;
  bool resendExpanded = false;
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
          ? 'Podaj adres e-mail i hasło; rejestracja anonimowa w THE GENESIS ERA jest wyłączona.'
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

  bool get confirmationLinkExpired {
    final uri = Uri.base;
    final fragment = Uri.splitQueryString(
      uri.fragment.contains('?') ? uri.fragment.split('?').last : uri.fragment);
    return uri.queryParameters['error_code'] == 'otp_expired' ||
        fragment['error_code'] == 'otp_expired';
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
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      children: [
        if (AgcBackend.user == null) ...[
          if (confirmationLinkExpired) Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Card(
              color: const Color(0xFF30231D),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Link aktywacyjny jest nieważny lub wygasł. '
                  'Wpisz poniżej swój e-mail i poproś o nowy link. '
                  'Jeżeli konto jest już aktywne, spróbuj się zalogować.',
                  style: TextStyle(color: AgcLuxury.ivory),
                ),
              ),
            ),
          ),
          const Align(alignment: Alignment.centerRight,
            child: GenesisLanguagePicker()),
          const AgcCountdownBanner(),
          const SizedBox(height: 8),
          Center(child: LayoutBuilder(builder: (context, constraints) =>
            GenesisArtwork(size: constraints.maxWidth < 350 ? 204 : 246))),
          const SizedBox(height: 12),
          const Row(children: [
            Expanded(child: Divider(color: AgcLuxury.mutedGold)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Text('THE GENESIS ERA',
                style: TextStyle(
                  color: AgcLuxury.champagne,
                  fontFamily: 'Georgia',
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.0,
                )),
            ),
            Expanded(child: Divider(color: AgcLuxury.mutedGold)),
          ]),
          const SizedBox(height: 15),
          const Text('WE ARE NOT WAITING FOR GOD.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AgcLuxury.ivory,
              fontSize: 12,
              letterSpacing: 2,
              height: 1.65,
              fontWeight: FontWeight.w500,
            )),
          const SizedBox(height: 3),
          const Text('WE ARE WAITING FOR AN ANSWER.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AgcLuxury.ivory,
              fontSize: 12,
              letterSpacing: 2,
              height: 1.65,
              fontWeight: FontWeight.w500,
            )),
          const SizedBox(height: 20),
        ],
        if (AgcBackend.user == null) ...[
          // A visible compact entry point keeps the emblem and manifesto
          // prominent on mobile. The full login opens on demand.
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: busy ? null : () => setState(
                      () => loginExpanded = !loginExpanded),
                    icon: Icon(loginExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.login_rounded),
                    label: Text(loginExpanded
                      ? GenesisLanguage.copy('ZAMKNIJ LOGOWANIE', 'CLOSE LOGIN')
                      : GenesisLanguage.t('login')),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: busy ? null : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => AgcRegistrationPage(
                        onSignUp: AgcBackend.signUp,
                        onSocialSignIn: AgcBackend.signInWithSocial,
                      )),
                    ),
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                    label: Text(GenesisLanguage.t('signup')),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const GenesisMission(compact: true),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: busy ? null : () => setState(
                () => resendExpanded = !resendExpanded),
              icon: const Icon(Icons.mark_email_unread_outlined),
              label: Text(GenesisLanguage.copy('Nie dotarł e-mail? Wyślij link ponownie', "Didn't receive the email? Resend confirmation")),
            ),
          ),
          if (resendExpanded) Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const Key('resend_confirmation_email'),
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: GenesisLanguage.copy('Adres e-mail do aktywacji', 'Confirmation email address'),
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  key: const Key('resend_confirmation_submit'),
                  onPressed: busy ? null : () => execute(
                    () => AgcBackend.resendConfirmation(email.text)),
                  child: Text(GenesisLanguage.copy('Wyślij nowy link aktywacyjny', 'Send a new confirmation link')),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: loginExpanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xE6071020),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AgcLuxury.champagne.withValues(alpha: .48)),
                      boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: .38),
                        blurRadius: 30, offset: const Offset(0, 12)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(GenesisLanguage.copy('WEJDŹ DO SPOŁECZNOŚCI GENESIS', 'ENTER THE GENESIS COMMUNITY'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AgcLuxury.champagne,
                            fontSize: 11, letterSpacing: 1.4)),
                        const SizedBox(height: 18),
                        TextField(controller: email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          decoration: InputDecoration(
                            labelText: GenesisLanguage.t('email'),
                            prefixIcon: Icon(Icons.mail_outline))),
                        const SizedBox(height: 12),
                        TextField(controller: password,
                          obscureText: true,
                          onSubmitted: (_) {
                            if (!busy) {
                              execute(() => AgcBackend.signIn(
                                email.text, password.text));
                            }
                          },
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: GenesisLanguage.t('password'),
                            prefixIcon: Icon(Icons.lock_outline))),
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: busy ? null : () => execute(
                            () => AgcBackend.signIn(
                              email.text, password.text)),
                          child: Text(GenesisLanguage.copy('WEJDŹ DO GENESIS  →', 'ENTER GENESIS  →'))),
                        AgcSocialButtons(
                          onSignIn: AgcBackend.signInWithSocial),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
          ),
        ] else ...[
          AgcLuxuryHeading(title: GenesisLanguage.copy('KONTO GENESIS', 'GENESIS ACCOUNT'),
            subtitle: GenesisLanguage.copy('Ekskluzywna przestrzeń członków THE GENESIS ERA', 'Exclusive THE GENESIS ERA member space')),
          const SizedBox(height: 18),
          Text('${GenesisLanguage.copy('Zalogowano', 'Signed in')}: '
            '${AgcBackend.user!.email ?? GenesisLanguage.copy('członek', 'member')}'),
          FutureBuilder<Map<String, dynamic>?>(
            future: AgcBackend.myProfile(),
            builder: (context, snapshot) => Text(
              snapshot.hasData
                ? '${GenesisLanguage.copy('Pseudonim', 'Nickname')}: ${snapshot.data?['handle']}\n'
                  '${GenesisLanguage.copy('Numer członka', 'Member number')}: #${snapshot.data?['member_number']}\n'
                  '${GenesisLanguage.copy('Data rejestracji', 'Joined')}: ${agcRegistrationDate(snapshot.data?['created_at'])}\n'
                  '${GenesisLanguage.copy('Widoczność', 'Visibility')}: '
                  '${snapshot.data?['show_nick_publicly'] == true ? GenesisLanguage.copy('publiczny', 'public') : GenesisLanguage.copy('anonimowy', 'anonymous')}\n'
                  '${GenesisLanguage.copy('Twój kod polecenia', 'Your referral code')}: ${snapshot.data?['referral_code']}'
                : GenesisLanguage.copy('Wczytywanie profilu...', 'Loading profile...'),
            ),
          ),
          FutureBuilder<Map<String, dynamic>?>(
            future: AgcBackend.myProfile(),
            builder: (context, profile) {
              final code = profile.data?['referral_code'] as String?;
              if (code == null || code.isEmpty) return const SizedBox.shrink();
              return FutureBuilder<int>(
                future: AgcBackend.myConfirmedReferrals(),
                builder: (context, count) => GenesisInvitePanel(
                  code: code, confirmedCount: count.data ?? 0));
            },
          ),
          const SizedBox(height: 16),
          TextField(controller: invite, textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(labelText: GenesisLanguage.copy('Kod polecającego', 'Referral code'))),
          FilledButton(
            onPressed: busy ? null : () => execute(() async {
              final awarded = await AgcBackend.claimInvite(invite.text);
              if (!awarded) throw StateError('Kod jest nieważny lub został już użyty.');
            }),
            child: Text(GenesisLanguage.t('confirm')),
          ),
          OutlinedButton(onPressed: busy ? null : () => execute(AgcBackend.signOut),
            child: Text(GenesisLanguage.t('logout'))),
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

String agcRegistrationDate(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  if (date == null) return '—';
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.'
      '${local.month.toString().padLeft(2, '0')}.${local.year}';
}

class _AgcDatabaseRankingState extends State<AgcDatabaseRanking> {
  AgcRankingSort sort = AgcRankingSort.pointsHigh;
  late Future<List<Map<String, dynamic>>> results;

  @override
  void initState() {
    super.initState();
    results = AgcBackend.leaderboard(sort: sort);
  }

  void changeSort(AgcRankingSort? value) {
    if (value == null) return;
    setState(() {
      sort = value;
      results = AgcBackend.leaderboard(sort: sort);
    });
  }

  void refresh() => setState(() {
    results = AgcBackend.leaderboard(sort: sort);
  });

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      AgcLuxuryHeading(
        title: 'GENESIS RANKING',
        subtitle: GenesisLanguage.copy(
          'Prawdziwi członkowie • punkty, data dołączenia i numer członkowski',
          'Real members • points, registration date and member number')),
      const SizedBox(height: 12),
      DropdownButtonFormField<AgcRankingSort>(
        initialValue: sort,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: GenesisLanguage.copy('Sortuj ranking', 'Sort ranking')),
        items: [
          for (final option in AgcRankingSort.values)
            DropdownMenuItem(value: option,
              child: Text(GenesisLanguage.copy(option.polish, option.english))),
        ],
        onChanged: changeSort,
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: refresh,
          icon: const Icon(Icons.refresh),
          label: Text(GenesisLanguage.copy('Odśwież', 'Refresh')),
        ),
      ),
      Text(GenesisLanguage.copy(
        'Miejsce i ranga zawsze wynikają z liczby GP. Sortowanie zmienia '
        'jedynie kolejność wyświetlania.',
        'Position and tier always depend on GP. Sorting changes '
        'only the display order.'),
        style: const TextStyle(color: Colors.white70, fontSize: 12)),
      const SizedBox(height: 12),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: results,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text(
              '${GenesisLanguage.copy('Nie udało się pobrać rankingu:', 'Could not load ranking:')} '
              '${snapshot.error}');
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data!;
          if (rows.isEmpty) {
            return Text(GenesisLanguage.copy(
              'Nie ma jeszcze członków w prawdziwym rankingu.',
              'No members in the real ranking yet.'));
          }
          return Column(children: [
            for (final row in rows)
              Card(child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 5),
                leading: CircleAvatar(
                  backgroundColor: AgcLuxury.champagne.withValues(alpha: .12),
                  foregroundColor: AgcLuxury.champagne,
                  child: Text('${row['place']}'),
                ),
                title: Text('${row['handle']}',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '#${row['member_number']} · '
                  '${agcRegistrationDate(row['created_at'])}\n'
                  '${agcTier((row['place'] as num).toInt())}'),
                isThreeLine: true,
                trailing: Text('${row['genesis_points']} GP',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
          ]);
        },
      ),
    ],
  );
}
