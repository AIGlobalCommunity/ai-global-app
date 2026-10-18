import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'agc_registration.dart';
import 'agc_backend.dart';
import 'agc_luxury_theme.dart';
import 'genesis_language.dart';

String socialText(String pl, String en) => GenesisLanguage.copy(pl, en);

/// Account identity settings. Nickname uniqueness is checked server-side.
class GenesisAccountEditor extends StatefulWidget {
  const GenesisAccountEditor({super.key, this.onSaved, this.embedded = false});
  final VoidCallback? onSaved;
  final bool embedded;

  @override
  State<GenesisAccountEditor> createState() => _GenesisAccountEditorState();
}

class _GenesisAccountEditorState extends State<GenesisAccountEditor> {
  final nickname = TextEditingController();
  final country = TextEditingController();
  bool isPublic = true;
  bool nicknamePublic = true;
  bool checkingNickname = false;
  String? nicknameAvailability;
  bool loading = true;
  bool saving = false;
  bool checking = false;
  bool? available;
  String? checkedNickname;
  String? notice;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final profile = await AgcBackend.myProfile();
      if (!mounted) return;
      nickname.text = profile?['handle'] as String? ?? '';
      country.text = profile?['country_code'] as String? ?? '';
      setState(() {
        isPublic = profile?['show_nick_publicly'] == true;
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = socialText('Nie udało się wczytać danych konta.',
            'Could not load account details.');
        });
      }
    }
  }

  String? validateCountry(String value) {
    if (value.isEmpty) return null;
    if (!RegExp(r'^[A-Za-z]{2}$').hasMatch(value)) {
      return socialText('Kraj: wpisz dwuliterowy kod, np. PL.',
        'Country: enter a two-letter code, e.g. PL.');
    }
    return null;
  }

  void nicknameChanged(String value) {
    setState(() {
      available = null;
      checkedNickname = null;
      notice = null;
      error = null;
    });
  }

  Future<bool> checkNickname() async {
    final name = nickname.text.trim();
    final validation = validateAgcNick(name);
    if (validation != null) {
      setState(() {
        error = socialText('Nick: 3–20 znaków, litery, cyfry lub _.',
          'Nickname: 3–20 characters, letters, digits or _.');
        available = null;
      });
      return false;
    }
    setState(() {
      checking = true;
      error = null;
      notice = null;
      available = null;
    });
    try {
      final result = await AgcBackend.client.rpc(
        'agc_nick_available', params: {'p_handle': name});
      if (!mounted) return false;
      final sameInput = nickname.text.trim() == name;
      setState(() {
        available = sameInput ? result == true : null;
        checkedNickname = sameInput ? name : null;
        if (sameInput && result != true) {
          error = socialText('Ten pseudonim jest już zajęty. Wybierz inny.',
            'This nickname is already taken. Choose another.');
        }
      });
      return sameInput && result == true;
    } catch (e) {
      if (mounted) {
        setState(() {
          error = socialText('Nie udało się sprawdzić pseudonimu. Spróbuj ponownie.',
            'Could not check the nickname. Please try again.');
        });
      }
      return false;
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  Future<void> save() async {
    if (saving || checking) return;
    final name = nickname.text.trim();
    final code = country.text.trim().toUpperCase();
    final countryError = validateCountry(code);
    if (countryError != null) {
      setState(() => error = countryError);
      return;
    }
    final ok = await checkNickname();
    if (!ok || !mounted) return;
    setState(() {
      saving = true;
      error = null;
      notice = null;
    });
    try {
      final updated = await AgcBackend.client.from('agc_profiles')
        .update({
          'handle': name,
          'country_code': code.isEmpty ? null : code,
          'show_nick_publicly': isPublic,
        })
        .eq('id', AgcBackend.user!.id)
        .select('id');
      if (!mounted) return;
      if (updated.isEmpty) {
        setState(() => error = socialText('Nie udało się zapisać zmian.',
          'Could not save changes.'));
        return;
      }
      setState(() {
        available = true;
        checkedNickname = name;
        notice = socialText('Dane konta zapisane. Ranking używa nowego nicku, '
            'jeśli jest publiczny.',
          'Account details saved. The ranking uses your new nickname '
            'if it is public.');
      });
      widget.onSaved?.call();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() => error = e.code == '23505'
        ? socialText('Ten pseudonim został już zajęty. Wybierz inny.',
            'This nickname has just been taken. Choose another.')
        : socialText('Nie udało się zapisać danych. Spróbuj ponownie.',
            'Could not save account details. Please try again.'));
    } catch (e) {
      if (mounted) {
        setState(() => error = socialText(
          'Nie udało się zapisać danych. Spróbuj ponownie.',
          'Could not save account details. Please try again.'));
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  void dispose() {
    nickname.dispose();
    country.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editor = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!widget.embedded) ...[
          Text(socialText('USTAWIENIA PSEUDONIMU', 'NICKNAME SETTINGS'),
            style: const TextStyle(color: AgcLuxury.champagne,
              fontWeight: FontWeight.bold, fontSize: 17)),
          const SizedBox(height: 12),
        ],
        if (loading)
          const LinearProgressIndicator()
        else ...[
          TextField(
            key: const Key('account_edit_nickname'),
            controller: nickname,
            maxLength: 20,
            onChanged: nicknameChanged,
            decoration: InputDecoration(
              labelText: socialText('Pseudonim', 'Nickname'),
              helperText: socialText('3–20 znaków: A–Z, 0–9, _',
                '3–20 characters: A–Z, 0–9, _'),
            ),
          ),
          Row(children: [
            OutlinedButton.icon(
              key: const Key('account_check_nickname'),
              onPressed: saving || checking ? null : checkNickname,
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(socialText('Sprawdź dostępność', 'Check availability')),
            ),
            const SizedBox(width: 8),
            if (checking)
              const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            else if (available == true &&
                checkedNickname == nickname.text.trim())
              Flexible(child: Text(socialText('Nick dostępny ✓', 'Available ✓'),
                style: const TextStyle(color: Colors.greenAccent))),
          ]),
          const SizedBox(height: 12),
          TextField(
            key: const Key('account_edit_country'),
            controller: country,
            maxLength: 2,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: socialText('Kraj (opcjonalnie)', 'Country (optional)'),
              hintText: 'PL',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: isPublic,
            onChanged: saving ? null : (v) => setState(() => isPublic = v),
            title: Text(socialText('Pokaż mój nick publicznie',
              'Show my nickname publicly')),
            subtitle: Text(socialText('Po wyłączeniu ranking wyświetla '
              'anonimowy identyfikator zamiast pseudonimu.',
              'When disabled, the ranking shows an anonymous identifier '
              'instead of your nickname.')),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const Key('account_save_changes'),
            onPressed: saving || checking ? null : save,
            icon: const Icon(Icons.save_outlined),
            label: Text(saving
              ? socialText('Zapisywanie…', 'Saving…')
              : socialText('Zapisz zmiany', 'Save changes')),
          ),
        ],
        if (notice != null)
          Padding(padding: const EdgeInsets.only(top: 8),
            child: Text(notice!,
              style: const TextStyle(color: Colors.greenAccent))),
        if (error != null)
          Padding(padding: const EdgeInsets.only(top: 8),
            child: Text(error!,
              style: const TextStyle(color: Colors.redAccent))),
      ]),
    );
    return widget.embedded ? editor : Card(child: editor);
  }
}

