import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'agc_backend.dart';
import 'agc_luxury_theme.dart';
import 'genesis_discussions.dart';
import 'genesis_language.dart';
import 'genesis_social.dart';

class GenesisCommunityFeed extends StatefulWidget {
  const GenesisCommunityFeed({super.key, this.onOpenDiscussions,
    this.onOpenGroup});
  final VoidCallback? onOpenDiscussions;
  final ValueChanged<String>? onOpenGroup;
  @override
  State<GenesisCommunityFeed> createState() => _GenesisCommunityFeedState();
}

class _GenesisCommunityFeedState extends State<GenesisCommunityFeed> {
  late Future<List<Map<String,dynamic>>> posts;
  @override
  void initState() { super.initState(); refresh(); }
  void refresh() => setState(() { posts = load(); });

  Future<List<Map<String,dynamic>>> load() async {
    final data = await AgcBackend.client.from('agc_group_posts')
      .select('id,group_id,author_id,author_label,body,created_at,image_path,link_url,video_url,agc_groups!inner(name,visibility)')
      .order('created_at',ascending:false).limit(40);
    final rows = List<Map<String,dynamic>>.from(data);
    if(rows.isEmpty) return rows;
    final ids = rows.map((p)=>p['id'] as String).toList();
    final likes = await AgcBackend.client.from('agc_post_likes')
      .select('post_id,member_id').inFilter('post_id',ids);
    final comments = await AgcBackend.client.from('agc_post_comments')
      .select('post_id').inFilter('post_id',ids);
    for(final row in rows) {
      final group = row['agc_groups'] as Map<String,dynamic>;
      row['visibility'] = group['visibility'];
      row['group_name'] = group['name'];
      row['likes'] = likes.where((x)=>x['post_id']==row['id']).length;
      row['liked'] = likes.any((x)=>x['post_id']==row['id'] &&
        x['member_id']==AgcBackend.user?.id);
      row['comments'] = comments.where((x)=>x['post_id']==row['id']).length;
    }
    final target = Uri.base.queryParameters['post'];
    if(target != null) {
      rows.sort((a,b)=>a['id']==target ? -1 : b['id']==target ? 1 : 0);
    }
    return rows;
  }

  Future<List<Map<String, dynamic>>> starterTopics() async {
    final rows = await AgcBackend.client.from('agc_group_prompts')
      .select('body,group_id,agc_groups!inner(name,visibility)')
      .limit(6);
    return List<Map<String, dynamic>>.from(rows);
  }

