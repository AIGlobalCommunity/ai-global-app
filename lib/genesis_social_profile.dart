import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'agc_registration.dart';
import 'agc_backend.dart';
import 'agc_luxury_theme.dart';
import 'genesis_language.dart';

String socialText(String pl, String en) => GenesisLanguage.copy(pl, en);

/// Account identity settings. Nickname uniqueness is checked server-side.
class GenesisAccountEditor extends StatefulWidget {
  const GenesisAccountEditor({super.key, this.onSaved});
  final VoidCallback? onSaved;

  @override
  State<GenesisAccountEditor> createState() => _GenesisAccountEditorState();
}

class _GenesisAccountEditorState extends State<GenesisAccountEditor> {
  final nickname = TextEditingController();
  final country = TextEditingController();
  bool isPublic = true;
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
      if (mounted) setState(() {
        loading = false;
        error = socialText('Nie udało się wczytać danych konta.',
          'Could not load account details.');
      });
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
      if (mounted) setState(() {
        error = socialText('Nie udało się sprawdzić pseudonimu. Spróbuj ponownie.',
          'Could not check the nickname. Please try again.');
      });
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
      if (mounted) setState(() => error = socialText(
        'Nie udało się zapisać danych. Spróbuj ponownie.',
        'Could not save account details. Please try again.'));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    nickname.dispose();
    country.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(socialText('EDYTUJ DANE KONTA', 'EDIT ACCOUNT DETAILS'),
          style: const TextStyle(color: AgcLuxury.champagne,
            fontWeight: FontWeight.bold, fontSize: 17)),
        const SizedBox(height: 8),
        Text(socialText('Zmień pseudonim, kraj i widoczność nicku. '
          'Numer członka i kod polecenia pozostają bez zmian.',
          'Change your nickname, country and nickname visibility. '
          'Your member number and referral code stay the same.')),
        const SizedBox(height: 12),
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
    ),
  );
}

/// Member-controlled, optional public information. Email is never displayed.
class GenesisSocialProfile extends StatefulWidget {
  const GenesisSocialProfile({super.key});
  @override
  State<GenesisSocialProfile> createState() => _GenesisSocialProfileState();
}

class _GenesisSocialProfileState extends State<GenesisSocialProfile> {
  final display = TextEditingController();
  final bio = TextEditingController();
  final interests = TextEditingController();
  final website = TextEditingController();
  final location = TextEditingController();
  bool isPublic = true;
  bool loading = true;
  bool saving = false;
  String? notice;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final row = await AgcBackend.client.from('agc_social_profiles')
        .select('display_name,bio,interests,website,location_text,is_public')
        .eq('member_id', AgcBackend.user!.id).maybeSingle();
      if (!mounted) return;
      display.text = row?['display_name'] as String? ?? '';
      bio.text = row?['bio'] as String? ?? '';
      interests.text = row?['interests'] as String? ?? '';
      website.text = row?['website'] as String? ?? '';
      location.text = row?['location_text'] as String? ?? '';
      setState(() { isPublic = row?['is_public'] as bool? ?? true; loading = false; });
    } catch (e) {
      if (mounted) setState(() { notice = '$e'; loading = false; });
    }
  }

  Future<void> save() async {
    final url = website.text.trim();
    if (url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        setState(() => notice = socialText(
          'Adres strony musi zaczynać się od https://', 'Website must use https://'));
        return;
      }
    }
    setState(() { saving = true; notice = null; });
    try {
      await AgcBackend.client.from('agc_social_profiles').upsert({
        'member_id': AgcBackend.user!.id,
        'display_name': display.text.trim(),
        'bio': bio.text.trim(),
        'interests': interests.text.trim(),
        'website': url.isEmpty ? null : url,
        'location_text': location.text.trim(),
        'is_public': isPublic,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (mounted) setState(() => notice = socialText('Profil zapisany.', 'Profile saved.'));
    } catch (e) {
      if (mounted) setState(() => notice = '$e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    display.dispose();
    bio.dispose();
    interests.dispose();
    website.dispose();
    location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(socialText('MÓJ PROFIL SPOŁECZNOŚCIOWY', 'MY SOCIAL PROFILE'),
        style: const TextStyle(color: AgcLuxury.champagne,
          fontWeight: FontWeight.bold, fontSize: 17)),
      const SizedBox(height: 8),
      Text(socialText('Uzupełnij swój opis jak na FB lub X. '
        'Samodzielnie decydujesz, czy informacje będą widoczne dla innych.',
        'Add a bio like on Facebook or X. You decide whether others can see it.')),
      if (loading) const LinearProgressIndicator() else ...[
        TextField(controller: display, maxLength: 70,
          decoration: InputDecoration(labelText: socialText('Nazwa wyświetlana', 'Display name'))),
        TextField(controller: bio, maxLength: 700, maxLines: 3,
          decoration: InputDecoration(labelText: socialText('O mnie', 'About me'))),
        TextField(controller: interests, maxLength: 240,
          decoration: InputDecoration(labelText: socialText('Zainteresowania', 'Interests'))),
        TextField(controller: website, maxLength: 500,
          decoration: InputDecoration(labelText: socialText('Moja strona https://', 'My website https://'))),
        TextField(controller: location, maxLength: 100,
          decoration: InputDecoration(labelText: socialText('Lokalizacja (opcjonalna)', 'Location (optional)'))),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: isPublic,
          onChanged: (v) => setState(() => isPublic = v),
          title: Text(socialText('Profil publiczny', 'Public profile'))),
        FilledButton.icon(onPressed: saving ? null : save,
          icon: const Icon(Icons.save_outlined),
          label: Text(socialText('Zapisz profil', 'Save profile'))),
      ],
      if (notice != null) Padding(padding: const EdgeInsets.only(top: 8),
        child: Text(notice!)),
    ]),
  ));
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
              ListTile(leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(item['handle'] as String),
                subtitle: Text('#${item['member_number']}${item['bio'] == null ? '' : ' · ${item['bio']}'}')),
          ]);
        }),
    ]);
}