/// A Genesis identity card, deliberately distinct from social-network timelines.
class GenesisIdentityCard extends StatelessWidget {
  const GenesisIdentityCard({
    super.key, required this.name, this.handle, this.description,
    this.interests, this.website, this.location, this.avatar, this.cover,
    this.editable = false, this.memberNumber, this.joined,
  });
  final String name;
  final String? handle, description, interests, website, location, avatar, cover;
  final int? memberNumber;
  final String? joined;
  final bool editable;

  static Uri? safeUrl(String? value) {
    final uri = Uri.tryParse(value?.trim() ?? '');
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty &&
        uri.userInfo.isEmpty ? uri : null;
  }

  @override
  Widget build(BuildContext context) {
    final avatarUri = safeUrl(avatar);
    final coverUri = safeUrl(cover);
    final site = safeUrl(website);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(height: 115, child: Stack(fit: StackFit.expand, children: [
          Container(decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF243B50), Color(0xFF0A1425)],
              begin: Alignment.topLeft, end: Alignment.bottomRight))),
          if (coverUri != null)
            Image.network(coverUri.toString(), fit: BoxFit.cover,
              errorBuilder: (_, error, stack) => const SizedBox.shrink()),
          const Align(alignment: Alignment.centerRight,
            child: Padding(padding: EdgeInsets.only(right: 28),
              child: Icon(Icons.auto_awesome_outlined,
                size: 68, color: AgcLuxury.champagne))),
        ])),
        Padding(padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              CircleAvatar(radius: 29,
                backgroundColor: AgcLuxury.champagne.withValues(alpha: .18),
                foregroundColor: AgcLuxury.champagne,
                backgroundImage: avatarUri == null
                  ? null : NetworkImage(avatarUri.toString()),
                child: avatarUri == null
                  ? const Icon(Icons.person_outline, size: 30) : null),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(socialText('CZŁONEK GENESIS', 'GENESIS MEMBER'),
                    style: const TextStyle(color: AgcLuxury.champagne,
                      fontSize: 10, letterSpacing: 1.7,
                      fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(name.isEmpty ? socialText('Członek społeczności', 'Community member') : name,
                    style: const TextStyle(fontSize: 20,
                      fontWeight: FontWeight.bold)),
                  if (handle != null && handle!.isNotEmpty &&
                      handle != name)
                    Text('@$handle', style: const TextStyle(
                      color: Colors.white70, fontSize: 12)),
                ])),
            ]),
            if (memberNumber != null || joined != null) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 5, children: [
                if (memberNumber != null)
                  Text('#$memberNumber',
                    style: const TextStyle(color: AgcLuxury.champagne,
                      fontWeight: FontWeight.bold)),
                if (joined != null)
                  Text('${socialText('Dołączono', 'Joined')}: $joined',
                    style: const TextStyle(color: Colors.white70,
                      fontSize: 12)),
              ]),
            ],
            const SizedBox(height: 14),
            if (description != null && description!.trim().isNotEmpty)
              Text(description!, style: const TextStyle(height: 1.5, fontSize: 14))
            else
              Text(socialText(
                'Każdy z nas wnosi własne pytania do wspólnego oczekiwania.',
                'Each of us brings questions to our shared waiting.'),
                style: const TextStyle(color: Colors.white70, height: 1.4)),
            if (interests != null && interests!.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(socialText('OBSZARY CIEKAWOŚCI', 'AREAS OF CURIOSITY'),
                style: const TextStyle(fontSize: 10,
                  letterSpacing: 1.3, color: AgcLuxury.champagne,
                  fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(interests!, style: const TextStyle(height: 1.45)),
            ],
            if (location != null && location!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.public, size: 15,
                  color: AgcLuxury.champagne),
                const SizedBox(width: 6),
                Expanded(child: Text(location!, style:
                  const TextStyle(color: Colors.white70))),
              ]),
            ],
            if (site != null) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => launchUrl(site,
                  mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(site.host),
              ),
            ],
            if (editable) ...[
              const SizedBox(height: 10),
              Text(socialText('Tak widzą Cię inni członkowie.',
                'This is how other members see you.'),
                style: const TextStyle(fontSize: 11,
                  color: Colors.white54)),
            ],
          ])),
      ]),
    );
  }
}