  void message(String text) {
    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text)));
    }
  }

  Future<void> toggleLike(Map<String,dynamic> post) async {
    try {
      if(post['liked']==true) {
        await AgcBackend.client.from('agc_post_likes').delete()
          .eq('post_id',post['id']).eq('member_id',AgcBackend.user!.id);
      } else {
        await AgcBackend.client.from('agc_post_likes').insert({
          'post_id':post['id'],'member_id':AgcBackend.user!.id});
      }
      refresh();
    } catch(e) { message('$e'); }
  }

  Widget media(Map<String,dynamic> post) {
    final imagePath=post['image_path'] as String?;
    final link=genesisExternalUrl(post['link_url'] as String?);
    final video=genesisExternalUrl(post['video_url'] as String?);
    final yt=video==null?null:genesisYoutubeId(video);
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      if(imagePath!=null) ...[
        const SizedBox(height:10),
        if(post['visibility']=='private')
          FutureBuilder<String>(
            future:AgcBackend.client.storage.from('agc-private-forum-images')
              .createSignedUrl(imagePath,600),
            builder:(ctx,s)=>s.hasData
              ? Image.network(s.data!,height:270,width:double.infinity,fit:BoxFit.contain)
              : const SizedBox(height:36,child:Center(child:CircularProgressIndicator())))
        else
          Image.network(
            AgcBackend.client.storage.from('agc-forum-images').getPublicUrl(imagePath),
            height:270,width:double.infinity,fit:BoxFit.contain,
            errorBuilder:(ctx,error,stack)=>const Icon(Icons.broken_image_outlined)),
      ],
      if(link!=null) TextButton.icon(
        onPressed:()=>launchUrl(link,mode:LaunchMode.externalApplication),
        icon:const Icon(Icons.open_in_new),label:Text(link.host)),
      if(video!=null) ...[
        if(yt!=null) InkWell(
          onTap:()=>launchUrl(video,mode:LaunchMode.externalApplication),
          child:Stack(alignment:Alignment.center,children:[
            Image.network('https://img.youtube.com/vi/$yt/hqdefault.jpg',
              height:200,width:double.infinity,fit:BoxFit.cover),
            const Icon(Icons.play_circle_fill,size:55,color:Colors.white),
          ])),
        TextButton.icon(onPressed:()=>launchUrl(video,mode:LaunchMode.externalApplication),
          icon:const Icon(Icons.play_arrow),label:Text(video.host)),
      ],
    ]);
  }

  Widget tile(Map<String,dynamic> post) => Card(
    margin:const EdgeInsets.only(bottom:12),
    child:Padding(padding:const EdgeInsets.all(14),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          const CircleAvatar(radius:17,child:Icon(Icons.person_outline,size:19)),
          const SizedBox(width:9),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(post['author_label'] as String,
              style:const TextStyle(color:AgcLuxury.champagne,fontWeight:FontWeight.w600)),
            Text('${post['group_name']} · ${post['visibility']=='private'?'🔒':'🌐'}',
              style:const TextStyle(fontSize:11,color:Colors.white70)),
          ])),
        ]),
        const SizedBox(height:8),
        Align(alignment:Alignment.centerLeft,child:TextButton.icon(
          key:Key('feed_open_group_${post['id']}'),
          onPressed:widget.onOpenGroup==null ? widget.onOpenDiscussions
            :()=>widget.onOpenGroup!(post['group_id'] as String),
          icon:const Icon(Icons.groups_outlined,size:17),
          label:Text(GenesisLanguage.copy('Przejdź do grupy i dołącz do rozmowy',
            'Open group and join the conversation')),
          style:TextButton.styleFrom(
            visualDensity:VisualDensity.compact,
            padding:const EdgeInsets.symmetric(horizontal:4)),
        )),
        const SizedBox(height:8),
        SelectableText(post['body'] as String),
        media(post),
        const Divider(height:25),
        Wrap(spacing:8,runSpacing:4,children:[
          TextButton.icon(
            key: Key('feed_like_${post['id']}'),
            onPressed:()=>toggleLike(post),
            icon:Icon(post['liked']==true?Icons.favorite:Icons.favorite_border,
              color:post['liked']==true?Colors.redAccent:null),
            label:Text('${GenesisLanguage.copy('Polub','Like')} · ${post['likes']}')),
          TextButton.icon(onPressed:() async {
            await showModalBottomSheet<void>(context:context,isScrollControlled:true,
              showDragHandle:true,builder:(_)=>GenesisComments(postId:post['id'] as String));
            refresh();
          },icon:const Icon(Icons.mode_comment_outlined),
            label:Text('${GenesisLanguage.copy('Komentuj','Comment')} · ${post['comments']}')),
          if(post['visibility']=='public')
            TextButton.icon(
              key: Key('feed_share_${post['id']}'),
              onPressed:()=>genesisSharePost(context,post),
              icon:const Icon(Icons.share_outlined),
              label:Text(GenesisLanguage.copy('Udostępnij','Share'))),
        ]),
      ])));

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Row(children:[
        const Icon(Icons.dynamic_feed_outlined,color:AgcLuxury.champagne),
        const SizedBox(width:8),
        Expanded(child:Text(GenesisLanguage.copy('AKTUALNOŚCI SPOŁECZNOŚCI',
          'COMMUNITY FEED'),style:const TextStyle(
          color:AgcLuxury.champagne,fontWeight:FontWeight.bold,fontSize:17))),
        if (widget.onOpenDiscussions != null)
          IconButton(onPressed:widget.onOpenDiscussions,
            icon:const Icon(Icons.edit_square),
            tooltip:GenesisLanguage.copy('Napisz post','Write post')),
        IconButton(onPressed:refresh,icon:const Icon(Icons.refresh),
          tooltip:GenesisLanguage.copy('Odśwież','Refresh')),
      ]),
      FutureBuilder<List<Map<String,dynamic>>>(future:posts,builder:(context,snapshot){
        if(snapshot.hasError) { return Text(
          '${GenesisLanguage.copy('Nie udało się pobrać postów','Could not load posts')}: ${snapshot.error}'); }
        if(!snapshot.hasData) { return const Center(child:CircularProgressIndicator()); }
        if(snapshot.data!.isEmpty) {
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: starterTopics(),
            builder: (context, starter) {
              if (!starter.hasData || starter.data!.isEmpty) {
                return Text(GenesisLanguage.copy(
                  'Otwórz Dyskusje i napisz pierwszy post.',
                  'Open Discussions and write the first post.'));
              }
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(GenesisLanguage.copy(
                  'TEMATY DO ROZMOWY · THE GENESIS ERA',
                  'DISCUSSION STARTERS · THE GENESIS ERA'),
                  style: const TextStyle(color: AgcLuxury.champagne,
                    fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                for (final item in starter.data!)
                  Card(child: ListTile(
                    leading: const Icon(Icons.lightbulb_outline,
                      color: AgcLuxury.champagne),
                    title: Text((item['agc_groups'] as Map<String,dynamic>)['name'] as String),
                    subtitle: Text(item['body'] as String),
                    onTap: widget.onOpenGroup == null
                      ? widget.onOpenDiscussions
                      : () => widget.onOpenGroup!(item['group_id'] as String),
                    trailing: const Icon(Icons.chevron_right))),
              ]);
            });
        }
        return Column(children:[for(final post in snapshot.data!) tile(post)]);
      }),
    ]);
}
