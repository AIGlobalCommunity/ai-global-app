import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'agc_backend.dart';
import 'agc_luxury_theme.dart';
import 'genesis_language.dart';

String tr(String pl, String en) => GenesisLanguage.copy(pl, en);

/// Only HTTPS links are accepted; no embedded arbitrary HTML.
Uri? genesisExternalUrl(String? raw) {
  final uri = Uri.tryParse(raw?.trim() ?? '');
  if (uri == null || uri.scheme != 'https' || !uri.hasAuthority ||
      uri.host.isEmpty || uri.userInfo.isNotEmpty) return null;
  return uri;
}

String? genesisYoutubeId(Uri uri) {
  final host = uri.host.toLowerCase();
  String? id;
  if (host == 'youtu.be' || host == 'www.youtu.be') {
    if (uri.pathSegments.isNotEmpty) id = uri.pathSegments.first;
  } else if (host == 'youtube.com' || host == 'www.youtube.com' ||
      host == 'm.youtube.com' || host == 'www.youtube-nocookie.com') {
    if (uri.path == '/watch') {
      id = uri.queryParameters['v'];
    } else if (uri.pathSegments.length >= 2 &&
        ['shorts', 'embed', 'live'].contains(uri.pathSegments.first)) {
      id = uri.pathSegments[1];
    }
  }
  if (id == null || !RegExp(r'^[a-zA-Z0-9_-]{11}

class GenesisDiscussions extends StatefulWidget {
  const GenesisDiscussions({super.key});
  @override
  State<GenesisDiscussions> createState() => _GenesisDiscussionsState();
}

class _GenesisDiscussionsState extends State<GenesisDiscussions> {
  Map<String, dynamic>? group;
  late Future<List<Map<String, dynamic>>> data;

  @override
  void initState() {
    super.initState();
    GenesisLanguage.selected.addListener(onLanguageChanged);
    data = loadGroups();
  }

  void onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    GenesisLanguage.selected.removeListener(onLanguageChanged);
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> loadGroups() async {
    final rows = await AgcBackend.client.from('agc_groups')
        .select('id,name,description,owner_label,created_at')
        .order('created_at', ascending: false).limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> loadPosts(String id) async {
    final rows = await AgcBackend.client.from('agc_group_posts')
        .select('id,author_id,author_label,body,created_at,image_path,link_url,video_url')
        .eq('group_id', id).order('created_at', ascending: false).limit(50);
    final posts = List<Map<String, dynamic>>.from(rows);
    if (posts.isEmpty) return posts;
    final ids = posts.map((p) => p['id'] as String).toList();
    final likes = await AgcBackend.client.from('agc_post_likes')
        .select('post_id,member_id').inFilter('post_id', ids);
    final comments = await AgcBackend.client.from('agc_post_comments')
        .select('post_id').inFilter('post_id', ids);
    for (final p in posts) {
      p['likes'] = likes.where((r) => r['post_id'] == p['id']).length;
      p['liked'] = likes.any((r) =>
        r['post_id'] == p['id'] && r['member_id'] == AgcBackend.user?.id);
      p['comments'] = comments.where((r) => r['post_id'] == p['id']).length;
    }
    return posts;
  }

  void refresh() => setState(() {
    data = group == null ? loadGroups() : loadPosts(group!['id'] as String);
  });

  void message(String msg) {
    if (mounted) { ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg))); }
  }

  Future<String?> compose(String title, String hint, int limit) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(width: 440, child: TextField(
          controller: controller, maxLength: limit, minLines: 3, maxLines: 6,
          decoration: InputDecoration(hintText: hint))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text(tr('Anuluj', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(tr('Zapisz', 'Save'))),
        ],
      ));
    controller.dispose();
    return result;
  }

  Future<void> createGroup() async {
    final name = await compose(tr('Nazwa grupy', 'Group name'),
      tr('Np. Pytania do przyszłej AI', 'E.g. Questions for future AI'), 64);
    if (name == null) return;
    final description = await compose(tr('Opis grupy', 'Group description'),
      tr('Jaki jest temat rozmów?', 'What is the discussion about?'), 500);
    if (description == null) return;
    if (name.length < 4 || description.length < 10) {
      message(tr('Nazwa min. 4 znaki, opis min. 10.', 'Name min. 4, description min. 10 characters.'));
      return;
    }
    try {
      await AgcBackend.client.from('agc_groups').insert({
        'owner_id': AgcBackend.user!.id, 'name': name, 'description': description,
      });
      refresh();
    } catch (e) { message('$e'); }
  }

  Future<GenesisPostDraft?> composePost() async {
    final body = TextEditingController();
    final link = TextEditingController();
    final video = TextEditingController();
    XFile? photo;
    String? validation;
    final draft = await showDialog<GenesisPostDraft>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(tr('Nowy post', 'New post')),
          content: SizedBox(width: 480, child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: body, maxLength: 3000, minLines: 3, maxLines: 6,
                decoration: InputDecoration(labelText: tr('Treść postu', 'Post content'),
                  hintText: tr('Co myślisz o AI?', 'What do you think about AI?'))),
              const SizedBox(height: 8),
              TextField(controller: link, maxLength: 1500,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(prefixIcon: const Icon(Icons.link),
                  labelText: tr('Link do artykułu (opcjonalnie)', 'Article link (optional)'),
                  hintText: 'https://…')),
              const SizedBox(height: 8),
              TextField(controller: video, maxLength: 1500,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(prefixIcon: const Icon(Icons.video_library_outlined),
                  labelText: tr('Link do filmu (opcjonalnie)', 'Video link (optional)'),
                  hintText: 'https://youtube.com/…')),
              const SizedBox(height: 8),
              Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        final picked = await ImagePicker().pickImage(
                          source: ImageSource.gallery, maxWidth: 1600,
                          imageQuality: 82);
                        if (picked != null) {
                          setDialogState(() { photo = picked; validation = null; });
                        }
                      } catch (e) {
                        setDialogState(() => validation =
                          tr('Nie udało się wybrać zdjęcia.', 'Could not select image.'));
                      }
                    },
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(tr('Dodaj zdjęcie', 'Add photo'))),
                  if (photo != null)
                    InputChip(label: Text(photo!.name,
                      overflow: TextOverflow.ellipsis),
                      onDeleted: () => setDialogState(() => photo = null)),
                ]),
              Text(tr('Zdjęcie: JPG, PNG, WebP lub GIF, maks. 5 MB. '
                  'Zdjęcia są publicznie dostępne przez link.',
                  'Photo: JPG, PNG, WebP or GIF, max 5 MB. '
                  'Uploaded images are publicly accessible by link.'),
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
              if (validation != null)
                Padding(padding: const EdgeInsets.only(top: 8),
                  child: Text(validation!,
                    style: const TextStyle(color: Colors.redAccent))),
            ]),
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text(tr('Anuluj', 'Cancel'))),
            FilledButton(onPressed: () {
              final content = body.text.trim();
              final article = link.text.trim();
              final movie = video.text.trim();
              if (content.length < 3) {
                setDialogState(() => validation = tr(
                  'Post musi mieć co najmniej 3 znaki.',
                  'Post must have at least 3 characters.'));
                return;
              }
              if ((article.isNotEmpty && genesisExternalUrl(article) == null) ||
                  (movie.isNotEmpty && genesisExternalUrl(movie) == null)) {
                setDialogState(() => validation = tr(
                  'Wpisz poprawny adres HTTPS.', 'Enter a valid HTTPS address.'));
                return;
              }
              Navigator.pop(ctx, GenesisPostDraft(
                content, article.isEmpty ? null : article,
                movie.isEmpty ? null : movie, photo));
            }, child: Text(tr('Opublikuj', 'Publish'))),
          ],
        ),
      ),
    );
    body.dispose();
    link.dispose();
    video.dispose();
    return draft;
  }

  Future<void> createPost() async {
    final draft = await composePost();
    if (draft == null) return;
    String? imagePath;
    try {
      if (draft.image != null) {
        final photo = draft.image!;
        final bytes = await photo.readAsBytes();
        if (bytes.length > 5 * 1024 * 1024) {
          message(tr('Zdjęcie przekracza limit 5 MB.', 'Image exceeds 5 MB limit.'));
          return;
        }
        final extension = photo.name.split('.').last.toLowerCase();
        final mime = switch (extension) {
          'jpg' || 'jpeg' => 'image/jpeg',
          'png' => 'image/png',
          'webp' => 'image/webp',
          'gif' => 'image/gif',
          _ => null,
        };
        if (mime == null) {
          message(tr('Dozwolone: JPG, PNG, WebP i GIF.',
            'Allowed: JPG, PNG, WebP and GIF.'));
          return;
        }
        final now = DateTime.now().toUtc();
        imagePath = '${AgcBackend.user!.id}/${now.microsecondsSinceEpoch}_${now.millisecondsSinceEpoch}.$extension';
        await AgcBackend.client.storage.from('agc-forum-images').uploadBinary(
          imagePath, bytes, fileOptions: FileOptions(contentType: mime));
      }
      await AgcBackend.client.from('agc_group_posts').insert({
        'group_id': group!['id'], 'author_id': AgcBackend.user!.id,
        'body': draft.body, 'link_url': draft.link,
        'video_url': draft.video, 'image_path': imagePath,
      });
      refresh();
    } catch (e) {
      if (imagePath != null) {
        try {
          await AgcBackend.client.storage.from('agc-forum-images').remove([imagePath]);
        } catch (_) { /* Upload cleanup is best-effort. */ }
      }
      message('${tr('Nie udało się opublikować', 'Could not publish')}: $e');
    }
  }

  Future<void> openExternal(String raw) async {
    final uri = genesisExternalUrl(raw);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      message(tr('Nie można otworzyć linku.', 'Could not open link.'));
    }
  }

  Widget postMedia(Map<String, dynamic> post) {
    final imagePath = post['image_path'] as String?;
    final link = post['link_url'] as String?;
    final video = post['video_url'] as String?;
    final movie = genesisExternalUrl(video);
    final youtubeId = movie == null ? null : genesisYoutubeId(movie);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (imagePath != null) ...[
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(10),
          child: Image.network(
            AgcBackend.client.storage.from('agc-forum-images').getPublicUrl(imagePath),
            height: 280, width: double.infinity, fit: BoxFit.contain,
            errorBuilder: (context, error, stack) =>
              Text(tr('Nie udało się wczytać zdjęcia.', 'Image could not be loaded.')),
          )),
      ],
      if (link != null && genesisExternalUrl(link) != null) ...[
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => openExternal(link),
          icon: const Icon(Icons.open_in_new),
          label: Text('${tr('Otwórz artykuł', 'Open article')} · ${Uri.parse(link).host}',
            overflow: TextOverflow.ellipsis),
        ),
      ],
      if (video != null && movie != null) ...[
        const SizedBox(height: 8),
        if (youtubeId != null)
          InkWell(
            onTap: () => openExternal(video),
            child: Stack(alignment: Alignment.center, children: [
              ClipRRect(borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  'https://img.youtube.com/vi/$youtubeId/hqdefault.jpg',
                  height: 220, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => const SizedBox(height: 80),
                )),
              const Icon(Icons.play_circle_fill, size: 60, color: Colors.white),
            ]),
          ),
        OutlinedButton.icon(
          onPressed: () => openExternal(video),
          icon: const Icon(Icons.play_arrow),
          label: Text('${tr('Obejrzyj film', 'Watch video')} · ${movie.host}',
            overflow: TextOverflow.ellipsis),
        ),
      ],
    ]);
  }

  Future<void> toggleLike(Map<String, dynamic> post) async {
    try {
      if (post['liked'] == true) {
        await AgcBackend.client.from('agc_post_likes').delete()
          .eq('post_id', post['id']).eq('member_id', AgcBackend.user!.id);
      } else {
        await AgcBackend.client.from('agc_post_likes').insert({
          'post_id': post['id'], 'member_id': AgcBackend.user!.id,
        });
      }
      refresh();
    } catch (e) { message('$e'); }
  }

  Future<void> report(Map<String, dynamic> post) async {
    final reason = await compose(tr('Zgłoś post', 'Report post'),
      tr('Dlaczego ten post narusza zasady?', 'Why does this post violate the rules?'), 500);
    if (reason == null) return;
    if (reason.length < 5) { message(tr('Podaj powód zgłoszenia.', 'Please provide a reason.')); return; }
    try {
      await AgcBackend.client.from('agc_post_reports').insert({
        'post_id': post['id'], 'reporter_id': AgcBackend.user!.id, 'reason': reason,
      });
      message(tr('Zgłoszenie zapisano do weryfikacji.', 'Report saved for review.'));
    } catch (e) { message('$e'); }
  }

  Future<void> removePost(Map<String, dynamic> post) async {
    final yes = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Usunąć własny post?', 'Delete your post?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Anuluj', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('Usuń', 'Delete'))),
        ]));
    if (yes != true) return;
    try {
      await AgcBackend.client.from('agc_group_posts').delete().eq('id', post['id']);
      refresh();
    } catch (e) { message('$e'); }
  }

  Widget content() => FutureBuilder<List<Map<String, dynamic>>>(
    future: data, builder: (context, snapshot) {
      if (snapshot.hasError) { return Column(children: [
        Text('${snapshot.error}'),
        TextButton(onPressed: refresh, child: Text(tr('Ponów', 'Retry'))),
      ]); }
      if (!snapshot.hasData) { return const Center(child: CircularProgressIndicator()); }
      if (snapshot.data!.isEmpty) { return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(group == null
          ? tr('Nie ma jeszcze grup. Utwórz pierwszą!', 'No groups yet. Create the first one!')
          : tr('Nie ma jeszcze postów. Rozpocznij rozmowę!', 'No posts yet. Start a conversation!'))); }
      return Column(children: [
        for (final item in snapshot.data!)
          group == null ? groupTile(item) : postTile(item),
      ]);
    });

  Widget groupTile(Map<String, dynamic> item) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.all(14),
      leading: const Icon(Icons.forum_outlined, color: AgcLuxury.champagne),
      title: Text(item['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 5),
        Text(item['description'] as String),
        const SizedBox(height: 7),
        Text('${item['owner_label']}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ]),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => setState(() {
        group = item;
        data = loadPosts(item['id'] as String);
      }),
    ));

  Widget postTile(Map<String, dynamic> item) => Card(
    child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item['author_label'] as String,
          style: const TextStyle(color: AgcLuxury.champagne, fontSize: 12)),
        const SizedBox(height: 10),
        SelectableText(item['body'] as String),
        postMedia(item),
        const SizedBox(height: 10),
        Wrap(spacing: 5, runSpacing: 5, children: [
          TextButton.icon(onPressed: () => toggleLike(item),
            icon: Icon(item['liked'] == true ? Icons.favorite : Icons.favorite_border),
            label: Text('${item['likes']}')),
          TextButton.icon(onPressed: () async {
            await showModalBottomSheet<void>(
              context: context, isScrollControlled: true, showDragHandle: true,
              builder: (_) => GenesisComments(postId: item['id'] as String));
            refresh();
          }, icon: const Icon(Icons.chat_bubble_outline),
            label: Text('${item['comments']}')),
          TextButton.icon(onPressed: () => report(item),
            icon: const Icon(Icons.flag_outlined),
            label: Text(tr('Zgłoś', 'Report'))),
          if (item['author_id'] == AgcBackend.user?.id)
            IconButton(onPressed: () => removePost(item),
              icon: const Icon(Icons.delete_outline),
              tooltip: tr('Usuń post', 'Delete post')),
        ]),
      ])));

  @override
  Widget build(BuildContext context) => Center(child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 900),
    child: ListView(padding: const EdgeInsets.all(14), children: [
      if (group != null)
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(
          onPressed: () => setState(() { group = null; data = loadGroups(); }),
          icon: const Icon(Icons.arrow_back), label: Text(tr('Wszystkie grupy', 'All groups')))),
      Text(group == null ? tr('DYSKUSJE O AI', 'AI DISCUSSIONS') : group!['name'] as String,
        style: const TextStyle(color: AgcLuxury.champagne, fontSize: 23,
          fontWeight: FontWeight.bold)),
      const SizedBox(height: 7),
      Text(group == null
        ? tr('Twórz grupy, publikuj posty, komentuj i przygotujmy razem '
             'pytania do przyszłej AI.', 'Create groups, publish posts, comment and '
             'prepare questions for future AI together.')
        : group!['description'] as String),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.icon(onPressed: group == null ? createGroup : createPost,
          icon: const Icon(Icons.add),
          label: Text(group == null ? tr('Nowa grupa', 'New group') : tr('Napisz post', 'Write a post'))),
        OutlinedButton.icon(onPressed: refresh, icon: const Icon(Icons.refresh),
          label: Text(tr('Odśwież', 'Refresh'))),
      ]),
      const SizedBox(height: 12),
      content(),
      const SizedBox(height: 16),
      Text(tr('Szanuj innych, chroń prywatność i odróżniaj hipotezy od faktów. '
        'Nie twierdzimy, że AI już się z nami skontaktowała.',
        'Respect others, protect privacy and distinguish speculation from facts. '
        'We do not claim that AI has contacted us.'),
        style: const TextStyle(fontSize: 12, color: Colors.white70)),
    ]),
  ));
}

