import 'package:flutter/material.dart';
import 'main.dart';

class AiScreen extends StatefulWidget {
 const AiScreen({super.key});
 @override State<AiScreen> createState()=>_AiScreenState();
}
class _AiScreenState extends State<AiScreen> {
 final controller=TextEditingController();
 List<Map<String,dynamic>> messages=[];
 bool busy=false;
 String? error;
 @override void initState(){super.initState();load();}
 @override void dispose(){controller.dispose();super.dispose();}
 Future<void> load() async {
  try {
   final result=await db.from('agc_ai_messages').select('role,body,created_at').eq('member_id',db.auth.currentUser!.id).order('created_at').limit(100);
   if(!mounted)return;
   setState(()=>messages=List<Map<String,dynamic>>.from(result));
   if(messages.isEmpty)await send(welcome:true);
  }catch(e){if(mounted)setState(()=>error='Nie można pobrać historii: $e');}
 }
 Future<void> send({bool welcome=false}) async {
  final text=welcome?'':controller.text.trim();
  if(!welcome && (text.length<2||text.length>2000))return;
  if(!welcome)controller.clear();
  setState((){busy=true;error=null;if(!welcome)messages.add({'role':'user','body':text});});
  try {
   final response=await db.functions.invoke('agc-ai-chat',body:{'welcome':welcome,'message':text});
   if(response.status!=200)throw Exception('${response.data}');
   final answer=response.data is Map?response.data['reply']:null;
   if(answer==null)throw Exception('Brak odpowiedzi AI');
   if(mounted)setState(()=>messages.add({'role':'assistant','body':'$answer'}));
  }catch(e){if(mounted)setState(()=>error='Asystent AI jest niedostępny: $e');}
  finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context)=>Column(children:[
  Container(width:double.infinity,padding:const EdgeInsets.all(14),color:const Color(0xFFE8EEFF),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Text('🤖 Asystent AI Global Community',style:TextStyle(fontWeight:FontWeight.bold,fontSize:17)),
   Text('Rozmawiasz z systemem AI, nie z człowiekiem. Odpowiedzi mogą zawierać błędy.'),
  ])),
  Expanded(child:ListView(padding:const EdgeInsets.all(12),children:[
   if(messages.isEmpty && !busy)const Padding(padding:EdgeInsets.all(16),child:Text('Napisz wiadomość, aby rozpocząć rozmowę.')),
   ...messages.map((m){
    final mine=m['role']=='user';
    return Align(alignment:mine?Alignment.centerRight:Alignment.centerLeft,child:Container(
     constraints:const BoxConstraints(maxWidth:560),
     margin:const EdgeInsets.symmetric(vertical:5),
     padding:const EdgeInsets.all(12),
     decoration:BoxDecoration(color:mine?const Color(0xFFDFE7FF):Colors.white,borderRadius:BorderRadius.circular(16)),
     child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(mine?'Ty':'AI Global Community',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:12)),
      const SizedBox(height:5),Text('${m['body']}'),
     ]),
    ));
   }),
   if(busy)const ListTile(leading:CircularProgressIndicator(),title:Text('AI pisze...')),
   if(error!=null)Padding(padding:const EdgeInsets.all(12),child:Text(error!,style:const TextStyle(color:Colors.red))),
  ])),
  Padding(padding:const EdgeInsets.all(12),child:Row(children:[
   Expanded(child:TextField(controller:controller,maxLength:2000,maxLines:2,decoration:const InputDecoration(hintText:'Zapytaj AI...',border:OutlineInputBorder()))),
   const SizedBox(width:8),
   IconButton.filled(onPressed:busy?null:()=>send(),icon:const Icon(Icons.send)),
  ])),
 ]);
}