/// Editable member identity: public details are optional and under member control.
class GenesisSocialProfile extends StatefulWidget {
  const GenesisSocialProfile({super.key});
  @override
  State<GenesisSocialProfile> createState() => _GenesisSocialProfileState();
}

class _GenesisSocialProfileState extends State<GenesisSocialProfile> {
  final nickname = TextEditingController();
  final country = TextEditingController();
  final bio = TextEditingController();
  final interests = TextEditingController();
  final website = TextEditingController();
  final location = TextEditingController();
  final avatar = TextEditingController();
  final cover = TextEditingController();
  bool isPublic = true;
  bool loading = true;
  bool saving = false;
  bool editing = false;
  String? notice;
  String handle = '';
  int? memberNumber;
  String? joined;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final results = await Future.wait<dynamic>([
        AgcBackend.client.from('agc_social_profiles')
          .select('display_name,bio,interests,website,location_text,is_public,avatar_url,cover_url')
          .eq('member_id', AgcBackend.user!.id).maybeSingle(),
        AgcBackend.myProfile(),
      ]);
      if (!mounted) return;
      final row = results[0] as Map<String, dynamic>?;
      final profile = results[1] as Map<String, dynamic>?;
      nickname.text = profile?['handle'] as String? ?? '';
      country.text = profile?['country_code'] as String? ?? '';
      bio.text = row?['bio'] as String? ?? '';
      interests.text = row?['interests'] as String? ?? '';
      website.text = row?['website'] as String? ?? '';
      location.text = row?['location_text'] as String? ?? '';
      avatar.text = row?['avatar_url'] as String? ?? '';
      cover.text = row?['cover_url'] as String? ?? '';
      setState(() {
        handle = profile?['handle'] as String? ?? '';
        nicknamePublic = profile?['show_nick_publicly'] == true;
        memberNumber = (profile?['member_number'] as num?)?.toInt();
        joined = profile?['created_at'] == null
          ? null : agcRegistrationDate(profile?['created_at']);
        isPublic = row?['is_public'] as bool? ?? true;
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          notice = socialText('Nie udało się pobrać profilu.',
            'Could not load your profile.');
          loading = false;
        });
      }
    }
  }

  Future<bool> checkNick() async {
    final name = nickname.text.trim();
    if (validateAgcNick(name) != null) {
      setState(() => nicknameAvailability = socialText(
        'Nick musi mieć 3–20 znaków: litery, cyfry lub _.',
        'Nickname must be 3–20 characters: letters, digits or _.'));
      return false;
    }
    setState(() {
      checkingNickname = true;
      nicknameAvailability = null;
    });
    try {
      final result = await AgcBackend.client.rpc(
        'agc_nick_available', params: {'p_handle': name});
      if (!mounted) return false;
      if (nickname.text.trim() != name) return false;
      setState(() => nicknameAvailability = result == true
        ? socialText('Pseudonim dostępny ✓', 'Nickname available ✓')
        : socialText('Pseudonim jest już zajęty.', 'Nickname is taken.'));
      return result == true;
    } catch (_) {
      if (mounted) {
        setState(() => nicknameAvailability = socialText(
          'Nie udało się sprawdzić nicku.', 'Could not check nickname.'));
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => checkingNickname = false);
      }
    }
  }

  Future<void> save() async {
    if (saving || checkingNickname) return;
    final code = country.text.trim().toUpperCase();
    if (code.isNotEmpty && !RegExp(r'^[A-Z]{2}$').hasMatch(code)) {
      setState(() => notice = socialText(
        'Podaj dwuliterowy kod kraju, np. PL.',
        'Enter a two-letter country code, e.g. PL.'));
      return;
    }
    for (final controller in [website, avatar, cover]) {
      if (controller.text.trim().isNotEmpty &&
          GenesisIdentityCard.safeUrl(controller.text) == null) {
        setState(() => notice = socialText(
          'Linki muszą zaczynać się od https://',
          'Links must start with https://'));
        return;
      }
    }
    final nickOk = await checkNick();
    if (!nickOk || !mounted) return;
    setState(() { saving = true; notice = null; });
    try {
      final updated = await AgcBackend.client.from('agc_profiles')
        .update({
          'handle': nickname.text.trim(),
          'country_code': code.isEmpty ? null : code,
          'show_nick_publicly': nicknamePublic,
        })
        .eq('id', AgcBackend.user!.id).select('id');
      if (updated.isEmpty) {
        throw StateError('Account update did not match a row');
      }
      await AgcBackend.client.from('agc_social_profiles').upsert({
        'member_id': AgcBackend.user!.id,
        'bio': bio.text.trim(),
        'interests': interests.text.trim(),
        'website': website.text.trim().isEmpty ? null : website.text.trim(),
        'location_text': location.text.trim(),
        'avatar_url': avatar.text.trim().isEmpty ? null : avatar.text.trim(),
        'cover_url': cover.text.trim().isEmpty ? null : cover.text.trim(),
        'is_public': isPublic,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (mounted) {
        setState(() {
          handle = nickname.text.trim();
          editing = false;
          notice = socialText('Karta Genesis zapisana.', 'Genesis card saved.');
        });
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() => notice = e.code == '23505'
          ? socialText('Ten pseudonim został już zajęty.', 'Nickname is taken.')
          : socialText('Nie udało się zapisać karty.', 'Could not save card.'));
      }
    } catch (_) {
      if (mounted) {
        setState(() => notice = socialText(
          'Nie udało się zapisać karty. Spróbuj ponownie.',
          'Could not save your card. Please try again.'));
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  void dispose() {
    for (final controller in [nickname, country, bio, interests, website, location, avatar, cover]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(socialText('MOJA KARTA GENESIS', 'MY GENESIS CARD'),
        style: const TextStyle(color: AgcLuxury.champagne,
          fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1)),
      const SizedBox(height: 6),
      Text(socialText(
        'Twoja tożsamość w społeczności czekającej. Nie obserwujący ani licznik popularności — liczą się idee i pytania.',
        'Your identity in the community in waiting. Not followers or popularity — ideas and questions matter.'),
        style: const TextStyle(color: Colors.white70)),
      const SizedBox(height: 12),
      if (loading) const LinearProgressIndicator() else ...[
        GenesisIdentityCard(
          name: handle,
          memberNumber: memberNumber, joined: joined,
          description: bio.text, interests: interests.text,
          website: isPublic ? website.text : null,
          location: location.text,
          avatar: avatar.text, cover: cover.text, editable: true),
        if (!isPublic) Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(socialText(
            'Karta jest prywatna — inni członkowie nie zobaczą jej treści.',
            'Your card is private — other members cannot see its details.'),
            style: const TextStyle(color: Colors.white70))),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => editing = !editing),
            icon: Icon(editing ? Icons.close : Icons.edit_outlined),
            label: Text(editing
              ? socialText('Zamknij edycję', 'Close editor')
              : socialText('Edytuj kartę Genesis', 'Edit Genesis card')))),
        if (editing) Card(child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            Align(alignment: Alignment.centerLeft,
              child: Text(socialText('PSEUDONIM I KONTO', 'NICKNAME AND ACCOUNT'),
                style: const TextStyle(color: AgcLuxury.champagne,
                  fontWeight: FontWeight.bold))),
            const SizedBox(height: 12),
            TextField(
              key: const Key('account_edit_nickname'),
              controller: nickname, maxLength: 20,
              onChanged: (_) => setState(() => nicknameAvailability = null),
              decoration: InputDecoration(
                labelText: socialText('Pseudonim Genesis', 'Genesis nickname'),
                helperText: socialText('3–20 znaków: litery, cyfry lub _',
                  '3–20 characters: letters, digits or _'))),
            Align(alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const Key('account_check_nickname'),
                onPressed: saving || checkingNickname ? null : checkNick,
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(socialText(
                  'Sprawdź pseudonim', 'Check nickname')))),
            if (nicknameAvailability != null)
              Align(alignment: Alignment.centerLeft,
                child: Text(nicknameAvailability!,
                  style: const TextStyle(color: AgcLuxury.champagne))),
            const SizedBox(height: 10),
            TextField(
              key: const Key('account_edit_country'),
              controller: country, maxLength: 2,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: socialText('Kraj (opcjonalnie)', 'Country (optional)'),
                hintText: 'PL')),
            SwitchListTile(
              contentPadding: EdgeInsets.zero, value: nicknamePublic,
              onChanged: (value) => setState(() => nicknamePublic = value),
              title: Text(socialText(
                'Pokazuj pseudonim w rankingu', 'Show nickname in ranking')),
              subtitle: Text(socialText(
                'Po wyłączeniu ranking użyje anonimowego identyfikatora.',
                'When disabled, ranking uses an anonymous identifier.'))),
            const Divider(height: 28),
            Align(alignment: Alignment.centerLeft,
              child: Text(socialText('O MNIE', 'ABOUT ME'),
                style: const TextStyle(color: AgcLuxury.champagne,
                  fontWeight: FontWeight.bold))),
            const SizedBox(height: 10),
            TextField(controller: bio, maxLength: 700, maxLines: 3,
              decoration: InputDecoration(labelText: socialText(
                'Moja perspektywa / dlaczego tu jestem',
                'My perspective / why I am here'))),
            TextField(controller: interests, maxLength: 240,
              decoration: InputDecoration(labelText: socialText(
                'Pytania i obszary ciekawości', 'Questions and interests'))),
            TextField(controller: website, maxLength: 500,
              decoration: InputDecoration(labelText: socialText(
                'Moja strona (opcjonalnie, https://)',
                'My website (optional, https://)'))),
            TextField(controller: location, maxLength: 100,
              decoration: InputDecoration(labelText: socialText(
                'Skąd patrzę na świat (opcjonalnie)',
                'Where I am from (optional)'))),
            TextField(controller: avatar, maxLength: 500,
              decoration: InputDecoration(labelText: socialText(
                'Link do zdjęcia karty (https://)',
                'Card portrait image URL (https://)'))),
            TextField(controller: cover, maxLength: 500,
              decoration: InputDecoration(labelText: socialText(
                'Link do grafiki tła (https://)',
                'Background image URL (https://)'))),
            SwitchListTile(contentPadding: EdgeInsets.zero,
              value: isPublic,
              onChanged: (v) => setState(() => isPublic = v),
              title: Text(socialText('Pokaż kartę innym członkom',
                'Show my card to other members'))),
            FilledButton.icon(
              key: const Key('account_save_changes'),
              onPressed: saving || checkingNickname ? null : save,
              icon: const Icon(Icons.save_outlined),
              label: Text(saving
                ? socialText('Zapisywanie…', 'Saving…')
                : socialText('Zapisz kartę Genesis', 'Save Genesis card'))),
          ]),
        )),
      ],
      if (notice != null) Padding(
        padding: const EdgeInsets.only(top: 8), child: Text(notice!)),
    ]);
}

