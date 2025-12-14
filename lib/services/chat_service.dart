import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Create or get existing 1-to-1 chat
  Future<String> createOrGetChat(String otherUserId) async {
    try {
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // Check if chat already exists between these two users
      final existingChats = await _firestore
          .collection('chats')
          .where('participants', arrayContains: currentUserId)
          .where('isGroup', isEqualTo: false)
          .get();

      // Find chat with both participants
      for (var doc in existingChats.docs) {
        final chat = ChatModel.fromDocument(doc);
        if (chat.participants.contains(otherUserId) &&
            chat.participants.length == 2) {
          return chat.id;
        }
      }

      // Create new chat if doesn't exist
      final chatRef = _firestore.collection('chats').doc();
      final newChat = ChatModel(
        id: chatRef.id,
        participants: [currentUserId!, otherUserId],
        unreadCount: {currentUserId!: 0, otherUserId: 0},
        isGroup: false,
        createdAt: DateTime.now(),
      );

      await chatRef.set(newChat.toJson());
      return chatRef.id;
    } catch (e) {
      throw Exception('Failed to create chat: ${e.toString()}');
    }
  }

  // Send a message in a chat
  Future<void> sendMessage(String chatId, String text) async {
    try {
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final messageRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc();

      final message = MessageModel(
        id: messageRef.id,
        chatId: chatId,
        senderId: currentUserId!,
        text: text,
        timestamp: DateTime.now(),
        isRead: false,
      );

      // Send message
      await messageRef.set(message.toJson());

      // Update chat metadata
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      final chat = ChatModel.fromDocument(chatDoc);

      // Increment unread count for other participants
      final updatedUnreadCount = Map<String, int>.from(chat.unreadCount);
      for (var participantId in chat.participants) {
        if (participantId != currentUserId) {
          updatedUnreadCount[participantId] =
              (updatedUnreadCount[participantId] ?? 0) + 1;
        }
      }

      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': text,
        'lastMessageTime': Timestamp.fromDate(DateTime.now()),
        'unreadCount': updatedUnreadCount,
      });
    } catch (e) {
      throw Exception('Failed to send message: ${e.toString()}');
    }
  }

  // Get stream of all chats for current user
  Stream<List<ChatModel>> getChatsStream() {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .handleError((error) {
          print('❌ Error in getChatsStream: $error');
          // If index error, return empty list instead of error
          if (error.toString().contains('failed-precondition')) {
            print('⚠️  Missing Firestore index for chats query');
          }
        })
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ChatModel.fromDocument(doc))
              .toList();
        });
  }

  // Get stream of messages in a chat
  Stream<List<MessageModel>> getMessagesStream(String chatId) async* {
    if (currentUserId == null) {
      yield [];
      return;
    }

    // SECURITY: Verify user is a participant before loading messages
    try {
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) {
        print('❌ Chat does not exist: $chatId');
        yield [];
        return;
      }

      final chat = ChatModel.fromDocument(chatDoc);
      if (!chat.participants.contains(currentUserId)) {
        print(
          '❌ SECURITY: User $currentUserId is not a participant in chat $chatId',
        );
        throw Exception('You are not a participant in this chat');
      }

      print('✅ SECURITY: User verified as participant in chat $chatId');

      // User is verified as participant - load messages
      await for (final snapshot
          in _firestore
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .orderBy('timestamp', descending: false)
              .snapshots()) {
        yield snapshot.docs
            .map((doc) => MessageModel.fromDocument(doc))
            .toList();
      }
    } catch (e) {
      print('❌ Error in getMessagesStream: $e');
      rethrow;
    }
  }

  // Mark message as read
  Future<void> markMessageAsRead(String chatId, String messageId) async {
    try {
      if (currentUserId == null) return;

      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
            'isRead': true,
            'readBy.$currentUserId': Timestamp.fromDate(DateTime.now()),
          });
    } catch (e) {
      throw Exception('Failed to mark message as read: ${e.toString()}');
    }
  }

  // Mark all messages in chat as read for current user
  Future<void> markChatAsRead(String chatId) async {
    try {
      if (currentUserId == null) return;

      // Get all unread messages
      final unreadMessages = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isNotEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      // Batch update
      final batch = _firestore.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readBy.$currentUserId': Timestamp.fromDate(DateTime.now()),
        });
      }
      await batch.commit();

      // Reset unread count for current user
      await _firestore.collection('chats').doc(chatId).update({
        'unreadCount.$currentUserId': 0,
      });
    } catch (e) {
      throw Exception('Failed to mark chat as read: ${e.toString()}');
    }
  }

  // Get other user info in a 1-to-1 chat
  Future<UserModel?> getOtherUserInChat(String chatId) async {
    try {
      if (currentUserId == null) return null;

      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      final chat = ChatModel.fromDocument(chatDoc);

      final otherUserId = chat.participants.firstWhere(
        (id) => id != currentUserId,
        orElse: () => '',
      );

      if (otherUserId.isEmpty) return null;

      final userDoc = await _firestore
          .collection('users')
          .doc(otherUserId)
          .get();
      return UserModel.fromDocument(userDoc);
    } catch (e) {
      throw Exception('Failed to get other user: ${e.toString()}');
    }
  }

  // Create group chat
  Future<String> createGroupChat(
    List<String> participantIds,
    String groupName,
  ) async {
    try {
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // Include current user in participants
      final allParticipants = {...participantIds, currentUserId!}.toList();

      final chatRef = _firestore.collection('chats').doc();

      // Initialize unread count for all participants
      final unreadCount = <String, int>{};
      for (var id in allParticipants) {
        unreadCount[id] = 0;
      }

      final newChat = ChatModel(
        id: chatRef.id,
        participants: allParticipants,
        unreadCount: unreadCount,
        isGroup: true,
        groupName: groupName,
        createdAt: DateTime.now(),
      );

      await chatRef.set(newChat.toJson());
      return chatRef.id;
    } catch (e) {
      throw Exception('Failed to create group chat: ${e.toString()}');
    }
  }

  // Get chat by ID
  Future<ChatModel?> getChatById(String chatId) async {
    try {
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (chatDoc.exists) {
        return ChatModel.fromDocument(chatDoc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get chat: ${e.toString()}');
    }
  }

  // Get multiple users by IDs
  Future<List<UserModel>> getUsersByIds(List<String> userIds) async {
    try {
      final users = <UserModel>[];
      for (var userId in userIds) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          users.add(UserModel.fromDocument(userDoc));
        }
      }
      return users;
    } catch (e) {
      throw Exception('Failed to get users: ${e.toString()}');
    }
  }
}
