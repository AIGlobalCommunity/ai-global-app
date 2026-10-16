import 'package:flutter/material.dart';
import 'main.dart';
import 'posts.dart';
import 'social.dart';

Future<List<Map<String,dynamic>>> communityFeed({String? groupId,String? authorId}) async {
  var q=db.from('agc_group_posts').select('id,group_id,author_id,author_label,body,image_path,link_url,video_url,created_at,agc_groups(name,visibility)');
  if(groupId!=null)q=q.eq('group_id',groupId);
  if(authorId!=null)q=q.eq('author_id',authorId);
  final posts=await q.order('created_at',ascending:false).limit(80);
  final all=List<Map<String,dynamic>>.from(posts);
  if(authorId==null) {
    var e=db.from('agc_editorial_posts').select('id,group_id,title,body,created_at,agc_groups(name,visibility),agc_editorial_replies(body,created_at)');
    if(groupId!=null)e=e.eq('group_id',groupId);
    final editorial=await e.order('created_at',ascending:false).limit(50);
    all.addAll(List<Map<String,dynamic>>.from(editorial).map((x)=>{...x,'editorial':true,'author_label':'Zespół AGC'}));
  }
  all.sort((a,b)=>'${b['created_at']}'.compareTo('${a['created_at']}'));
  return all;
}
class FeedScreen extends StatefulWidget {
 const FeedScreen({super.key});
 @override State<FeedScreen> createState()=>_FeedScreenState();
}
class _FeedScreenState extends State<FeedScreen> {
 late Future<List<Map<String,dynamic>>> future;
 @override void initState(){super.initState();reload();}
 void reload(){future=_loadWithSharedPost();}
 Future<List<Map<String,dynamic>>> _loadWithSharedPost() async {
  final items=await communityFeed();
  final id=Uri.base.queryParameters['post'];
  if(id==null || id.length!=36 || items.any((p)=>p['id']==id))return items;
  final p=await db.from('agc_group_posts').select('id,group_id,author_id,author_label,body,image_path,link_url,video_url,created_at,agc_groups(name,visibility)').eq('id',id).maybeSingle();
  if(p!=null)items.insert(0,Map<String,dynamic>.from(p));
  return items;
 }
 Future<void> compose() async {
  final groups=await db.from('agc_groups').select('id,name,visibility,owner_id').eq('visibility','public').order('name');
  if(!mounted)return;
  final result=await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>ComposeScreen(groups:List<Map<String,dynamic>>.from(groups))));
  if(result==true)setState(reload);
 }
 @override Widget build(BuildContext context)=>RefreshIndicator(
  onRefresh:() async {setState(reload);await future;},
  child:ListView(padding:const EdgeInsets.all(12),children:[
   Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text('Twoja społeczność AI 🌍',style:Theme.of(context).textTheme.titleLarge),
    const SizedBox(height:6),
    const Text('Wpisy, pomysły i rozmowy członków AI Global Community.'),
    const SizedBox(height:12),
    if(db.auth.currentUser!=null) FilledButton.icon(onPressed:compose,icon:const Icon(Icons.edit),label:const Text('Co nowego? Dodaj post'))
    else const Text('Zaloguj się, aby publikować i reagować.'),
   ]))),
   FutureBuilder<List<Map<String,dynamic>>>(future:future,builder:(context,snapshot){
    if(snapshot.hasError)return Padding(padding:const EdgeInsets.all(20),child:Text('Błąd pobierania wpisów: ${snapshot.error}'));
    if(!snapshot.hasData)return const Center(child:Padding(padding:EdgeInsets.all(24),child:CircularProgressIndicator()));
    if(snapshot.data!.isEmpty)return const Padding(padding:EdgeInsets.all(24),child:Text('Jeszcze nie ma wpisów. Rozpocznij dyskusję!'));
    return Column(children:snapshot.data!.map((p)=>PostCard(post:p)).toList());
   }),
  ]),
 );
}