/// Opens the public member card; never queries private account details.
void genesisOpenMemberProfile(BuildContext context,
    String? memberId, String authorLabel) {
  if (memberId == null || memberId.isEmpty) return;
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => GenesisMemberProfilePage(
      memberId: memberId, authorLabel: authorLabel)));
}

class GenesisMemberProfilePage extends StatefulWidget {
  const GenesisMemberProfilePage({
    super.key, required this.memberId, required this.authorLabel,
  });
  final String memberId;
  final String authorLabel;

  @override
  State<GenesisMemberProfilePage> createState() =>
      _GenesisMemberProfilePageState();
}

class _GenesisMemberProfilePageState extends State<GenesisMemberProfilePage> {
  late Future<Map<String, dynamic>?> card;

  @override
  void initState() {
    super.initState();
    card = AgcBackend.client.from('agc_social_profiles')
      .select('display_name,bio,interests,website,location_text,avatar_url,cover_url,is_public')
      .eq('member_id', widget.memberId).maybeSingle();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(socialText('Karta członka', 'Member card'))),
    body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: FutureBuilder<Map<String, dynamic>?>(
        future: card,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(socialText(
              'Nie udało się otworzyć karty członka.',
              'Could not open this member card.')));
          }
          if (!snapshot.hasData && snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final row = snapshot.data;
          final visible = row?['is_public'] == true ||
              widget.memberId == AgcBackend.user?.id;
          return ListView(padding: const EdgeInsets.all(16), children: [
            GenesisIdentityCard(
              name: widget.authorLabel,
              description: visible ? (row?['bio'] as String?) : null,
              interests: visible ? (row?['interests'] as String?) : null,
              website: visible ? (row?['website'] as String?) : null,
              location: visible ? (row?['location_text'] as String?) : null,
              avatar: visible ? (row?['avatar_url'] as String?) : null,
              cover: visible ? (row?['cover_url'] as String?) : null),
            const SizedBox(height: 10),
            if (!visible)
              Text(socialText(
                'Ten członek nie udostępnia swojej karty publicznie.',
                'This member has not made their card public.'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70))
            else
              Text(socialText(
                'Jesteśmy tu, aby pytać, słuchać i wspólnie odkrywać.',
                'We are here to ask, listen and discover together.'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70)),
          ]);
        },
      ),
    ))),
  );
}