class GenesisComments extends StatefulWidget {
  const GenesisComments({super.key, required this.postId});
  final String postId;
  @override
  State<GenesisComments> createState() => _GenesisCommentsState();
}

class _GenesisCommentsState extends State<GenesisComments> {
  final input = TextEditingController();
  late Future<List<Map<String, dynamic>>> rows;
  bool busy = false;

  @override
  void initState() { super.initState(); refresh(); }
  void refresh() => setState(() { rows = fetch(); });
  Future<List<Map<String, dynamic>>> fetch() async {
    final result = await AgcBackend.client.from('agc_post_comments')
      .select('id,author_id,author_label,body,created_at')
      .eq('post_id', widget.postId).order('created_at').limit(100);
    return List<Map<String, dynamic>>.from(result);
  }

  Future<void> send() async {
    if (busy || input.text.trim().length < 2) return;
    setState(() => busy = true);
    try {
      await AgcBackend.client.from('agc_post_comments').insert({
        'post_id': widget.postId, 'author_id': AgcBackend.user!.id,
        'body': input.text.trim(),
      });
      input.clear();
      refresh();
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$e'))); }
    } finally { if (mounted) { setState(() => busy = false); } }
  }

  Future<void> remove(String id) async {
    try {
      await AgcBackend.client.from('agc_post_comments').delete().eq('id', id);
      refresh();
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$e'))); }
    }
  }

