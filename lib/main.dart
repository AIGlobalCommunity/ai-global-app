import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'social.dart';
import 'ai.dart';

const projectUrl = 'https://gjnddmurmegbklvedhnp.supabase.co';
const publishableKey = 'sb_publishable_Ty3Beae5ztODv0MM3Z_HDA_WEGwOyLP';
final db = Supabase.instance.client;
const dark = Color(0xFF0D1837);
const accent = Color(0xFF5A65F5);
const gold = Color(0xFFFFD98A);

Future<void> main() async {
 WidgetsFlutterBinding.ensureInitialized();
 try {
  await Supabase.initialize(url: projectUrl, publishableKey: publishableKey);
  runApp(const CommunityApp());
 } catch (e) {
  runApp(MaterialApp(home:Scaffold(body:Center(child:Padding(padding:const EdgeInsets.all(24),child:Text('Nie można połączyć się z serwisem. Sprawdź połączenie internetowe i odśwież stronę.\n$e',textAlign:TextAlign.center))))));
 }
}

class CommunityApp extends StatelessWidget {
 const CommunityApp({super.key});
 @override Widget build(BuildContext context)=>MaterialApp(
  title:'AI Global Community — społeczność przyszłości',
  debugShowCheckedModeBanner:false,
  theme:ThemeData(
   useMaterial3:true,
   fontFamily:'Roboto',
   colorScheme:ColorScheme.fromSeed(seedColor:accent,brightness:Brightness.light),
   scaffoldBackgroundColor:const Color(0xFFF5F7FD),
   appBarTheme:const AppBarTheme(backgroundColor:Colors.white,foregroundColor:dark,elevation:0,scrolledUnderElevation:0),
   cardTheme:CardThemeData(color:Colors.white,elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20),side:const BorderSide(color:Color(0xFFE8EBF5)))),
   filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(backgroundColor:accent,foregroundColor:Colors.white,padding:const EdgeInsets.symmetric(horizontal:20,vertical:16),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)))),
   inputDecorationTheme:InputDecorationTheme(border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)),contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:14)),
  ),
  home:const CommunityShell(),
 );
}

class AGCLogo extends StatelessWidget {
 final double size;
 const AGCLogo({super.key,this.size=42});
 @override Widget build(BuildContext context)=>Container(
  width:size,height:size,
  decoration:const BoxDecoration(shape:BoxShape.circle,gradient:LinearGradient(colors:[Color(0xFF8798FF),Color(0xFF4054DA)],begin:Alignment.topLeft,end:Alignment.bottomRight)),
  child:Icon(Icons.public_rounded,color:Colors.white,size:size*0.64),
 );
}

class CommunityShell extends StatefulWidget {
 const CommunityShell({super.key});
 @override State<CommunityShell> createState()=>_CommunityShellState();
}
class _CommunityShellState extends State<CommunityShell> {
 int tab=0;
 late final StreamSubscription<AuthState> subscription;
 @override void initState(){
  super.initState();
  subscription=db.auth.onAuthStateChange.listen((event){
   if(mounted)setState((){if(event.session==null && tab==4)tab=0;});
  });
 }
 @override void dispose(){subscription.cancel();super.dispose();}
 void goLogin(){setState(()=>tab=3);}
 @override Widget build(BuildContext context){
  final loggedIn=db.auth.currentUser!=null;
  final screens=<Widget>[
   FeedScreen(key:ValueKey('feed-$loggedIn'),onLogin:goLogin),
   const GroupsScreen(),
   const DiscoverScreen(),
   loggedIn?const ProfileScreen():AuthScreen(onSuccess:()=>setState(()=>tab=3)),
   loggedIn?const AiScreen():AuthScreen(onSuccess:()=>setState(()=>tab=4)),
  ];
  return Scaffold(
   appBar:AppBar(
    title:Row(mainAxisSize:MainAxisSize.min,children:[
     const AGCLogo(size:38),const SizedBox(width:10),
     const Flexible(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('AI GLOBAL',style:TextStyle(fontWeight:FontWeight.w900,fontSize:17,letterSpacing:1.2,color:dark)),
      Text('COMMUNITY',style:TextStyle(fontWeight:FontWeight.w700,fontSize:10,letterSpacing:3,color:accent)),
     ])),
    ]),
    actions:[
     if(!loggedIn)Padding(padding:const EdgeInsets.only(right:12),child:FilledButton.icon(onPressed:goLogin,icon:const Icon(Icons.login,size:18),label:const Text('Zaloguj'))),
     if(loggedIn)PopupMenuButton<String>(tooltip:'Moje konto',icon:const Icon(Icons.account_circle_outlined),onSelected:(value) async {
      if(value=='logout'){await db.auth.signOut();if(mounted)setState(()=>tab=0);}
      if(value=='profile')setState(()=>tab=3);
     },itemBuilder:(_)=>const [
      PopupMenuItem(value:'profile',child:Text('Mój profil')),
      PopupMenuItem(value:'logout',child:Text('Wyloguj')),
     ]),
    ],
   ),
   body:SafeArea(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1024),child:screens[tab]))),
   bottomNavigationBar:NavigationBar(
    height:72,
    backgroundColor:Colors.white,
    selectedIndex:tab,
    onDestinationSelected:(index)=>setState(()=>tab=index),
    destinations:const [
     NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'Start'),
     NavigationDestination(icon:Icon(Icons.groups_outlined),selectedIcon:Icon(Icons.groups),label:'Grupy'),
     NavigationDestination(icon:Icon(Icons.search),label:'Szukaj'),
     NavigationDestination(icon:Icon(Icons.person_outline),selectedIcon:Icon(Icons.person),label:'Konto'),
     NavigationDestination(icon:Icon(Icons.auto_awesome_outlined),selectedIcon:Icon(Icons.auto_awesome),label:'AI'),
    ],
   ),
  );
 }
}

