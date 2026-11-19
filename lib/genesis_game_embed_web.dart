// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'agc_backend.dart';
import 'genesis_language.dart';
import 'genesis_global_ranking.dart';

/// HTML5 games send finished scores to their authenticated Flutter parent.
/// Only the signed-in user's personal best is stored in Supabase.
class GenesisGameTab extends StatefulWidget {
  const GenesisGameTab({super.key});

  @override
  State<GenesisGameTab> createState() => _GenesisGameTabState();
}

class _GenesisGameTabState extends State<GenesisGameTab> {
  static bool registered = false;
  static const signalView = 'genesis-signal-html5-iframe';
  static const defenderView = 'genesis-defender-html5-iframe';
  static const wolfView = 'genesis-wolf-html5-iframe';
  static const blocksView = 'genesis-blocks-html5-iframe';
  static const skiView = 'genesis-ski-html5-iframe';
  static const snakeView = 'genesis-snake-html5-iframe';
  static const cityView = 'genesis-city-html5-iframe';
  static const city3dView = 'genesis-city-3d-html5-iframe';
  static const cityMultiView = 'genesis-city-multiplayer-html5-iframe';
  static final Map<String, html.IFrameElement> frames = {};
  StreamSubscription<html.MessageEvent>? messages;
  Timer? scoreRetryTimer;
  StreamSubscription<AuthState>? authChanges;
  bool rulesOpen = false;
  OverlayEntry? defenderFullscreenOverlay;
  OverlayEntry? signalFullscreenOverlay;
  OverlayEntry? wolfFullscreenOverlay;
  OverlayEntry? blocksFullscreenOverlay;
  OverlayEntry? skiOverlay;
  OverlayEntry? snakeFullscreenOverlay;
  OverlayEntry? cityFullscreenOverlay;
  String activeCityView = cityView;

  static const scoreStoragePrefix = 'agc-game-pending-';
  static const buildVersion = String.fromEnvironment(
    'AGC_BUILD_VERSION', defaultValue: 'DEV');
  static const buildDate = String.fromEnvironment(
    'AGC_BUILD_DATE', defaultValue: 'LOCAL');
  static const gameKeys = ['signal', 'defender', 'wolf', 'blocks', 'snake', 'ski', 'city'];
  static const titles = ['GENESIS SIGNAL','GENESIS DEFENDER','WILK I JAJKA','GENESIS BLOCKS','GENESIS SNAKE','SKOKI NARCIARSKIE','GENESIS CITY 2D'];
  static const gameViews = [signalView, defenderView, wolfView, blocksView, snakeView, skiView, cityView];
  Map<String, (int, int, bool?)> ratings = {};
  final voting = <int>{};
  int ratingRequest = 0;
  bool ratingsReady = false;
  bool ratingsFailed = false;

  Future<void> _loadRatings() async {
    final request = ++ratingRequest;
    final owner = AgcBackend.user?.id;
    try {
      final rows = await AgcBackend.client.rpc('agc_game_ratings');
      if (!mounted || request != ratingRequest || owner != AgcBackend.user?.id) return;
      setState(() {
        ratings = {
          for (final row in rows)
            row['game'] as String: (row['likes'] as int, row['dislikes'] as int, row['mine'] as bool?),
        };
        ratingsReady = true;
        ratingsFailed = false;
      });
    } catch (_) {
      if (mounted && request == ratingRequest) setState(() => ratingsFailed = true);
    }
  }

  Future<void> _vote(int index, bool positive) async {
    if (AgcBackend.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zaloguj się, aby ocenić grę.')));
      return;
    }
    if (!voting.add(index)) return;
    setState(() {});
    try {
      await AgcBackend.client.rpc('agc_rate_game', params: {'p_game': gameKeys[index], 'p_positive': positive});
      if (mounted) await _loadRatings();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nie udało się zapisać oceny. Spróbuj ponownie.')));
    } finally {
      if (mounted) setState(() => voting.remove(index));
    }
  }

  (int, int, bool?) _rating(int index) => ratings[gameKeys[index]] ?? (0, 0, null);

  int _compareRatings(int a, int b) {
    final x = _rating(a), y = _rating(b);
    final nx = x.$1 + x.$2, ny = y.$1 + y.$2;
    final ratio = (y.$1 * nx).compareTo(x.$1 * ny);
    if (ratio != 0) return ratio;
    final volume = ny.compareTo(nx);
    return volume != 0 ? volume : a.compareTo(b);
  }

  Future<void> _shareGameScore(int index) async {
    final key = gameKeys[index];
    var points = pendingScores[key]?.$1 ?? 0;
    if (AgcBackend.user != null) {
      try {
        final record = await AgcBackend.client.from('agc_game_scores')
          .select('best_score')
          .eq('member_id', AgcBackend.user!.id)
          .eq('game_key', key).maybeSingle();
        final saved = (record?['best_score'] as num?)?.toInt() ?? 0;
        if (saved > points) points = saved;
      } catch (_) {}
    }
    try {
      final raw = html.window.localStorage['$scoreStoragePrefix$key'];
      if (raw != null) {
        final local = jsonDecode(raw);
        if (local is Map && local['score'] is int &&
            (local['score'] as int) > points) {
          points = local['score'] as int;
        }
      }
    } catch (_) {}
    if (!mounted) return;
    if (points <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Zagraj i zdobądź punkty, aby udostępnić wynik.')));
      return;
    }
    final handle = AgcBackend.user?.userMetadata?['handle']?.toString() ?? 'Gracz';
    final url = Uri.https('thegenesisera.com', '/share-result.html', {
      'game': key, 'score': '$points', 'nick': handle,
    });
    html.window.open(url.toString(), '_blank');
  }

  Widget _shareScoreButton(int index) => TextButton.icon(
    onPressed: () => _shareGameScore(index),
    icon: const Icon(Icons.share_outlined, size: 18),
    label: const Text('UDOSTĘPNIJ WYNIK'),
  );

