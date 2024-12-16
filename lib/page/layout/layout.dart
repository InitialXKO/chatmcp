import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import './chat_page/chat_page.dart';
import './chat_history.dart';
import 'package:ChatMcp/provider/provider_manager.dart';
import 'package:ChatMcp/provider/chat_model_provider.dart';

class LayoutPage extends StatefulWidget {
  const LayoutPage({super.key});

  @override
  State<LayoutPage> createState() => _LayoutPageState();
}

class _LayoutPageState extends State<LayoutPage> {
  bool hideChatHistory = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ProviderManager.chatModelProvider.loadAvailableModels();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatModelProvider>(
        builder: (context, chatModelProvider, child) {
      return Scaffold(
        body: Row(
          children: [
            if (!hideChatHistory)
              Container(
                width: 250,
                color: Colors.grey[200],
                child: ChatHistoryPanel(
                  onToggle: () => setState(() {
                    hideChatHistory = !hideChatHistory;
                  }),
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: 50,
                    color: Colors.grey[100],
                    padding:
                        EdgeInsets.fromLTRB(hideChatHistory ? 70 : 0, 0, 16, 0),
                    child: Row(
                      children: [
                        if (hideChatHistory)
                          IconButton(
                            icon: const Icon(Icons.menu),
                            onPressed: () => setState(() {
                              hideChatHistory = !hideChatHistory;
                            }),
                          ),
                        // model select
                        Container(
                          constraints: const BoxConstraints(maxWidth: 150),
                          decoration: BoxDecoration(
                            // color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: ButtonTheme(
                              alignedDropdown: true,
                              child: DropdownButton<String>(
                                value: chatModelProvider.currentModel,
                                items: ProviderManager
                                    .chatModelProvider.availableModels
                                    .map((model) => DropdownMenuItem(
                                          value: model.name,
                                          child: Tooltip(
                                            message: model.label,
                                            child: Text(
                                              model.label,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ))
                                    .toList(),
                                onChanged: (String? value) {
                                  if (value != null) {
                                    setState(() {
                                      ProviderManager.chatModelProvider
                                          .currentModel = value;
                                    });
                                  }
                                },
                                menuMaxHeight: 200,
                                elevation: 20,
                                isDense: true,
                                underline: Container(
                                  height: 0,
                                ),
                                isExpanded: true,
                                alignment: AlignmentDirectional.centerStart,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            ProviderManager.chatProvider.clearActiveChat();
                          },
                        ),
                      ],
                    ),
                  ),
                  const Expanded(
                    child: ChatPage(),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}
