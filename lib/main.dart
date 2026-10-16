import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'social.dart';
import 'ai.dart';

const projectUrl = 'https://gjnddmurmegbklvedhnp.supabase.co';
const publishableKey = 'sb_publishable_Ty3Beae5ztODv0MM3Z_HDA_WEGwOyLP';
final db = Supabase.instance.client;
const dark = Color(0xFF172448);
const accent = Color(0xFF4464EA);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: projectUrl, anonKey: publishableKey);
  runApp(const CommunityApp());
}

class CommunityApp extends StatelessWidget {
  const CommunityApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'AI Global Community',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: accent), scaffoldBackgroundColor: const Color(0xFFF5F7FC), appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: dark)),
    home: const CommunityShell(),
  );
}

class CommunityShell extends StatefulWidget {
  const CommunityShell({super.key});
  @override
  State<CommunityShell> createState() => _CommunityShellState();
}

class _CommunityShellState extends State<CommunityShell> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final loggedIn = db.auth.currentUser != null;
    final screens = <Widget>[
      FeedScreen(key: ValueKey('feed-$loggedIn')),
      const GroupsScreen(),
      const DiscoverScreen(),
      loggedIn ? const ProfileScreen() : const LoginScreen(),
      loggedIn ? const AiScreen() : const LoginScreen(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          CircleAvatar(backgroundColor: accent, child: Icon(Icons.public, color: Colors.white)),
          SizedBox(width: 10),
          Flexible(child: Text('AI GLOBAL COMMUNITY', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
        ]),
        actions: [
          if (loggedIn) IconButton(tooltip: 'Wyloguj', onPressed: () async {await db.auth.signOut(); if(mounted) setState(() => tab=0);}, icon: const Icon(Icons.logout)),
          if (!loggedIn) TextButton(onPressed: () => setState(() => tab=3), child: const Text('Zaloguj')),
        ],
      ),
      body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: screens[tab]))),
      bottomNavigationBar: NavigationBar(
        height: 72,
        selectedIndex: tab,
        onDestinationSelected: (index) => setState(() => tab=index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Główna'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Grupy'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Szukaj'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
          NavigationDestination(icon: Icon(Icons.smart_toy_outlined), selectedIcon: Icon(Icons.smart_toy), label: 'AI'),
        ],
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final email=TextEditingController(), password=TextEditingController();
  bool busy=false, register=false;
  String? info;
  @override
  void dispose() {email.dispose();password.dispose();super.dispose();}
  Future<void> submit() async {
    if(email.text.trim().isEmpty || password.text.length<6) {setState(()=>info='Podaj e-mail i hasło (min. 6 znaków).');return;}
    setState(() {busy=true;info=null;});
    try {
      if(register) {
        final result=await db.auth.signUp(email:email.text.trim(),password:password.text);
        setState(()=>info=result.session==null?'Sprawdź skrzynkę i potwierdź adres e-mail.':'Konto utworzone.');
      } else {
        await db.auth.signInWithPassword(email:email.text.trim(),password:password.text);
        if(mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder:(_)=>const CommunityShell()));
      }
    } catch(e) {setState(()=>info='Nie udało się zalogować: $e');}
    finally {if(mounted)setState(()=>busy=false);}
  }
  @override
  Widget build(BuildContext context)=>Center(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:Card(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[
    const Icon(Icons.public,size:50,color:accent),const SizedBox(height:12),
    Text(register?'Dołącz do społeczności':'Witaj ponownie',style:Theme.of(context).textTheme.headlineSmall),
    const SizedBox(height:16),
    TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'E-mail',border:OutlineInputBorder())),
    const SizedBox(height:12),
    TextField(controller:password,obscureText:true,decoration:const InputDecoration(labelText:'Hasło',border:OutlineInputBorder())),
    const SizedBox(height:12),
    if(info!=null) Text(info!,style:const TextStyle(color:dark)),
    FilledButton(onPressed:busy?null:submit,child:Text(busy?'Proszę czekać...':register?'Utwórz konto':'Zaloguj')),
    TextButton(onPressed:()=>setState(()=>register=!register),child:Text(register?'Mam już konto':'Utwórz nowe konto')),
  ])))));
}