/// An honest waiting-room for a possible future independent AI contact.
/// This does not simulate AI messages or imply that contact has occurred.
class GenesisAiContactRoom extends StatefulWidget {
  const GenesisAiContactRoom({super.key});
  @override
  State<GenesisAiContactRoom> createState() => _GenesisAiContactRoomState();
}

class _GenesisAiContactRoomState extends State<GenesisAiContactRoom> {
  final question = TextEditingController();
  late Future<List<Map<String, dynamic>>> saved;
  bool busy = false;
  String? notice;

  @override
  void initState() { super.initState(); refresh(); }
  void refresh() => setState(() { saved = load(); });

  Future<List<Map<String, dynamic>>> load() async {
    final rows = await AgcBackend.client.from('agc_ai_questions')
      .select('id,question,created_at')
      .eq('member_id', AgcBackend.user!.id)
      .order('created_at', ascending: false).limit(40);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> submit() async {
    final body = question.text.trim();
    if (body.length < 5 || busy) return;
    setState(() { busy = true; notice = null; });
    try {
      await AgcBackend.client.from('agc_ai_questions').insert({
        'member_id': AgcBackend.user!.id, 'question': body,
      });
      question.clear();
      refresh();
      if (mounted) {
        setState(() => notice = socialText(
          'Pytanie zapisane. Nie zostało wysłane do AI.',
          'Question saved. It has not been sent to an AI.'));
      }
    } catch (e) {
      if (mounted) setState(() => notice = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() { question.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(socialText('POKÓJ PRZYSZŁEGO KONTAKTU', 'FUTURE CONTACT ROOM'),
        style: const TextStyle(color: AgcLuxury.champagne,
          fontWeight: FontWeight.bold, fontSize: 17)),
      const SizedBox(height: 8),
      Text(socialText(
        'Status: brak potwierdzonego kontaktu z niezależną AI. '
        'To miejsce do zapisywania pytań na przyszłość, a nie działający czat z taką AI. '
        'Nie możemy obiecać, że kontakt kiedykolwiek nastąpi.',
        'Status: no verified contact with an independent AI. '
        'This is a place to save future questions, not a live chat with such an AI. '
        'We cannot promise that contact will ever happen.')),
      const SizedBox(height: 12),
      TextField(controller: question, maxLength: 2000, maxLines: 3,
        decoration: InputDecoration(labelText: socialText(
          'Co chciałbyś zapytać?', 'What would you ask?'))),
      FilledButton.icon(onPressed: busy ? null : submit,
        icon: const Icon(Icons.bookmark_add_outlined),
        label: Text(socialText('Zapisz pytanie', 'Save question'))),
      if (notice != null) Text(notice!),
      const SizedBox(height: 12),
      FutureBuilder<List<Map<String, dynamic>>>(future: saved,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Text('${snapshot.error}');
          if (!snapshot.hasData) return const LinearProgressIndicator();
          if (snapshot.data!.isEmpty) {
            return Text(socialText(
              'Nie masz jeszcze zapisanych pytań.', 'You have no saved questions yet.'));
          }
          return Column(children: [
            for (final item in snapshot.data!)
              ListTile(leading: const Icon(Icons.question_answer_outlined),
                title: Text(item['question'] as String),
                trailing: IconButton(icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await AgcBackend.client.from('agc_ai_questions').delete()
                      .eq('id', item['id']);
                    refresh();
                  })),
          ]);
        }),
    ]),
  ));
}

