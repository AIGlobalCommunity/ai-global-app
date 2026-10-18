import 'dart:async';

import 'package:flutter/material.dart';
import 'agc_backend.dart';
import 'agc_luxury_theme.dart';
import 'genesis_language.dart';
import 'genesis_social_profile.dart';

String chatText(String pl, String en) => GenesisLanguage.copy(pl, en);

/// Genesis Chat: private member-to-member messages and the existing
/// future-AI question room. They are intentionally separate conversations.
class GenesisChat extends StatefulWidget {
  const GenesisChat({super.key});

  @override
  State<GenesisChat> createState() => _GenesisChatState();
}

class _GenesisChatState extends State<GenesisChat> {
  bool questions = false;
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> messages = [];
  Map<String, String> names = {};
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    refresh();
    refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && !questions) {
        refresh(silent: true);
      }
    });
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> refresh({bool silent = false}) async {
    final me = AgcBackend.user?.id;
    if (me == null) {
      return;
    }
    if (!silent && mounted) {
      setState(() { loading = true; error = null; });
    }
    try {
      final rows = await AgcBackend.client.from('agc_direct_messages')
        .select('id,sender_id,recipient_id,body,created_at')
        .or('sender_id.eq.$me,recipient_id.eq.$me')
        .order('created_at', ascending: false).limit(500);
      final fetched = List<Map<String, dynamic>>.from(rows);
      final peers = fetched.map((m) => m['sender_id'] == me
        ? m['recipient_id'] as String : m['sender_id'] as String).toSet();
      final labels = <String, String>{};
      if (peers.isNotEmpty) {
        final members = await AgcBackend.client.from('agc_public_scores')
          .select('id,handle').inFilter('id', peers.toList());
        for (final member in members) {
          labels[member['id'] as String] =
            member['handle'] as String? ?? chatText('Członek', 'Member');
        }
      }
      if (mounted) {
        setState(() {
        messages = fetched;
        names = labels;
        loading = false;
        error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
        loading = false;
        if (!silent) {
          error = chatText('Nie udało się pobrać rozmów.',
            'Could not load conversations.');
        }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = AgcBackend.user?.id;
    final lastByPeer = <String, Map<String, dynamic>>{};
    for (final message in messages) {
      final peer = message['sender_id'] == me
        ? message['recipient_id'] as String : message['sender_id'] as String;
      lastByPeer.putIfAbsent(peer, () => message);
    }
    return Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: Column(children: [
            Text('GENESIS CHAT', style: const TextStyle(
              color: AgcLuxury.champagne, fontSize: 23,
              letterSpacing: 1.5, fontWeight: FontWeight.bold)),
            const SizedBox(height: 7),
            Text(chatText(
              'Rozmawiaj z członkami społeczności. Pytania do przyszłej AI '
              'przechowujemy oddzielnie — nie są rozmową z AI.',
              'Talk with community members. Questions for a future AI '
              'are stored separately — they are not an AI conversation.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, icon: const Icon(Icons.mail_outline),
                  label: Text(chatText('Wiadomości', 'Messages'))),
                ButtonSegment(value: true,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(chatText('Genesis / AI', 'Genesis / AI'))),
              ],
              selected: {questions},
              onSelectionChanged: (v) => setState(() => questions = v.first)),
          ])),
        Expanded(child: questions
          ? ListView(padding: const EdgeInsets.all(14), children: [
              const GenesisAiContactRoom(),
            ])
          : RefreshIndicator(
              onRefresh: refresh,
              child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                    children: [
                      Row(children: [
                        Expanded(child: Text(chatText(
                          'PRYWATNE ROZMOWY', 'PRIVATE CONVERSATIONS'),
                          style: const TextStyle(color: AgcLuxury.champagne,
                            fontWeight: FontWeight.bold, letterSpacing: 1))),
                        IconButton(onPressed: refresh,
                          tooltip: chatText('Odśwież', 'Refresh'),
                          icon: const Icon(Icons.refresh)),
                      ]),
                      if (error != null) Text(error!),
                      if (lastByPeer.isEmpty) Card(child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(children: [
                          const Icon(Icons.mark_chat_unread_outlined,
                            size: 36, color: AgcLuxury.champagne),
                          const SizedBox(height: 12),
                          Text(chatText('Nie masz jeszcze rozmów.',
                            'You have no conversations yet.'),
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(chatText(
                            'Wejdź do dyskusji, kliknij pseudonim autora '
                            'i wybierz „Napisz do użytkownika”.',
                            'Open a discussion, tap an author name '
                            'and choose “Message member”.'),
                            textAlign: TextAlign.center),
                        ])))
                      else
                        for (final entry in lastByPeer.entries)
                          Card(child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.person_outline)),
                            title: Text(names[entry.key] ??
                              chatText('Członek Genesis', 'Genesis member'),
                              style: const TextStyle(
                                color: AgcLuxury.champagne,
                                fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              '${entry.value['sender_id'] == me ? '↗ ' : '↙ '}${entry.value['body']}',
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(builder: (_) =>
                                  GenesisConversationPage(
                                    memberId: entry.key,
                                    memberName: names[entry.key] ??
                                      chatText('Członek Genesis',
                                        'Genesis member'))));
                              if (mounted) {
                                refresh(silent: true);
                              }
                            },
                          )),
                    ]))),
      ]),
    ));
  }
}