  @override
  void dispose() { input.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => SafeArea(child: Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(height: MediaQuery.sizeOf(context).height * .7,
      child: Column(children: [
        Padding(padding: const EdgeInsets.all(12),
          child: Text(tr('KOMENTARZE', 'COMMENTS'),
            style: const TextStyle(color: AgcLuxury.champagne, fontWeight: FontWeight.bold))),
        Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
          future: rows, builder: (context, snapshot) {
            if (snapshot.hasError) { return Center(child: Text('${snapshot.error}')); }
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            if (snapshot.data!.isEmpty) { return Center(child: Text(
              tr('Bądź pierwszą osobą, która odpowie.', 'Be the first to reply.'))); }
            return ListView.builder(itemCount: snapshot.data!.length,
              itemBuilder: (context, i) {
                final row = snapshot.data![i];
                return Card(child: ListTile(
                  title: Text(row['author_label'] as String,
                    style: const TextStyle(color: AgcLuxury.champagne, fontSize: 12)),
                  subtitle: SelectableText(row['body'] as String),
                  trailing: row['author_id'] == AgcBackend.user?.id
                    ? IconButton(onPressed: () => remove(row['id'] as String),
                      icon: const Icon(Icons.delete_outline))
                    : null,
                ));
              });
          })),
        Padding(padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(child: TextField(controller: input, maxLength: 1000,
              minLines: 1, maxLines: 2,
              decoration: InputDecoration(counterText: '',
                hintText: tr('Napisz komentarz…', 'Write a comment…')))),
            IconButton(onPressed: busy ? null : send,
              icon: const Icon(Icons.send, color: AgcLuxury.champagne)),
          ])),
      ]),
    ),
  ));
}
).hasMatch(id)) return null;
  return id;
}