class AuthScreen extends StatefulWidget {
 final VoidCallback? onSuccess;
 const AuthScreen({super.key,this.onSuccess});
 @override State<AuthScreen> createState()=>_AuthScreenState();
}
class _AuthScreenState extends State<AuthScreen> {
 final email=TextEditingController(),password=TextEditingController(),name=TextEditingController();
 bool busy=false,register=false,obscure=true,reset=false;
 String? info;
 bool infoError=false;
 @override void dispose(){email.dispose();password.dispose();name.dispose();super.dispose();}
 Future<void> submit() async {
  final address=email.text.trim();
  if(!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(address)){setState((){info='Podaj poprawny adres e-mail.';infoError=true;});return;}
  if(!reset && password.text.length<6){setState((){info='Hasło musi mieć co najmniej 6 znaków.';infoError=true;});return;}
  setState((){busy=true;info=null;});
  try {
   if(reset){
    await db.auth.resetPasswordForEmail(address);
    if(mounted)setState((){info='Wysłaliśmy wiadomość umożliwiającą odzyskanie hasła. Sprawdź pocztę.';infoError=false;});
   } else if(register){
    final result=await db.auth.signUp(email:address,password:password.text,data:{'display_name':name.text.trim()});
    if(!mounted)return;
    if(result.session==null){
     setState((){info='Konto utworzone. Otwórz wiadomość w poczcie i potwierdź e-mail, a następnie zaloguj się.';infoError=false;register=false;});
    }else{
     widget.onSuccess?.call();
    }
   }else{
    await db.auth.signInWithPassword(email:address,password:password.text);
    widget.onSuccess?.call();
   }
  } on AuthException catch(e){
   if(mounted)setState((){info=e.message;infoError=true;});
  }catch(_){
   if(mounted)setState((){info='Nie udało się połączyć z serwisem logowania. Spróbuj ponownie.';infoError=true;});
  }finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context)=>Center(child:SingleChildScrollView(padding:const EdgeInsets.all(18),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:460),child:Card(child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
  const Center(child:AGCLogo(size:72)),const SizedBox(height:14),
  Text(reset?'Odzyskaj dostęp':register?'Dołącz do AI Global Community':'Witaj w AI Global Community',textAlign:TextAlign.center,style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w800,color:dark)),
  const SizedBox(height:8),
  Text(reset?'Podaj adres e-mail powiązany z kontem.':register?'Załóż konto, aby publikować i dołączać do grup.':'Zaloguj się, aby rozmawiać, tworzyć posty i korzystać z AI.',textAlign:TextAlign.center,style:const TextStyle(color:Colors.blueGrey)),
  const SizedBox(height:24),
  if(register) ...[TextField(controller:name,textCapitalization:TextCapitalization.words,decoration:const InputDecoration(labelText:'Nazwa wyświetlana',prefixIcon:Icon(Icons.badge_outlined))),const SizedBox(height:12)],
  TextField(controller:email,keyboardType:TextInputType.emailAddress,autofillHints:const [AutofillHints.email],decoration:const InputDecoration(labelText:'Adres e-mail',prefixIcon:Icon(Icons.mail_outline))),
  if(!reset)...[const SizedBox(height:12),TextField(controller:password,obscureText:obscure,autofillHints:[register?AutofillHints.newPassword:AutofillHints.password],decoration:InputDecoration(labelText:'Hasło',prefixIcon:const Icon(Icons.lock_outline),suffixIcon:IconButton(onPressed:()=>setState(()=>obscure=!obscure),icon:Icon(obscure?Icons.visibility_outlined:Icons.visibility_off_outlined))))],
  if(info!=null)...[const SizedBox(height:14),Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:infoError?const Color(0xFFFFE9E9):const Color(0xFFEAF6EE),borderRadius:BorderRadius.circular(10)),child:Text(info!,style:TextStyle(color:infoError?const Color(0xFF9E2525):const Color(0xFF23623D))))],
  const SizedBox(height:20),
  FilledButton.icon(onPressed:busy?null:submit,icon:Icon(reset?Icons.mail_outline:register?Icons.person_add_alt_1:Icons.login),label:Text(busy?'Proszę czekać...':reset?'Wyślij link':register?'Utwórz konto':'Zaloguj się')),
  if(!reset)TextButton(onPressed:busy?null:()=>setState((){register=!register;info=null;}),child:Text(register?'Masz już konto? Zaloguj się':'Nie masz konta? Zarejestruj się')),
  TextButton(onPressed:busy?null:()=>setState((){reset=!reset;register=false;info=null;}),child:Text(reset?'Wróć do logowania':'Nie pamiętasz hasła?')),
  const SizedBox(height:6),
  const Text('Bezpieczne logowanie przez Supabase Auth',textAlign:TextAlign.center,style:TextStyle(fontSize:12,color:Colors.blueGrey)),
 ]))))));
}
