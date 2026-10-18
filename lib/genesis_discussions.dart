import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'agc_backend.dart';
import 'agc_luxury_theme.dart';
import 'genesis_language.dart';
import 'genesis_social.dart';
import 'genesis_social_profile.dart';

String tr(String pl, String en) => GenesisLanguage.copy(pl, en);

/// Only HTTPS links are accepted; no embedded arbitrary HTML.
Uri? genesisExternalUrl(String? raw) {
  final uri = Uri.tryParse(raw?.trim() ?? '');
  if (uri == null || uri.scheme != 'https' || !uri.hasAuthority ||
      uri.host.isEmpty || uri.userInfo.isNotEmpty) {
    return null;
  }
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
  if (id == null || !RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(id)) return null;
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
  const GenesisDiscussions({super.key, this.initialGroupId});
  final String? initialGroupId;
  @override
  State<GenesisDiscussions> createState() => _GenesisDiscussionsState();
}

class _GenesisDiscussionsState extends State<GenesisDiscussions> {
  Map<String, dynamic>? group;
  String groupQuery = '';
  String groupFilter = 'all';
  bool showMemberSearch = false;
  final Set<String> leavingGroups = <String>{};
  late Future<List<Map<String, dynamic>>> data;

  @override
  void initState() {
    super.initState();
    GenesisLanguage.selected.addListener(onLanguageChanged);
    data = loadGroups();
    if (widget.initialGroupId != null) {
      openInitialGroup(widget.initialGroupId!);
    }
  }

