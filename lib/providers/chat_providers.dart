import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/chat_service.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService();
});

final chatsStreamProvider = StreamProvider<List<ChatModel>>((ref) {
  final chatService = ref.watch(chatServiceProvider);
  return chatService.getChatsStream();
});

final messagesStreamProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, chatId) {
      final chatService = ref.watch(chatServiceProvider);
      return chatService.getMessagesStream(chatId);
    });

final chatProvider = FutureProvider.family<ChatModel?, String>((
  ref,
  chatId,
) async {
  final chatService = ref.watch(chatServiceProvider);
  return await chatService.getChatById(chatId);
});