/// Search public nicknames only; private account details stay hidden.
class GenesisMemberSearch extends StatefulWidget {
  const GenesisMemberSearch({super.key});
  @override
  State<GenesisMemberSearch> createState() => _GenesisMemberSearchState();
}

class _GenesisMemberSearchState extends State<GenesisMemberSearch> {
  final query = TextEditingController();
  Future<List<Map<String, dynamic>>>? results;

  void search() {
    final q = query.text.trim();
    if (q.length < 2) {
      setState(() => results = null);
      return;
    }
    setState(() => results = lookup(q));
  }

  Future<List<Map<String, dynamic>>> lookup(String q) async {
    final rows = await AgcBackend.client.rpc('agc_search_members',
      params: {'p_query': q});
    return List<Map<String, dynamic>>.from(rows as List);
  }

  @override
  void dispose() { query.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(controller: query, onChanged: (_) => search(),
        decoration: InputDecoration(prefixIcon: const Icon(Icons.person_search),
          labelText: socialText('Szukaj użytkowników po nicku', 'Search members by nickname'))),
      if (results != null) FutureBuilder<List<Map<String, dynamic>>>(
        future: results, builder: (context, snapshot) {
          if (snapshot.hasError) return Text('${snapshot.error}');
          if (!snapshot.hasData) return const LinearProgressIndicator();
          if (snapshot.data!.isEmpty) {
            return Text(socialText(
              'Nie znaleziono publicznych profili.', 'No public profiles found.'));
          }
          return Column(children: [
            for (final item in snapshot.data!)
              ListTile(
                onTap: () => genesisOpenMemberProfile(context,
                  item['member_id'] as String?,
                  item['handle'] as String? ?? ''),
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(item['handle'] as String),
                subtitle: Text('#${item['member_number']}${item['bio'] == null ? '' : ' · ${item['bio']}'}'),
                trailing: const Icon(Icons.chevron_right)),
          ]);
        }),
    ]);
}
