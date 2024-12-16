import 'package:flutter/material.dart';
import 'package:ChatMcp/dao/chat.dart';
import 'package:ChatMcp/dao/chat_message.dart';
import 'package:logging/logging.dart';
import 'package:ChatMcp/llm/model.dart' as llmModel;
import 'package:ChatMcp/llm/openai_client.dart' as openai;
import 'package:ChatMcp/llm/claude_client.dart' as claude;

class ChatProvider extends ChangeNotifier {
  static final ChatProvider _instance = ChatProvider._internal();
  factory ChatProvider() => _instance;
  ChatProvider._internal() {}

  Chat? _activeChat;
  List<Chat> _chats = [];
  bool isSelectMode = false;
  Set<int?> selectedChats = {};

  Chat? get activeChat => _activeChat;
  List<Chat> get chats => _chats;

  List<llmModel.Model> get availableModels => [
        ...openai.models,
        ...claude.models,
      ];

  Future<void> loadChats() async {
    final chatDao = ChatDao();
    _chats = await chatDao.query(
      orderBy: 'updatedAt DESC',
    );
    notifyListeners();
  }

  Future<void> setActiveChat(Chat chat) async {
    _activeChat = chat;
    notifyListeners();
  }

  Future<void> createChat(
      Chat chat, List<llmModel.ChatMessage> messages) async {
    final chatDao = ChatDao();
    final id = await chatDao.insert(chat);
    await loadChats();
    final newChat = await chatDao.queryById(id.toString());
    await addChatMessage(newChat!.id!, messages);
    setActiveChat(newChat);
  }

  Future<void> updateChat(Chat chat) async {
    final chatDao = ChatDao();
    Logger.root.info('updateChat: ${chat.toJson()}');
    await chatDao.update(chat, chat.id!.toString());
    await loadChats();
    if (_activeChat?.id == chat.id) {
      setActiveChat(chat);
    }
  }

  Future<void> deleteChat(int chatId) async {
    final chatDao = ChatDao();
    await chatDao.delete(chatId.toString());
    await loadChats();
    if (_activeChat?.id == chatId) {
      _activeChat = null;
    }
    notifyListeners();
  }

  Future<void> clearActiveChat() async {
    _activeChat = null;
    notifyListeners();
  }

  Future<void> addChatMessage(
      int chatId, List<llmModel.ChatMessage> messages) async {
    final chatMessageDao = ChatMessageDao();
    for (var message in messages) {
      await chatMessageDao.insert(ChatMessage(
        chatId: chatId,
        body: message.toString(),
      ));
    }
    notifyListeners();
  }

  void enterSelectMode() {
    isSelectMode = true;
    selectedChats.clear();
    notifyListeners();
  }

  void exitSelectMode() {
    isSelectMode = false;
    selectedChats.clear();
    notifyListeners();
  }

  void selectChat(int? chatId) {
    selectedChats.add(chatId);
    notifyListeners();
  }

  void unselectChat(int? chatId) {
    selectedChats.remove(chatId);
    notifyListeners();
  }

  void toggleSelectChat(int? chatId) {
    if (selectedChats.contains(chatId)) {
      selectedChats.remove(chatId);
    } else {
      selectedChats.add(chatId);
    }
    notifyListeners();
  }

  void toggleSelectAll() {
    if (selectedChats.length == chats.length) {
      selectedChats.clear();
    } else {
      selectedChats = chats.map((chat) => chat.id).toSet();
    }
    notifyListeners();
  }

  Future<void> deleteSelectedChats() async {
    final chatDao = ChatDao();

    // 从数据库中删除选中的聊天记录
    for (var chatId in selectedChats) {
      if (chatId != null) {
        await chatDao.delete(chatId.toString());
      }
    }

    // 重新加载聊天列表
    await loadChats();

    // 如果当前活动的聊天被删除，需要更新activeChat
    if (selectedChats.contains(activeChat?.id)) {
      if (_chats.isNotEmpty) {
        await setActiveChat(_chats.first);
      } else {
        await clearActiveChat();
      }
    }

    // 退出选择模式
    exitSelectMode();
  }
}
