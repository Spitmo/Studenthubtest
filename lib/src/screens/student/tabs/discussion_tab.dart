import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ADD THIS
import '../../../services/supabase_service.dart'; // ADD THIS

class DiscussionTab extends StatefulWidget {
  const DiscussionTab({super.key});

  @override
  State<DiscussionTab> createState() => _DiscussionTabState();
}

class _DiscussionTabState extends State<DiscussionTab> {
  final List<_Msg> _messages = [];
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _isLoading = true;
  RealtimeChannel? _realtimeChannel; // ADD REALTIME CHANNEL

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _initializeRealtime(); // INITIALIZE REALTIME
  }

  // LOAD MESSAGES FROM SUPABASE
  Future<void> _loadMessages() async {
    try {
      final response = await SupabaseService.client
          .from('messages')
          .select('*, users(name, roll_number)')
          .order('created_at', ascending: true);

      if (response != null) {
        final List<dynamic> messages = response;
        setState(() {
          _messages.clear();
          _messages.addAll(messages.map((msg) {
            final user = msg['users'] ?? {};
            return _Msg(
              msg['message'] ?? '',
              msg['user_id'] == SupabaseService.currentUser?.id,
              DateTime.parse(
                  msg['created_at'] ?? DateTime.now().toIso8601String()),
              user['name'] ?? 'Unknown',
              user['roll_number'] ?? '', // ADD ROLL NUMBER
            );
          }).toList());
          _isLoading = false;
        });

        // Scroll to bottom after loading
        _scrollToBottom();
      }
    } catch (e) {
      print('Error loading messages: $e');
      // Fallback to dummy data
      _loadDummyData();
    }
  }

  void _loadDummyData() {
    setState(() {
      _messages.addAll([
        _Msg(
            'Welcome to the StudentHub discussion! Feel free to ask questions and share ideas.',
            false,
            DateTime.now().subtract(const Duration(hours: 2)),
            'Admin',
            '2023000'),
        _Msg(
            'Anyone working on the math assignment? I need help with problem 5.',
            true,
            DateTime.now().subtract(const Duration(hours: 1)),
            'You',
            '2023001'),
        _Msg(
            'I can help! The key is to use the quadratic formula.',
            false,
            DateTime.now().subtract(const Duration(minutes: 45)),
            'Alice',
            '2023002'),
        _Msg(
            'Thanks Alice! That really helped.',
            true,
            DateTime.now().subtract(const Duration(minutes: 30)),
            'You',
            '2023001'),
        _Msg(
            'Is the library open today?',
            false,
            DateTime.now().subtract(const Duration(minutes: 15)),
            'Bob',
            '2023003'),
        _Msg(
            'Yes, until 10 PM',
            false,
            DateTime.now().subtract(const Duration(minutes: 10)),
            'Carol',
            '2023004'),
      ]);
      _isLoading = false;
    });
  }

  // INITIALIZE REALTIME FOR MESSAGES
  void _initializeRealtime() {
    _realtimeChannel = SupabaseService.client
        .channel('discussion-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            print('💬 Discussion Real-time: ${payload.eventType}');

            if (payload.eventType == 'INSERT') {
              // Fetch the new message with user data
              try {
                final newMessage = await SupabaseService.client
                    .from('messages')
                    .select('*, users(name, roll_number)')
                    .eq('id', payload.newRecord['id'])
                    .single();

                if (newMessage != null) {
                  final user = newMessage['users'] ?? {};
                  final message = _Msg(
                    newMessage['message'] ?? '',
                    newMessage['user_id'] == SupabaseService.currentUser?.id,
                    DateTime.parse(newMessage['created_at'] ??
                        DateTime.now().toIso8601String()),
                    user['name'] ?? 'Unknown',
                    user['roll_number'] ?? '',
                  );

                  if (mounted) {
                    setState(() {
                      _messages.add(message);
                    });
                    _scrollToBottom();
                  }

                  // Show notification for others' messages
                  if (!message.isMine) {
                    _showNewMessageNotification(message.sender, message.text);
                  }
                }
              } catch (e) {
                print('Error fetching new message: $e');
              }
            }
          },
        )
        .subscribe();
  }

  void _showNewMessageNotification(String sender, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('💬 $sender: ${_truncateMessage(message)}'),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  String _truncateMessage(String message) {
    return message.length > 30 ? '${message.substring(0, 30)}...' : message;
  }

  // SEND MESSAGE TO SUPABASE
  void _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final currentUser = SupabaseService.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please login to send messages')),
      );
      return;
    }

    try {
      // Send to Supabase - realtime will handle the update
      await SupabaseService.client.from('messages').insert({
        'user_id': currentUser.id,
        'message': text,
        'created_at': DateTime.now().toIso8601String(),
      });

      _controller.clear();
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message')),
      );
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Header with realtime status
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    backgroundColor: scheme.primary.withOpacity(0.1),
                    child: Icon(
                      Icons.forum_rounded,
                      color: scheme.primary,
                    ),
                  ),
                  // Realtime indicator
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.surface, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Student Discussion',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      _isLoading
                          ? 'Loading messages...'
                          : '${_messages.length} messages • Live',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _isLoading ? Colors.orange : Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _loadMessages,
                icon: Icon(Icons.refresh_rounded, color: scheme.primary),
                tooltip: 'Refresh messages',
              ),
            ],
          ),
        ),

        // Messages List
        Expanded(
          child: _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading messages...'),
                    ],
                  ),
                )
              : _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.forum_outlined,
                            size: 64,
                            color: scheme.onSurface.withOpacity(0.3),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No messages yet',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Start the conversation!',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: scheme.onSurface.withOpacity(0.6),
                                ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final m = _messages[i];
                        return _buildMessageBubble(m, scheme);
                      },
                    ),
        ),

        // Input Area
        SafeArea(
          top: false,
          child: Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 16,
            ),
            decoration: BoxDecoration(
              color: scheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide:
                            BorderSide(color: scheme.outline.withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide:
                            BorderSide(color: scheme.outline.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: scheme.primary),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      filled: true,
                      fillColor: scheme.surface,
                    ),
                    maxLines: null,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: IconButton(
                    onPressed: _send,
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                    tooltip: 'Send message',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(_Msg message, ColorScheme scheme) {
    final isMine = message.isMine;
    final color = isMine ? scheme.primary : scheme.surface;
    final textColor = isMine ? Colors.white : scheme.onSurface;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: scheme.primary.withOpacity(0.1),
              child: Text(
                message.sender.substring(0, 1),
                style: TextStyle(
                  color: scheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMine ? 16 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMine)
                    Row(
                      children: [
                        Text(
                          message.sender,
                          style: TextStyle(
                            color: textColor.withOpacity(0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '(${message.rollNumber})',
                          style: TextStyle(
                            color: textColor.withOpacity(0.5),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  if (!isMine) const SizedBox(height: 4),
                  Text(
                    message.text,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('h:mm a').format(message.ts),
                    style: TextStyle(
                      color: textColor.withOpacity(0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMine) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: scheme.primary.withOpacity(0.2),
              child: Text(
                'Y',
                style: TextStyle(
                  color: scheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Msg {
  final String text;
  final bool isMine;
  final DateTime ts;
  final String sender;
  final String rollNumber; // ADD ROLL NUMBER

  _Msg(this.text, this.isMine, this.ts, this.sender, this.rollNumber);
}