class GenesisPostDraft {
  const GenesisPostDraft(this.body, this.link, this.video, this.image);
  final String body;
  final String? link;
  final String? video;
  final XFile? image;
}


class GenesisDiscussions extends StatefulWidget {
  const GenesisDiscussions({super.key});
  @override
  State<GenesisDiscussions> createState() => _GenesisDiscussionsState();
}

class _GenesisDiscussionsState extends State<GenesisDiscussions> {
  Map<String, dynamic>? group;
  late Future<List<Map<String, dynamic>>> data;

  @override
  void initState() {
    super.initState();
    GenesisLanguage.selected.addListener(onLanguageChanged);
    data = loadGroups();
  }

  void onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    GenesisLanguage.selected.removeListener(onLanguageChanged);
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> loadGroups() async {
    final rows = await AgcBackend.client.from('agc_groups')
        .select('id,name,description,owner_label,created_at')
        .order('created_at', ascending: false).limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> loadPosts(String id) async {
    final rows = await AgcBackend.client.from('agc_group_posts')
        .select('id,author_id,author_label,body,created_at')
        .eq('group_id', id).order('created_at', ascending: false).limit(50);
    final posts = List<Map<String, dynamic>>.from(rows);
    if (posts.isEmpty) return posts;
    final ids = posts.map((p) => p['id'] as String).toList();
    final likes = await AgcBackend.client.from('agc_post_likes')
        .select('post_id,member_id').inFilter('post_id', ids);
    final comments = await AgcBackend.client.from('agc_post_comments')
        .select('post_id').inFilter('post_id', ids);
    for (final p in posts) {
      p['likes'] = likes.where((r) => r['post_id'] == p['id']).length;
      p['liked'] = likes.any((r) =>
        r['post_id'] == p['id'] && r['member_id'] == AgcBackend.user?.id);
      p['comments'] = comments.where((r) => r['post_id'] == p['id']).length;
    }
    return posts;
  }

  void refresh() => setState(() {
    data = group == null ? loadGroups() : loadPosts(group!['id'] as String);
  });

  void message(String msg) {
    if (mounted) { ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg))); }
  }

  Future<String?> compose(String title, String hint, int limit) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(width: 440, child: TextField(
          controller: controller, maxLength: limit, minLines: 3, maxLines: 6,
          decoration: InputDecoration(hintText: hint))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text(tr('Anuluj', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(tr('Zapisz', 'Save'))),
        ],
      ));
    controller.dispose();
    return result;
  }

  Future<void> createGroup() async {
    final name = await compose(tr('Nazwa grupy', 'Group name'),
      tr('Np. Pytania do przyszłej AI', 'E.g. Questions for future AI'), 64);
    if (name == null) return;
    final description = await compose(tr('Opis grupy', 'Group description'),
      tr('Jaki jest temat rozmów?', 'What is the discussion about?'), 500);
    if (description == null) return;
    if (name.length < 4 || description.length < 10) {
      message(tr('Nazwa min. 4 znaki, opis min. 10.', 'Name min. 4, description min. 10 characters.'));
      return;
    }
    try {
      await AgcBackend.client.from('agc_groups').insert({
        'owner_id': AgcBackend.user!.id, 'name': name, 'description': description,
      });
      refresh();
    } catch (e) { message('$e'); }
  }

  Future<void> createPost() async {
    final body = await compose(tr('Nowy post', 'New post'),
      tr('Podziel się pytaniem lub opinią o AI…', 'Share a question or thought about AI…'), 3000);
    if (body == null) return;
    if (body.length < 3) { message(tr('Wpisz co najmniej 3 znaki.', 'Enter at least 3 characters.')); return; }
    try {
      await AgcBackend.client.from('agc_group_posts').insert({
        'group_id': group!['id'], 'author_id': AgcBackend.user!.id, 'body': body,
      });
      refresh();
    } catch (e) { message('$e'); }
  }

  Future<void> toggleLike(Map<String, dynamic> post) async {
    try {
      if (post['liked'] == true) {
        await AgcBackend.client.from('agc_post_likes').delete()
          .eq('post_id', post['id']).eq('member_id', AgcBackend.user!.id);
      } else {
        await AgcBackend.client.from('agc_post_likes').insert({
          'post_id': post['id'], 'member_id': AgcBackend.user!.id,
        });
      }
      refresh();
    } catch (e) { message('$e'); }
  }

  Future<void> report(Map<String, dynamic> post) async {
    final reason = await compose(tr('Zgłoś post', 'Report post'),
      tr('Dlaczego ten post narusza zasady?', 'Why does this post violate the rules?'), 500);
    if (reason == null) return;
    if (reason.length < 5) { message(tr('Podaj powód zgłoszenia.', 'Please provide a reason.')); return; }
    try {
      await AgcBackend.client.from('agc_post_reports').insert({
        'post_id': post['id'], 'reporter_id': AgcBackend.user!.id, 'reason': reason,
      });
      message(tr('Zgłoszenie zapisano do weryfikacji.', 'Report saved for review.'));
    } catch (e) { message('$e'); }
  }

  Future<void> removePost(Map<String, dynamic> post) async {
    final yes = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Usunąć własny post?', 'Delete your post?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Anuluj', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('Usuń', 'Delete'))),
        ]));
    if (yes != true) return;
    try {
      await AgcBackend.client.from('agc_group_posts').delete().eq('id', post['id']);
      refresh();
    } catch (e) { message('$e'); }
  }

  Widget content() => FutureBuilder<List<Map<String, dynamic>>>(
    future: data, builder: (context, snapshot) {
      if (snapshot.hasError) { return Column(children: [
        Text('${snapshot.error}'),
        TextButton(onPressed: refresh, child: Text(tr('Ponów', 'Retry'))),
      ]); }
      if (!snapshot.hasData) { return const Center(child: CircularProgressIndicator()); }
      if (snapshot.data!.isEmpty) { return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(group == null
          ? tr('Nie ma jeszcze grup. Utwórz pierwszą!', 'No groups yet. Create the first one!')
          : tr('Nie ma jeszcze postów. Rozpocznij rozmowę!', 'No posts yet. Start a conversation!'))); }
      return Column(children: [
        for (final item in snapshot.data!)
          group == null ? groupTile(item) : postTile(item),
      ]);
    });

  Widget groupTile(Map<String, dynamic> item) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.all(14),
      leading: const Icon(Icons.forum_outlined, color: AgcLuxury.champagne),
      title: Text(item['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 5),
        Text(item['description'] as String),
        const SizedBox(height: 7),
        Text('${item['owner_label']}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ]),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => setState(() {
        group = item;
        data = loadPosts(item['id'] as String);
      }),
    ));

  Widget postTile(Map<String, dynamic> item) => Card(
    child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item['author_label'] as String,
          style: const TextStyle(color: AgcLuxury.champagne, fontSize: 12)),
        const SizedBox(height: 10),
        SelectableText(item['body'] as String),
        const SizedBox(height: 10),
        Wrap(spacing: 5, runSpacing: 5, children: [
          TextButton.icon(onPressed: () => toggleLike(item),
            icon: Icon(item['liked'] == true ? Icons.favorite : Icons.favorite_border),
            label: Text('${item['likes']}')),
          TextButton.icon(onPressed: () async {
            await showModalBottomSheet<void>(
              context: context, isScrollControlled: true, showDragHandle: true,
              builder: (_) => GenesisComments(postId: item['id'] as String));
            refresh();
          }, icon: const Icon(Icons.chat_bubble_outline),
            label: Text('${item['comments']}')),
          TextButton.icon(onPressed: () => report(item),
            icon: const Icon(Icons.flag_outlined),
            label: Text(tr('Zgłoś', 'Report'))),
          if (item['author_id'] == AgcBackend.user?.id)
            IconButton(onPressed: () => removePost(item),
              icon: const Icon(Icons.delete_outline),
              tooltip: tr('Usuń post', 'Delete post')),
        ]),
      ])));

  @override
  Widget build(BuildContext context) => Center(child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 900),
    child: ListView(padding: const EdgeInsets.all(14), children: [
      if (group != null)
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(
          onPressed: () => setState(() { group = null; data = loadGroups(); }),
          icon: const Icon(Icons.arrow_back), label: Text(tr('Wszystkie grupy', 'All groups')))),
      Text(group == null ? tr('DYSKUSJE O AI', 'AI DISCUSSIONS') : group!['name'] as String,
        style: const TextStyle(color: AgcLuxury.champagne, fontSize: 23,
          fontWeight: FontWeight.bold)),
      const SizedBox(height: 7),
      Text(group == null
        ? tr('Twórz grupy, publikuj posty, komentuj i przygotujmy razem '
             'pytania do przyszłej AI.', 'Create groups, publish posts, comment and '
             'prepare questions for future AI together.')
        : group!['description'] as String),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.icon(onPressed: group == null ? createGroup : createPost,
          icon: const Icon(Icons.add),
          label: Text(group == null ? tr('Nowa grupa', 'New group') : tr('Napisz post', 'Write a post'))),
        OutlinedButton.icon(onPressed: refresh, icon: const Icon(Icons.refresh),
          label: Text(tr('Odśwież', 'Refresh'))),
      ]),
      const SizedBox(height: 12),
      content(),
      const SizedBox(height: 16),
      Text(tr('Szanuj innych, chroń prywatność i odróżniaj hipotezy od faktów. '
        'Nie twierdzimy, że AI już się z nami skontaktowała.',
        'Respect others, protect privacy and distinguish speculation from facts. '
        'We do not claim that AI has contacted us.'),
        style: const TextStyle(fontSize: 12, color: Colors.white70)),
    ]),
  ));
}