  Widget _ratingBar(int index) {
    final (likes, dislikes, mine) = _rating(index);
    final total = likes + dislikes;
    return Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
      for (final positive in [true, false])
        TextButton.icon(
          onPressed: voting.contains(index) ? null : () => _vote(index, positive),
          icon: Icon(positive
            ? (mine == true ? Icons.thumb_up : Icons.thumb_up_outlined)
            : (mine == false ? Icons.thumb_down : Icons.thumb_down_outlined), size: 17),
          label: Text(positive ? 'Lubię · $likes' : 'Nie lubię · $dislikes'),
        ),
      if (ratingsFailed)
        IconButton(onPressed: _loadRatings, tooltip: 'Odśwież oceny', icon: const Icon(Icons.refresh))
      else
        Text(!ratingsReady ? '…' : total == 0 ? 'Brak ocen' : '${(100 * likes / total).round()}% lubi'),
    ]);
  }

  String categoryFilter = 'all';
  int gamesPerRow = 2; // 0 = compact list
  bool diagnosticsOpen = false;
  String lastBridgeStatus = 'Brak zdarzeń z gry';
  String lastDatabaseStatus = 'Nie sprawdzono';
  String lastSaveStatus = 'Nie wysłano wyniku';
  int receivedScoreEvents = 0;
  int? lastReceivedScore;
  int? game;
  int? rankingGame;
  Future<List<Map<String, dynamic>>>? rankingFuture;
  String? scoreNotice;
  bool saving = false;
  final Map<String, (int, int)> pendingScores = {};

  String get gameKey => game == 0 ? 'signal' : game == 1 ? 'defender' : game == 3 ? 'blocks' : game == 4 ? 'snake' : 'wolf';
  Map<String, dynamic> get gameAuthStatus {
    final user = AgcBackend.user;
    final handle = user?.userMetadata?['handle']?.toString().trim();
    final identity = (handle != null && handle.isNotEmpty)
        ? handle
        : (user?.email ?? 'Gracz');
    return {'type': 'genesis-auth-status',
      'signedIn': user != null,
      'displayName': user == null ? '' : identity};
  }

  void sendGameAuthStatus(html.IFrameElement frame) {
    frame.contentWindow?.postMessage(
      jsonEncode(gameAuthStatus), html.window.location.origin);
  }


  @override
  void initState() {
    super.initState();
    if (!registered) {
      _register(signalView, 'genesis-game.html?embed=1&version=$buildVersion', 'GENESIS SIGNAL');
      _register(defenderView, 'genesis-defender.html?embed=1&version=$buildVersion', 'GENESIS DEFENDER');
      _register(wolfView, 'genesis-wolf-eggs.html?embed=1&version=$buildVersion', 'WILK I JAJKA');
      _register(blocksView, 'genesis-blocks.html?embed=1&version=$buildVersion', 'GENESIS BLOCKS');
      _register(skiView, 'skoki-narciarskie.html?embed=1&version=$buildVersion', 'Skoki narciarskie');
      _register(snakeView, 'genesis-snake.html?embed=1&version=$buildVersion', 'GENESIS SNAKE');
      _register(cityView, 'genesis-city.html?embed=1&version=$buildVersion', 'GENESIS CITY 2D');
      _register(city3dView, 'genesis-city-3d.html?embed=1&version=$buildVersion', 'GENESIS CITY 3D');
      _register(cityMultiView, 'genesis-city-multiplayer.html?embed=1&version=$buildVersion', 'GENESIS CITY Multiplayer');
      registered = true;
    }
    messages = html.window.onMessage.listen(_onMessage);
    if (AgcBackend.configured) {
      _loadRatings();
      authChanges = AgcBackend.client.auth.onAuthStateChange.listen((_) {
        if (!mounted) return;
        _loadRatings();
        setState(() {});
        for (final frame in frames.values) {
          sendGameAuthStatus(frame);
        }
        if (AgcBackend.user != null) _recoverPendingScores();
      });
    }
    scoreRetryTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _recoverPendingScores();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverPendingScores());
  }

  @override
  void dispose() {
    skiOverlay?.remove();
    skiOverlay?.dispose();
    cityFullscreenOverlay?.remove();
    cityFullscreenOverlay?.dispose();
    snakeFullscreenOverlay?.remove();
    snakeFullscreenOverlay?.dispose();
    snakeFullscreenOverlay = null;
    defenderFullscreenOverlay?.remove();
    defenderFullscreenOverlay?.dispose();
    defenderFullscreenOverlay = null;
    signalFullscreenOverlay?.remove();
    signalFullscreenOverlay?.dispose();
    signalFullscreenOverlay = null;
    wolfFullscreenOverlay?.remove();
    wolfFullscreenOverlay?.dispose();
    wolfFullscreenOverlay = null;
    blocksFullscreenOverlay?.remove();
    blocksFullscreenOverlay?.dispose();
    blocksFullscreenOverlay = null;
    messages?.cancel();
    authChanges?.cancel();
    scoreRetryTimer?.cancel();
    super.dispose();
  }

  static void _register(String type, String src, String title) {
    ui_web.platformViewRegistry.registerViewFactory(
      type,
      (int viewId) {
        final frame = html.IFrameElement()
          ..src = src
          ..title = title
          ..allowFullscreen = true
          ..setAttribute('allow', 'fullscreen')
          ..style.border = '0'
          ..style.width = '100%'
          ..style.height = '100%'
          ..setAttribute('loading', 'lazy');
        frames[type] = frame;
        // The iframe may request auth before the Flutter message listener is ready.
        // Send the current state again whenever the game document finishes loading.
        frame.onLoad.listen((_) {
          frame.contentWindow?.postMessage(
            jsonEncode({
              'type': 'genesis-auth-status',
              'signedIn': AgcBackend.user != null,
              'displayName': AgcBackend.user?.userMetadata?['handle']?.toString()
                  ?? AgcBackend.user?.email ?? '',
            }),
            html.window.location.origin,
          );
        });
        return frame;
      },
    );
  }

  void _showSkiFullscreen() {
    if (skiOverlay != null) return;
    skiOverlay = OverlayEntry(builder: (_) => const Positioned.fill(
      child: HtmlElementView(viewType: skiView),
    ));
    Overlay.of(context, rootOverlay: true).insert(skiOverlay!);
  }

  void _showCityFullscreen([String view = cityView]) {
    if (view != cityView && !_cityPreviewAllowed) return;
    activeCityView = view;
    if (!mounted || cityFullscreenOverlay != null) return;
    cityFullscreenOverlay = OverlayEntry(builder: (_) => Positioned.fill(
      child: HtmlElementView(viewType: activeCityView),
    ));
    Overlay.of(context, rootOverlay: true).insert(cityFullscreenOverlay!);
  }
  void _closeCityFullscreen() {
    cityFullscreenOverlay?.remove();
    cityFullscreenOverlay?.dispose();
    cityFullscreenOverlay = null;
    if (mounted) setState(() { game = null; scoreNotice = null; });
  }

  void _showSnakeFullscreen() {
    if (!mounted || snakeFullscreenOverlay != null) return;
    snakeFullscreenOverlay = OverlayEntry(builder: (_) => const Positioned.fill(
      child: HtmlElementView(viewType: snakeView),
    ));
    Overlay.of(context, rootOverlay: true).insert(snakeFullscreenOverlay!);
  }
  void _closeSnakeFullscreen() {
    snakeFullscreenOverlay?.remove();
    snakeFullscreenOverlay?.dispose();
    snakeFullscreenOverlay = null;
    if (mounted) setState(() { game = null; scoreNotice = null; });
  }

  void _showDefenderFullscreen() {
    if (!mounted || defenderFullscreenOverlay != null) return;
    defenderFullscreenOverlay = OverlayEntry(builder: (_) => const Positioned.fill(
      child: HtmlElementView(viewType: defenderView),
    ));
    Overlay.of(context, rootOverlay: true).insert(defenderFullscreenOverlay!);
  }

  void _closeDefenderFullscreen() {
    defenderFullscreenOverlay?.remove();
    defenderFullscreenOverlay?.dispose();
    defenderFullscreenOverlay = null;
    if (mounted) setState(() { game = null; scoreNotice = null; });
  }

  void _showSignalFullscreen() {
    if (!mounted || signalFullscreenOverlay != null) return;
    signalFullscreenOverlay = OverlayEntry(builder: (_) => const Positioned.fill(
      child: HtmlElementView(viewType: signalView),
    ));
    Overlay.of(context, rootOverlay: true).insert(signalFullscreenOverlay!);
  }

  void _closeSignalFullscreen() {
    signalFullscreenOverlay?.remove();
    signalFullscreenOverlay?.dispose();
    signalFullscreenOverlay = null;
    if (mounted) setState(() { game = null; scoreNotice = null; });
  }

  void _showWolfFullscreen() {
    if (!mounted || wolfFullscreenOverlay != null) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    wolfFullscreenOverlay = OverlayEntry(builder: (_) => const Positioned.fill(
      child: HtmlElementView(viewType: wolfView),
    ));
    overlay.insert(wolfFullscreenOverlay!);
  }

  void _hideWolfFullscreen() {
    wolfFullscreenOverlay?.remove();
    wolfFullscreenOverlay?.dispose();
    wolfFullscreenOverlay = null;
  }

  void _showBlocksFullscreen() {
    if (!mounted || blocksFullscreenOverlay != null) return;
    blocksFullscreenOverlay = OverlayEntry(builder: (_) => const Positioned.fill(
      child: HtmlElementView(viewType: blocksView),
    ));
    Overlay.of(context, rootOverlay: true).insert(blocksFullscreenOverlay!);
  }

  void _hideBlocksFullscreen() {
    blocksFullscreenOverlay?.remove();
    blocksFullscreenOverlay?.dispose();
    blocksFullscreenOverlay = null;
  }

  Future<void> _onMessage(html.MessageEvent event) async {
    if (!mounted ||
        event.origin != html.window.location.origin ||
        event.data is! String) {
      return;
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(event.data as String);
    } catch (_) {
      return;
    }
    if (decoded is Map<String, dynamic> &&
        decoded['type'] == 'genesis-share-finished-score' &&
        gameKeys.contains(decoded['game']) &&
        decoded['score'] is num) {
      final points = (decoded['score'] as num).toInt();
      if (points < 0 || points > 10000000) return;
      final handle = AgcBackend.user?.userMetadata?['handle']?.toString() ?? 'Gracz';
      final url = Uri.https('thegenesisera.com', '/share-result.html', {
        'game': decoded['game'] as String,
        'score': '$points',
        'nick': handle,
      });
      html.window.open(url.toString(), '_blank');
      return;
    }
    if (decoded is Map && decoded['game'] == 'ski' && decoded['type'] == 'genesis-ski-exit-fullscreen') {
      skiOverlay?.remove();
      skiOverlay?.dispose();
      skiOverlay = null;
      return;
    }
    if (decoded is Map<String, dynamic> &&
        decoded['type'] == 'genesis-city-exit-fullscreen') {
      _closeCityFullscreen();
      return;
    }
    if (decoded is Map<String, dynamic> &&
        decoded['type'] == 'genesis-snake-exit-fullscreen' &&
        decoded['game'] == 'snake') {
      _closeSnakeFullscreen();
      return;
    }
    if (decoded is Map<String, dynamic> &&
        decoded['type'] == 'genesis-defender-exit-fullscreen' &&
        decoded['game'] == 'defender') {
      _closeDefenderFullscreen();
      return;
    }
    if (decoded is Map<String, dynamic> &&
        decoded['type'] == 'genesis-signal-exit-fullscreen' &&
        decoded['game'] == 'signal') {
      _closeSignalFullscreen();
      return;
    }
    // A fullscreen HtmlElementView may be hosted in a separate platform view.
    // Accept only the explicit exit command from a same-origin frame even if
    // its WindowProxy differs from the registered catalogue iframe.
    if (decoded is Map<String, dynamic> &&
        decoded['type'] == 'genesis-blocks-exit-fullscreen' &&
        decoded['game'] == 'blocks') {
      _hideBlocksFullscreen();
      if (mounted) setState(() { game = null; scoreNotice = null; });
      return;
    }
    if (decoded is Map<String, dynamic> && decoded['type'] == 'genesis-wolf-exit-fullscreen') {
      _hideWolfFullscreen();
      setState(() { game = null; scoreNotice = null; });
      return;
    }
    final isKnownFrame = frames.values.any((frame) => event.source == frame.contentWindow);
    // Fullscreen games can use a different iframe instance from the catalog.
    // The same-origin check above still applies to every score message.
    final fullscreenScore = decoded is Map<String, dynamic> &&
        decoded['type'] == 'genesis-game-score' &&
        gameKeys.contains(decoded['game']);
    if (!isKnownFrame && !fullscreenScore) return;
    if (decoded is Map<String, dynamic> && decoded['type'] == 'genesis-wolf-fullscreen') {
      _showWolfFullscreen();
      return;
    }

    if (decoded is Map<String, dynamic> && decoded['type'] == 'genesis-auth-request') {
      for (final frame in frames.values) {
        if (event.source == frame.contentWindow) {
          sendGameAuthStatus(frame);
          break;
        }
      }
      return;
    }
    if (decoded is Map<String, dynamic> &&
        decoded['type'] == 'genesis-open-ranking' &&
        (decoded['game'] == 'wolf' || decoded['game'] == 'blocks')) {
      final selected = decoded['game'] == 'blocks' ? 3 : 2;
      if (selected == 3) _hideBlocksFullscreen();
      if (selected == 2) _hideWolfFullscreen();
      _showRanking(selected);
      return;
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['type'] != 'genesis-game-score' ||
        !gameKeys.contains(decoded['game']) ||
        decoded['score'] is! int ||
        decoded['level'] is! int) {
      return;
    }
    final points = decoded['score'] as int;
    final stage = decoded['level'] as int;
    receivedScoreEvents++;
    lastReceivedScore = points;
    lastBridgeStatus = 'Odebrano ${decoded['game']}: $points pkt · poziom $stage';
    if (mounted) setState(() {});

    if (points < 10 || points > 10000000 || stage < 1 || stage > 1000) {
      return;
    }
    if (AgcBackend.user == null) {
      // Keep the guest's best result until the account is signed in.
      // Do not attribute it to another previously signed-in account.
      try {
        final key = decoded['game'] as String;
        final storageKey = '$scoreStoragePrefix$key';
        final oldRaw = html.window.localStorage[storageKey];
        var oldBest = 0;
        if (oldRaw != null) {
          final previous = jsonDecode(oldRaw);
          if (previous is Map && previous['score'] is int) {
            oldBest = previous['score'] as int;
          }
        }
        if (points >= oldBest) {
          html.window.localStorage[storageKey] = jsonEncode({
            'game': key, 'score': points, 'level': stage,
            'at': DateTime.now().millisecondsSinceEpoch,
          });
          html.window.localStorage.remove('agc-game-owner-$key');
        }
      } catch (_) {}
      setState(() => scoreNotice = GenesisLanguage.copy(
        'Wynik zachowany. Tworzę automatyczny nick gościa do rankingu…',
        'Score saved. Creating an automatic guest nickname…'));
      await _ensureGuestIdentity();
      return;
    }
    final key = decoded['game'] as String;
    final current = pendingScores[key];
    if (current == null || points > current.$1) {
      pendingScores[key] = (points, stage);
    }
    try {
      final storedRaw = html.window.localStorage['$scoreStoragePrefix$key'];
      var storedBest = 0;
      if (storedRaw != null) {
        final previous = jsonDecode(storedRaw);
        if (previous is Map && previous['score'] is int) {
          storedBest = previous['score'] as int;
        }
      }
      if (points >= storedBest) {
        html.window.localStorage['$scoreStoragePrefix$key'] = jsonEncode({
          'game': key, 'score': points, 'level': stage,
          'at': DateTime.now().millisecondsSinceEpoch,
        });
      }
      html.window.localStorage['agc-game-owner-$key'] = AgcBackend.user!.id;
    } catch (_) {}
    _notifyGameScoreStatus(key, 'pending', points);
    if (!saving) {
      await _savePendingScores();
    }
  }

  void _recoverPendingScores() {
    if (!mounted || AgcBackend.user == null) return;
    for (final key in gameKeys) {
      try {
        final raw = html.window.localStorage['$scoreStoragePrefix$key'];
        if (raw == null) continue;
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic> ||
            decoded['game'] != key ||
            decoded['score'] is! int ||
            decoded['level'] is! int ||
            decoded['at'] is! int) {
          continue;
        }
        final points = decoded['score'] as int;
        final stage = decoded['level'] as int;
        final age = DateTime.now().millisecondsSinceEpoch -
          (decoded['at'] as int);
        if (points < 10 || points > 10000000 ||
            stage < 1 || stage > 1000 ||
            age < -60000 || age > 86400000) {
          continue;
        }
        final owner = html.window.localStorage['agc-game-owner-$key'];
        // Unowned scores were earned as a guest and can be claimed on sign-in.
        if (owner != null && owner != AgcBackend.user!.id) continue;
        if (owner == null) html.window.localStorage['agc-game-owner-$key'] = AgcBackend.user!.id;
        final current = pendingScores[key];
        if (current == null || points > current.$1) {
          pendingScores[key] = (points, stage);
        }
      } catch (_) {
        // Storage can be disabled by privacy settings.
      }
    }
    if (!saving && pendingScores.isNotEmpty) {
      _savePendingScores();
    }
  }

  void _clearConfirmedScore(String key, int confirmedScore) {
    try {
      final storageKey = '$scoreStoragePrefix$key';
      final raw = html.window.localStorage[storageKey];
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> &&
          decoded['score'] is int &&
          (decoded['score'] as int) <= confirmedScore) {
        html.window.localStorage.remove(storageKey);
      }
    } catch (_) {}
  }

  void _notifyGameScoreStatus(String key, String state, int points, [String detail = '']) {
    final frame = frames[gameViews[gameKeys.indexOf(key)]];
    if (frame == null) return;
    try {
      frame.contentWindow?.postMessage(jsonEncode({
        'type': 'genesis-score-status',
        'game': key,
        'state': state,
        'score': points,
        'detail': detail,
      }), html.window.location.origin);
    } catch (_) {}
  }

  bool guestSignInRunning = false;

  Future<void> _ensureGuestIdentity() async {
    if (!mounted || !AgcBackend.configured || AgcBackend.user != null ||
        guestSignInRunning) { return; }
    guestSignInRunning = true;
    try {
      final suffix = DateTime.now().microsecondsSinceEpoch
          .remainder(1000000).toString().padLeft(6, '0');
      final nick = 'Genesis_$suffix';
      await AgcBackend.client.auth.signInAnonymously(data: {
        'handle': nick,
        'show_nick_publicly': true,
        'game_guest': true,
      });
      if (mounted) {
        _recoverPendingScores();
        setState(() => scoreNotice = 'Grasz jako $nick · zapisuję wynik online.');
      }
    } on AuthException catch (error) {
      if (mounted) { setState(() => scoreNotice =
        'Ranking gości niedostępny: ${error.message}. Wynik zapisany lokalnie.'); }
    } catch (error) {
      if (mounted) { setState(() => scoreNotice =
        'Nie udało się utworzyć profilu gościa. Wynik zapisany lokalnie.'); }
    } finally {
      guestSignInRunning = false;
    }
  }

  Future<void> _savePendingScores() async {
    if (saving || !mounted || pendingScores.isEmpty ||
        AgcBackend.user == null) {
      return;
    }
    setState(() {
      saving = true;
      scoreNotice = GenesisLanguage.copy(
        'Zapisuję wynik w rankingu…', 'Saving score to leaderboard…');
    });
    try {
      final keys = pendingScores.keys.toList();
      for (final key in keys) {
        if (!mounted || AgcBackend.user == null) break;
        final pending = pendingScores.remove(key);
        if (pending == null) continue;
        final (points, stage) = pending;
        try {
          final updated = await AgcBackend.client.rpc(
            'agc_submit_game_score',
            params: {
              'p_game_key': key,
              'p_score': points,
              'p_level': stage,
            },
          );
          if (!mounted) return;
          var confirmed = updated == true;
          if (!confirmed) {
            // A duplicate best is already saved; a rate-limited update
            // must remain queued for the next retry.
            final existing = await AgcBackend.client
              .from('agc_game_scores')
              .select('best_score')
              .eq('game_key', key)
              .eq('member_id', AgcBackend.user!.id)
              .maybeSingle();
            confirmed = existing != null &&
              (existing['best_score'] as int) >= points;
          }
          if (confirmed) {
            _clearConfirmedScore(key, points);
            GenesisGlobalRanking.scoreRevision.value++;
            _notifyGameScoreStatus(key, 'saved', points);
            lastSaveStatus = 'POTWIERDZONE: $key · $points pkt';
            setState(() {
              scoreNotice = GenesisLanguage.copy(
                '✓ Wynik zapisany w rankingu! 🏆',
                '✓ Score saved to leaderboard! 🏆');
              if (rankingGame == gameKeys.indexOf(key)) {
                rankingFuture = _leaders(key);
              }
            });
          } else {
            final newer = pendingScores[key];
            if (newer == null || newer.$1 < points) pendingScores[key] = pending;
            lastSaveStatus = 'OCZEKUJE: $key · $points pkt';
            _notifyGameScoreStatus(key, 'pending', points);
            setState(() => scoreNotice = GenesisLanguage.copy(
              'Wynik oczekuje na zapis. Ponowię automatycznie.',
              'Score pending. I will retry automatically.'));
          }
        } on PostgrestException catch (error) {
          lastSaveStatus = 'BŁĄD BAZY: ${error.message}';
          _notifyGameScoreStatus(key, 'error', points, error.message);
          final newer = pendingScores[key];
          if (newer == null || newer.$1 < points) {
            pendingScores[key] = pending;
          }
          if (!mounted) return;
          setState(() => scoreNotice = GenesisLanguage.copy(
            'Błąd zapisu: ${error.message}. Ponowię automatycznie.',
            'Save error: ${error.message}. Retrying automatically.'));
        } catch (error) {
          lastSaveStatus = 'BŁĄD POŁĄCZENIA: $error';
          _notifyGameScoreStatus(key, 'error', points, '$error');
          pendingScores[key] = pending;
          if (!mounted) return;
          setState(() => scoreNotice = GenesisLanguage.copy(
            'Błąd połączenia. Wynik zachowany, ponowię zapis.',
            'Connection error. Score kept for retry.'));
        }
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
        if (pendingScores.isNotEmpty) {
          // Next periodic retry handles RPC throttling and transient failures.
        }
      }
    }
  }

  Future<List<Map<String, dynamic>>> _leaders(String key) async {
    if (!AgcBackend.configured) {
      throw StateError('Brak połączenia z bazą Supabase. Sprawdź konfigurację i odśwież stronę.');
    }
    final raw = await AgcBackend.client
      .from('agc_game_scores')
      .select('member_id,best_score,best_level,updated_at')
      .eq('game_key', key)
      .order('best_score', ascending: false)
      .order('updated_at', ascending: true)
      .limit(100);
    final rows = List<Map<String, dynamic>>.from(raw);
    if (rows.isEmpty) {
      return rows;
    }
    final ids = rows.map((r) => r['member_id'] as String).toList();
    // Scores remain visible even if public nickname lookup is unavailable.
    final handles = <String, String>{};
    try {
      final members = await AgcBackend.client.rpc(
        'agc_game_ranking_names', params: {'p_ids': ids});
      for (final member in members) {
        handles[member['id'] as String] =
          member['display_handle'] as String? ?? 'Gracz anonimowy';
      }
    } catch (_) {}
    return rows.map((r) => {
      ...r,
      'handle': handles[r['member_id']] ?? 'Gracz anonimowy',
    }).toList();
  }

  void _showRanking(int selectedGame) {
    if (selectedGame == 3) _hideBlocksFullscreen();
    _recoverPendingScores();
    setState(() {
      rankingGame = selectedGame;
      rankingFuture = _loadRanking(gameKeys[selectedGame]);
    });
  }

  Future<List<Map<String, dynamic>>> _loadRanking(String key) async {
    // Avoid showing a stale empty leaderboard while the player's
    // score is still being submitted.
    for (var i = 0; i < 25 && saving; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    return _leaders(key);
  }

  void _closeRanking() {
    setState(() {
      rankingGame = null;
      rankingFuture = null;
    });
  }

  Widget _rankingPage(int selectedGame) {
    final title = titles[selectedGame];
    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(children: [
            IconButton.filledTonal(
              onPressed: _closeRanking,
              tooltip: GenesisLanguage.copy('Zamknij ranking', 'Close leaderboard'),
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(GenesisLanguage.copy('RANKING GRACZY', 'PLAYER LEADERBOARD'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(title, style: const TextStyle(color: Color(0xFFD8B66A))),
              ],
            )),
            IconButton(
              onPressed: () => _showRanking(selectedGame),
              tooltip: GenesisLanguage.copy('Odśwież ranking', 'Refresh leaderboard'),
              icon: const Icon(Icons.refresh),
            ),
            IconButton.filled(
              onPressed: _closeRanking,
              tooltip: GenesisLanguage.copy('Zamknij ranking', 'Close leaderboard'),
              icon: const Icon(Icons.close),
            ),
          ]),
        ),
        _versionLabel(),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Text(GenesisLanguage.copy(
            'Najlepszy wynik każdego gracza · niezależnie od GP',
            'Each player’s best score · separate from GP'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12)),
        ),
            Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
              future: rankingFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 32),
                        const SizedBox(height: 8),
                        Text(GenesisLanguage.copy(
                          'Nie udało się pobrać rankingu.',
                          'Could not load leaderboard.'),
                          textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        SelectableText('${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: Color(0xFFFFC777))),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _showRanking(selectedGame),
                          icon: const Icon(Icons.refresh),
                          label: Text(GenesisLanguage.copy(
                            'SPRÓBUJ PONOWNIE', 'RETRY')),
                        ),
                      ],
                    )));
                }
                final rows = snapshot.data ?? [];
                if (rows.isEmpty) {
                  return Center(child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.emoji_events_outlined,
                        color: Color(0xFFD8B66A), size: 40),
                      const SizedBox(height: 10),
                      Text(GenesisLanguage.copy(
                        'Jeszcze nie ma zapisanych wyników.',
                        'No saved scores yet.'),
                        textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _showRanking(selectedGame),
                        icon: const Icon(Icons.refresh),
                        label: Text(GenesisLanguage.copy(
                          'ODŚWIEŻ RANKING', 'REFRESH LEADERBOARD')),
                      ),
                    ],
                  ));
                }
                String dateLabel(dynamic value) {
                  final parsed = DateTime.tryParse(value?.toString() ?? '');
                  if (parsed == null) return '—';
                  final date = parsed.toLocal();
                  String two(int n) => n.toString().padLeft(2, '0');
                  return '${two(date.day)}.${two(date.month)}.${date.year}';
                }
                Widget cell(String value, double width, {
                  bool emphasize = false, TextAlign align = TextAlign.left,
                }) => SizedBox(
                  width: width,
                  child: Text(value,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    textAlign: align,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
                      color: emphasize ? gold : Colors.white,
                    )),
                );
                return LayoutBuilder(builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 540;
                  final nameWidth = wide ? 190.0 : 115.0;
                  final pointsWidth = wide ? 105.0 : 75.0;
                  final dateWidth = wide ? 105.0 : 85.0;
                  const levelWidth = 55.0;
                  Widget rankingRow(List<Widget> children, {bool header = false,
                    bool mine = false}) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: mine ? gold.withValues(alpha: .16)
                        : header ? const Color(0xFF19344A)
                        : Colors.transparent,
                      border: const Border(bottom: BorderSide(
                        color: Color(0xFF29445A), width: .5)),
                    ),
                    child: Row(children: children),
                  );
                  return ListView.builder(
                    itemCount: rows.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return rankingRow([
                          cell('#', 35),
                          cell(GenesisLanguage.copy('Gracz', 'Player'), nameWidth),
                          cell(GenesisLanguage.copy('Punkty', 'Points'), pointsWidth,
                            align: TextAlign.right),
                          cell(GenesisLanguage.copy('Data', 'Date'), dateWidth,
                            align: TextAlign.center),
                          cell('Level', levelWidth, align: TextAlign.right),
                        ], header: true);
                      }
                      final row = rows[index - 1];
                      final mine = row['member_id'] == AgcBackend.user?.id;
                      final place = index <= 3
                        ? ['🥇', '🥈', '🥉'][index - 1] : '$index';
                      return rankingRow([
                        cell(place, 35, emphasize: index <= 3),
                        cell("${row['handle']}${mine ? ' ★' : ''}",
                          nameWidth, emphasize: mine),
                        cell('${row['best_score']}', pointsWidth,
                          emphasize: true, align: TextAlign.right),
                        cell(dateLabel(row['updated_at']), dateWidth,
                          align: TextAlign.center),
                        cell('${row['best_level'] ?? '—'}', levelWidth,
                          align: TextAlign.right),
                      ], mine: mine);
                    },
                  );
                });
              },
            )),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 9, 14, 12),
          decoration: const BoxDecoration(
            color: Color(0xFF071525),
            border: Border(top: BorderSide(color: Color(0xFF46647C))),
          ),
          child: FilledButton.icon(
            onPressed: _closeRanking,
            icon: const Icon(Icons.close_rounded, size: 22),
            label: Text(GenesisLanguage.copy(
              'ZAMKNIJ RANKING · WRÓĆ DO GRY',
              'CLOSE LEADERBOARD · BACK TO GAME')),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: const Color(0xFFD8B66A),
              foregroundColor: const Color(0xFF071525),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ]),
    );
  }


  Widget _versionLabel() => Center(
    child: SelectableText(
      'GENESIS ARCADE · v2026.10.19-R100 · BUILD $buildVersion · $buildDate UTC',
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Color(0xFF90B2C8), fontSize: 10, letterSpacing: .4),
    ),
  );

  void _openDiagnostics() {
    setState(() => diagnosticsOpen = true);
    _checkDatabase();
  }

  Future<void> _checkDatabase() async {
    if (AgcBackend.user == null) {
      if (mounted) {
        setState(() => lastDatabaseStatus = 'Brak logowania — zaloguj się w KONTO');
      }
      return;
    }
    try {
      await AgcBackend.client
        .from('agc_game_scores')
        .select('game_key,best_score')
        .limit(1);
      if (mounted) {
        setState(() => lastDatabaseStatus = 'POŁĄCZENIE OK — odczyt rankingu działa');
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() => lastDatabaseStatus = 'BŁĄD: ${error.message}');
      }
    } catch (error) {
      if (mounted) {
        setState(() => lastDatabaseStatus = 'BŁĄD: $error');
      }
    }
  }

  Widget _diagnosticsPage() => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.bug_report_outlined, color: gold),
            const SizedBox(width: 8),
            const Expanded(child: Text('DIAGNOSTYKA GRY',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
            IconButton.filled(
              onPressed: () => setState(() => diagnosticsOpen = false),
              tooltip: 'Zamknij diagnostykę',
              icon: const Icon(Icons.close)),
          ]),
          _versionLabel(),
          const Divider(height: 24),
          Expanded(child: ListView(children: [
            ListTile(
              title: const Text('Logowanie'),
              subtitle: Text(AgcBackend.user == null
                ? 'BRAK — wyniki nie będą zapisywane'
                : 'OK — konto zalogowane')),
            ListTile(
              title: const Text('Połączenie z rankingiem'),
              subtitle: Text(lastDatabaseStatus)),
            ListTile(
              title: const Text('Komunikaty z gry'),
              subtitle: Text('$lastBridgeStatus · zdarzeń: $receivedScoreEvents')),
            ListTile(
              title: const Text('Ostatni odebrany wynik'),
              subtitle: Text(lastReceivedScore?.toString() ?? 'Brak')),
            ListTile(
              title: const Text('Zapis do bazy'),
              subtitle: Text(lastSaveStatus)),
            ListTile(
              title: const Text('Kolejka wyników'),
              subtitle: Text(pendingScores.isEmpty
                ? 'Pusta' : pendingScores.entries
                    .map((e) => '${e.key}: ${e.value.$1} pkt')
                    .join(' · '))),
            if (scoreNotice != null)
              ListTile(title: const Text('Komunikat'),
                subtitle: Text(scoreNotice!)),
          ])),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: _checkDatabase,
              icon: const Icon(Icons.wifi_tethering),
              label: const Text('SPRAWDŹ BAZĘ'),
            )),
            const SizedBox(width: 8),
            Expanded(child: FilledButton.icon(
              onPressed: () {
                _recoverPendingScores();
                _savePendingScores();
                _checkDatabase();
              },
              icon: const Icon(Icons.sync),
              label: const Text('PONÓW ZAPIS'),
            )),
          ]),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => setState(() => diagnosticsOpen = false),
            icon: const Icon(Icons.arrow_back),
            label: const Text('WRÓĆ DO GRY'),
          ),
        ],
      ),
    ),
  );

  static const gold = Color(0xFFD8B66A);

  Widget _arcadeButton({
    required VoidCallback onPressed,
    required bool primary,
    required Color accent,
    required IconData icon,
    required String label,
  }) => Expanded(
    flex: primary ? 5 : 4,
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: primary
          ? LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: accent == const Color(0xFF39CBFF)
                ? [const Color(0xFF20D8FF), const Color(0xFF0079DB),
                   const Color(0xFF003A89)]
                : [const Color(0xFFFFDC79), const Color(0xFFFF9B29),
                   const Color(0xFFB44709)],
            )
          : const LinearGradient(colors: [
              Color(0xFF142B41), Color(0xFF071526),
            ]),
        border: Border.all(
          color: primary ? accent : const Color(0xFF4C7696),
          width: primary ? 1.6 : 1),
        boxShadow: primary ? [
          BoxShadow(
            color: accent.withValues(alpha: .45),
            blurRadius: 17, spreadRadius: 1),
          const BoxShadow(
            color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 4)),
        ] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(15),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 21,
                    color: primary ? Colors.white
                      : const Color(0xFF9DDCFF)),
                  const SizedBox(width: 6),
                  Flexible(child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: primary ? Colors.white
                        : const Color(0xFF9DDCFF),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      letterSpacing: .35,
                    ))),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded, size: 18,
                    color: primary ? Colors.white
                      : const Color(0xFF9DDCFF)),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _gameCard({
    required int index,
    required IconData icon,
    required String title,
    required String category,
    required String description,
  }) {
    final signal = index == 0;
    final accent = signal
      ? const Color(0xFF39CBFF) : const Color(0xFFFFB05A);
    final image = signal
      ? 'assets/genesis_signal_cinematic.jpg'
      : 'assets/genesis_defender_cinematic.jpg';
    final features = signal
      ? <(IconData, String)>[
          (Icons.extension_outlined,
            GenesisLanguage.copy('Kolejne poziomy', 'Progressive levels')),
          (Icons.leaderboard_outlined,
            GenesisLanguage.copy('Ranking graczy', 'Player leaderboard')),
          (Icons.lightbulb_outline,
            GenesisLanguage.copy('Wskazówki', 'Hints')),
          (Icons.emoji_events_outlined,
            GenesisLanguage.copy('Pobij swój rekord', 'Beat your high score')),
        ]
      : <(IconData, String)>[
          (Icons.rocket_launch_outlined,
            GenesisLanguage.copy(
              'Lot w czterech kierunkach', 'Full directional flight')),
          (Icons.my_location_outlined,
            GenesisLanguage.copy('Kolejne fale dronów', 'Enemy drone waves')),
          (Icons.leaderboard_outlined,
            GenesisLanguage.copy('Ranking graczy', 'Player leaderboard')),
          (Icons.shield_outlined,
            GenesisLanguage.copy('Tarcze i naprawy', 'Shields and repairs')),
        ];
    void openGame() {
      try {
        html.window.localStorage['agc-game-owner-${signal ? 'signal' : 'defender'}'] =
          AgcBackend.user?.id ?? '';
      } catch (_) {}
      setState(() {
        game = index;
        scoreNotice = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (signal) { _showSignalFullscreen(); } else { _showDefenderFullscreen(); }
      });
    }
    return _ratedCard(index: index, accent: accent,
      content: InkWell(
          onTap: openGame,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(children: [
                SizedBox(
                  height: 235, width: double.infinity,
                  child: Image.asset(image, fit: BoxFit.cover, filterQuality: FilterQuality.high, semanticLabel: title),
                ),
                Positioned.fill(child: IgnorePointer(
                  child: DecoratedBox(decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0, .6, 1],
                      colors: [
                        const Color(0xFF041020).withValues(alpha: .02),
                        const Color(0xFF041020).withValues(alpha: .03),
                        const Color(0xFF041020).withValues(alpha: .25),
                      ],
                    ),
                  )),
                )),
                Positioned(
                  top: 12, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF071525)
                        .withValues(alpha: .84),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: accent.withValues(alpha: .8)),
                    ),
                    child: Text(category, style: TextStyle(
                      color: accent, fontSize: 11,
                      fontWeight: FontWeight.w700, letterSpacing: 1.1)),
                  ),
                ),
              ]),
              Expanded(child: Padding(
                padding: const EdgeInsets.fromLTRB(17, 5, 17, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (featureIcon, featureText) in features)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(children: [
                          Icon(featureIcon, color: accent, size: 20),
                          const SizedBox(width: 12),
                          Expanded(child: Text(featureText,
                            style: const TextStyle(
                              color: Color(0xFFD5E5F1), fontSize: 13))),
                        ]),
                      ),
                    const Spacer(),
                    Row(children: [
                      _arcadeButton(
                        onPressed: openGame,
                        primary: true,
                        accent: accent,
                        icon: Icons.play_arrow_rounded,
                        label: GenesisLanguage.copy('ZAGRAJ', 'PLAY'),
                      ),
                      const SizedBox(width: 10),
                      _arcadeButton(
                        onPressed: () => _showRanking(index),
                        primary: false,
                        accent: accent,
                        icon: Icons.emoji_events_outlined,
                        label: GenesisLanguage.copy('E-RANKING', 'E-RANKING'),
                      ),
                    ]),
                  ],
                ),
              )),
            ],
          ),
        ),
    );
  }

  Widget _ratedCard({required int index, required Color accent, required Widget content}) {
    return Container(
      key: ValueKey(gameKeys[index]),
      decoration: BoxDecoration(
        color: const Color(0xFF071525),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: accent.withValues(alpha: .9), width: 1.3),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: .18),
            blurRadius: 20, spreadRadius: -2),
          const BoxShadow(
            color: Color(0x99000000), blurRadius: 24,
            offset: Offset(0, 10)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(height: 500, child: content),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(children: [
              _ratingBar(index),
              _shareScoreButton(index),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _arcadeExtraCard({required int index}) {
    final wolf = index == 2;
    final ski = index == 5;
    final snake = index == 4;
    final city = index == 6;
    final accent = ski ? const Color(0xFF9DDDF6) : snake ? const Color(0xFF71F7C4) : wolf ? const Color(0xFFFFB05A) : const Color(0xFF39CBFF);
    final title = titles[index];
    void openGame() {
      if (ski) { _showSkiFullscreen(); return; }
      if (city) { _showCityFullscreen(); return; }
      setState(() { game = index; scoreNotice = null; });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (snake) { _showSnakeFullscreen(); } else if (wolf) { _showWolfFullscreen(); } else { _showBlocksFullscreen(); }
      });
    }
    final features = city
      ? <(IconData, String)>[(Icons.directions_car_outlined, 'Otwarty świat i swobodna jazda'),(Icons.local_shipping_outlined, 'Misje kurierskie i punkty'),(Icons.map_outlined, 'Mapa miasta i ruch uliczny'),(Icons.phone_android_outlined, 'Sterowanie na telefonie')]
      : ski
      ? <(IconData, String)>[
          (Icons.landscape_outlined, '25 skoczni od HS 35 do HS 235'),
          (Icons.speed_outlined, 'Wybij się na końcu progu'),
          (Icons.air, 'Steruj lotem gestem lub strzałkami'),
          (Icons.emoji_events_outlined, 'Ląduj telemarkiem i awansuj'),
        ]
      : snake
      ? <(IconData, String)>[
          (Icons.gamepad_outlined, 'Steruj gestem, strzałkami lub WASD'),
          (Icons.diamond_outlined, 'Zbieraj kryształy i wydłużaj węża'),
          (Icons.speed_outlined, 'Przyspieszaj co 70 punktów'),
          (Icons.border_outer, 'Graj ze ścianami lub bez'),
        ]
      : wolf
      ? <(IconData, String)>[
          (Icons.egg_outlined, 'Łap jajka z czterech stron'),
          (Icons.speed_outlined, 'Coraz szybsza rozgrywka'),
          (Icons.leaderboard_outlined, 'Ranking graczy'),
          (Icons.emoji_events_outlined, 'Pobij swój rekord'),
        ]
      : <(IconData, String)>[
          (Icons.grid_view_rounded, 'Układaj klocki na planszy 8×8'),
          (Icons.auto_awesome_outlined, 'Łącz linie i zdobywaj punkty'),
          (Icons.leaderboard_outlined, 'Ranking graczy'),
          (Icons.emoji_events_outlined, 'Pobij swój rekord'),
        ];
    return _ratedCard(index: index, accent: accent,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(onTap: openGame, child: Stack(children: [
            SizedBox(height: 235, width: double.infinity,
              child: city
                ? DecoratedBox(decoration: const BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFF0A1C30), Color(0xFF237C75), Color(0xFF071629)])),
                    child: Stack(alignment: Alignment.center, children: [
                      const Positioned(top: 15, left: 20, child: Icon(Icons.location_city,
                        size: 68, color: Color(0x886AD8BD))),
                      const Icon(Icons.directions_car_filled_rounded, size: 145,
                        color: Color(0xFFFFC65A)),
                      const Positioned(bottom: 14, child: Text('WARSZAWA · OPEN CITY',
                        style: TextStyle(fontSize: 20, color: Colors.white,
                          fontWeight: FontWeight.w900, letterSpacing: 1.3,
                          shadows: [Shadow(color: Colors.black, blurRadius: 10)]))),
                    ]))
                : ski
                ? Image.network('assets/ski-cover.jpg', fit: BoxFit.cover)
                : snake
                ? Image.network('assets/snake-cover.png', fit: BoxFit.cover)
                : wolf
                ? Image.network('wolfart/farm-scene.jpg', fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.pets, size: 90, color: Color(0xFFFFB05A))))
                : DecoratedBox(
                    decoration: const BoxDecoration(gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0xFF0B1C39), Color(0xFF163F6B), Color(0xFF081425)])),
                    child: Stack(alignment: Alignment.center, children: [
                      Positioned(top: 18, left: 20, child: Icon(Icons.auto_awesome,
                        color: accent.withValues(alpha: .8), size: 28)),
                      Transform.rotate(angle: -.11, child: Wrap(
                        spacing: 7, runSpacing: 7, children: [
                          for (var i = 0; i < 16; i++)
                            Container(width: 43, height: 43, decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft, end: Alignment.bottomRight,
                                colors: [
                                  [const Color(0xFF54D6FF), const Color(0xFFFFC04D),
                                   const Color(0xFFB28BFF), const Color(0xFF64E9A2)][i % 4],
                                  const Color(0xFF174A84),
                                ]),
                              border: Border.all(color: Colors.white70),
                              boxShadow: const [BoxShadow(color: Color(0xAA000000),
                                blurRadius: 12, offset: Offset(0, 5))])),
                        ],
                      )),
                      const Positioned(bottom: 16, child: Text('GENESIS BLOCKS',
                        style: TextStyle(color: Colors.white, fontSize: 23,
                          fontWeight: FontWeight.w900, letterSpacing: 2,
                          shadows: [Shadow(color: Colors.black, blurRadius: 12)]))),
                    ])),
            ),
            Positioned(top: 12, right: 12, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xDD071525), borderRadius: BorderRadius.circular(9),
                border: Border.all(color: accent.withValues(alpha: .8))),
              child: Text(city ? 'OTWARTY ŚWIAT' : ski ? 'SPORTOWA' : (snake || wolf) ? 'ZRĘCZNOŚCIOWA' : 'ŁAMIGŁÓWKA',
                style: TextStyle(color: accent, fontSize: 11,
                  fontWeight: FontWeight.w700, letterSpacing: 1.1)),
            )),
          ])),
          Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(17, 13, 17, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(title, style: TextStyle(color: accent, fontSize: 18,
                fontWeight: FontWeight.w800, letterSpacing: 1.1)),
              const SizedBox(height: 12),
              for (final (featureIcon, featureText) in features)
                Padding(padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Icon(featureIcon, color: accent, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(featureText, style: const TextStyle(
                      color: Color(0xFFD5E5F1), fontSize: 13))),
                  ])),
              const Spacer(),
              Row(children: [
                _arcadeButton(onPressed: openGame, primary: true, accent: accent,
                  icon: Icons.play_arrow_rounded, label: 'ZAGRAJ'),
                const SizedBox(width: 10),
                _arcadeButton(onPressed: () => _showRanking(index),
                  primary: false, accent: accent,
                  icon: Icons.emoji_events_outlined, label: 'E-RANKING'),
              ]),
              _shareScoreButton(index),
            ]))),
        ],
      ),
    );
  }

  bool get _cityPreviewAllowed =>
      AgcBackend.user?.email?.trim().toLowerCase() == 'mpiw123@gmail.com';

  Widget _cityPreviewCard(String title, String subtitle, String view,
      IconData icon, Color accent) => Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [
        Color(0xFF0C263D), Color(0xFF081522)]),
      border: Border.all(color: accent, width: 1.4),
      borderRadius: BorderRadius.circular(20)),
    padding: const EdgeInsets.all(18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(height: 142, decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(colors: [
          accent.withValues(alpha: .36), const Color(0xFF091728)])),
        child: Icon(icon, size: 76, color: accent)),
      const SizedBox(height: 14),
      Text(title, style: const TextStyle(fontWeight: FontWeight.w900,
        fontSize: 19, color: Colors.white)),
      const SizedBox(height: 8),
      Text(subtitle, style: const TextStyle(color: Colors.white70)),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: () => _showCityFullscreen(view),
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('URUCHOM PROTOTYP')),
    ]));

  Widget _cityPreviews() {
    if (!_cityPreviewAllowed) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 24),
      const Text('🔒 GENESIS CITY · PROTOTYPY PRYWATNE',
        style: TextStyle(fontWeight: FontWeight.w900,
          color: Color(0xFFF5C86C), fontSize: 18)),
      const SizedBox(height: 8),
      const Text('Widoczne tylko dla konta testowego. Multiplayer to obecnie symulacja botów, bez połączenia między graczami.'),
      const SizedBox(height: 14),
      LayoutBuilder(builder: (context, constraints) {
        final cards = [
          _cityPreviewCard('GENESIS CITY 3D',
            'Perspektywa zza auta, jazda i znaczniki misji. Prototyp pseudo-3D.',
            city3dView, Icons.view_in_ar_outlined, const Color(0xFFFFC86D)),
          _cityPreviewCard('GENESIS CITY Multiplayer',
            'Prototyp wspólnego miasta z botami; sieciowy multiplayer w kolejnym etapie.',
            cityMultiView, Icons.groups_outlined, const Color(0xFF9CAFFF)),
        ];
        if (constraints.maxWidth < 800) {
          return Column(children: [
            for (final card in cards) Padding(
              padding: const EdgeInsets.only(bottom: 12), child: card)]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final card in cards) Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5), child: card))]);
      }),
    ]);
  }

  Widget _compactGameCard(int index, {required bool listMode}) {
    final title = titles[index];
    final icon = index == 6 ? Icons.directions_car_filled_outlined : index == 0 ? Icons.hub_outlined
      : index == 1 ? Icons.rocket_launch_outlined
      : index == 2 ? Icons.egg_outlined
      : index == 3 ? Icons.grid_view_rounded
      : index == 4 ? Icons.gamepad_outlined
      : Icons.downhill_skiing_outlined;
    final color = index == 6 ? const Color(0xFF6AD8BD) : index == 2 ? const Color(0xFFFFB05A)
      : index == 4 ? const Color(0xFF71F7C4)
      : const Color(0xFF69CFFF);
    void open() {
      if (index == 5) { _showSkiFullscreen(); return; }
      if (index == 6) { _showCityFullscreen(); return; }
      setState(() { game = index; scoreNotice = null; });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (index == 4) { _showSnakeFullscreen(); }
        else if (index == 2) { _showWolfFullscreen(); }
        else if (index == 3) { _showBlocksFullscreen(); }
        else if (index == 1) { _showDefenderFullscreen(); }
        else if (index == 0) { _showSignalFullscreen(); }
      });
    }
    return Material(
      color: const Color(0xFF0C2236),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: open,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: .65)),
            borderRadius: BorderRadius.circular(15)),
          child: listMode
            ? Row(children: [
                Icon(icon, color: color, size: 34),
                const SizedBox(width: 12),
                Expanded(child: Text(title, maxLines: 2,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
                IconButton(tooltip: 'Ranking', icon: const Icon(Icons.emoji_events_outlined),
                  onPressed: () => _showRanking(index)),
                IconButton(tooltip: 'Zagraj', icon: const Icon(Icons.play_arrow_rounded),
                  onPressed: open),
              ])
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, color: color, size: 45),
                const SizedBox(height: 9),
                Text(title, maxLines: 2, textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 9),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  IconButton(tooltip: 'Zagraj', icon: const Icon(Icons.play_circle_fill),
                    onPressed: open),
                  IconButton(tooltip: 'Ranking', icon: const Icon(Icons.emoji_events_outlined),
                    onPressed: () => _showRanking(index)),
                ]),
              ]),
        ),
      ),
    );
  }

  Widget _gameLibrary() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1050),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          const Center(child: Icon(
            Icons.sports_esports_outlined, size: 42, color: gold)),
          const SizedBox(height: 8),
          const Center(child: Text('GRA',
            style: TextStyle(
              fontSize: 25, color: gold,
              fontWeight: FontWeight.w700, letterSpacing: 1.5))),
          const SizedBox(height: 8),
          Text(GenesisLanguage.copy(
            'WYBIERZ GRĘ I ODKRYWAJ NOWE WYZWANIA',
            'CHOOSE A GAME AND DISCOVER NEW CHALLENGES'),
            textAlign: TextAlign.center),
          _versionLabel(),
          if (AgcBackend.user == null) const Card(child: Padding(padding: EdgeInsets.all(12), child: Text('⚠ TRYB GOŚCIA — możesz grać, ale punkty NIE są zapisywane w rankingu online. Zaloguj się w zakładce KONTO przed grą.', textAlign: TextAlign.center))),
          TextButton.icon(onPressed: () => setState(() => rulesOpen = true), icon: const Icon(Icons.gavel_outlined), label: const Text('REGULAMIN GIER I RANKINGÓW')),
          _cityPreviews(),
          const SizedBox(height: 10),
          Wrap(spacing: 7, runSpacing: 7, crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Widok:', style: TextStyle(fontWeight: FontWeight.bold)),
              for (final count in [1, 2, 3, 4, 0])
                ChoiceChip(
                  label: Text(count == 0 ? 'Lista' : '$count'),
                  selected: gamesPerRow == count,
                  onSelected: (_) => setState(() => gamesPerRow = count)),
            ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final entry in [
              ('all', GenesisLanguage.copy('Wszystkie', 'All')),
              ('puzzle', GenesisLanguage.copy('Łamigłówki', 'Puzzles')),
              ('shooter', GenesisLanguage.copy('Strzelanki', 'Shooters')),
              ('arcade', GenesisLanguage.copy('Zręcznościowe', 'Arcade')),
              ('sport', GenesisLanguage.copy('Sportowe', 'Sports')),
              ('offline', 'Offline'),
            ])
              ChoiceChip(
                label: Text(entry.$2),
                selected: categoryFilter == entry.$1,
                onSelected: (_) => setState(() => categoryFilter = entry.$1),
              ),
          ]),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, constraints) {
            final cards = [
              _gameCard(
                index: 0,
                icon: Icons.hub_outlined,
                title: 'GENESIS SIGNAL',
                category: GenesisLanguage.copy(
                  'ŁAMIGŁÓWKA', 'PUZZLE'),
                description: GenesisLanguage.copy(
                  'Obracaj segmenty sieci, połącz sygnał i rozwiązuj coraz trudniejsze plansze.',
                  'Rotate network segments, connect the signal and solve harder puzzles.'),
              ),
              _gameCard(
                index: 1,
                icon: Icons.rocket_launch_outlined,
                title: 'GENESIS DEFENDER',
                category: GenesisLanguage.copy(
                  'STRZELANKA', 'SHOOTER'),
                description: GenesisLanguage.copy(
                  'Broń stacji Genesis przed dronami, przetrwaj fale i pobij rekord.',
                  'Defend the Genesis station, survive waves and beat the high score.'),
              ),
            ];
            const categories = [
              ['puzzle'], ['shooter'], ['arcade','offline'], ['puzzle','offline'], ['arcade','offline'], ['sport','offline'], ['arcade','offline'],
            ];
            final indices = [
              for (var i = 0; i < gameKeys.length; i++)
                if (categoryFilter == 'all' || categories[i].contains(categoryFilter)) i,
            ]..sort(_compareRatings);
            final visible = [
              for (final i in indices)
                i < 2 ? cards[i] : _arcadeExtraCard(index: i),
            ];
            final count = gamesPerRow;
            if (count == 0) {
              return Column(children: [
                for (final i in indices)
                  Padding(padding: const EdgeInsets.only(bottom: 8),
                    child: _compactGameCard(i, listMode: true)),
              ]);
            }
            if (count >= 3) {
              final tileWidth = (constraints.maxWidth - 12 * (count - 1)) / count;
              return Wrap(spacing: 12, runSpacing: 12, children: [
                for (final i in indices)
                  SizedBox(width: tileWidth, height: 178,
                    child: _compactGameCard(i, listMode: false)),
              ]);
            }
            if (count == 1 || constraints.maxWidth < 700) {
              return Column(children: [
                for (final card in visible) ...[
                  card, const SizedBox(height: 12),
                ],
              ]);
            }
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (final card in visible)
                SizedBox(width: (constraints.maxWidth - 12) / 2, child: card),
            ]);
          }),
        ],
      ),
    ),
  );

  Widget _rulesPage() => SafeArea(child: Column(children: [
    ListTile(
      leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => rulesOpen = false)),
      title: const Text('REGULAMIN GIER I RANKINGÓW', style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: const Text('THE GENESIS ERA · 18.11.2026'),
    ),
    Expanded(child: ListView(padding: const EdgeInsets.all(18), children: const [
      Text('1. Udział w grach', style: TextStyle(fontWeight: FontWeight.bold)),
      Text('Gry są dostępne bez opłat. Można grać bez logowania, ale wynik niezalogowanego gracza nie jest dodawany do rankingu online.'),
      SizedBox(height: 14),
      Text('2. Konto i zapis wyniku', style: TextStyle(fontWeight: FontWeight.bold)),
      Text('Aby uczestniczyć w rankingu, zaloguj się na swoje konto THE GENESIS ERA przed rozpoczęciem gry. Zapis wymaga połączenia z internetem oraz potwierdzenia przez serwer. Wynik widoczny wyłącznie w grze lub na urządzeniu nie oznacza zapisu online.'),
      SizedBox(height: 14),
      Text('3. Punktacja', style: TextStyle(fontWeight: FontWeight.bold)),
      Text('Wyniki od 10 punktów mogą zostać zgłoszone do rankingu. Ranking pojedynczej gry pokazuje najlepszy potwierdzony wynik danego gracza. Ranking globalny sumuje najlepsze potwierdzone wyniki tego gracza z poszczególnych gier. Punkty w grach nie są punktami GP platformy.'),
      SizedBox(height: 14),
      Text('4. Uczciwa gra', style: TextStyle(fontWeight: FontWeight.bold)),
      Text('Zabronione jest manipulowanie wynikami, automatyzowanie rozgrywki, wykorzystywanie błędów i podszywanie się pod innych graczy. Podejrzane wyniki mogą zostać zweryfikowane lub usunięte po sprawdzeniu.'),
      SizedBox(height: 14),
      Text('5. Dostępność i błędy', style: TextStyle(fontWeight: FontWeight.bold)),
      Text('Działanie gier i rankingu zależy od urządzenia, przeglądarki i usług sieciowych. W przypadku błędu sprawdź status logowania oraz diagnostykę rankingu. Zapis nie jest gwarantowany podczas awarii lub gry offline.'),
      SizedBox(height: 14),
      Text('6. Dane i widoczność', style: TextStyle(fontWeight: FontWeight.bold)),
      Text('Ranking może prezentować pseudonim gracza, jego pozycję, wyniki i gry. Obsługa konta i danych podlega zasadom prywatności platformy.'),
      SizedBox(height: 14),
      Text('7. Zmiany zasad', style: TextStyle(fontWeight: FontWeight.bold)),
      Text('Zasady mogą być aktualizowane wraz z rozwojem gier. Data aktualizacji jest podana powyżej.'),
      SizedBox(height: 18),
      Text('Dokument informacyjny do zatwierdzenia przez operatora platformy przed uznaniem go za oficjalny regulamin.', style: TextStyle(fontSize: 12, color: Colors.amber)),
    ])),
  ]));

  @override
  Widget build(BuildContext context) {
    if (rulesOpen) return _rulesPage();
    if (diagnosticsOpen) {
      return _cityPreviewAllowed ? _diagnosticsPage() : _gameLibrary();
    }
    if (rankingGame != null) {
      return _rankingPage(rankingGame!);
    }
    if (game == null) {
      return _gameLibrary();
    }
    final selectedGame = game!;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 7, 8, 5),
        child: Row(children: [
          IconButton.filledTonal(
            onPressed: () => setState(() {
              game = null;
              scoreNotice = null;
            }),
            tooltip: GenesisLanguage.copy(
              'Wróć do gier', 'Back to games'),
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(
            titles[selectedGame],
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold, color: gold, fontSize: 16),
          )),
          IconButton(
            onPressed: _openDiagnostics,
            tooltip: 'Diagnostyka rankingu',
            icon: const Icon(Icons.bug_report_outlined),
          ),
          IconButton.filledTonal(
            onPressed: () => _showRanking(selectedGame),
            tooltip: GenesisLanguage.copy(
              'Ranking tej gry', 'This game leaderboard'),
            icon: const Icon(Icons.emoji_events_outlined),
          ),
        ]),
      ),
      _versionLabel(),
      TextButton.icon(onPressed: () => setState(() => rulesOpen = true), icon: const Icon(Icons.gavel_outlined), label: const Text('REGULAMIN')),
      if (AgcBackend.user == null)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 5),
          child: Text(GenesisLanguage.copy(
            '⚠ Zaloguj się w KONTO, aby zapisywać punkty w rankingu.',
            '⚠ Sign in under ACCOUNT to save scores to the leaderboard.'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFFFC777), fontSize: 12)),
        ),
      if (scoreNotice != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(scoreNotice!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: gold, fontSize: 11)),
        ),
      Expanded(child: SizedBox.expand(child: HtmlElementView(
        key: ValueKey(selectedGame),
        viewType: gameViews[selectedGame],
      ))),
    ]);
  }
}
