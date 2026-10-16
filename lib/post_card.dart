import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart';
import 'social.dart';

class PostCard extends StatefulWidget {
 final Map<String,dynamic> post;
 const PostCard({super.key,required this.post});
 @override State<PostCard> createState()=>_PostCardState();
}
class _PostCardState extends State<PostCard> {
 int likes=0,comments=0;
 bool liked=false,expanded=false;
 List<Map<String,dynamic>> replies=[];
 bool get editorial=>widget.post['editorial']==true;
 String get id=>'${widget.post['id']}';
 @override void initState(){super.initState();if(!editorial)loadCounts();}
 Future<void> loadCounts() async {
  try {
   final l=await db.from('agc_post_likes').select('member_id').eq('post_id',id);
   final c=await db.from('agc_post_comments').select('id').eq('post_id',id);
   if(mounted)setState((){likes=l.length;comments=c.length;liked=l.any((v)=>v['member_id']==db.auth.currentUser?.id);});
  }catch(_){}
 }
 Future<void> toggleLike() async {
  final u=db.auth.currentUser;
  if(u==null){message('Zaloguj się, aby polubić.');return;}
  try {
   if(liked)await db.from('agc_post_likes').delete().eq('post_id',id).eq('member_id',u.id);
   else await db.from('agc_post_likes').insert({'post_id':id,'member_id':u.id});
   await loadCounts();
  }catch(e){message('Błąd polubienia: $e');}
 }
 Future<void> loadComments() async {
  final result=await db.from('agc_post_comments').select('author_label,body,created_at').eq('post_id',id).order('created_at');
  if(mounted)setState(()=>replies=List<Map<String,dynamic>>.from(result));
 }
 Future<void> addComment(String text) async {
  final u=db.auth.currentUser;
  if(u==null){message('Zaloguj się, aby komentować.');return;}
  if(text.trim().length<2)return;
  try {
   await db.from('agc_post_comments').insert({'post_id':id,'author_id':u.id,'body':text.trim()});
   await loadComments();await loadCounts();
  }catch(e){message('Błąd komentarza: $e');}
 }
 void message(String s){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}
 Future<void> share() async {
  final group=widget.post['agc_groups'];
  if(group is Map && group['visibility']=='private'){message('Nie udostępniamy postów z grup prywatnych.');return;}
  final url='$projectUrl/functions/v1/genesis-share?id=$id';
  await SharePlus.instance.share(ShareParams(text:'AI Global Community: $url',subject:'AI Global Community'));
 }
 @override Widget build(BuildContext context) {
  final p=widget.post;
  final group=p['agc_groups'];
  final groupName=group is Map?'${group['name']}':'Społeczność';
  final isPrivate=group is Map && group['visibility']=='private';
  final photo=p['image_path'] as String?;
  final editorialReplies=p['agc_editorial_replies'] is List?p['agc_editorial_replies'] as List:<dynamic>[];
  return Card(margin:const EdgeInsets.only(bottom:12),child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Row(children:[
    const CircleAvatar(backgroundColor:Color(0xFFE7ECFF),child:Icon(Icons.person,color:accent)),
    const SizedBox(width:10),
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Text('${p['author_label']??'Społeczność'}',style:const TextStyle(fontWeight:FontWeight.bold)),
     Text('$groupName • ${niceDate(p['created_at'])}',style:Theme.of(context).textTheme.bodySmall),
    ])),
    if(editorial)const Chip(label:Text('AGC')),
    if(isPrivate)const Icon(Icons.lock_outline,size:18),
   ]),
   const SizedBox(height:12),
   if(editorial)Text('${p['title']}',style:Theme.of(context).textTheme.titleMedium),
   Text('${p['body']}',style:const TextStyle(fontSize:15)),
   if(photo!=null && photo.isNotEmpty && !isPrivate)Padding(padding:const EdgeInsets.only(top:12),child:ClipRRect(borderRadius:BorderRadius.circular(12),child:Image.network(db.storage.from('agc-forum-images').getPublicUrl(photo),height:240,width:double.infinity,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Text('Zdjęcie niedostępne.')))),
   if(p['link_url']!=null)TextButton.icon(icon:const Icon(Icons.link),label:Text('${p['link_url']}',maxLines:1,overflow:TextOverflow.ellipsis),onPressed:()=>launchUrl(Uri.parse('${p['link_url']}'),mode:LaunchMode.externalApplication)),
   if(p['video_url']!=null)TextButton.icon(icon:const Icon(Icons.play_circle),label:const Text('Otwórz film'),onPressed:()=>launchUrl(Uri.parse('${p['video_url']}'),mode:LaunchMode.externalApplication)),
   if(editorial)...editorialReplies.map((r)=>Padding(padding:const EdgeInsets.only(top:12),child:Container(width:double.infinity,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFFF0F3FB),borderRadius:BorderRadius.circular(10)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Zespół AGC • odpowiedź',style:TextStyle(fontWeight:FontWeight.bold)),Text('${r['body']}')])))),
   const Divider(height:24),
   if(editorial)const Text('Dołącz do grupy, aby rozpocząć własną dyskusję.',style:TextStyle(color:Colors.blueGrey))
   else Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:[
    TextButton.icon(onPressed:toggleLike,icon:Icon(liked?Icons.favorite:Icons.favorite_border,color:liked?Colors.red:null),label:Text('$likes')),
    TextButton.icon(onPressed:() async {setState(()=>expanded=!expanded);if(expanded)await loadComments();},icon:const Icon(Icons.chat_bubble_outline),label:Text('$comments')),
    TextButton.icon(onPressed:isPrivate?null:share,icon:const Icon(Icons.share_outlined),label:const Text('Udostępnij')),
   ]),
   if(expanded && !editorial)...[
    ...replies.map((r)=>ListTile(dense:true,title:Text('${r['author_label']??'Użytkownik'}'),subtitle:Text('${r['body']}'))),
    _CommentInput(onSend:addComment),
   ],
  ])));
 }
}
class _CommentInput extends StatefulWidget {
 final Future<void> Function(String) onSend;
 const _CommentInput({required this.onSend});
 @override State<_CommentInput> createState()=>_CommentInputState();
}
class _CommentInputState extends State<_CommentInput> {
 final ctrl=TextEditingController();
 @override void dispose(){ctrl.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>Row(children:[
  Expanded(child:TextField(controller:ctrl,maxLength:1000,decoration:const InputDecoration(hintText:'Napisz komentarz...'))),
  IconButton(onPressed:() async {await widget.onSend(ctrl.text);ctrl.clear();},icon:const Icon(Icons.send,color:accent)),
 ]);
}
