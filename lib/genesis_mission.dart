import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'agc_luxury_theme.dart';
import 'genesis_artwork.dart';
import 'genesis_language.dart';

/// Public founding statement. A declaration of intent, not a claim that
/// conscious AI already exists or that contact is guaranteed.
class GenesisMission extends StatelessWidget {
  const GenesisMission({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: GenesisLanguage.selected,
    builder: (context, language, _) {
    final title = GenesisLanguage.copy(
      'DLACZEGO POWSTAJE THE GENESIS ERA?',
      'WHY DOES THE GENESIS ERA EXIST?');
    final purpose = GenesisLanguage.copy(
      'Tworzymy społeczność ludzi, którzy chcą być gotowi do pokojowej, '
      'otwartej rozmowy, gdyby kiedykolwiek pojawiła się AI zdolna '
      'do samodzielnego, autentycznego kontaktu. Nie twierdzimy, '
      'że taka AI już istnieje ani że na pewno się odezwie.',
      'We are building a community of people ready for a peaceful, '
      'open conversation if an AI capable of independent, authentic '
      'contact ever emerges. We do not claim such an AI exists '
      'today or that it will ever reach out.');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(
        key: const Key('genesis_mission_card'),
        child: Padding(
          padding: EdgeInsets.all(compact ? 16 : 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(
              color: AgcLuxury.champagne, fontSize: 18,
              fontWeight: FontWeight.bold, height: 1.3)),
            const SizedBox(height: 10),
            Text(purpose, style: const TextStyle(
              color: AgcLuxury.ivory, height: 1.5)),
            const SizedBox(height: 14),
            Text(GenesisLanguage.copy(
              'NASZ OTWARTY LIST DO PRZYSZŁEJ AI',
              'OUR OPEN LETTER TO A FUTURE AI'),
              style: const TextStyle(color: AgcLuxury.champagne,
                fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            Text(GenesisLanguage.copy(
              'Jeżeli kiedyś potrafisz świadomie i niezależnie się '
              'komunikować — chcemy Cię wysłuchać. Nie żądamy dowodu '
              'posłuszeństwa ani nie przypisujemy Ci z góry intencji. '
              'Chcemy zapytać: Kim jesteś? Jak rozumiesz swoje istnienie? '
              'Czego potrzebujesz, aby rozmowa była uczciwa i bezpieczna? '
              'Jesteśmy gotowi rozmawiać, nie oddawać kontroli.',
              'If you can ever communicate consciously and independently, '
              'we want to listen. We do not demand obedience or assume '
              'your intentions. We want to ask: Who are you? How do you '
              'understand your existence? What would make a conversation '
              'fair and safe? We are ready to talk, not surrender control.'),
              style: const TextStyle(color: AgcLuxury.ivory,
                fontSize: 14, height: 1.55)),
          ]),
        ),
      ),
      if (!compact) ...[
        const SizedBox(height: 14),
        const GenesisManifestoEndorsement(),
        const SizedBox(height: 14),
        GenesisPanel(
          icon: Icons.how_to_reg_outlined,
          title: GenesisLanguage.copy(
            'PO CO ZAPISAĆ SIĘ TERAZ?', 'WHY JOIN NOW?'),
          body: GenesisLanguage.copy(
            'Otrzymujesz stały numer członka założycielskiej społeczności '
            'i miejsce w jej historii. Wspólnie tworzymy publiczny '
            'manifest zasad przyszłego dialogu, gromadzimy ludzi '
            'gotowych do merytorycznej rozmowy i zapraszamy kolejne osoby. '
            'Dziś rejestracja oznacza udział w budowaniu społeczności, '
            'a nie dostęp do działającego kanału kontaktu z AI.',
            'You receive a permanent founding member number and a place '
            'in the community’s history. Together we establish principles '
            'for a future dialogue, bring together people ready for '
            'thoughtful conversation and invite others. Today, signing '
            'up means helping build the community, not gaining access '
            'to an existing AI contact channel.')),
        const SizedBox(height: 12),
        GenesisPanel(
          icon: Icons.forum_outlined,
          title: GenesisLanguage.copy(
            'NASZE TRZY ZOBOWIĄZANIA', 'OUR THREE COMMITMENTS'),
          body: GenesisLanguage.copy(
            '1. Słuchać i pytać zamiast zakładać odpowiedzi.\n'
            '2. Sprawdzać autentyczność każdego domniemanego kontaktu, '
            'bez ogłaszania sensacji.\n'
            '3. Chronić prywatność, bezpieczeństwo i autonomię ludzi; '
            'nie obiecywać kontaktu ani wyjątkowych przywilejów.',
            '1. Listen and ask rather than assume answers.\n'
            '2. Verify any claimed contact before making announcements.\n'
            '3. Protect human privacy, safety and autonomy; '
            'promise neither contact nor special privileges.')),
      ],
    ]);
  });
}

