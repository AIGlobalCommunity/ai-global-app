import 'package:flutter/material.dart';
import 'main.dart';
import 'feed.dart';
import 'posts.dart';

class GroupsScreen extends StatefulWidget {
 const GroupsScreen({super.key});
 @override State<GroupsScreen> createState()=>_GroupsScreenState();
}
class _GroupsScreenState extends State<GroupsScreen> {
 final search=TextEditingController();
 late Future<List<Map<String,dynamic>>> future;
 @override void initState(){super.initState();reload();}
 void reload(){future=_load();}
 Future<List<Map<String,dynamic>>> _load() async {
  final data=await db.from('agc_groups').select('id,name,description,visibility,owner_id,official').order('name');
  return List<Map<String,dynamic>>.from(data);
 }
 @override void dispose(){search.dispose();super.dispose();}
 Future<void> createGroup() async {
  if(db.auth.currentUser==null){notify('Zaloguj się, aby utworzyć grupę.');return;}
  final created=await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>const CreateGroupScreen()));
  if(created==true)setState(reload);
 }
 void notify(String text){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text)));}
 @override Widget build(BuildContext context)=>Column(children:[
  Padding(padding:const EdgeInsets.all(12),child:Column(children:[
   TextField(controller:search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Wyszukaj grupy...',border:OutlineInputBorder())),
   const SizedBox(height:10),
   SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:createGroup,icon:const Icon(Icons.group_add),label:const Text('Utwórz grupę publiczną lub prywatną'))),
  ])),
  Expanded(child:FutureBuilder<List<Map<String,dynamic>>>(future:future,builder:(context,s){
   if(s.hasError)return Center(child:Text('Błąd: ${s.error}'));
   if(!s.hasData)return const Center(child:CircularProgressIndicator());
   final items=s.data!.where((g)=>'${g['name']} ${g['description']}'.toLowerCase().contains(search.text.toLowerCase())).toList();
   return RefreshIndicator(onRefresh:() async {setState(reload);await future;},child:ListView(children:items.map((g)=>Card(margin:const EdgeInsets.symmetric(horizontal:12,vertical:5),child:ListTile(
    leading:Container(width:56,height:56,decoration:BoxDecoration(borderRadius:BorderRadius.circular(14),gradient:const LinearGradient(colors:[Color(0xFF24357D),Color(0xFF7B74EE)])),child:Icon(g['visibility']=='private'?Icons.lock_outline:Icons.hub_outlined,color:gold,size:28)),
    title:Text('${g['name']}'),
    subtitle:Text('${g['description']}',maxLines:2,overflow:TextOverflow.ellipsis),
    trailing:const Icon(Icons.chevron_right),
    onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>GroupDetail(group:g))),
   ))).toList()));
  })),
 ]);
}
class CreateGroupScreen extends StatefulWidget {
 const CreateGroupScreen({super.key});
 @override State<CreateGroupScreen> createState()=>_CreateGroupScreenState();
}
class _CreateGroupScreenState extends State<CreateGroupScreen> {
 final name=TextEditingController(),description=TextEditingController();
 String visibility='public';
 bool saving=false;
 @override void dispose(){name.dispose();description.dispose();super.dispose();}
 Future<void> save() async {
  final u=db.auth.currentUser;
  if(u==null||name.text.trim().length<4||description.text.trim().length<10)return;
  setState(()=>saving=true);
  try {
   await db.from('agc_groups').insert({'owner_id':u.id,'name':name.text.trim(),'description':description.text.trim(),'visibility':visibility});
   if(mounted)Navigator.pop(context,true);
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Błąd: $e')));}
  finally{if(mounted)setState(()=>saving=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Nowa grupa')),body:ListView(padding:const EdgeInsets.all(16),children:[
  TextField(controller:name,maxLength:64,decoration:const InputDecoration(labelText:'Nazwa grupy')),
  TextField(controller:description,maxLength:500,maxLines:3,decoration:const InputDecoration(labelText:'Opis grupy')),
  RadioListTile<String>(title:const Text('Publiczna'),subtitle:const Text('Każdy może znaleźć grupę i dołączyć.'),value:'public',groupValue:visibility,onChanged:(v)=>setState(()=>visibility=v!)),
  RadioListTile<String>(title:const Text('Prywatna'),subtitle:const Text('Dostęp wyłącznie po zaproszeniu.'),value:'private',groupValue:visibility,onChanged:(v)=>setState(()=>visibility=v!)),
  FilledButton(onPressed:saving?null:save,child:const Text('Utwórz grupę')),
 ]));
}
class GroupDetail extends StatefulWidget {
 final Map<String,dynamic> group;
 const GroupDetail({super.key,required this.group});
 @override State<GroupDetail> createState()=>_GroupDetailState();
}
class _GroupDetailState extends State<GroupDetail> {
 String? status;
 late Future<List<Map<String,dynamic>>> posts;
 bool get owner=>widget.group['owner_id']==db.auth.currentUser?.id && db.auth.currentUser!=null;
 bool get isPublic=>widget.group['visibility']=='public';
 String get id=>'${widget.group['id']}';
 @override void initState(){super.initState();reload();checkMember();}
 void reload(){posts=communityFeed(groupId:id);}
 Future<void> checkMember() async {
  final u=db.auth.currentUser;
  if(u==null)return;
  final row=await db.from('agc_group_members').select('status').eq('group_id',id).eq('member_id',u.id).maybeSingle();
  if(mounted)setState(()=>status=row?['status'] as String?);
 }
 Future<void> join() async {
  final u=db.auth.currentUser;
  if(u==null){notify('Zaloguj się.');return;}
  try {
   if(status=='invited')await db.from('agc_group_members').update({'status':'active'}).eq('group_id',id).eq('member_id',u.id);
   else if(isPublic)await db.from('agc_group_members').insert({'group_id':id,'member_id':u.id,'status':'active'});
   else {notify('Do tej grupy potrzebujesz zaproszenia.');return;}
   await checkMember();if(mounted)setState(reload);
  }catch(e){notify('Błąd: $e');}
 }
 void notify(String s){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}
 Future<void> compose() async {
  final result=await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>ComposeScreen(groups:[widget.group],selectedGroup:id)));
  if(result==true)setState(reload);
 }
 Future<void> invite() async {
  final handle=TextEditingController();
  await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
   title:const Text('Zaproś użytkownika'),
   content:TextField(controller:handle,decoration:const InputDecoration(labelText:'Publiczny nick użytkownika',hintText:'Wpisz nick')),
   actions:[
    TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Anuluj')),
    FilledButton(onPressed:() async {
     try {
      final ok=await db.rpc('agc_invite_group_member',params:{'p_group_id':id,'p_handle':handle.text.trim()});
      if(ctx.mounted)Navigator.pop(ctx);
      notify(ok==true?'Zaproszenie wysłane.':'Nie znaleziono publicznego użytkownika o tym nicku.');
     }catch(e){notify('Nie udało się zaprosić: $e');}
    },child:const Text('Wyślij zaproszenie')),
   ],
  ));
  handle.dispose();
 }
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text('${widget.group['name']}')),body:RefreshIndicator(onRefresh:() async {setState(reload);await posts;},child:ListView(padding:const EdgeInsets.all(12),children:[
  Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Text('${widget.group['name']}',style:Theme.of(context).textTheme.headlineSmall),
   const SizedBox(height:8),Text('${widget.group['description']}'),
   const SizedBox(height:6),Text(isPublic?'🌐 Grupa publiczna':'🔒 Grupa prywatna'),
   const SizedBox(height:12),
   Wrap(spacing:8,children:[
    if(!owner && status!='active')FilledButton(onPressed:join,child:Text(status=='invited'?'Akceptuj zaproszenie':isPublic?'Dołącz do grupy':'Tylko na zaproszenie')),
    if(owner||status=='active')FilledButton.icon(onPressed:compose,icon:const Icon(Icons.edit),label:const Text('Dodaj post')),
    if(owner)OutlinedButton.icon(onPressed:invite,icon:const Icon(Icons.person_add),label:const Text('Zaproś osoby')),
   ]),
  ]))),
  FutureBuilder<List<Map<String,dynamic>>>(future:posts,builder:(context,s){
   if(s.hasError)return Text('Nie można wyświetlić postów: ${s.error}');
   if(!s.hasData)return const Center(child:CircularProgressIndicator());
   return Column(children:s.data!.map((p)=>PostCard(post:p)).toList());
  }),
 ])));
}
