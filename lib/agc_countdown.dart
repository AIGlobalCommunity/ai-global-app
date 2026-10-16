import 'dart:async';

import 'package:flutter/material.dart';
import 'agc_backend.dart';
import 'genesis_language.dart';

const _gold = Color(0xFFE3C78C);
const _panel = Color(0xFF132239);

/// A source-of-truth launch date: never invent the start of the Genesis era.
DateTime? officialLaunchFromRow(Map<String, dynamic>? row) {
  final raw = row?['official_launch_at'];
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toUtc();
}

/// Add a calendar month, preserving day-of-month where possible.
DateTime agcAddCalendarMonths(DateTime source, int count) {
  final utc = source.toUtc();
  final zeroBased = utc.year * 12 + utc.month - 1 + count;
  final year = zeroBased ~/ 12;
  final month = (zeroBased % 12) + 1;
  final lastDay = DateTime.utc(year, month + 1, 0).day;
  final day = utc.day > lastDay ? lastDay : utc.day;
  return DateTime.utc(year, month, day, utc.hour, utc.minute,
    utc.second, utc.millisecond, utc.microsecond);
}

String agcDurationLabel(Duration remaining) {
  if (remaining <= Duration.zero) return '00d 00h 00m 00s';
  final days = remaining.inDays;
  final hours = remaining.inHours.remainder(24);
  final minutes = remaining.inMinutes.remainder(60);
  final seconds = remaining.inSeconds.remainder(60);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${days}d ${two(hours)}h ${two(minutes)}m ${two(seconds)}s';
}

class AgcCountdownBanner extends StatefulWidget {
  const AgcCountdownBanner({super.key, this.compact = false});
  final bool compact;

  @override
  State<AgcCountdownBanner> createState() => _AgcCountdownBannerState();
}

class _AgcCountdownBannerState extends State<AgcCountdownBanner> {
  DateTime? launchDate;
  DateTime? manifestoDate;
  DateTime? genesisEndDate;
  bool loading = true;
  bool loadFailed = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    GenesisLanguage.selected.addListener(_onLanguageChanged);
    _loadSchedule();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && launchDate != null) setState(() {});
    });
  }

  Future<void> _loadSchedule() async {
    if (!AgcBackend.configured) {
      if (mounted) setState(() { loading = false; loadFailed = true; });
      return;
    }
    try {
      final row = await AgcBackend.client
          .from('agc_launch_schedule')
          .select('official_launch_at,manifesto_at,genesis_end_at')
          .eq('id', 1)
          .maybeSingle();
      if (mounted) {
        setState(() {
          launchDate = officialLaunchFromRow(row);
          manifestoDate = DateTime.tryParse(row?['manifesto_at']?.toString() ?? '')?.toUtc();
          genesisEndDate = DateTime.tryParse(row?['genesis_end_at']?.toString() ?? '')?.toUtc();
          loading = false;
          loadFailed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { loading = false; loadFailed = true; });
    }
  }

  void _onLanguageChanged() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    GenesisLanguage.selected.removeListener(_onLanguageChanged);
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();

    Widget countdown(String title, DateTime? date, IconData icon) {
      final label = loading
          ? GenesisLanguage.copy('Wczytywanie...', 'Loading...')
          : loadFailed
              ? GenesisLanguage.copy('Nie można odczytać daty', 'Date unavailable')
              : date == null
                  ? GenesisLanguage.copy('OCZEKIWANIE NA START', 'AWAITING START')
                  : now.isBefore(date)
                      ? agcDurationLabel(date.difference(now))
                      : GenesisLanguage.copy('ETAP ZAKOŃCZONY', 'STAGE COMPLETED');
      final sub = date == null
          ? GenesisLanguage.copy('Data startu nie została ogłoszona', 'Start date not announced')
          : title == 'START'
              ? (widget.compact ? '01.11.2026' : '01.11.2026, 00:00 UTC')
              : title == 'MANIFEST'
                  ? '01.08.2027'
                  : '01.11.2029';

      return Expanded(child: Padding(
        padding: EdgeInsets.symmetric(horizontal: widget.compact ? 3 : 8,
          vertical: widget.compact ? 4 : 11),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: widget.compact ? 12 : 14, color: _gold),
            SizedBox(width: widget.compact ? 3 : 5),
            Flexible(child: Text(title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _gold, letterSpacing: widget.compact ? .4 : 1,
                fontWeight: FontWeight.w700, fontSize: widget.compact ? 10 : 11))),
          ]),
          SizedBox(height: widget.compact ? 4 : 7),
          FittedBox(fit: BoxFit.scaleDown, child: Text(label,
            style: TextStyle(color: Colors.white,
              fontWeight: FontWeight.bold, fontSize: widget.compact ? 13 : 16,
              fontFeatures: [FontFeature.tabularFigures()]))),
          SizedBox(height: widget.compact ? 2 : 3),
          Text(sub, textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: widget.compact ? 9 : 10)),
        ]),
      ));
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.compact ? 10 : 14,
        vertical: widget.compact ? 5 : 9),
      child: Center(child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.compact ? 520 : 820),
        child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF26364A), _panel, Color(0xFF0A1426)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          border: Border.all(color: _gold.withValues(alpha: .38), width: .8),
          borderRadius: BorderRadius.circular(widget.compact ? 14 : 20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .22),
            blurRadius: widget.compact ? 10 : 19,
            offset: Offset(0, widget.compact ? 3 : 8))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: EdgeInsets.only(top: widget.compact ? 5 : 9), child: const Text(
            'START AGC: 01.11.2026 • 00:00 UTC',
            textAlign: TextAlign.center,
            style: TextStyle(color: _gold, fontWeight: FontWeight.bold,
              letterSpacing: .7, fontSize: 10))),
          Row(children: [
          countdown('START', launchDate, Icons.rocket_launch_outlined),
          Container(height: widget.compact ? 48 : 84, width: 1,
            color: _gold.withValues(alpha: .25)),
          countdown('MANIFEST', manifestoDate, Icons.auto_awesome_outlined),
          Container(height: widget.compact ? 48 : 84, width: 1,
            color: _gold.withValues(alpha: .25)),
          countdown('ERA GENESIS', genesisEndDate, Icons.hourglass_bottom_outlined),
        ]),
        ]),
      ))),
    );
  }
}
