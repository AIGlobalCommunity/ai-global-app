import 'package:flutter/material.dart';
import 'main.dart';
import 'feed.dart';
import 'posts.dart';
import 'groups.dart';

class DiscoverScreen extends StatefulWidget {
 const DiscoverScreen({super.key});
 @override State<DiscoverScreen> createState()=>_DiscoverScreenState();
}
class _DiscoverScreenState extends State<DiscoverScreen> {
 final query=TextEditingController();
 bool people=true;
 late Future<List<Map<String,dynamic>>> results;
 @override void initState(){super.initState();search();}
 void search(){results=_search();}
 Future<List<Map<String,dynamic>>> _search() async {
  final q=query.text.trim();
  if(people){
   final r=await db.from('agc_social_profiles').select('member_id,display_name,bio,interests,location_text,avatar_url').eq('is_public',true).limit(100);
   return List<Map<String,dynamic>>.from(r).where((x)=>q.isEmpty||'${x['display_name']} ${x['bio']} ${x['interests']}'.toLowerCase().contains(q.toLowerCase())).toList();
  }
  final r=await db.from('agc_groups').select('id,name,description,visibility,owner_id,official').limit(100);
  return List<Map<String,dynamic>>.from(r).where((x)=>q.isEmpty||'${x['name']} ${x['description']}'.toLowerCase().contains(q.toLowerCase())).toList();
 }
 @override void dispose(){query.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>Column(children:[
  Padding(padding:const EdgeInsets.all(12),child:Column(children:[
   TextField(controller:query,onChanged:(_)=>setState(search),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Szukaj użytkowników lub grup',border:OutlineInputBorder())),
   const SizedBox(height:8),
   SegmentedButton<bool>(segments:const [ButtonSegment(value:true,label:Text('Użytkownicy'),icon:Icon(Icons.people)),ButtonSegment(value:false,label:Text('Grupy'),icon:Icon(Icons.groups))],selected:{people},onSelectionChanged:(v)=>setState((){people=v.first;search();})),
  ])),
  Expanded(child:FutureBuilder<List<Map<String,dynamic>>>(future:results,builder:(context,s){
   if(s.hasError)return Center(child:Text('Błąd wyszukiwania: ${s.error}'));
   if(!s.hasData)return const Center(child:CircularProgressIndicator());
   if(s.data!.isEmpty)return const Center(child:Text('Brak wyników.'));
   return ListView(children:s.data!.map((x)=>Card(margin:const EdgeInsets.symmetric(horizontal:12,vertical:4),child:ListTile(
    leading:CircleAvatar(child:Icon(people?Icons.person:Icons.groups)),
    title:Text('${people?(x['display_name']??'Użytkownik'):x['name']}'),
    subtitle:Text('${people?(x['bio']??''):x['description']}',maxLines:2,overflow:TextOverflow.ellipsis),
    onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>people?PublicProfile(memberId:'${x['member_id']}'):GroupDetail(group:x))),
   ))).toList());
  })),
 ]);
}

