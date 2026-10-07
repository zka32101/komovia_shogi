import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/index.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.uid,
    required this.displayName,
    required this.otherUid,
    required this.otherDisplayName,
  });

  final String uid;
  final String displayName;
  final String otherUid;
  final String otherDisplayName;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final threadId = ref
        .read(directMessageServiceProvider)
        .threadIdFor(widget.uid, widget.otherUid);
    final messages = ref.watch(messagesStreamProvider(threadId)).value ?? [];

    return Scaffold(
      appBar: AppBar(title: Text(widget.otherDisplayName)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              reverse: true,
              children: messages.reversed
                  .map(
                    (m) => Align(
                      alignment: m.fromUid == widget.uid
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(m.content),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: 'Message'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    final text = _controller.text.trim();
                    if (text.isEmpty) return;
                    ref.read(sendMessageProvider)(
                      fromUid: widget.uid,
                      fromDisplayName: widget.displayName,
                      toUid: widget.otherUid,
                      toDisplayName: widget.otherDisplayName,
                      content: text,
                    );
                    _controller.clear();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