  @override
  void didUpdateWidget(covariant GenesisDiscussions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialGroupId != null &&
        widget.initialGroupId != oldWidget.initialGroupId) {
      openInitialGroup(widget.initialGroupId!);
    }
  }

  Future<void> openInitialGroup(String id) async {
    try {
      final groups = await loadGroups();
      if (!mounted || widget.initialGroupId != id) return;
      for (final item in groups) {
        if (item['id'] == id) {
          openGroup(item);
          return;
        }
      }
      message(tr('Ta grupa jest niedostępna.', 'This group is unavailable.'));
    } catch (e) {
      message(tr('Nie udało się otworzyć grupy.', 'Could not open the group.'));
    }
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
        .select('id,name,description,owner_id,owner_label,visibility,official,created_at,cover_url')
        .order('created_at', ascending: false).limit(100);
    final groups = List<Map<String, dynamic>>.from(rows);
    if (groups.isEmpty) {
      return groups;
    }
    final ids = groups.map((g) => g['id'] as String).toList();
    final userId = AgcBackend.user?.id;
    final memberships = userId == null
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await AgcBackend.client.from('agc_group_members')
              .select('group_id,status')
              .eq('member_id', userId)
              .inFilter('group_id', ids));
    final posts = List<Map<String, dynamic>>.from(
      await AgcBackend.client.from('agc_group_posts')
        .select('id,group_id,body,author_id,author_label,created_at,image_path,video_url,link_url')
        .inFilter('group_id', ids)
        .order('created_at', ascending: false)
        .limit(1000));
    final postIds = posts.map((p) => p['id'] as String).toList();
    final comments = postIds.isEmpty
      ? <Map<String, dynamic>>[]
      : List<Map<String, dynamic>>.from(
          await AgcBackend.client.from('agc_post_comments')
            .select('id,post_id,body,author_id,author_label,created_at')
            .inFilter('post_id', postIds)
            .order('created_at', ascending: false)
            .limit(1000));
    final commentIds = comments.map((c) => c['id'] as String).toList();
    final commentLikes = commentIds.isEmpty
      ? <Map<String, dynamic>>[]
      : List<Map<String, dynamic>>.from(
          await AgcBackend.client.from('agc_comment_likes')
            .select('comment_id,member_id')
            .inFilter('comment_id', commentIds)
            .limit(1000));
    final commentLikeCounts = <String, int>{};
    final myCommentLikes = <String>{};
    for (final like in commentLikes) {
      final id = like['comment_id'] as String;
      commentLikeCounts[id] = (commentLikeCounts[id] ?? 0) + 1;
      if (like['member_id'] == userId) {
        myCommentLikes.add(id);
      }
    }
    for (final comment in comments) {
      final id = comment['id'] as String;
      comment['likes'] = commentLikeCounts[id] ?? 0;
      comment['liked'] = myCommentLikes.contains(id);
    }
    final likes = postIds.isEmpty
      ? <Map<String, dynamic>>[]
      : List<Map<String, dynamic>>.from(
          await AgcBackend.client.from('agc_post_likes')
            .select('post_id,member_id')
            .inFilter('post_id', postIds)
            .limit(1000));
    final likeCounts = <String, int>{};
    final likedPosts = <String>{};
    for (final like in likes) {
      final id = like['post_id'] as String;
      likeCounts[id] = (likeCounts[id] ?? 0) + 1;
      if (like['member_id'] == userId) {
        likedPosts.add(id);
      }
    }
    final memberStatus = <String, String>{
      for (final membership in memberships)
        membership['group_id'] as String: membership['status'] as String,
    };
    final postCounts = <String, int>{};
    final commentCounts = <String, int>{};
    final postCommentCounts = <String, int>{};
    final lastActivity = <String, DateTime>{};
    final latestPost = <String, Map<String, dynamic>>{};
    final latestComment = <String, Map<String, dynamic>>{};
    final postGroupIds = <String, String>{};
    for (final post in posts) {
      final id = post['group_id'] as String;
      postGroupIds[post['id'] as String] = id;
      postCounts[id] = (postCounts[id] ?? 0) + 1;
      latestPost.putIfAbsent(id, () => post);
      final date = DateTime.tryParse(post['created_at'] as String? ?? '');
      if (date != null && !lastActivity.containsKey(id)) {
        lastActivity[id] = date;
      }
    }
    for (final comment in comments) {
      final id = postGroupIds[comment['post_id']];
      if (id == null) {
        continue;
      }
      latestComment.putIfAbsent(id, () => comment);
      commentCounts[id] = (commentCounts[id] ?? 0) + 1;
      final postId = comment['post_id'] as String;
      postCommentCounts[postId] = (postCommentCounts[postId] ?? 0) + 1;
      final date = DateTime.tryParse(comment['created_at'] as String? ?? '');
      if (date != null &&
          (lastActivity[id] == null || date.isAfter(lastActivity[id]!))) {
        lastActivity[id] = date;
      }
    }
    for (final item in groups) {
      final id = item['id'] as String;
      item['my_status'] = memberStatus[id];
      item['post_count'] = postCounts[id] ?? 0;
      item['activity_count'] = (postCounts[id] ?? 0) + (commentCounts[id] ?? 0);
      item['last_activity'] = lastActivity[id];
      final canRead = item['visibility'] == 'public' ||
        item['owner_id'] == userId || memberStatus[id] == 'active';
      final preview = latestPost[id];
      if (preview != null) {
        final postId = preview['id'] as String;
        preview['likes'] = likeCounts[postId] ?? 0;
        preview['liked'] = likedPosts.contains(postId);
        preview['comments'] = postCommentCounts[postId] ?? 0;
        preview['visibility'] = item['visibility'];
        preview['group_name'] = item['name'];
      }
      item['latest_post'] = canRead ? preview : null;
      item['latest_comment'] = canRead ? latestComment[id] : null;
      item['can_preview'] = canRead;
    }
    return groups;
  }

  Future<List<Map<String, dynamic>>> loadPrompts(String id) async {
    final rows = await AgcBackend.client.from('agc_group_prompts')
      .select('body').eq('group_id', id).limit(5);
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
      p['visibility'] = group?['visibility'] ?? 'public';
      p['group_name'] = group?['name'] ?? '';
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
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    String visibility = 'public';
    String? validation;
    final draft = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(tr('Nowa grupa', 'New group')),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    key: const Key('new_group_name'),
                    controller: nameController,
                    maxLength: 64,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: tr('Nazwa grupy', 'Group name'),
                      hintText: tr('Np. Pytania do przyszłej AI',
                        'E.g. Questions for future AI'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('new_group_description'),
                    controller: descriptionController,
                    maxLength: 500,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: tr('Opis grupy', 'Group description'),
                      hintText: tr('Jaki jest temat rozmów?',
                        'What is the discussion about?'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(tr('Widoczność grupy', 'Group visibility'),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 10, runSpacing: 8, children: [
                    ChoiceChip(
                      key: const Key('new_group_public'),
                      label: Text(tr('🌐 Publiczna', '🌐 Public')),
                      selected: visibility == 'public',
                      onSelected: (_) =>
                        setDialogState(() => visibility = 'public'),
                    ),
                    ChoiceChip(
                      key: const Key('new_group_private'),
                      label: Text(tr('🔒 Prywatna', '🔒 Private')),
                      selected: visibility == 'private',
                      onSelected: (_) =>
                        setDialogState(() => visibility = 'private'),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    visibility == 'public'
                      ? tr('Posty są widoczne dla społeczności i można je udostępniać.',
                          'Posts are visible to the community and can be shared.')
                      : tr('Posty widzą tylko członkowie. Dołączenie wymaga zaproszenia; '
                           'udostępnianie publiczne jest wyłączone.',
                          'Only members can see posts. Joining requires an invitation; '
                           'public sharing is disabled.'),
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  if (validation != null) ...[
                    const SizedBox(height: 10),
                    Text(validation!,
                      style: const TextStyle(color: Colors.redAccent)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('Anuluj', 'Cancel')),
            ),
            FilledButton.icon(
              key: const Key('new_group_submit'),
              icon: const Icon(Icons.group_add_outlined),
              label: Text(tr('Utwórz grupę', 'Create group')),
              onPressed: () {
                final name = nameController.text.trim();
                final description = descriptionController.text.trim();
                if (name.length < 4 || description.length < 10) {
                  setDialogState(() => validation = tr(
                    'Nazwa musi mieć min. 4 znaki, a opis min. 10.',
                    'Name must have at least 4 characters and description at least 10.'));
                  return;
                }
                Navigator.pop(ctx, {
                  'name': name,
                  'description': description,
                  'visibility': visibility,
                });
              },
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    descriptionController.dispose();
    if (draft == null || !mounted) return;
    try {
      await AgcBackend.client.from('agc_groups').insert({
        'owner_id': AgcBackend.user!.id,
        'name': draft['name'],
        'description': draft['description'],
        'visibility': draft['visibility'],
      });
      refresh();
      message(tr('Grupa została utworzona.', 'Group created.'));
    } catch (e) {
      message('${tr('Nie udało się utworzyć grupy', 'Could not create group')}: $e');
    }
  }

  Future<Map<String, dynamic>?> myMembership() async {
    if (group == null) return null;
    return await AgcBackend.client.from('agc_group_members')
      .select('status').eq('group_id', group!['id'])
      .eq('member_id', AgcBackend.user!.id).maybeSingle();
  }

  Future<void> joinGroup() async {
    try {
      await AgcBackend.client.from('agc_group_members').insert({
        'group_id': group!['id'], 'member_id': AgcBackend.user!.id,
        'status': 'active',
      });
      refresh();
    } catch (e) { message('$e'); }
  }

  Future<void> acceptInvite() async {
    try {
      await AgcBackend.client.from('agc_group_members').update({'status':'active'})
        .eq('group_id', group!['id']).eq('member_id', AgcBackend.user!.id)
        .eq('status','invited');
      refresh();
    } catch (e) { message('$e'); }
  }

  Future<void> leaveGroup(Map<String, dynamic> target) async {
    final id = target['id'] as String;
    if (leavingGroups.contains(id) ||
        target['owner_id'] == AgcBackend.user?.id ||
        target['my_status'] != 'active') {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Opuścić grupę?', 'Leave this group?')),
        content: Text(tr(
          'Czy chcesz opuścić grupę „${target['name']}”? '
          'Aby ponownie dołączyć do prywatnej grupy, potrzebujesz zaproszenia.',
          'Leave “${target['name']}”? '
          'You will need an invitation to rejoin a private group.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Anuluj', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('Opuść grupę', 'Leave group'))),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => leavingGroups.add(id));
    try {
      final removed = await AgcBackend.client.from('agc_group_members')
        .delete().eq('group_id', id)
        .eq('member_id', AgcBackend.user!.id)
        .select('group_id');
      if (removed.isEmpty) {
        message(tr('Nie udało się opuścić grupy.',
          'Could not leave the group.'));
        return;
      }
      if (!mounted) return;
      setState(() {
        if (group?['id'] == id) {
          group = null;
        }
        data = loadGroups();
      });
      message(tr('Opuszczono grupę.', 'You left the group.'));
    } catch (e) {
      message('${tr('Nie udało się opuścić grupy', 'Could not leave group')}: $e');
    } finally {
      if (mounted) setState(() => leavingGroups.remove(id));
    }
  }

  bool deletingGroup = false;

  Future<void> deleteGroup(Map<String, dynamic> target) async {
    if (deletingGroup ||
        target['owner_id'] != AgcBackend.user?.id ||
        target['official'] == true) {
      return;
    }
    final name = target['name'] as String;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Usunąć grupę?', 'Delete group?')),
        content: Text(tr(
          'Czy na pewno chcesz trwale usunąć grupę „$name”? '
          'Wszystkie posty, komentarze, polubienia i członkostwa '
          'tej grupy zostaną usunięte. Tej operacji nie można cofnąć.',
          'Are you sure you want to permanently delete “$name”? '
          'All posts, comments, likes and memberships in this group '
          'will be deleted. This action cannot be undone.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Anuluj', 'Cancel')),
          ),
          FilledButton.icon(
            key: const Key('confirm_delete_group'),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_forever_outlined),
            label: Text(tr('Usuń na zawsze', 'Delete permanently')),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => deletingGroup = true);
    try {
      final deleted = await AgcBackend.client.from('agc_groups')
        .delete()
        .eq('id', target['id'])
        .eq('owner_id', AgcBackend.user!.id)
        .eq('official', false)
        .select('id');
      if (deleted.isEmpty) {
        message(tr('Nie udało się usunąć grupy. Sprawdź uprawnienia.',
          'Could not delete the group. Check your permissions.'));
        return;
      }
      if (!mounted) return;
      setState(() {
        if (group?['id'] == target['id']) {
          group = null;
        }
        data = loadGroups();
      });
      message(tr('Grupa została usunięta.', 'Group deleted.'));
    } catch (e) {
      message('${tr('Błąd usuwania grupy', 'Could not delete group')}: $e');
    } finally {
      if (mounted) setState(() => deletingGroup = false);
    }
  }

  Future<void> inviteMember() async {
    final handle = await compose(
      tr('Zaproś użytkownika', 'Invite a member'),
      tr('Podaj dokładny publiczny nick użytkownika',
        'Enter the member’s exact public nickname'), 64);
    if (handle == null || handle.trim().isEmpty) return;
    try {
      final success = await AgcBackend.client.rpc('agc_invite_group_member',
        params: {'p_group_id': group!['id'], 'p_handle': handle.trim()});
      message(success == true
        ? tr('Zaproszenie wysłane.', 'Invitation sent.')
        : tr('Nie znaleziono użytkownika z publicznym nickiem.',
          'No member with that public nickname was found.'));
    } catch (e) { message('$e'); }
  }

  Widget threadComposer() => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const CircleAvatar(radius: 19, child: Icon(Icons.person_outline)),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton(
            key: const Key('start_group_thread'),
            onPressed: createPost,
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            ),
            child: Text(tr('Co słychać? Napisz post…',
              'What’s happening? Write a post…')),
          )),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          TextButton.icon(
            onPressed: createPost,
            icon: const Icon(Icons.edit_note_outlined),
            label: Text(tr('Napisz post', 'Write post')),
          ),
          TextButton.icon(
            onPressed: createPost,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(tr('Zdjęcie / link', 'Photo / link')),
          ),
        ]),
      ]),
    ),
  );

  Widget membershipActions() {
    if (group == null) return const SizedBox.shrink();
    final owner = group!['owner_id'] == AgcBackend.user?.id;
    if (owner) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        threadComposer(),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
            onPressed: inviteMember,
            icon: const Icon(Icons.person_add_alt_1),
            label: Text(tr('Zaproś po nicku', 'Invite by nickname')),
          ),
          if (group!['official'] != true)
            OutlinedButton.icon(
              key: const Key('delete_owned_group'),
              onPressed: deletingGroup ? null : () => deleteGroup(group!),
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              label: Text(tr('Usuń grupę', 'Delete group')),
            ),
        ]),
      ]);
    }
    return FutureBuilder<Map<String, dynamic>?>(
      future: myMembership(),
      builder: (context, snapshot) {
        if (!snapshot.hasData && snapshot.connectionState != ConnectionState.done) {
          return const LinearProgressIndicator();
        }
        final status = snapshot.data?['status'];
        if (status == 'invited') {
          return FilledButton.icon(
            onPressed: acceptInvite,
            icon: const Icon(Icons.mark_email_read_outlined),
            label: Text(tr('Przyjmij zaproszenie', 'Accept invitation')),
          );
        }
        if (status == 'active') {
          return threadComposer();
        }
        if (group!['visibility'] == 'public') {
          return FilledButton.icon(
            onPressed: joinGroup,
            icon: const Icon(Icons.group_add_outlined),
            label: Text(tr('Dołącz, aby rozpocząć dyskusję', 'Join to start a discussion')),
          );
        }
        return Text(tr('Grupa prywatna — dostęp tylko na zaproszenie.',
          'Private group — invitation required.'));
      },
    );
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
          title: Text(tr('Utwórz post', 'Create post')),
          content: SizedBox(width: 480, child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Align(alignment: Alignment.centerLeft,
                child: Text((group?['name'] as String? ?? '') +
                    (group?['visibility'] == 'private' ? ' · 🔒' : ' · 🌐'),
                  style: const TextStyle(fontSize: 12, color: Colors.white70))),
              const SizedBox(height: 12),
              TextField(controller: body, maxLength: 3000, minLines: 3, maxLines: 6,
                decoration: InputDecoration(labelText: tr('Treść posta', 'Post content'),
                  hintText: tr('Co chcesz przekazać społeczności?',
                    'What would you like to share?'))),
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
                        if (!ctx.mounted) return;
                        if (picked != null) {
                          setDialogState(() { photo = picked; validation = null; });
                        }
                      } catch (_) {
                        if (!ctx.mounted) return;
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
              Text(group?['visibility'] == 'private'
                  ? tr('Zdjęcie: JPG, PNG, WebP lub GIF, maks. 5 MB. '
                      'Widoczne tylko dla członków grupy.',
                      'Photo: JPG, PNG, WebP or GIF, max 5 MB. '
                      'Visible to group members only.')
                  : tr('Zdjęcie: JPG, PNG, WebP lub GIF, maks. 5 MB. '
                      'Publiczne zdjęcia są dostępne przez link.',
                      'Photo: JPG, PNG, WebP or GIF, max 5 MB. '
                      'Public photos can be accessed by link.'),
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
            }, child: Text(tr('Opublikuj', 'Post'))),
          ],
        ),
      ),
    );
    body.dispose();
    link.dispose();
    video.dispose();
    return draft;
  }

  bool postingThread = false;

  Future<void> createPost() async {
    if (postingThread) return;
    final draft = await composePost();
    if (draft == null || !mounted) return;
    setState(() => postingThread = true);
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
        await AgcBackend.client.storage.from(
          group?['visibility'] == 'private' ? 'agc-private-forum-images' : 'agc-forum-images'
        ).uploadBinary(
          imagePath, bytes, fileOptions: FileOptions(contentType: mime));
      }
      await AgcBackend.client.from('agc_group_posts').insert({
        'group_id': group!['id'], 'author_id': AgcBackend.user!.id,
        'body': draft.body, 'link_url': draft.link,
        'video_url': draft.video, 'image_path': imagePath,
      });
      refresh();
      message(tr('Post opublikowany.', 'Post published.'));
    } catch (e) {
      if (imagePath != null) {
        try {
          await AgcBackend.client.storage.from(
            group?['visibility'] == 'private' ? 'agc-private-forum-images' : 'agc-forum-images'
          ).remove([imagePath]);
        } catch (_) { /* Upload cleanup is best-effort. */ }
      }
      message('${tr('Nie udało się opublikować', 'Could not publish')}: $e');
    } finally {
      if (mounted) setState(() => postingThread = false);
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
        if (post['visibility'] == 'private')
          FutureBuilder<String>(
            future: AgcBackend.client.storage.from('agc-private-forum-images')
              .createSignedUrl(imagePath, 600),
            builder: (context, snapshot) => snapshot.hasData
              ? Image.network(snapshot.data!, height: 280,
                  width: double.infinity, fit: BoxFit.contain)
              : const SizedBox(height: 40, child: Center(
                  child: CircularProgressIndicator())),
          )
        else
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
      final imagePath = post['image_path'] as String?;
      if (imagePath != null) {
        try {
          await AgcBackend.client.storage.from(
            group?['visibility'] == 'private' ? 'agc-private-forum-images' : 'agc-forum-images'
          ).remove([imagePath]);
        } catch (_) { /* Best-effort media cleanup. */ }
      }
      refresh();
    } catch (e) { message('$e'); }
  }

  List<Map<String, dynamic>> filteredGroups(List<Map<String, dynamic>> rows) {
    final currentId = AgcBackend.user?.id;
    final items = rows.where((item) {
      final matchesSearch = groupQuery.isEmpty ||
        (item['name'] as String).toLowerCase().contains(groupQuery) ||
        (item['description'] as String).toLowerCase().contains(groupQuery);
      if (!matchesSearch) {
        return false;
      }
      return switch (groupFilter) {
        'public' => item['visibility'] == 'public',
        'private' => item['visibility'] == 'private',
        'mine' => item['owner_id'] == currentId ||
          item['my_status'] == 'active',
        _ => true,
      };
    }).toList();
    if (groupFilter == 'active') {
      items.sort((a, b) {
        final byActivity = (b['activity_count'] as int)
          .compareTo(a['activity_count'] as int);
        if (byActivity != 0) {
          return byActivity;
        }
        final aDate = a['last_activity'] as DateTime? ??
          DateTime.tryParse(a['created_at'] as String? ?? '');
        final bDate = b['last_activity'] as DateTime? ??
          DateTime.tryParse(b['created_at'] as String? ?? '');
        return (bDate ?? DateTime(1970))
          .compareTo(aDate ?? DateTime(1970));
      });
    } else if (groupFilter == 'newest') {
      items.sort((a, b) =>
        (b['created_at'] as String).compareTo(a['created_at'] as String));
    } else {
      items.sort((a, b) => (a['name'] as String)
        .toLowerCase().compareTo((b['name'] as String).toLowerCase()));
    }
    return items;
  }

  Widget groupFilters() => Wrap(
    spacing: 7, runSpacing: 6, children: [
      for (final filter in <String>[
        'all', 'public', 'private', 'mine', 'newest', 'active'
      ])
        ChoiceChip(
          key: Key('group_filter_$filter'),
          selected: groupFilter == filter,
          label: Text(switch (filter) {
            'public' => tr('🌐 Publiczne', '🌐 Public'),
            'private' => tr('🔒 Prywatne', '🔒 Private'),
            'mine' => tr('👤 Moje grupy', '👤 My groups'),
            'newest' => tr('🕒 Najnowsze', '🕒 Newest'),
            'active' => tr('🔥 Najaktywniejsze', '🔥 Most active'),
            _ => tr('Wszystkie', 'All'),
          }),
          onSelected: (_) => setState(() => groupFilter = filter),
        ),
    ],
  );

  Widget content() => FutureBuilder<List<Map<String, dynamic>>>(
    future: data, builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Column(children: [
          Text('${snapshot.error}'),
          TextButton(onPressed: refresh, child: Text(tr('Ponów', 'Retry'))),
        ]);
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.data!.isEmpty) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Text(group == null
            ? tr('Nie ma jeszcze grup. Utwórz pierwszą!',
                'No groups yet. Create the first one!')
            : tr('Nie ma jeszcze postów. Rozpocznij rozmowę!',
                'No posts yet. Start a conversation!')),
        );
      }
      final items = group == null
        ? filteredGroups(snapshot.data!)
        : snapshot.data!;
      if (items.isEmpty) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Text(groupFilter == 'mine' && groupQuery.isEmpty
            ? tr('Nie należysz jeszcze do żadnej grupy. '
                'Dołącz do publicznej lub utwórz własną.',
                'You have not joined any groups yet. '
                'Join a public group or create your own.')
            : tr('Nie znaleziono pasujących grup.',
                'No matching groups found.')),
        );
      }
      return Column(children: [
        for (final item in items)
          group == null ? groupTile(item) : postTile(item),
      ]);
    });

  void openGroup(Map<String, dynamic> item) => setState(() {
    group = item;
    data = loadPosts(item['id'] as String);
  });

  Widget groupPreview({
    required IconData icon,
    required String heading,
    required Map<String, dynamic>? entry,
    bool isComment = false,
  }) {
    if (entry == null) return const SizedBox.shrink();
    final body = (entry['body'] as String? ?? '').replaceAll(
      RegExp(r'\s+'), ' ').trim();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: isComment
          ? Colors.white.withValues(alpha: 0.035)
          : AgcLuxury.champagne.withValues(alpha: 0.065),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isComment
          ? Colors.white.withValues(alpha: 0.12)
          : AgcLuxury.champagne.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 15, color: isComment
            ? Colors.white70 : AgcLuxury.champagne),
          const SizedBox(width: 7),
          Text(heading.toUpperCase(),
            style: TextStyle(fontSize: 10,
              color: isComment ? Colors.white70 : AgcLuxury.champagne,
              letterSpacing: 0.8, fontWeight: FontWeight.bold)),
          const Spacer(),
          Flexible(child: Text(postAge(entry['created_at']),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: Colors.white54))),
        ]),
        const SizedBox(height: 7),
        Align(alignment: Alignment.centerLeft,
          child: InkWell(
            onTap: () => genesisOpenMemberProfile(context,
              entry['author_id'] as String?,
              entry['author_label'] as String? ?? tr('Użytkownik', 'Member')),
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(child: Text(entry['author_label'] as String? ??
                  tr('Użytkownik', 'Member'),
                  style: const TextStyle(fontSize: 12,
                    color: AgcLuxury.champagne, fontWeight: FontWeight.w600))),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 15,
                  color: AgcLuxury.champagne),
              ])))),
        const SizedBox(height: 5),
        Text(body, maxLines: isComment ? 3 : 4,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: isComment ? 12.5 : 14,
            fontWeight: isComment ? FontWeight.normal : FontWeight.w500,
            height: 1.35)),
      ]),
    );
  }

  Future<void> openPreviewComments(Map<String, dynamic> post) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => GenesisComments(postId: post['id'] as String),
    );
    if (mounted) refresh();
  }

  Future<void> toggleCommentLike(Map<String, dynamic> comment) async {
    final userId = AgcBackend.user?.id;
    if (userId == null) return;
    try {
      if (comment['liked'] == true) {
        await AgcBackend.client.from('agc_comment_likes')
          .delete().eq('comment_id', comment['id'])
          .eq('member_id', userId);
      } else {
        await AgcBackend.client.from('agc_comment_likes').insert({
          'comment_id': comment['id'], 'member_id': userId,
        });
      }
      refresh();
    } catch (e) {
      message(tr('Nie udało się zapisać polubienia.',
        'Could not save the like.'));
    }
  }

  Widget groupCommentActions(Map<String, dynamic> item) {
    final comment = item['latest_comment'] as Map<String, dynamic>?;
    if (comment == null) return const SizedBox.shrink();
    final post = <String, dynamic>{
      'id': comment['post_id'],
    };
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Wrap(spacing: 2, children: [
        TextButton.icon(
          onPressed: () => toggleCommentLike(comment),
          icon: Icon(comment['liked'] == true
            ? Icons.favorite : Icons.favorite_border,
            size: 16, color: comment['liked'] == true
              ? Colors.redAccent : null),
          label: Text("${tr('Polub', 'Like')} · ${comment['likes']}"),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8)),
        ),
        TextButton.icon(
          onPressed: () => openPreviewComments(post),
          icon: const Icon(Icons.reply_outlined, size: 16),
          label: Text(tr('Odpowiedz', 'Reply')),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8)),
        ),
      ]),
    );
  }

  Widget groupPreviewActions(Map<String, dynamic> item) {
    final post = item['latest_post'] as Map<String, dynamic>?;
    if (post == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Wrap(
        spacing: 2, runSpacing: 0,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TextButton.icon(
            onPressed: () => toggleLike(post),
            icon: Icon(post['liked'] == true
              ? Icons.favorite : Icons.favorite_border,
              size: 17, color: post['liked'] == true
                ? Colors.redAccent : null),
            label: Text("${tr('Polub', 'Like')} · ${post['likes']}"),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8)),
          ),
          TextButton.icon(
            onPressed: () => openPreviewComments(post),
            icon: const Icon(Icons.mode_comment_outlined, size: 17),
            label: Text("${tr('Komentuj', 'Comment')} · ${post['comments']}"),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8)),
          ),
          if (item['visibility'] == 'public')
            TextButton.icon(
              onPressed: () => genesisSharePost(context, post),
              icon: const Icon(Icons.share_outlined, size: 17),
              label: Text(tr('Udostępnij', 'Share')),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8)),
            ),
        ],
      ),
    );
  }

  Widget groupTile(Map<String, dynamic> item) {
    final isOwner = item['owner_id'] == AgcBackend.user?.id;
    final canLeave = !isOwner && item['my_status'] == 'active';
    final canPreview = item['can_preview'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => openGroup(item),
              borderRadius: BorderRadius.circular(8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(padding: const EdgeInsets.only(top: 2),
                    child: Icon(item['visibility'] == 'private'
                      ? Icons.lock_outline : Icons.public,
                      color: AgcLuxury.champagne, size: 22)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tr('GRUPA DYSKUSYJNA', 'DISCUSSION GROUP'),
                        style: const TextStyle(
                          color: AgcLuxury.champagne, fontSize: 10,
                          letterSpacing: 1.1, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(item['name'] as String,
                        style: const TextStyle(
                          color: AgcLuxury.champagne,
                          fontWeight: FontWeight.bold, fontSize: 20,
                          height: 1.2)),
                      const SizedBox(height: 7),
                      Text(item['description'] as String,
                        maxLines: 3, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13, color: Colors.white70, height: 1.35)),
                      const SizedBox(height: 8),
                      Text(
                        "${item['visibility'] == 'private' ? tr('Prywatna', 'Private') : tr('Publiczna', 'Public')} · ${tr('Posty', 'Posts')}: ${item['post_count']}",
                        style: const TextStyle(fontSize: 12,
                          color: Colors.white70)),
                    ],
                  )),
                  if (isOwner && item['official'] != true)
                    IconButton(
                      key: Key('delete_group_${item['id']}'),
                      tooltip: tr('Usuń swoją grupę', 'Delete your group'),
                      onPressed: deletingGroup ? null : () => deleteGroup(item),
                      icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent, size: 20),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
            if (!canPreview)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(tr(
                  '🔒 Posty i komentarze widoczne tylko dla członków.',
                  '🔒 Posts and comments are visible to members only.'),
                  style: const TextStyle(fontSize: 12,
                    color: Colors.white70)),
              )
            else ...[
              groupPreview(
                icon: Icons.article_outlined,
                heading: tr('Ostatni post', 'Latest post'),
                entry: item['latest_post'] as Map<String, dynamic>?),
              groupPreviewActions(item),
              groupPreview(
                icon: Icons.mode_comment_outlined,
                heading: tr('Ostatni komentarz', 'Latest comment'),
                entry: item['latest_comment'] as Map<String, dynamic>?,
                isComment: true),
              groupCommentActions(item),
              if (item['latest_post'] == null)
                Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Text(tr('Jeszcze nie ma postów. Zacznij rozmowę!',
                    'No posts yet. Start a conversation!'),
                    style: const TextStyle(fontSize: 12,
                      color: Colors.white70))),
            ],
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  key: Key('view_group_${item['id']}'),
                  onPressed: () => openGroup(item),
                  icon: const Icon(Icons.forum_outlined, size: 16),
                  label: Text(tr('Zobacz dyskusję', 'View discussion')),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11, vertical: 6)),
                ),
              )),
              if (item['visibility'] == 'public')
                IconButton(
                  tooltip: tr('Udostępnij grupę', 'Share group'),
                  onPressed: () => genesisShareGroup(context, item),
                  icon: const Icon(Icons.share_outlined, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
              if (groupFilter == 'mine' && canLeave)
                TextButton(
                  key: Key('leave_group_${item['id']}'),
                  onPressed: leavingGroups.contains(item['id'])
                    ? null : () => leaveGroup(item),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 3),
                    foregroundColor: Colors.white54,
                    textStyle: const TextStyle(fontSize: 11)),
                  child: Text(tr('Opuść', 'Leave')),
                ),
            ]),
          ],
        ),
      ),
    );
  }

  String postAge(dynamic value) {
    final created = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (created == null) return '';
    final age = DateTime.now().difference(created);
    if (age.isNegative || age.inMinutes < 1) return tr('Teraz', 'Now');
    if (age.inHours < 1) return '${age.inMinutes} min';
    if (age.inDays < 1) return '${age.inHours} h';
    if (age.inDays < 7) return '${age.inDays} d';
    return '${created.day}.${created.month}.${created.year}';
  }

  Widget postTile(Map<String, dynamic> item) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          InkWell(
            onTap: () => genesisOpenMemberProfile(context,
              item['author_id'] as String?,
              item['author_label'] as String? ?? ''),
            borderRadius: BorderRadius.circular(30),
            child: const CircleAvatar(radius: 18,
              child: Icon(Icons.person_outline))),
          const SizedBox(width: 10),
          Expanded(child: InkWell(
            onTap: () => genesisOpenMemberProfile(context,
              item['author_id'] as String?,
              item['author_label'] as String? ?? ''),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(child: Text(item['author_label'] as String,
                    style: const TextStyle(color: AgcLuxury.champagne,
                      fontWeight: FontWeight.w600))),
                  const Icon(Icons.chevron_right, size: 17,
                    color: AgcLuxury.champagne),
                ]),
                Text(postAge(item['created_at']),
                  style: const TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          )),
          if (item['author_id'] == AgcBackend.user?.id)
            IconButton(
              onPressed: () => removePost(item),
              icon: const Icon(Icons.delete_outline),
              tooltip: tr('Usuń własny post', 'Delete your post'),
            ),
        ]),
        const SizedBox(height: 12),
        Text(tr('POST W DYSKUSJI', 'DISCUSSION POST'),
          style: const TextStyle(color: AgcLuxury.champagne,
            fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 6),
        SelectableText(item['body'] as String,
          style: const TextStyle(fontSize: 15, height: 1.45)),
        postMedia(item),
        const Divider(height: 24),
        Wrap(spacing: 8, runSpacing: 4, children: [
          TextButton.icon(
            onPressed: () => toggleLike(item),
            icon: Icon(item['liked'] == true
              ? Icons.favorite : Icons.favorite_border,
              color: item['liked'] == true ? Colors.redAccent : null),
            label: Text("${tr('Polub', 'Like')} · ${item['likes']}"),
          ),
          TextButton.icon(
            onPressed: () async {
              await showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => GenesisComments(postId: item['id'] as String));
              refresh();
            },
            icon: const Icon(Icons.mode_comment_outlined),
            label: Text("${tr('Komentuj', 'Comment')} · ${item['comments']}"),
          ),
          if (item['visibility'] == 'public')
            TextButton.icon(
              onPressed: () => genesisSharePost(context, item),
              icon: const Icon(Icons.share_outlined),
              label: Text(tr('Udostępnij', 'Share')),
            ),
          IconButton(
            onPressed: () => report(item),
            icon: const Icon(Icons.flag_outlined),
            tooltip: tr('Zgłoś post', 'Report post'),
          ),
        ]),
      ])));

  @override
  Widget build(BuildContext context) => Center(child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 650),
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
      if (group == null) ...[
        const SizedBox(height: 12),
        TextField(onChanged: (value) =>
          setState(() => groupQuery = value.trim().toLowerCase()),
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search),
            hintText: tr('Szukaj grup...', 'Search groups...'))),
        const SizedBox(height: 10),
        groupFilters(),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => setState(() => showMemberSearch = !showMemberSearch),
          icon: const Icon(Icons.person_search_outlined),
          label: Text(tr('Wyszukiwarka użytkowników', 'Find members'))),
        if (showMemberSearch) const GenesisMemberSearch(),
      ],
      if (group?['official'] == true) ...[
        const SizedBox(height: 10),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: loadPrompts(group!['id'] as String),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            return Column(children: [
              for (final prompt in snapshot.data!)
                Card(child: ListTile(
                  leading: const Icon(Icons.lightbulb_outline,
                    color: AgcLuxury.champagne),
                  title: Text(tr('Pytanie otwierające · THE GENESIS ERA',
                    'Starter question · THE GENESIS ERA')),
                  subtitle: Text(prompt['body'] as String))),
            ]);
          }),
      ],
      if (group != null) ...[
        if (group!['visibility'] == 'public')
          Align(alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => genesisShareGroup(context, group!),
              icon: const Icon(Icons.share_outlined, size: 17),
              label: Text(tr('Udostępnij grupę', 'Share group')))),
        const SizedBox(height: 10),
        Text(group!['visibility'] == 'private'
          ? tr('🔒 Tylko członkowie widzą wypowiedzi i mogą je polubić lub komentować. Udostępnianie publiczne jest wyłączone.',
              '🔒 Only members can see, like and comment on posts. Public sharing is disabled.')
          : tr('🌐 Członkowie mogą polubić, komentować i udostępniać publiczne wypowiedzi.',
              '🌐 Members can like, comment and share public posts.'),
          style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (group == null)
          FilledButton.icon(onPressed: createGroup,
            icon: const Icon(Icons.add),
            label: Text(tr('Nowa grupa', 'New group')))
        else membershipActions(),
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
  final inputFocus = FocusNode();
  late Future<List<Map<String, dynamic>>> rows;
  String? replyingTo;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    rows = fetch();
    input.addListener(onInputChanged);
  }

  void onInputChanged() {
    if (mounted) setState(() {});
  }

  void refresh() => setState(() { rows = fetch(); });

  Future<List<Map<String, dynamic>>> fetch() async {
    final result = await AgcBackend.client.from('agc_post_comments')
      .select('id,author_id,author_label,body,created_at')
      .eq('post_id', widget.postId)
      .order('created_at')
      .limit(100);
    final comments = List<Map<String, dynamic>>.from(result);
    if (comments.isEmpty) return comments;
    final ids = comments.map((c) => c['id'] as String).toList();
    final likes = await AgcBackend.client.from('agc_comment_likes')
      .select('comment_id,member_id').inFilter('comment_id', ids);
    for (final comment in comments) {
      comment['likes'] = likes.where(
        (like) => like['comment_id'] == comment['id']).length;
      comment['liked'] = likes.any((like) =>
        like['comment_id'] == comment['id'] &&
        like['member_id'] == AgcBackend.user?.id);
    }
    return comments;
  }

  Future<void> toggleCommentLike(Map<String, dynamic> comment) async {
    final userId = AgcBackend.user?.id;
    if (userId == null) return;
    try {
      if (comment['liked'] == true) {
        await AgcBackend.client.from('agc_comment_likes')
          .delete().eq('comment_id', comment['id'])
          .eq('member_id', userId);
      } else {
        await AgcBackend.client.from('agc_comment_likes').insert({
          'comment_id': comment['id'], 'member_id': userId,
        });
      }
      refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('Nie udało się zapisać polubienia.',
            'Could not save the like.'))));
      }
    }
  }

  String commentAge(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    final age = DateTime.now().difference(date);
    if (age.isNegative || age.inMinutes < 1) return tr('Teraz', 'Now');
    if (age.inHours < 1) return '${age.inMinutes} min';
    if (age.inDays < 1) return '${age.inHours} h';
    if (age.inDays < 7) return '${age.inDays} d';
    return '${date.day}.${date.month}.${date.year}';
  }

  void replyTo(Map<String, dynamic> comment) {
    final label = comment['author_label'] as String;
    setState(() {
      replyingTo = label;
      input.text = '@$label ';
      input.selection = TextSelection.collapsed(offset: input.text.length);
    });
    inputFocus.requestFocus();
  }

  void cancelReply() {
    setState(() {
      replyingTo = null;
      input.clear();
    });
  }

  bool get canSend {
    final text = input.text.trim();
    if (replyingTo == null) return text.length >= 2;
    return text.replaceFirst('@${replyingTo!}', '').trim().length >= 2;
  }

  Future<void> send() async {
    if (busy || !canSend || AgcBackend.user == null) return;
    setState(() => busy = true);
    try {
      await AgcBackend.client.from('agc_post_comments').insert({
        'post_id': widget.postId,
        'author_id': AgcBackend.user!.id,
        'body': input.text.trim(),
      });
      input.clear();
      setState(() => replyingTo = null);
      inputFocus.unfocus();
      refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("${tr('Nie udało się dodać komentarza: ', 'Could not add comment: ')}$e"),
        ));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> remove(String id) async {
    try {
      await AgcBackend.client.from('agc_post_comments')
        .delete().eq('id', id);
      refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
        ));
      }
    }
  }

  @override
  void dispose() {
    input.removeListener(onInputChanged);
    input.dispose();
    inputFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 10),
            child: Row(children: [
              const Icon(Icons.forum_outlined, color: AgcLuxury.champagne),
              const SizedBox(width: 8),
              Expanded(child: Text(tr('Komentarze', 'Comments'),
                style: const TextStyle(
                  fontSize: 18,
                  color: AgcLuxury.champagne,
                  fontWeight: FontWeight.bold))),
              IconButton(
                onPressed: () => Navigator.pop(context),
                tooltip: tr('Zamknij', 'Close'),
                icon: const Icon(Icons.close),
              ),
            ]),
          ),
          const Divider(height: 1),
          Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
            future: rows,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tr('Nie udało się wczytać komentarzy.',
                      'Could not load comments.')),
                    TextButton(onPressed: refresh,
                      child: Text(tr('Spróbuj ponownie', 'Try again'))),
                  ],
                ));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final comments = snapshot.data!;
              if (comments.isEmpty) {
                return Center(child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.chat_bubble_outline,
                        size: 36, color: AgcLuxury.champagne),
                      const SizedBox(height: 10),
                      Text(tr('Brak komentarzy.',
                        'No comments yet.')),
                      const SizedBox(height: 5),
                      Text(tr('Napisz pierwszy komentarz.',
                        'Write the first comment.'),
                        textAlign: TextAlign.center),
                    ],
                  ),
                ));
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
                itemCount: comments.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final comment = comments[i];
                  final isMine = comment['author_id'] == AgcBackend.user?.id;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => genesisOpenMemberProfile(context,
                          comment['author_id'] as String?,
                          comment['author_label'] as String? ?? ''),
                        child: const CircleAvatar(radius: 16,
                          child: Icon(Icons.person_outline, size: 18))),
                      const SizedBox(width: 8),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InkWell(
                                  onTap: () => genesisOpenMemberProfile(context,
                                    comment['author_id'] as String?,
                                    comment['author_label'] as String? ?? ''),
                                  child: Row(mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(comment['author_label'] as String,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AgcLuxury.champagne)),
                                      const Icon(Icons.chevron_right,
                                        size: 16, color: AgcLuxury.champagne),
                                    ])),
                                const SizedBox(height: 5),
                                SelectableText(comment['body'] as String),
                              ],
                            ),
                          ),
                          Row(children: [
                            Text(commentAge(comment['created_at']),
                              style: const TextStyle(
                                fontSize: 11, color: Colors.white70)),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () => toggleCommentLike(comment),
                              icon: Icon(comment['liked'] == true
                                ? Icons.favorite : Icons.favorite_border,
                                size: 15,
                                color: comment['liked'] == true
                                  ? Colors.redAccent : null),
                              label: Text("${tr('Polub', 'Like')} · ${comment['likes']}"),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5)),
                            ),
                            TextButton(
                              onPressed: () => replyTo(comment),
                              child: Text(tr('Odpowiedz', 'Reply')),
                            ),
                            if (isMine)
                              IconButton(
                                onPressed: () => remove(comment['id'] as String),
                                icon: const Icon(Icons.delete_outline, size: 17),
                                tooltip: tr('Usuń komentarz', 'Delete comment'),
                                visualDensity: VisualDensity.compact,
                              ),
                          ]),
                        ],
                      )),
                    ],
                  );
                },
              );
            },
          )),
          const Divider(height: 1),
          if (replyingTo != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Row(children: [
                Expanded(child: Text(
                  "${tr('Odpowiadasz: ', 'Replying to: ')}$replyingTo",
                  style: const TextStyle(
                    fontSize: 12, color: AgcLuxury.champagne))),
                IconButton(
                  onPressed: cancelReply,
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: tr('Anuluj odpowiedź', 'Cancel reply'),
                ),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const CircleAvatar(
                radius: 17, child: Icon(Icons.person_outline, size: 19)),
              const SizedBox(width: 8),
              Expanded(child: TextField(
                key: const Key('group_comment_input'),
                controller: input,
                focusNode: inputFocus,
                maxLength: 1000,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: tr('Dodaj komentarz…', 'Add a comment…'),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                ),
              )),
              const SizedBox(width: 6),
              IconButton.filled(
                key: const Key('group_comment_send'),
                onPressed: busy || !canSend ? null : send,
                tooltip: tr('Wyślij komentarz', 'Send comment'),
                icon: busy
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
              ),
            ]),
          ),
        ]),
      ),
    ),
  );
}
