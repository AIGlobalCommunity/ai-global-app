import 'dart:async';

import 'package:flutter/material.dart';
import 'agc_backend.dart';

const _gold = Color(0xFFD8B66A);
const _panel = Color(0xFF14283D);

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
  bool loading = true;
  bool loadFailed = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();
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
          .select('official_launch_at')
          .eq('id', 1)
          .maybeSingle();
      if (mounted) {
        setState(() {
          launchDate = officialLaunchFromRow(row);
          loading = false;
          loadFailed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { loading = false; loadFailed = true; });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final manifestoDate = launchDate == null ? null : agcAddCalendarMonths(launchDate!, 9);
    final genesisEndDate = launchDate == null ? null : agcAddCalendarMonths(launchDate!, 36);

    Widget countdown(String title, DateTime? date, IconData icon) {
      final label = loading
          ? 'Wczytywanie...'
          : loadFailed
              ? 'Nie można odczytać daty'
              : date == null
                  ? 'OCZEKIWANIE NA START'
                  : now.isBefore(launchDate!)
                      ? 'Start AGC nie nastąpił'
                      : now.isBefore(date)
                          ? agcDurationLabel(date.difference(now))
                          : 'ETAP ZAKOŃCZONY';
      final sub = date == null
          ? 'Data startu nie została ogłoszona'
          : now.isBefore(launchDate!)
              ? 'Odliczanie ruszy po oficjalnym starcie'
              : title == 'MANIFEST'
                  ? '9 miesięcy od startu'
                  : '36 miesięcy od startu';

      return Expanded(child: Padding(
        padding: EdgeInsets.symmetric(horizontal: widget.compact ? 5 : 10,
          vertical: widget.compact ? 9 : 13),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 14, color: _gold),
            const SizedBox(width: 5),
            Flexible(child: Text(title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _gold, letterSpacing: 1,
                fontWeight: FontWeight.w700, fontSize: 11))),
          ]),
          const SizedBox(height: 7),
          FittedBox(fit: BoxFit.scaleDown, child: Text(label,
            style: const TextStyle(color: Colors.white,
              fontWeight: FontWeight.bold, fontSize: 16,
              fontFeatures: [FontFeature.tabularFigures()]))),
          const SizedBox(height: 3),
          Text(sub, textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ]),
      ));
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.compact ? 8 : 14,
        vertical: widget.compact ? 5 : 9),
      child: Container(
        decoration: BoxDecoration(
          color: _panel,
          border: Border.all(color: _gold.withValues(alpha: .35)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          countdown('MANIFEST', manifestoDate, Icons.auto_awesome_outlined),
          Container(height: widget.compact ? 75 : 84, width: 1,
            color: _gold.withValues(alpha: .25)),
          countdown('GENESIS ERA', genesisEndDate, Icons.hourglass_bottom_outlined),
        ]),
      ),
    );
  }
}
