import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';

class ComposeScreen extends StatefulWidget {
 final List<Map<String,dynamic>> groups;
 final String? selectedGroup;
 const ComposeScreen({super.key,required this.groups,this.selectedGroup});
 @override State<ComposeScreen> createState()=>_ComposeScreenState();
}
class _ComposeScreenState extends State<ComposeScreen> {
 final body=TextEditingController(),link=TextEditingController(),video=TextEditingController();
 String? groupId;
 XFile? photo;
 bool saving=false;
 @override void initState(){super.initState();groupId=widget.selectedGroup??(widget.groups.isNotEmpty?'${widget.groups.first['id']}':null);}
 @override void dispose(){body.dispose();link.dispose();video.dispose();super.dispose();}
 Future<void> publish() async {
  final user=db.auth.currentUser;
  if(user==null||groupId==null||body.text.trim().length<3)return;
  setState(()=>saving=true);
  try {
   final g=widget.groups.firstWhere((x)=>x['id']==groupId);
   final publicGroup=g['visibility']=='public';
   final member=await db.from('agc_group_members').select('status').eq('group_id',groupId!).eq('member_id',user.id).maybeSingle();
   if(member==null && publicGroup) {
    await db.from('agc_group_members').insert({'group_id':groupId,'member_id':user.id,'status':'active'});
   } else if(member==null && g['owner_id']!=user.id) {
    throw Exception('Nie masz dostępu do tej grupy.');
   } else if(member!=null && member['status']!='active') {
    throw Exception('Najpierw zaakceptuj zaproszenie.');
   }
   String? path;
   if(photo!=null) {
    if(!publicGroup)throw Exception('W grupach prywatnych publikowanie zdjęć jest chwilowo niedostępne.');
    final bytes=await photo!.readAsBytes();
    if(bytes.length>5*1024*1024)throw Exception('Maksymalny rozmiar zdjęcia to 5 MB.');
    final ext=photo!.name.toLowerCase().split('.').last;
    if(!['jpg','jpeg','png','webp'].contains(ext))throw Exception('Wybierz plik JPG, PNG lub WebP.');
    final now=DateTime.now().millisecondsSinceEpoch;
    path='${user.id}/${now}_${now}.$ext';
    await db.storage.from('agc-forum-images').uploadBinary(path,Uint8List.fromList(bytes),fileOptions:FileOptions(contentType:ext=='png'?'image/png':ext=='webp'?'image/webp':'image/jpeg'));
   }
   final linkText=link.text.trim(),videoText=video.text.trim();
   if(linkText.isNotEmpty && Uri.tryParse(linkText)?.scheme!='https')throw Exception('Link musi używać HTTPS.');
   if(videoText.isNotEmpty && Uri.tryParse(videoText)?.scheme!='https')throw Exception('Link do filmu musi używać HTTPS.');
   await db.from('agc_group_posts').insert({'group_id':groupId,'author_id':user.id,'body':body.text.trim(),'image_path':path,'link_url':linkText.isEmpty?null:linkText,'video_url':videoText.isEmpty?null:videoText});
   if(mounted)Navigator.pop(context,true);
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Nie udało się opublikować: $e')));}
  finally{if(mounted)setState(()=>saving=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Nowy post')),body:ListView(padding:const EdgeInsets.all(16),children:[
  DropdownButtonFormField<String>(value:groupId,decoration:const InputDecoration(labelText:'Opublikuj w grupie'),items:widget.groups.map((g)=>DropdownMenuItem<String>(value:'${g['id']}',child:Text('${g['name']}'))).toList(),onChanged:(v)=>setState(()=>groupId=v)),
  const SizedBox(height:14),
  TextField(controller:body,maxLines:6,maxLength:3000,decoration:const InputDecoration(labelText:'O czym myślisz?',border:OutlineInputBorder())),
  TextField(controller:link,decoration:const InputDecoration(labelText:'Link (opcjonalnie, https://)')),
  TextField(controller:video,decoration:const InputDecoration(labelText:'Link do filmu (opcjonalnie)')),
  const SizedBox(height:12),
  OutlinedButton.icon(onPressed:() async {final p=await ImagePicker().pickImage(source:ImageSource.gallery,imageQuality:85);if(p!=null)setState(()=>photo=p);},icon:const Icon(Icons.image),label:Text(photo==null?'Dodaj zdjęcie':'Zdjęcie: ${photo!.name}')),
  const SizedBox(height:16),
  FilledButton.icon(onPressed:saving?null:publish,icon:const Icon(Icons.publish),label:Text(saving?'Publikuję...':'Opublikuj')),
 ]));
}
