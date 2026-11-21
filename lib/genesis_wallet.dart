import 'package:flutter/material.dart';
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
          Card(child:ListTile(leading:const Icon(Icons.shopping_cart_outlined),title:Text(t('Zakup GCO','Buy GCO')),subtitle:Text(t('Jeszcze niedostępny','Not available yet')),trailing:const Icon(Icons.lock_outline))),
          Card(child:ListTile(leading:const Icon(Icons.swap_horiz),title:Text(t('Transfery i sprzedaż','Transfers and sales')),subtitle:Text(t('Jeszcze niedostępne','Not available yet')),trailing:const Icon(Icons.lock_outline))),
          const SizedBox(height:16),Text(t('Historia operacji','Transaction history'),style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold)),
          if(rows.isEmpty) Text(t('Brak operacji','No transactions')),
          for(final row in rows) ListTile(leading:const Icon(Icons.add_circle_outline),title:Text(row['reason'].toString()),subtitle:Text(row['created_at'].toString().split('T').first),trailing:Text('+${row['amount']} GCO',style:const TextStyle(color:Colors.greenAccent))),
        ]);
      }),
      const Divider(),
      ExpansionTile(title:Text(t('Zasady GENESIS COIN – etap testowy','GENESIS COIN – pilot rules')),children:[Padding(padding:const EdgeInsets.all(12),child:Text(t('GCO to bezpłatne, niezbywalne punkty przypisane do konta. Administrator przyznaje je ręcznie. Nie są kryptowalutą, środkiem płatniczym ani inwestycją. Nie mają kursu ani prawa do wypłaty. Zakup, transfer, sprzedaż i wydawanie są obecnie niedostępne. Błędy salda zgłoś operatorowi platformy. Nieuprawnione działania mogą skutkować korektą po wyjaśnieniu. Zasady nie ograniczają ustawowych praw użytkownika.','GCO are free, non-transferable account points granted manually by the administrator. They are not cryptocurrency, money or an investment. No exchange rate or redemption applies. Purchases, transfers, sales and spending are currently unavailable. Report balance errors to the platform operator. Unauthorised activity may result in corrections after review. Statutory rights remain unaffected.')))])
    ])));
  }
}
