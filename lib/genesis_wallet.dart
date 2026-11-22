import 'package:flutter/material.dart';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
import 'agc_backend.dart';
import 'genesis_language.dart';

class GenesisWallet extends StatefulWidget {
  const GenesisWallet({super.key});
  @override
  State<GenesisWallet> createState() => _GenesisWalletState();
}
class _GenesisWalletState extends State<GenesisWallet> {
  late Future<Map<String,dynamic>> data;
  @override
  void initState() { super.initState(); data = load(); }
  Future<Map<String,dynamic>> load() async {
    final user = AgcBackend.user;
    if (user == null || user.isAnonymous) return {};
    final balance = await AgcBackend.client.rpc('agc_coin_balance');
    final rows = await AgcBackend.client.from('agc_coin_ledger').select('amount,reason,created_at').eq('member_id',user.id).order('created_at',ascending:false).limit(100);
    return {'balance':balance,'rows':rows};
  }
  void refresh() => setState(() => data=load());
  bool sending=false;
  String requestId(){ final r=Random.secure(); final a=List.generate(16,(_)=>r.nextInt(256)); a[6]=(a[6]&15)|64;a[8]=(a[8]&63)|128;final h=a.map((v)=>v.toRadixString(16).padLeft(2,'0')).join();return '${h.substring(0,8)}-${h.substring(8,12)}-${h.substring(12,16)}-${h.substring(16,20)}-${h.substring(20)}';}
  Future<void> transfer() async {
    if(sending)return;
    String recipient='',amount='';
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text(t('Przelew GCO','Send GCO')),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(onChanged:(v)=>recipient=v,decoration:InputDecoration(labelText:t('E-mail lub nick','Email or nickname'))),TextField(onChanged:(v)=>amount=v,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'GCO'))]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(t('Anuluj','Cancel'))),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(t('Dalej','Next')))]));
    if(ok!=true||!mounted)return;
    final points=int.tryParse(amount.trim());if(points==null||points<=0||recipient.trim().isEmpty)return;
    final confirm=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text(t('Potwierdź przelew','Confirm transfer')),content:Text('$points GCO → ${recipient.trim()}'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(t('Anuluj','Cancel'))),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(t('Wyślij','Send')))]));
    if(confirm!=true||!mounted||sending)return;
    setState(()=>sending=true);
    try{await AgcBackend.client.rpc('agc_coin_transfer',params:{'p_recipient':recipient.trim(),'p_amount':points,'p_request':requestId()});if(mounted){refresh();ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(t('Przelew wykonany','Transfer completed'))));}}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(t('Nie potwierdzono przelewu. Sprawdź historię i saldo.','Transfer not confirmed. Check history and balance.'))));}finally{if(mounted)setState(()=>sending=false);}
  }
  String t(String pl,String en)=>GenesisLanguage.copy(pl,en);
  @override
  Widget build(BuildContext context) {
    final user=AgcBackend.user;
    if(user==null||user.isAnonymous) return Center(child:Text(t('Zaloguj się na stałe konto, aby otworzyć portfel.','Sign in to a permanent account to open your wallet.')));
    return Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:680),child:ListView(padding:const EdgeInsets.all(18),children:[
      Row(mainAxisAlignment:MainAxisAlignment.center,children:[const Icon(Icons.account_balance_wallet_outlined,color:Color(0xFFD8B66A),size:30),const SizedBox(width:8),const Text('GENESIS WALLET',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),IconButton(onPressed:refresh,icon:const Icon(Icons.refresh))]),
      FutureBuilder<Map<String,dynamic>>(future:data,builder:(context,snapshot){
        if(snapshot.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
        if(snapshot.hasError)return Text(t('Nie udało się pobrać portfela. Odśwież.','Unable to load wallet. Refresh.'));
        final result=snapshot.data??{};
        final rows=(result['rows'] as List?)??[];
        return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Card(child:Padding(padding:const EdgeInsets.all(24),child:Column(children:[
            Container(width:76,height:76,decoration:const BoxDecoration(shape:BoxShape.circle,gradient:LinearGradient(colors:[Color(0xFFFFE9A3),Color(0xFF966525)])),child:const Center(child:Text('G',style:TextStyle(fontSize:46,fontWeight:FontWeight.w900,color:Color(0xFF31200B))))),
            const SizedBox(height:12),Text(t('Dostępne saldo','Available balance')),
            Text('${result['balance']??0} GCO',style:const TextStyle(fontSize:34,fontWeight:FontWeight.bold,color:Color(0xFFD8B66A))),
            const Text('GENESIS COIN'),
          ]))),
          Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            const Text('1 zł = 10 GCO',textAlign:TextAlign.center,style:TextStyle(fontSize:24,fontWeight:FontWeight.bold,color:Color(0xFFD8B66A))),
            Text(t('Podaj dokładny nick z platformy w wiadomości do wpłaty. GCO przyznajemy po ręcznej weryfikacji.','Include your exact platform nickname in the payment message. GCO are credited after manual verification.')),
            const SizedBox(height:12),
            FilledButton.icon(onPressed:() async {await launchUrl(Uri.parse('https://buycoffee.to/lektuno.pl/genesis-coins-gco-wesprzyj-rozwoj-swiata-gier'),mode:LaunchMode.externalApplication);},icon:const Icon(Icons.volunteer_activism),label:Text(t('WESPRZYJ I OTRZYMAJ GCO','SUPPORT AND RECEIVE GCO'))),
          ]))),
          Card(child:ListTile(onTap:sending?null:transfer,leading:const Icon(Icons.swap_horiz),title:Text(t('Przelej GCO','Send GCO')),subtitle:Text(t('E-mail lub nick · bez opłat','Email or nickname · free')),trailing:const Icon(Icons.chevron_right))),
          const SizedBox(height:16),Text(t('Historia operacji','Transaction history'),style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold)),
          if(rows.isEmpty) Text(t('Brak operacji','No transactions')),
          for(final row in rows) ListTile(leading:const Icon(Icons.add_circle_outline),title:Text(row['reason'].toString()),subtitle:Text(row['created_at'].toString().split('T').first),trailing:Text('${(row['amount'] as num)>0?'+':''}${row['amount']} GCO',style:TextStyle(color:(row['amount'] as num)>0?Colors.greenAccent:Colors.orangeAccent))),
        ]);
      }),
      const Divider(),
      ExpansionTile(title:Text(t('Zasady GENESIS COIN','GENESIS COIN rules')),children:[Padding(padding:const EdgeInsets.all(12),child:Text(t('GCO to wirtualne żetony przypisane do konta. Administrator przyznaje je ręcznie, także za wsparcie platformy: 10 GCO za 1 zł. Nie są kryptowalutą, środkiem płatniczym ani inwestycją. Nie podlegają wymianie na pieniądze. Transfer żetonów między kontami jest bezpłatny. Wsparcie jest dobrowolne. Błędy salda zgłoś operatorowi platformy. Nieuprawnione działania mogą skutkować korektą po wyjaśnieniu. Zasady nie ograniczają ustawowych praw użytkownika.','GCO are virtual account tokens granted manually, including for platform support at 10 GCO per PLN. They are not cryptocurrency, money or an investment. No cash redemption applies. Free transfers between accounts are available. Support is voluntary. Report balance errors to the platform operator. Unauthorised activity may result in corrections after review. Statutory rights remain unaffected.')))])
    ])));
  }
}
