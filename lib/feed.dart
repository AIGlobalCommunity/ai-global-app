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
 final VoidCallback? onLogin;
 const FeedScreen({super.key,this.onLogin});
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
   AGCHero(onJoin:widget.onLogin,onPost:compose,loggedIn:db.auth.currentUser!=null),
   const SizedBox(height:14),
   Padding(padding:const EdgeInsets.symmetric(horizontal:6,vertical:8),child:Row(children:[
    const Icon(Icons.dynamic_feed,color:accent),
    const SizedBox(width:8),
    Text('Z życia społeczności',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800,color:dark)),
   ])),
   FutureBuilder<List<Map<String,dynamic>>>(future:future,builder:(context,snapshot){
    if(snapshot.hasError)return Padding(padding:const EdgeInsets.all(20),child:Text('Błąd pobierania wpisów: ${snapshot.error}'));
    if(!snapshot.hasData)return const Center(child:Padding(padding:EdgeInsets.all(24),child:CircularProgressIndicator()));
    if(snapshot.data!.isEmpty)return const Padding(padding:EdgeInsets.all(24),child:Text('Jeszcze nie ma wpisów. Rozpocznij dyskusję!'));
    return Column(children:snapshot.data!.map((p)=>PostCard(post:p)).toList());
   }),
  ]),
 );
}

class AGCHero extends StatelessWidget {
 final VoidCallback? onJoin;
 final VoidCallback onPost;
 final bool loggedIn;
 const AGCHero({super.key,this.onJoin,required this.onPost,required this.loggedIn});
 @override Widget build(BuildContext context)=>Container(
  clipBehavior:Clip.antiAlias,
  decoration:BoxDecoration(
   gradient:const LinearGradient(colors:[Color(0xFF101E4E),Color(0xFF2F3C94),Color(0xFF6358D6)],begin:Alignment.topLeft,end:Alignment.bottomRight),
   borderRadius:BorderRadius.circular(24),
  ),
  child:Stack(children:[
   const Positioned(top:-75,right:-45,child:_OrbitArt()),
   const Positioned(bottom:-55,left:-60,child:_GlowRing()),
   Padding(padding:const EdgeInsets.fromLTRB(24,38,24,34),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:6),decoration:BoxDecoration(color:Colors.white.withValues(alpha:0.13),borderRadius:BorderRadius.circular(50),border:Border.all(color:Colors.white24)),child:const Text('✦  THE GENESIS ERA',style:TextStyle(color:gold,fontWeight:FontWeight.w800,letterSpacing:1.4,fontSize:11))),
    const SizedBox(height:24),
    const Text('Przyszłość AI\ntworzymy razem.',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:32,height:1.15)),
    const SizedBox(height:14),
    const ConstrainedBox(constraints:BoxConstraints(maxWidth:420),child:Text('Miejsce dla ludzi, pomysłów i rozmów o sztucznej inteligencji. Odkrywaj grupy, publikuj i poznawaj społeczność.',style:TextStyle(color:Color(0xFFE5E9FF),fontSize:15,height:1.5))),
    const SizedBox(height:24),
    FilledButton.icon(
     style:FilledButton.styleFrom(backgroundColor:gold,foregroundColor:dark),
     onPressed:loggedIn?onPost:onJoin,
     icon:Icon(loggedIn?Icons.edit_outlined:Icons.login),
     label:Text(loggedIn?'Napisz pierwszy post':'Zaloguj się / Dołącz'),
    ),
    const SizedBox(height:14),
    const Wrap(spacing:16,runSpacing:8,children:[
     _HeroFact(icon:Icons.groups_2_outlined,text:'Grupy tematyczne'),
     _HeroFact(icon:Icons.forum_outlined,text:'Dyskusje'),
     _HeroFact(icon:Icons.auto_awesome_outlined,text:'Asystent AI'),
    ]),
   ])),
  ]),
 );
}
class _HeroFact extends StatelessWidget {
 final IconData icon;
 final String text;
 const _HeroFact({required this.icon,required this.text});
 @override Widget build(BuildContext context)=>Row(mainAxisSize:MainAxisSize.min,children:[Icon(icon,size:16,color:gold),const SizedBox(width:5),Text(text,style:const TextStyle(color:Colors.white,fontSize:12))]);
}
class _OrbitArt extends StatelessWidget {
 const _OrbitArt();
 @override Widget build(BuildContext context)=>SizedBox(width:260,height:260,child:Stack(alignment:Alignment.center,children:[
  Container(width:245,height:245,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:Colors.white.withValues(alpha:0.12),width:1.5))),
  Container(width:205,height:205,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:gold.withValues(alpha:0.35),width:1.5))),
  Container(width:155,height:155,decoration:BoxDecoration(shape:BoxShape.circle,gradient:RadialGradient(colors:[const Color(0xFF8CCEFF).withValues(alpha:0.6),const Color(0xFF7B75F5).withValues(alpha:0.12)]))),
  const Icon(Icons.public_rounded,color:Color(0xFFB6CEFF),size:104),
  const Positioned(top:29,right:48,child:Icon(Icons.star_rounded,color:gold,size:24)),
  const Positioned(bottom:32,left:23,child:Icon(Icons.circle,color:Color(0xFF95D6FF),size:10)),
 ]));
}
class _GlowRing extends StatelessWidget {
 const _GlowRing();
 @override Widget build(BuildContext context)=>Container(width:170,height:170,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:Colors.white.withValues(alpha:0.08),width:25)));
}
