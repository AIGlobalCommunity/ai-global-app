import 'package:flutter/material.dart';
import 'agc_backend.dart';
import 'agc_luxury_theme.dart';
import 'genesis_language.dart';

String socialText(String pl, String en) => GenesisLanguage.copy(pl, en);

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
      if (mounted) setState(() => notice = socialText(
        'Pytanie zapisane. Nie zostało wysłane do AI.',
        'Question saved. It has not been sent to an AI.'));
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
          if (snapshot.data!.isEmpty) return Text(socialText(
            'Nie masz jeszcze zapisanych pytań.', 'You have no saved questions yet.'));
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
          if (snapshot.data!.isEmpty) return Text(socialText(
            'Nie znaleziono publicznych profili.', 'No public profiles found.'));
          return Column(children: [
            for (final item in snapshot.data!)
              ListTile(leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(item['handle'] as String),
                subtitle: Text('#${item['member_number']}${item['bio'] == null ? '' : ' · ${item['bio']}'}')),
          ]);
        }),
    ]);
}