/// Private one-to-one thread. No conversation is created until a message is sent.
class GenesisConversationPage extends StatefulWidget {
  const GenesisConversationPage({
    super.key, required this.memberId, required this.memberName,
  });
  final String memberId;
  final String memberName;

  @override
  State<GenesisConversationPage> createState() =>
      _GenesisConversationPageState();
}

class _GenesisConversationPageState extends State<GenesisConversationPage> {
  final composer = TextEditingController();
  final scroll = ScrollController();
  Timer? timer;
  bool loading = true;
  bool sending = false;
  String? error;
  List<Map<String, dynamic>> messages = [];

  @override
  void initState() {
    super.initState();
    refresh();
    timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && !sending) {
        refresh(silent: true);
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    composer.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> refresh({bool silent = false}) async {
    final me = AgcBackend.user?.id;
    if (me == null) return;
    if (!silent && mounted) setState(() { loading = true; error = null; });
    try {
      final rows = await AgcBackend.client.from('agc_direct_messages')
        .select('id,sender_id,recipient_id,body,created_at')
        .inFilter('sender_id', [me, widget.memberId])
        .inFilter('recipient_id', [me, widget.memberId])
        .order('created_at', ascending: false).limit(300);
      final fetched = List<Map<String, dynamic>>.from(rows.reversed);
      if (!mounted) {
        return;
      }
      final changed = fetched.length != messages.length ||
        (fetched.isNotEmpty && messages.isNotEmpty &&
          fetched.last['id'] != messages.last['id']);
      setState(() {
        messages = fetched;
        loading = false;
        error = null;
      });
      if (changed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scroll.hasClients) {
            scroll.animateTo(scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut);
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
        loading = false;
        if (!silent) {
          error = chatText('Nie udało się pobrać wiadomości.',
            'Could not load messages.');
        }
        });
      }
    }
  }

  Future<void> send() async {
    final me = AgcBackend.user?.id;
    final body = composer.text.trim();
    if (me == null || me == widget.memberId || body.isEmpty || sending ||
        body.length > 3000) {
      return;
    }
    setState(() { sending = true; error = null; });
    try {
      await AgcBackend.client.from('agc_direct_messages').insert({
        'sender_id': me, 'recipient_id': widget.memberId, 'body': body,
      });
      composer.clear();
      await refresh(silent: true);
    } catch (_) {
      if (mounted) {
        setState(() => error = chatText(
          'Nie udało się wysłać wiadomości. Spróbuj ponownie.',
          'Could not send the message. Please try again.'));
      }
    } finally {
      if (mounted) {
        setState(() => sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = AgcBackend.user?.id;
    return Scaffold(
      appBar: AppBar(title: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.memberName, style: const TextStyle(fontSize: 17)),
          Text(chatText('Prywatna rozmowa Genesis',
            'Private Genesis conversation'),
            style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ])),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(children: [
          Expanded(child: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.all(16),
                itemCount: messages.isEmpty ? 1 : messages.length,
                itemBuilder: (context, index) {
                  if (messages.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 35),
                      child: Column(children: [
                        const Icon(Icons.chat_bubble_outline,
                          size: 42, color: AgcLuxury.champagne),
                        const SizedBox(height: 12),
                        Text(chatText('Rozpocznij rozmowę',
                          'Start a conversation'),
                          style: const TextStyle(fontSize: 18,
                            fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(chatText(
                          'Pierwsza wiadomość otworzy prywatny czat '
                          'i pojawi się w zakładce CZAT u obu osób.',
                          'Your first message opens a private chat '
                          'visible in the CHAT tab for both members.'),
                          textAlign: TextAlign.center),
                      ]));
                  }
                  final item = messages[index];
                  final mine = item['sender_id'] == me;
                  return Align(
                    alignment: mine
                      ? Alignment.centerRight : Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 490),
                      child: Card(
                        color: mine
                          ? AgcLuxury.champagne.withValues(alpha: .15)
                          : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['body'] as String,
                                style: const TextStyle(height: 1.4)),
                              const SizedBox(height: 5),
                              Text(
                                (item['created_at'] as String? ?? '')
                                  .replaceFirst('T', ' ').split('.').first,
                                style: const TextStyle(
                                  color: Colors.white54, fontSize: 10)),
                            ]))),
                    ));
                })),
          if (error != null) Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(error!, style: const TextStyle(
              color: Colors.orangeAccent))),
          Padding(padding: const EdgeInsets.fromLTRB(10, 8, 10, 14),
            child: Row(children: [
              Expanded(child: TextField(
                controller: composer, maxLength: 3000, maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: chatText('Napisz wiadomość…',
                    'Write a message…'),
                  border: const OutlineInputBorder()),
                onSubmitted: (_) => send())),
              const SizedBox(width: 7),
              IconButton.filled(
                onPressed: sending ? null : send,
                tooltip: chatText('Wyślij', 'Send'),
                icon: const Icon(Icons.send)),
            ])),
        ]),
      ))),
    );
  }
}
