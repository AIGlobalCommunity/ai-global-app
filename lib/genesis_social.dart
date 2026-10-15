import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'genesis_language.dart';

String genesisPublicPostUrl(String id) =>
    'https://gjnddmurmegbklvedhnp.supabase.co/functions/v1/genesis-share?id=$id';

Future<void> genesisSharePost(BuildContext context, Map<String, dynamic> post) async {
  if (post['visibility'] != 'public') {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
      GenesisLanguage.copy('Posty z grup prywatnych nie mogą być udostępniane publicznie.',
        'Private group posts cannot be shared publicly.'))));
    return;
  }
  final link = genesisPublicPostUrl(post['id'] as String);
  final text = (post['body'] as String? ?? '').trim();
  final excerpt = text.length > 170 ? '${text.substring(0, 170)}…' : text;
  final message = '$excerpt\n$link';
  final options = <(String, IconData, Uri)>[
    ('Facebook', Icons.facebook,
      Uri.https('www.facebook.com','/sharer/sharer.php',{'u':link})),
    ('X', Icons.alternate_email,
      Uri.https('twitter.com','/intent/tweet',{'url':link,'text':excerpt})),
    ('WhatsApp', Icons.chat,
      Uri.https('api.whatsapp.com','/send',{'text':message})),
    ('Telegram', Icons.send,
      Uri.https('t.me','/share/url',{'url':link,'text':excerpt})),
    ('LinkedIn', Icons.work_outline,
      Uri.https('www.linkedin.com','/sharing/share-offsite/',{'url':link})),
    ('Reddit', Icons.forum_outlined,
      Uri.https('www.reddit.com','/submit',{'url':link,'title':excerpt})),
    ('Pinterest', Icons.push_pin_outlined,
      Uri.https('pinterest.com','/pin/create/button/',{'url':link,
        if (post['image_path'] != null)
          'media':'https://gjnddmurmegbklvedhnp.supabase.co/storage/v1/object/public/agc-forum-images/${post['image_path']}'})),
  ];
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context:context,showDragHandle:true,
    builder:(ctx)=>SafeArea(child:Padding(
      padding:const EdgeInsets.all(18),
      child:SingleChildScrollView(child:Column(
        mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,
        children:[
          Text(GenesisLanguage.copy('Udostępnij post','Share post'),
            style:Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height:8),
          Text(GenesisLanguage.copy(
            'Publiczny link zawiera zdjęcie i opis do podglądu w serwisach społecznościowych.',
            'The public link includes an image and description for social previews.'),
            style:const TextStyle(fontSize:12)),
          const SizedBox(height:12),
          for(final option in options)
            ListTile(leading:Icon(option.$2),title:Text(option.$1),
              onTap:() async {
                Navigator.pop(ctx);
                await launchUrl(option.$3,mode:LaunchMode.externalApplication);
              }),
          ListTile(leading:const Icon(Icons.ios_share),
            title:Text(GenesisLanguage.copy('Udostępnij w innych aplikacjach',
              'Share to other apps')),
            onTap:() async {
              Navigator.pop(ctx);
              await SharePlus.instance.share(ShareParams(text:message,uri:Uri.parse(link)));
            }),
          ListTile(leading:const Icon(Icons.copy),
            title:Text(GenesisLanguage.copy('Kopiuj link','Copy link')),
            onTap:() async {
              await Clipboard.setData(ClipboardData(text:link));
              if(ctx.mounted) Navigator.pop(ctx);
            }),
        ],
      )),
    )));
}
