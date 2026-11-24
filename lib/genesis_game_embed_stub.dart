import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'agc_backend.dart';

/// Native fallback: game cards open the HTML5 games in the browser.
class GenesisGameTab extends StatefulWidget {
  const GenesisGameTab({super.key});

  @override
  State<GenesisGameTab> createState() => _GenesisGameTabState();
}
class _GenesisGameTabState extends State<GenesisGameTab> {
  static const games = [
    ('signal','GENESIS SIGNAL','genesis-game.html'),('defender','GENESIS DEFENDER','genesis-defender.html'),('wolf','WILK I JAJKA','genesis-wolf-eggs.html'),('blocks','GENESIS BLOCKS','genesis-blocks.html'),('snake','GENESIS SNAKE','genesis-snake.html'),('ski','SKOKI NARCIARSKIE','skoki-narciarskie.html'),('maze','GENESIS MAZE','genesis-maze.html'),('slingshot','GENESIS SLINGSHOT','genesis-slingshot.html'),('crystals','GENESIS CRYSTALS','genesis-crystals.html'),('solitaire','GENESIS SOLITAIRE','genesis-solitaire.html'),('freecell','GENESIS FREECELL','genesis-freecell.html'),('spider','GENESIS SPIDER','genesis-spider.html'),('hearts','GENESIS KIERKI','genesis-hearts.html'),('blackjack','GENESIS BLACKJACK 21','genesis-blackjack.html'),('duck','GENESIS DUCK HUNT','genesis-duck.html')
  ];
  Set<String> favorites = {};
  String? owner;
  bool onlyFavorites=false, busy=false;
  int columns=4, revision=0;
  StreamSubscription<AuthState>? auth;
  @override
  void initState(){super.initState();if(AgcBackend.configured){_load();auth=AgcBackend.client.auth.onAuthStateChange.listen((_)=>_load());}}
  @override
  void dispose(){auth?.cancel();super.dispose();}
  Future<void> _load() async {
    final u=AgcBackend.user;final next=u==null||u.isAnonymous?null:u.id;final req=++revision;
    if(owner!=next)setState((){owner=next;favorites={};onlyFavorites=false;});
    if(next==null)return;
    try{final rows=await AgcBackend.client.from('agc_game_favorites').select('game_key').eq('user_id',next);
    if(mounted&&req==revision)setState(()=>favorites={for(final row in rows) row['game_key'] as String});}catch(_){if(mounted&&req==revision)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Nie udało się pobrać ulubionych.')));}
  }
  Future<void> _toggle(String key) async {
    final uid=owner;if(uid==null||busy||AgcBackend.user?.id!=uid)return;
    setState(()=>busy=true);
    try{if(favorites.contains(key)){await AgcBackend.client.from('agc_game_favorites').delete().eq('user_id',uid).eq('game_key',key);}else{await AgcBackend.client.from('agc_game_favorites').insert({'user_id':uid,'game_key':key});}if(mounted)await _load();}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Nie udało się zapisać ulubionych.')));}finally{if(mounted)setState(()=>busy=false);}
  }
  static const gold = Color(0xFFD8B66A);
  static const buildVersion = String.fromEnvironment(
    'AGC_BUILD_VERSION', defaultValue: 'DEV');
  static const buildDate = String.fromEnvironment(
    'AGC_BUILD_DATE', defaultValue: 'LOCAL');

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        children: [
          const Center(child: Icon(
            Icons.sports_esports_outlined, color: gold, size: 44)),
          const SizedBox(height: 10),
          const Center(child: Text('GRA',
            style: TextStyle(fontSize: 24, color: gold,
              fontWeight: FontWeight.bold))),
          const SizedBox(height: 10),
          const Center(child: Text(
            'WYBIERZ GRĘ I ODKRYWAJ NOWE WYZWANIA')),
          const SizedBox(height: 5),
          const Center(child: Text(
            'Gry otwierają się w przeglądarce.',
            style: TextStyle(fontSize: 11))),
          const SizedBox(height: 6),
          Center(child: SelectableText(
            'GENESIS ARCADE · v2026.10.19 · BUILD $buildVersion · $buildDate UTC',
            style: const TextStyle(fontSize: 10, color: Color(0xFF90B2C8)),
            textAlign: TextAlign.center)),
          const SizedBox(height: 20),
          Wrap(spacing:6,children:[for(final n in [1,2,3,4])ChoiceChip(label:Text('$n'),selected:columns==n,onSelected:(_)=>setState(()=>columns=n)),if(owner!=null)FilterChip(label:const Text('⭐ Ulubione'),selected:onlyFavorites,onSelected:(v)=>setState(()=>onlyFavorites=v))]),
          LayoutBuilder(builder:(context,box){
            final visible=games.where((g)=>!onlyFavorites||favorites.contains(g.$1)).toList()..sort((a,b)=>(favorites.contains(b.$1)?1:0).compareTo(favorites.contains(a.$1)?1:0));
            return Wrap(spacing:6,runSpacing:6,children:[for(final g in visible)SizedBox(width:(box.maxWidth-6*(columns-1))/columns,height:130,child:Card(child:InkWell(onTap:()=>_open(g.$3),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[GestureDetector(onTap:()=>_showRanking(context,g.$3),child:const Icon(Icons.emoji_events_outlined,color:gold)),Flexible(child:Text(g.$2,textAlign:TextAlign.center,maxLines:3,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11))),if(owner!=null)IconButton(tooltip:'Ulubione',visualDensity:VisualDensity.compact,onPressed:busy?null:()=>_toggle(g.$1),icon:Icon(favorites.contains(g.$1)?Icons.star:Icons.star_border,color:gold))]))))]);
          }),
        ],
      ),
    ),
  );

  Future<void> _showRanking(
    BuildContext context, String file,
  ) async {
    final key = games.firstWhere((g)=>g.$3==file).$1;
    final title = games.firstWhere((g)=>g.$3==file).$2;
    Future<List<Map<String, dynamic>>> load() async {
      final raw = await AgcBackend.client
        .from('agc_game_scores')
        .select('member_id,best_score,best_level,updated_at')
        .eq('game_key', key)
        .order('best_score', ascending: false)
        .order('updated_at', ascending: true)
        .limit(100);
      final scores = List<Map<String, dynamic>>.from(raw);
      if (scores.isEmpty) {
        return scores;
      }
      final ids = scores.map((e) => e['member_id'] as String).toList();
      final members = await AgcBackend.client
        .from('agc_public_scores')
        .select('id,handle')
        .inFilter('id', ids);
      final names = <String, String>{
        for (final m in members)
          m['id'] as String: m['handle'] as String? ?? 'Genesis',
      };
      return scores.map((e) => {
        ...e,
        'handle': names[e['member_id']] ?? 'Genesis',
      }).toList();
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .7,
        child: Column(children: [
          const Icon(Icons.emoji_events_outlined, color: gold, size: 32),
          const SizedBox(height: 5),
          Text('RANKING · $title', style: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 12),
          Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
            future: load(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Center(child: Text(
                  'Nie udało się pobrać rankingu.'));
              }
              final rows = snapshot.data ?? [];
              if (rows.isEmpty) {
                return const Center(child: Text(
                  'Brak wyników. Zostań pierwszym graczem!'));
              }
              return ListView.builder(
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  return ListTile(
                    leading: CircleAvatar(child: Text('${index + 1}')),
                    title: Text('${row['handle']}'),
                    subtitle: Text('Poziom / fala: ${row['best_level']}'),
                    trailing: Text('${row['best_score']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold, color: gold)),
                  );
                },
              );
            },
          )),
        ]),
      )),
    );
  }

  Future<void> _open(String file) async {
    await launchUrl(
      Uri.parse('https://thegenesisera.com/$file'),
      mode: LaunchMode.externalApplication,
    );
  }
}