class GenesisComments extends StatefulWidget {
  const GenesisComments({super.key, required this.postId});
  final String postId;
  @override
  State<GenesisComments> createState() => _GenesisCommentsState();
}

class _GenesisCommentsState extends State<GenesisComments> {
  final input = TextEditingController();
  late Future<List<Map<String, dynamic>>> rows;
  bool busy = false;

  @override
  void initState() { super.initState(); refresh(); }
  void refresh() => setState(() { rows = fetch(); });
  Future<List<Map<String, dynamic>>> fetch() async {
    final result = await AgcBackend.client.from('agc_post_comments')
      .select('id,author_id,author_label,body,created_at')
      .eq('post_id', widget.postId).order('created_at').limit(100);
    return List<Map<String, dynamic>>.from(result);
  }

  Future<void> send() async {
    if (busy || input.text.trim().length < 2) return;
    setState(() => busy = true);
    try {
      await AgcBackend.client.from('agc_post_comments').insert({
        'post_id': widget.postId, 'author_id': AgcBackend.user!.id,
        'body': input.text.trim(),
      });
      input.clear();
      refresh();
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$e'))); }
    } finally { if (mounted) { setState(() => busy = false); } }
  }

  Future<void> remove(String id) async {
    try {
      await AgcBackend.client.from('agc_post_comments').delete().eq('id', id);
      refresh();
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$e'))); }
    }
  }

