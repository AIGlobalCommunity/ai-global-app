import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'genesis_language.dart';

const genesisShareEndpoint =
    'https://gjnddmurmegbklvedhnp.supabase.co/functions/v1/genesis-share';
const genesisShareDefaultImage = 'https://thegenesisera.com/icons/Icon-512.png';

String genesisPublicPostUrl(String id) => '$genesisShareEndpoint?id=$id';
String genesisPublicGroupUrl(String id) => '$genesisShareEndpoint?group=$id';

String genesisShareExcerpt(String value, [int maxLength = 190]) {
  final clean = value.replaceFirst(
    RegExp(r'^🧠 Inspiracja do dyskusji · materiał redakcyjny AI\s*'),
    '').replaceAll(RegExp(r'\s+'), ' ').trim();
  return clean.length > maxLength ? '${clean.substring(0, maxLength).trimRight()}…' : clean;
}

String genesisShareImage(Map<String, dynamic> item) {
  final path = item['image_path'];
  if (path is String &&
      RegExp(r'^[0-9a-f-]{36}/[0-9]+_[0-9]+\.(jpg|jpeg|png|webp|gif)$',
        caseSensitive: false).hasMatch(path)) {
    return 'https://gjnddmurmegbklvedhnp.supabase.co/storage/v1/object/public/agc-forum-images/$path';
  }
  final video = Uri.tryParse(item['video_url'] as String? ?? '');
  if (video != null) {
    String? id;
    if (video.host == 'youtu.be') {
      id = video.pathSegments.isEmpty ? null : video.pathSegments.first;
    } else if (['youtube.com', 'www.youtube.com', 'm.youtube.com']
        .contains(video.host)) {
      id = video.queryParameters['v'];
    }
    if (id != null && RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)) {
      return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
    }
  }
  return genesisShareDefaultImage;
}

Future<void> genesisSharePost(
    BuildContext context, Map<String, dynamic> post) async {
  if (post['visibility'] != 'public') {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
      GenesisLanguage.copy(
        'Postów z grup prywatnych nie można udostępniać publicznie.',
        'Posts from private groups cannot be shared publicly.'))));
    return;
  }
  final excerpt = genesisShareExcerpt(post['body'] as String? ?? '');
  final groupName = post['group_name'] as String? ?? 'THE GENESIS ERA';
  final link = genesisPublicPostUrl(post['id'] as String);
  await genesisShareDialog(context,
    title: groupName,
    excerpt: excerpt,
    image: genesisShareImage(post),
    link: link,
    kind: GenesisLanguage.copy('Post / dyskusja', 'Post / discussion'));
}

Future<void> genesisShareGroup(
    BuildContext context, Map<String, dynamic> group) async {
  if (group['visibility'] != 'public') {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
      GenesisLanguage.copy('Grupy prywatnej nie można udostępnić publicznie.',
        'Private groups cannot be shared publicly.'))));
    return;
  }
  await genesisShareDialog(context,
    title: group['name'] as String? ?? 'THE GENESIS ERA',
    excerpt: genesisShareExcerpt(group['description'] as String? ?? ''),
    image: genesisShareDefaultImage,
    link: genesisPublicGroupUrl(group['id'] as String),
    kind: GenesisLanguage.copy('Grupa dyskusyjna', 'Discussion group'));
}

Future<void> genesisShareDialog(BuildContext context, {
  required String title,
  required String excerpt,
  required String image,
  required String link,
  required String kind,
}) async {
  final message = '$title\n$excerpt\n$link';
  final options = <(String, IconData, Uri)>[
    ('Facebook', Icons.facebook,
      Uri.https('www.facebook.com', '/sharer/sharer.php', {'u': link})),
    ('X', Icons.alternate_email,
      Uri.https('twitter.com', '/intent/tweet',
        {'url': link, 'text': '$title — $excerpt'})),
    ('WhatsApp', Icons.chat,
      Uri.https('api.whatsapp.com', '/send', {'text': message})),
    ('Telegram', Icons.send,
      Uri.https('t.me', '/share/url', {'url': link, 'text': '$title — $excerpt'})),
    ('LinkedIn', Icons.work_outline,
      Uri.https('www.linkedin.com', '/sharing/share-offsite/', {'url': link})),
    ('Reddit', Icons.forum_outlined,
      Uri.https('www.reddit.com', '/submit', {'url': link, 'title': title})),
    ('Pinterest', Icons.push_pin_outlined,
      Uri.https('pinterest.com', '/pin/create/button/',
        {'url': link, 'media': image, 'description': '$title — $excerpt'})),
  ];
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context, showDragHandle: true, isScrollControlled: true,
    builder: (ctx) => SafeArea(child: FractionallySizedBox(
      heightFactor: 0.86,
      child: Padding(padding: const EdgeInsets.all(18),
        child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(GenesisLanguage.copy('Udostępnij', 'Share'),
              style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 10),
            Card(clipBehavior: Clip.antiAlias,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.network(image, width: double.infinity, height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stack) => const SizedBox(
                      height: 100,
                      child: Center(child: Icon(Icons.auto_awesome, size: 45)))),
                  Padding(padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(kind.toUpperCase(),
                          style: const TextStyle(fontSize: 11,
                            fontWeight: FontWeight.w600)),
                        const SizedBox(height: 5),
                        Text(title, style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        Text(excerpt, maxLines: 3,
                          overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 5),
                        const Text('THEGENESISERA.COM',
                          style: TextStyle(fontSize: 11)),
                      ])),
                ])),
            const SizedBox(height: 8),
            Text(GenesisLanguage.copy(
              'Taką zajawkę ze zdjęciem i opisem przygotowaliśmy do udostępnienia. '
              'Ostateczny wygląd zależy od serwisu i jego pamięci podręcznej.',
              'This image and description are prepared for sharing. '
              'The final preview depends on the platform and its cache.'),
              style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            for (final option in options)
              ListTile(
                leading: Icon(option.$2),
                title: Text(option.$1),
                onTap: () async {
                  Navigator.pop(ctx);
                  await launchUrl(option.$3,
                    mode: LaunchMode.externalApplication);
                }),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: Text(GenesisLanguage.copy(
                'Udostępnij w innych aplikacjach', 'Share to other apps')),
              onTap: () async {
                Navigator.pop(ctx);
                await SharePlus.instance.share(ShareParams(text: message));
              }),
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(GenesisLanguage.copy('Kopiuj link', 'Copy link')),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: link));
                if (ctx.mounted) Navigator.pop(ctx);
              }),
          ]))),
    ))),
  );
}
