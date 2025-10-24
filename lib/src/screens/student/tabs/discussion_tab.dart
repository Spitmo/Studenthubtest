import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/supabase_service.dart';

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
  RealtimeChannel? _realtimeChannel;

  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserRollNumber;

  @override
  void initState() {
    super.initState();
    _initializeUserSession();
  }

  Future<void> _initializeUserSession() async {
    try {
      final session = await SupabaseService.getUserSession();
      setState(() {
        _currentUserId = session['user_id'];
        _currentUserName = session['user_name'];
        _currentUserRollNumber = session['roll_number'];
      });

      await _loadMessages();
      _initializeRealtime();
    } catch (e) {
      print('Error initializing user session: $e');
      _loadDummyData();
    }
  }

  Future<void> _loadMessages() async {
    try {
      print('🔄 Loading messages for user: $_currentUserId');

      // FIXED: Remove roll_number from query since it doesn't exist in database
      final response = await SupabaseService.client
          .from('messages')
          .select('*, users(name)') // ONLY SELECT EXISTING COLUMNS
          .order('created_at', ascending: true);

      final List<dynamic> messages = response;

      final List<_Msg> newMessages = messages.map((msg) {
        final user = msg['users'] ?? {};
        return _Msg(
          msg['message'] ?? '',
          msg['user_id'] == _currentUserId,
          DateTime.parse(msg['created_at'] ?? DateTime.now().toIso8601String()),
          user['name'] ?? 'Unknown',
          '', // EMPTY ROLL NUMBER SINCE COLUMN DOESN'T EXIST
          msg['id'].toString(),
        );
      }).toList();

      setState(() {
        _messages.clear();
        _messages.addAll(newMessages);
        _isLoading = false;
      });

      print('✅ Loaded ${_messages.length} messages');
      _scrollToBottom();
    } catch (e) {
      print('❌ Error loading messages: $e');
      _loadDummyData();
    }
  }

  void _loadDummyData() {
    if (_messages.isEmpty) {
      setState(() {
        _messages.addAll([
          _Msg(
            'Welcome to the StudentHub discussion! Feel free to ask questions and share ideas.',
            false,
            DateTime.now().subtract(const Duration(hours: 2)),
            'Admin',
            '2023000',
            'dummy1',
          ),
          _Msg(
            'Anyone working on the math assignment? I need help with problem 5.',
            _currentUserId != null,
            DateTime.now().subtract(const Duration(hours: 1)),
            _currentUserName ?? 'You',
            _currentUserRollNumber ?? '2023001',
            'dummy2',
          ),
        ]);
        _isLoading = false;
      });
    }
  }

  void _initializeRealtime() {
    _realtimeChannel?.unsubscribe();

    _realtimeChannel = SupabaseService.client
        .channel('public:messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            print('💬 Real-time Update: ${payload.eventType}');
            print('📦 New Message ID: ${payload.newRecord['id']}');

            if (payload.eventType == PostgresChangeEvent.insert) {
              _handleNewMessage(payload.newRecord['id']);
            }
          },
        )
        .subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        print('✅ Real-time subscribed successfully');
      } else if (status == RealtimeSubscribeStatus.timedOut) {
        print('⏰ Real-time subscription timed out');
      } else {
        print('❌ Real-time subscription status: $status');
      }
      if (error != null) {
        print('❌ Real-time error: $error');
      }
    });
  }

  Future<void> _handleNewMessage(String messageId) async {
    try {
      print('🔄 Fetching new message: $messageId');

      // FIXED: Remove roll_number from query
      final newMessage = await SupabaseService.client
          .from('messages')
          .select('*, users(name)') // ONLY SELECT EXISTING COLUMNS
          .eq('id', messageId)
          .single();

      final user = newMessage['users'] ?? {};
      final message = _Msg(
        newMessage['message'] ?? '',
        newMessage['user_id'] == _currentUserId,
        DateTime.parse(
            newMessage['created_at'] ?? DateTime.now().toIso8601String()),
        user['name'] ?? 'Unknown',
        '', // EMPTY ROLL NUMBER
        newMessage['id'].toString(),
      );

      final bool messageExists = _messages.any((msg) => msg.id == message.id);

      if (mounted && !messageExists) {
        setState(() {
          _messages.add(message);
        });
        _scrollToBottom();
        print('✅ New message added: ${message.text}');

        if (!message.isMine) {
          _showNewMessageNotification(message.sender, message.text);
        }
      } else {
        print('⚠️ Message already exists or not mounted: ${message.text}');
      }
    } catch (e) {
      print('❌ Error handling new message: $e');
    }
  }

  void _showNewMessageNotification(String sender, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('💬 $sender: ${_truncateMessage(message)}'),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _truncateMessage(String message) {
    return message.length > 30 ? '${message.substring(0, 30)}...' : message;
  }

  void _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to send messages')),
      );
      return;
    }

    try {
      final tempMessage = _Msg(
        text,
        true,
        DateTime.now(),
        _currentUserName ?? 'You',
        _currentUserRollNumber ?? '',
        'temp_${DateTime.now().millisecondsSinceEpoch}',
      );

      setState(() {
        _messages.add(tempMessage);
      });
      _controller.clear();
      _scrollToBottom();

      await SupabaseService.client.from('messages').insert({
        'user_id': _currentUserId,
        'message': text,
        'created_at': DateTime.now().toIso8601String(),
      });

      print('✅ Message sent to database: $text');
    } catch (e) {
      print('❌ Error sending message: $e');

      setState(() {
        _messages.removeWhere((msg) => msg.id.startsWith('temp_'));
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
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
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _realtimeChannel != null
                            ? Colors.green
                            : Colors.grey,
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
                          : '${_messages.length} messages • ${_realtimeChannel != null ? 'Live' : 'Offline'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _isLoading
                                ? Colors.orange
                                : (_realtimeChannel != null
                                    ? Colors.green
                                    : Colors.grey),
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                  });
                  _loadMessages();
                },
                icon: Icon(Icons.refresh_rounded, color: scheme.primary),
                tooltip: 'Refresh messages',
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(
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
                          const SizedBox(height: 16),
                          Text(
                            'No messages yet',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
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
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.only(
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
                        // REMOVED ROLL NUMBER DISPLAY SINCE IT DOESN'T EXIST
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
                _currentUserName != null && _currentUserName!.isNotEmpty
                    ? _currentUserName!.substring(0, 1)
                    : 'Y',
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
  final String rollNumber;
  final String id;

  _Msg(this.text, this.isMine, this.ts, this.sender, this.rollNumber, this.id);
}
