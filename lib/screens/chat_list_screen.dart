import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/auth_providers.dart';
import '../providers/chat_providers.dart';
import '../models/chat_model.dart';
import 'chat_screen.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  String _formatTime(DateTime? timestamp) {
    if (timestamp == null) return '';

    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(timestamp);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEE').format(timestamp);
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }

  void _showNewChatDialog(BuildContext context, WidgetRef ref) {
    final searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start New Chat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: searchController,
              decoration: const InputDecoration(
                labelText: 'Search by username',
                hintText: 'Enter username',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final username = searchController.text.trim();
              if (username.isEmpty) return;

              try {
                final authService = ref.read(authServiceProvider);
                final user = await authService.getUserByUsername(username);

                if (user == null) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('User not found')),
                    );
                  }
                  return;
                }

                final chatService = ref.read(chatServiceProvider);
                final chatId = await chatService.createOrGetChat(user.uid);

                if (context.mounted) {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(chatId: chatId),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              }
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final currentUser = ref.watch(currentUserProvider);
    final chatsStream = ref.watch(chatsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authService = ref.read(authServiceProvider);
              await authService.signOut();
              if (context.mounted) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
          ),
        ],
      ),
      body: currentUser.when(
        data: (user) {
          if (user == null) {
            //If Firebase user exists but Firestore user doesn't, show error
            return authState.value != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 60,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        const Text('User data not found'),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final authService = ref.read(authServiceProvider);
                            await authService.signOut();
                          },
                          child: const Text('Sign Out'),
                        ),
                      ],
                    ),
                  )
                : const Center(child: Text('No user data'));
          }

          return chatsStream.when(
            data: (chats) {
              return RefreshIndicator(
                onRefresh: () async {
                  //force refresh
                  ref.invalidate(chatsStreamProvider);
                  //waiting a bit to refresh
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                child: chats.isEmpty
                    ? ListView(
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height - 200,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: 80,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No chats yet',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap the + button to start a chat',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Pull down to refresh',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        itemCount: chats.length,
                        itemBuilder: (context, index) {
                          final chat = chats[index];
                          final unreadCount = chat.unreadCount[user.uid] ?? 0;

                          return _ChatListItem(
                            key: ValueKey(chat.id),
                            chat: chat,
                            currentUserId: user.uid,
                            unreadCount: unreadCount,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ChatScreen(chatId: chat.id),
                                ),
                              );
                            },
                            formatTime: _formatTime,
                          );
                        },
                      ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) {
              final errorMsg = error.toString();
              final isIndexError =
                  errorMsg.contains('failed-precondition') ||
                  errorMsg.contains('index');
              final isPermissionError = errorMsg.contains('permission-denied');

              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isIndexError
                            ? Icons.warning_amber
                            : Icons.error_outline,
                        size: 60,
                        color: isIndexError ? Colors.orange : Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isIndexError
                            ? 'Database Index Required'
                            : isPermissionError
                            ? 'Permission Denied'
                            : 'Error Loading Chats',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isIndexError
                            ? 'Please create the required Firestore index in Firebase Console. Check the terminal for the link.'
                            : isPermissionError
                            ? 'Please check your Firestore security rules in Firebase Console.'
                            : errorMsg,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          ref.invalidate(chatsStreamProvider);
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading user data: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final authService = ref.read(authServiceProvider);
                  await authService.signOut();
                  if (context.mounted) {
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/login', (route) => false);
                  }
                },
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewChatDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ChatListItem extends ConsumerStatefulWidget {
  final ChatModel chat;
  final String currentUserId;
  final int unreadCount;
  final VoidCallback onTap;
  final String Function(DateTime?) formatTime;

  const _ChatListItem({
    super.key,
    required this.chat,
    required this.currentUserId,
    required this.unreadCount,
    required this.onTap,
    required this.formatTime,
  });

  @override
  ConsumerState<_ChatListItem> createState() => _ChatListItemState();
}

class _ChatListItemState extends ConsumerState<_ChatListItem> {
  String? _displayName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (widget.chat.isGroup) {
      if (mounted) {
        setState(() {
          _displayName = widget.chat.groupName ?? 'Group Chat';
          _isLoading = false;
        });
      }
    } else {
      try {
        print('🔍 Loading user data for chat: ${widget.chat.id}');
        print('🔍 Participants: ${widget.chat.participants}');
        print('🔍 Current user: ${widget.currentUserId}');

        final chatService = ref.read(chatServiceProvider);
        final otherUser = await chatService.getOtherUserInChat(widget.chat.id);

        print('🔍 Other user found: ${otherUser?.displayName ?? 'NULL'}');

        if (mounted) {
          setState(() {
            _displayName = otherUser?.displayName ?? 'User not found';
            _isLoading = false;
          });
        }
      } catch (e) {
        print('❌ Error loading user data: $e');
        if (mounted) {
          setState(() {
            _displayName = 'Error loading user';
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void didUpdateWidget(_ChatListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload user data if chat changed
    if (oldWidget.chat.id != widget.chat.id) {
      _loadUserData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          widget.chat.isGroup ? Icons.group : Icons.person,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(
        _isLoading ? 'Loading...' : (_displayName ?? 'Unknown User'),
        style: TextStyle(
          fontWeight: widget.unreadCount > 0
              ? FontWeight.bold
              : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        widget.chat.lastMessage ?? 'No messages yet',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: widget.unreadCount > 0
              ? FontWeight.w500
              : FontWeight.normal,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            widget.formatTime(widget.chat.lastMessageTime),
            style: TextStyle(
              fontSize: 12,
              color: widget.unreadCount > 0
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey[600],
            ),
          ),
          if (widget.unreadCount > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                widget.unreadCount > 99 ? '99+' : widget.unreadCount.toString(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      onTap: widget.onTap,
    );
  }
}