class ProfileScreen extends StatefulWidget {
 const ProfileScreen({super.key});
 @override State<ProfileScreen> createState()=>_ProfileScreenState();
}
class _ProfileScreenState extends State<ProfileScreen> {
 late Future<Map<String,dynamic>?> profile;
 late Future<List<Map<String,dynamic>>> posts;
 @override void initState(){super.initState();reload();}
 void reload(){
  final id=db.auth.currentUser!.id;
  profile=db.from('agc_social_profiles').select().eq('member_id',id).maybeSingle();
  posts=communityFeed(authorId:id);
 }
 Future<void> edit() async {
  final result=await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>const EditProfileScreen()));
  if(result==true)setState(reload);
 }
 Future<void> compose() async {
  final r=await db.from('agc_groups').select('id,name,visibility,owner_id').eq('visibility','public').order('name');
  if(!mounted)return;
  final result=await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>ComposeScreen(groups:List<Map<String,dynamic>>.from(r))));
  if(result==true)setState(reload);
 }
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(12),children:[
  FutureBuilder<Map<String,dynamic>?>(future:profile,builder:(context,s){
   if(s.hasError)return Text('Błąd profilu: ${s.error}');
   final p=s.data;
   return Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    if(p?['cover_url']!=null)Image.network('${p!['cover_url']}',height:130,width:double.infinity,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const SizedBox.shrink()),
    const SizedBox(height:12),
    const CircleAvatar(radius:28,child:Icon(Icons.person,size:32)),
    const SizedBox(height:10),
    Text('${p?['display_name']??db.auth.currentUser?.email??'Mój profil'}',style:Theme.of(context).textTheme.headlineSmall),
    Text('${p?['bio']??'Dodaj opis, zainteresowania i informacje o sobie.'}'),
    if(p?['interests']!=null)Text('Zainteresowania: ${p!['interests']}'),
    if(p?['location_text']!=null)Text('Lokalizacja: ${p!['location_text']}'),
    if(p?['website']!=null)Text('Strona: ${p!['website']}'),
    const SizedBox(height:12),
    Wrap(spacing:8,children:[
     OutlinedButton.icon(onPressed:edit,icon:const Icon(Icons.edit),label:const Text('Edytuj profil')),
     FilledButton.icon(onPressed:compose,icon:const Icon(Icons.add),label:const Text('Dodaj wpis')),
    ]),
   ])));
  }),
  Padding(padding:const EdgeInsets.all(12),child:Text('Moje wpisy',style:Theme.of(context).textTheme.titleLarge)),
  FutureBuilder<List<Map<String,dynamic>>>(future:posts,builder:(context,s){
   if(s.hasError)return Text('Błąd: ${s.error}');
   if(!s.hasData)return const Center(child:CircularProgressIndicator());
   return Column(children:s.data!.map((p)=>PostCard(post:p)).toList());
  }),
 ]);
}
class PublicProfile extends StatelessWidget {
 final String memberId;
 const PublicProfile({super.key,required this.memberId});
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Profil użytkownika')),body:ListView(padding:const EdgeInsets.all(12),children:[
  FutureBuilder<Map<String,dynamic>?>(future:db.from('agc_social_profiles').select().eq('member_id',memberId).eq('is_public',true).maybeSingle(),builder:(context,s){
   if(!s.hasData)return const Card(child:Padding(padding:EdgeInsets.all(18),child:Text('Profil nie jest publiczny lub jest niedostępny.')));
   final p=s.data!;
   return Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text('${p['display_name']??'Użytkownik'}',style:Theme.of(context).textTheme.headlineSmall),
    Text('${p['bio']??''}'),
    Text('${p['interests']??''}'),
    Text('${p['location_text']??''}'),
   ])));
  }),
  FutureBuilder<List<Map<String,dynamic>>>(future:communityFeed(authorId:memberId),builder:(context,s){
   if(!s.hasData)return const Center(child:CircularProgressIndicator());
   return Column(children:s.data!.map((p)=>PostCard(post:p)).toList());
  }),
 ]));
}
class EditProfileScreen extends StatefulWidget {
 const EditProfileScreen({super.key});
 @override State<EditProfileScreen> createState()=>_EditProfileScreenState();
}
class _EditProfileScreenState extends State<EditProfileScreen> {
 final fields=List.generate(7,(_)=>TextEditingController());
 bool isPublic=true,saving=false;
 final names=['Nazwa wyświetlana','O mnie','Zainteresowania','Strona WWW (https://)','Lokalizacja','URL zdjęcia profilowego (https://)','URL zdjęcia w tle (https://)'];
 final keys=['display_name','bio','interests','website','location_text','avatar_url','cover_url'];
 @override void initState(){super.initState();load();}
 Future<void> load() async {
  final p=await db.from('agc_social_profiles').select().eq('member_id',db.auth.currentUser!.id).maybeSingle();
  if(p!=null && mounted)setState((){for(var i=0;i<keys.length;i++){fields[i].text='${p[keys[i]]??''}';}isPublic=p['is_public']!=false;});
 }
 @override void dispose(){for(final f in fields){f.dispose();}super.dispose();}
 Future<void> save() async {
  setState(()=>saving=true);
  try {
   final data=<String,dynamic>{'member_id':db.auth.currentUser!.id,'is_public':isPublic};
   for(var i=0;i<keys.length;i++){data[keys[i]]=fields[i].text.trim().isEmpty?null:fields[i].text.trim();}
   await db.from('agc_social_profiles').upsert(data,onConflict:'member_id');
   if(mounted)Navigator.pop(context,true);
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Błąd zapisu: $e')));}
  finally{if(mounted)setState(()=>saving=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Edytuj profil')),body:ListView(padding:const EdgeInsets.all(16),children:[
  ...List.generate(fields.length,(i)=>Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(controller:fields[i],maxLines:i==1?3:1,decoration:InputDecoration(labelText:names[i],border:const OutlineInputBorder())))),
  SwitchListTile(title:const Text('Profil publiczny'),subtitle:const Text('Inni użytkownicy mogą Cię wyszukać.'),value:isPublic,onChanged:(v)=>setState(()=>isPublic=v)),
  FilledButton(onPressed:saving?null:save,child:Text(saving?'Zapisuję...':'Zapisz profil')),
 ]));
}
