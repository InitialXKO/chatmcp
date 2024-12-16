import 'package:flutter/material.dart';
import '../setting/setting.dart';
import 'package:provider/provider.dart';
import 'package:ChatMcp/provider/chat_provider.dart';

class ChatHistoryPanel extends StatelessWidget {
  final VoidCallback? onToggle;
  const ChatHistoryPanel({super.key, this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) => SizedBox(
        height: double.infinity,
        child: Stack(
          children: [
            Container(
              padding:
                  const EdgeInsets.only(top: 35, left: 8, right: 8, bottom: 50),
              child: ListView.builder(
                itemCount: chatProvider.chats.length,
                itemBuilder: (context, index) {
                  final chat = chatProvider.chats[index];
                  final isActive = chat.id == chatProvider.activeChat?.id;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.grey.withAlpha(25) : null,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ListTile(
                      dense: true,
                      visualDensity: const VisualDensity(vertical: -4),
                      leading: chatProvider.isSelectMode
                          ? Checkbox(
                              value:
                                  chatProvider.selectedChats.contains(chat.id),
                              onChanged: (bool? value) {
                                if (value == true) {
                                  chatProvider.selectChat(chat.id);
                                } else {
                                  chatProvider.unselectChat(chat.id);
                                }
                              },
                            )
                          : null,
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              chat.title,
                              style: const TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${chat.updatedAt.month}/${chat.updatedAt.day}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      onTap: () => chatProvider.isSelectMode
                          ? chatProvider.toggleSelectChat(chat.id)
                          : chatProvider.setActiveChat(chat),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 0,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: onToggle,
              ),
            ),
            // 底部操作栏
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width * 0.8,
                              height: MediaQuery.of(context).size.height * 0.8,
                              child: const SettingPage(),
                            ),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(chatProvider.isSelectMode
                          ? Icons.close
                          : Icons.delete),
                      onPressed: () {
                        if (chatProvider.isSelectMode) {
                          chatProvider.exitSelectMode();
                        } else {
                          chatProvider.enterSelectMode();
                        }
                      },
                    ),
                    if (chatProvider.isSelectMode) ...[
                      IconButton(
                        icon: const Icon(Icons.select_all),
                        onPressed: () => chatProvider.toggleSelectAll(),
                      ),
                      ElevatedButton(
                        onPressed: chatProvider.selectedChats.isNotEmpty
                            ? () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('确认删除'),
                                    content: const Text('确定要删除选中的对话吗？'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('取消'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          chatProvider.deleteSelectedChats();
                                          Navigator.pop(context);
                                        },
                                        child: const Text('确定'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            : null,
                        child: const Text('删除'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
