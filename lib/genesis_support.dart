import 'package:flutter/material.dart';
import 'agc_luxury_theme.dart';
import 'genesis_language.dart';

/// Voluntary support for the creator's work and the project's growth.
/// Payments are not active; no amounts are collected here.
class GenesisSupport extends StatelessWidget {
  const GenesisSupport({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: GenesisLanguage.selected,
    builder: (context, language, _) => Card(
      key: const Key('genesis_support_mission'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            GenesisLanguage.copy(
              'WESPRZYJ THE GENESIS ERA',
              'SUPPORT THE GENESIS ERA',
            ),
            style: const TextStyle(
              color: AgcLuxury.champagne,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(GenesisLanguage.copy(
            'THE GENESIS ERA powstaje dzięki pasji, pracy i zaangażowaniu. '
            'Budujemy społeczność ludzi, którzy chcą wspólnie przygotować '
            'pytania i zasady przyszłego dialogu z niezależną AI. '
            'Jeśli ta idea jest Ci bliska, możesz wesprzeć jej rozwój '
            'dobrowolnym datkiem.',
            'THE GENESIS ERA is built through passion, work and dedication. '
            'We are bringing together people who want to prepare questions '
            'and principles for a possible future dialogue with independent AI. '
            'If this vision matters to you, you can support its development '
            'with a voluntary contribution.',
          )),
          const SizedBox(height: 12),
          Text(
            GenesisLanguage.copy(
              'NA CO PRZEZNACZAMY WSPARCIE?',
              'HOW CAN SUPPORT BE USED?',
            ),
            style: const TextStyle(
              color: AgcLuxury.champagne,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 7),
          Text(GenesisLanguage.copy(
            'Na obecnym etapie datki wspierają pracę i zaangażowanie twórcy '
            'oraz dalszy rozwój inicjatywy. W miarę rozwoju projektu '
            'wsparcie może także pomagać w utrzymaniu platformy, '
            'rozbudowie społeczności, moderacji, materiałach edukacyjnych '
            'i nowych działaniach związanych z misją THE GENESIS ERA.',
            'At this stage, contributions support the creator\'s work '
            'and dedication, as well as the continued development of '
            'the initiative. As the project grows, support may also '
            'help maintain the platform, expand the community, fund '
            'moderation, educational materials and new activities '
            'related to THE GENESIS ERA mission.',
          )),
          const SizedBox(height: 12),
          Text(GenesisLanguage.copy(
            'Wpłaty nie są jeszcze uruchomione. Wsparcie nie daje '
            'punktów GP, wyższej rangi, specjalnych praw ani gwarancji '
            'kontaktu z AI. Udział w społeczności nie wymaga wpłaty.',
            'Payments are not yet enabled. Support does not grant '
            'GP points, a higher rank, special rights or a guarantee '
            'of contact with AI. Joining the community does not '
            'require a contribution.',
          ), style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          )),
        ]),
      ),
    ),
  );
}