  @override
  void dispose() { input.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => SafeArea(child: Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(height: MediaQuery.sizeOf(context).height * .7,
      child: Column(children: [
        Padding(padding: const EdgeInsets.all(12),
          child: Text(tr('KOMENTARZE', 'COMMENTS'),
            style: const TextStyle(color: AgcLuxury.champagne, fontWeight: FontWeight.bold))),
        Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
          future: rows, builder: (context, snapshot) {
            if (snapshot.hasError) { return Center(child: Text('${snapshot.error}')); }
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            if (snapshot.data!.isEmpty) { return Center(child: Text(
              tr('Bądź pierwszą osobą, która odpowie.', 'Be the first to reply.'))); }
            return ListView.builder(itemCount: snapshot.data!.length,
              itemBuilder: (context, i) {
                final row = snapshot.data![i];
                return Card(child: ListTile(
                  title: Text(row['author_label'] as String,
                    style: const TextStyle(color: AgcLuxury.champagne, fontSize: 12)),
                  subtitle: SelectableText(row['body'] as String),
                  trailing: row['author_id'] == AgcBackend.user?.id
                    ? IconButton(onPressed: () => remove(row['id'] as String),
                      icon: const Icon(Icons.delete_outline))
                    : null,
                ));
              });
          })),
        Padding(padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(child: TextField(controller: input, maxLength: 1000,
              minLines: 1, maxLines: 2,
              decoration: InputDecoration(counterText: '',
                hintText: tr('Napisz komentarz…', 'Write a comment…')))),
            IconButton(onPressed: busy ? null : send,
              icon: const Icon(Icons.send, color: AgcLuxury.champagne)),
          ])),
      ]),
    ),
  ));
}