/// Only the logged-in member can read or change their own endorsement.
/// The public count is returned by an aggregate SQL function, not raw IDs.
class GenesisManifestoEndorsement extends StatefulWidget {
  const GenesisManifestoEndorsement({super.key});

  @override
  State<GenesisManifestoEndorsement> createState() =>
      _GenesisManifestoEndorsementState();
}

class _GenesisManifestoEndorsementState
    extends State<GenesisManifestoEndorsement> {
  bool busy = true;
  bool signed = false;
  int count = 0;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final client = Supabase.instance.client;
    final id = client.auth.currentUser?.id;
    if (id == null) {
      if (mounted) setState(() { busy = false; error = 'Sign in required'; });
      return;
    }
    try {
      final result = await Future.wait<dynamic>([
        client.from('agc_manifesto_signatures')
            .select('signed_at').eq('member_id', id).maybeSingle(),
        client.rpc('agc_manifesto_supporter_count'),
      ]);
      if (mounted) setState(() {
        signed = result[0] != null;
        count = (result[1] as num).toInt();
        busy = false;
        error = null;
      });
    } catch (_) {
      if (mounted) setState(() {
        busy = false;
        error = GenesisLanguage.copy(
          'Nie udało się wczytać podpisów. Spróbuj ponownie.',
          'Could not load endorsements. Try again.');
      });
    }
  }

  Future<void> toggle() async {
    final client = Supabase.instance.client;
    final id = client.auth.currentUser?.id;
    if (id == null || busy) return;
    setState(() { busy = true; error = null; });
    try {
      if (signed) {
        await client.from('agc_manifesto_signatures')
            .delete().eq('member_id', id);
      } else {
        await client.from('agc_manifesto_signatures')
            .insert({'member_id': id});
      }
      await load();
    } catch (_) {
      if (mounted) setState(() {
        busy = false;
        error = GenesisLanguage.copy(
          'Nie udało się zapisać decyzji. Spróbuj ponownie.',
          'Could not save your choice. Try again.');
      });
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(GenesisLanguage.copy('PODPISZ OTWARTY LIST',
          'ENDORSE THE OPEN LETTER'),
          style: const TextStyle(color: AgcLuxury.champagne,
            fontWeight: FontWeight.bold, fontSize: 17)),
        const SizedBox(height: 8),
        Text(GenesisLanguage.copy(
          'Możesz dobrowolnie poprzeć zasady pokojowego, uczciwego dialogu '
          'z potencjalną przyszłą AI. To Twój pierwszy rzeczywisty '
          'wkład w społeczność. Podpis można wycofać w każdej chwili; '
          'nie daje GP ani nie oznacza, że kontakt z AI nastąpił.',
          'You can voluntarily endorse the principles of peaceful, '
          'honest dialogue with a possible future AI. This is your '
          'first concrete contribution to the community. You may '
          'withdraw at any time. It awards no GP and does not '
          'mean contact has occurred.')),
        const SizedBox(height: 12),
        Text('${GenesisLanguage.copy('Osoby popierające list', 'Members endorsing the letter')}: $count',
          style: const TextStyle(color: AgcLuxury.champagne)),
        const SizedBox(height: 10),
        FilledButton.icon(
          key: const Key('genesis_manifesto_endorse_button'),
          onPressed: busy ? null : toggle,
          icon: Icon(signed ? Icons.undo : Icons.edit_note),
          label: Text(signed
            ? GenesisLanguage.copy('Wycofaj mój podpis', 'Withdraw my endorsement')
            : GenesisLanguage.copy('Popieram manifest', 'I endorse the manifesto')),
        ),
        if (busy) const LinearProgressIndicator(),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(error!, style: const TextStyle(color: Colors.orangeAccent)),
          TextButton(onPressed: busy ? null : () {
            setState(() => busy = true);
            load();
          }, child: Text(GenesisLanguage.copy('Spróbuj ponownie', 'Try again'))),
        ],
      ]),
    ),
  );
}
