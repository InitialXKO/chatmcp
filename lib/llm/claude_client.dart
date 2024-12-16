import 'package:dio/dio.dart';
import 'dart:convert';
import 'base_llm_client.dart';
import 'model.dart';
import 'package:logging/logging.dart';
import 'package:ChatMcp/provider/provider_manager.dart';

var models = [
  Model(
    name: 'claude-3-opus-20240229',
    label: 'Claude-3 Opus',
  ),
  Model(
    name: 'claude-3-5-sonnet-latest',
    label: 'Claude-3-5 Sonnet',
  ),
  Model(
    name: 'claude-3-5-haiku-latest',
    label: 'Claude-3-5 Haiku',
  ),
];

class ClaudeClient extends BaseLLMClient {
  final String apiKey;
  String baseUrl;
  final Dio _dio;

  ClaudeClient({
    required this.apiKey,
    String? baseUrl,
    Dio? dio,
  })  : baseUrl = (baseUrl == null || baseUrl.isEmpty)
            ? 'https://api.anthropic.com/v1'
            : baseUrl,
        _dio = dio ??
            Dio(BaseOptions(
              headers: {
                'Content-Type': 'application/json',
                'x-api-key': apiKey,
                'anthropic-version': '2023-06-01',
              },
            ));

  @override
  Future<LLMResponse> chatCompletion(CompletionRequest request) async {
    final messages = request.messages
        .map((m) => {
              'role': m.role == MessageRole.user ? 'user' : 'assistant',
              'content': [
                {
                  'type': 'text',
                  'text': m.content ?? '',
                }
              ],
            })
        .toList();

    final body = {
      'model': request.model,
      'messages': messages,
      'max_tokens': 4096,
    };

    if (request.tools != null && request.tools!.isNotEmpty) {
      body['tools'] = {
        'function_calling': {
          'tools': request.tools,
        }
      };
    }

    try {
      final response = await _dio.post(
        '$baseUrl/messages',
        data: jsonEncode(body),
      );

      var json;
      if (response.data is ResponseBody) {
        final responseBody = response.data as ResponseBody;
        final responseStr = await utf8.decodeStream(responseBody.stream);
        json = jsonDecode(responseStr);
      } else {
        json = response.data;
      }

      final content = json['content'][0]['text'];

      // Parse tool calls if present
      final toolCalls = json['tool_calls']
          ?.map<ToolCall>((t) => ToolCall(
                id: t['id'],
                type: t['type'],
                function: FunctionCall(
                  name: t['function']['name'],
                  arguments: t['function']['arguments'],
                ),
              ))
          ?.toList();

      return LLMResponse(
        content: content,
        toolCalls: toolCalls,
      );
    } catch (e) {
      throw Exception(
          "Claude API call failed: $baseUrl/messages body: ${jsonEncode(body)} error: $e");
    }
  }

  @override
  Stream<LLMResponse> chatStreamCompletion(CompletionRequest request) async* {
    final messages = request.messages
        .map((m) => {
              'role': m.role == MessageRole.user ? 'user' : 'assistant',
              'content': m.content ?? '',
            })
        .toList();

    final body = {
      'model': request.model,
      'messages': messages,
      'max_tokens': 4096,
      'stream': true,
    };

    if (request.tools != null && request.tools!.isNotEmpty) {
      body['tools'] = {
        'function_calling': {
          'tools': request.tools,
        }
      };
      body['tool_choice'] = {'type': 'any'};
    }

    try {
      _dio.options.responseType = ResponseType.stream;
      final response = await _dio.post(
        '$baseUrl/messages',
        data: jsonEncode(body),
      );

      String buffer = '';
      String currentContent = '';
      List<ToolCall>? currentToolCalls;

      await for (final chunk in response.data.stream) {
        final decodedChunk = utf8.decode(chunk);
        buffer += decodedChunk;

        while (buffer.contains('\n')) {
          final index = buffer.indexOf('\n');
          final line = buffer.substring(0, index).trim();
          buffer = buffer.substring(index + 1);

          if (!line.startsWith('data:')) continue;

          final jsonStr = line.substring(5).trim();
          if (jsonStr.isEmpty) continue;

          try {
            final event = jsonDecode(jsonStr);
            final eventType = event['type'];

            switch (eventType) {
              case 'content_block_start':
                final content = event['content_block'];
                final text = content['text'];
                yield LLMResponse(content: text);
              case 'content_block_delta':
                final delta = event['delta'];
                if (delta['type'] == 'text_delta') {
                  currentContent += delta['text'];
                  yield LLMResponse(content: delta['text']);
                } else if (delta['type'] == 'input_json_delta') {
                  // Handle tool use delta
                  final partialJson = delta['partial_json'];
                  // You may want to accumulate the JSON and parse it when complete
                }
                break;

              case 'content_block_stop':
                // Handle end of a content block
                break;

              case 'message_stop':
                // Handle end of message
                break;

              case 'error':
                final error = event['error'];
                throw Exception('Stream error: ${error['message']}');

              case 'ping':
                // Ignore ping events
                break;
            }
          } catch (e) {
            Logger.root.warning('Failed to parse chunk: $jsonStr error: $e');
            continue;
          }
        }
      }
    } catch (e) {
      throw Exception(
          "Claude streaming API call failed: $baseUrl/messages body: ${jsonEncode(body)} error: $e");
    }
  }

  @override
  Future<String> genTitle(List<ChatMessage> messages) async {
    final conversationText = messages.map((msg) {
      final role = msg.role == MessageRole.user ? "Human" : "Assistant";
      return "$role: ${msg.content}";
    }).join("\n");

    final prompt = ChatMessage(
      role: MessageRole.user,
      content:
          """Generate a concise title (max 20 characters) for the following conversation.
The title should summarize the main topic. Return only the title without any explanation or extra punctuation.

Conversation:
$conversationText""",
    );

    final response = await chatCompletion(CompletionRequest(
      model: "claude-3-5-haiku-20241022",
      messages: [prompt],
    ));

    return response.content?.trim() ?? "New Chat";
  }

  @override
  Future<Map<String, dynamic>> checkToolCall(
    String content,
    Map<String, List<Map<String, dynamic>>> toolsResponse,
  ) async {
    // Convert tools to Claude's format
    final tools = toolsResponse.entries
        .map((entry) {
          return entry.value.map((tool) {
            final parameters = tool['parameters'];
            if (parameters is! Map<String, dynamic>) {
              return {
                'name': tool['name'],
                'description': tool['description'],
                'input_schema': {
                  'type': 'object',
                  'properties': {},
                  'required': [],
                },
              };
            }

            return {
              'name': tool['name'],
              'description': tool['description'],
              'input_schema': {
                'type': 'object',
                'properties': parameters['properties'] ?? {},
                'required': parameters['required'] ?? [],
              },
            };
          }).toList();
        })
        .expand((x) => x)
        .toList();

    final body = {
      'model': ProviderManager.chatModelProvider.currentModel,
      'messages': [
        {
          'role': 'user',
          'content': content,
        }
      ],
      'tools': tools,
      'max_tokens': 4096,
    };

    try {
      final response = await _dio.post(
        '$baseUrl/messages',
        data: jsonEncode(body),
      );

      var jsonData;
      if (response.data is ResponseBody) {
        final responseBody = response.data as ResponseBody;
        final responseStr = await utf8.decodeStream(responseBody.stream);
        jsonData = jsonDecode(responseStr);
      } else {
        jsonData = response.data;
      }

      // Check if response contains tool calls in the content array
      final contentBlocks = jsonData['content'] as List?;
      if (contentBlocks == null || contentBlocks.isEmpty) {
        return {
          'need_tool_call': false,
          'content': '',
        };
      }

      // Look for tool_calls in the response
      final toolUseBlocks = contentBlocks.where((block) =>
          block['type'] == 'tool_calls' || block['type'] == 'tool_use');

      if (toolUseBlocks.isEmpty) {
        // Get text content from the first text block
        final textBlock = contentBlocks.firstWhere(
          (block) => block['type'] == 'text',
          orElse: () => {'text': ''},
        );
        return {
          'need_tool_call': false,
          'content': textBlock['text'] ?? '',
        };
      }

      // Extract tool calls
      final toolCalls = toolUseBlocks
          .map((block) => {
                'id': block['id'],
                'name': block['name'],
                'arguments': block['input'],
              })
          .toList();

      // Get any accompanying text content
      final textBlock = contentBlocks.firstWhere(
        (block) => block['type'] == 'text',
        orElse: () => {'text': ''},
      );

      return {
        'need_tool_call': true,
        'content': textBlock['text'] ?? '',
        'tool_calls': toolCalls,
      };
    } catch (e) {
      throw Exception(
          'Claude tool call check failed: $baseUrl/messages body: ${jsonEncode(body)} error: $e');
    }
  }

  @override
  Future<List<String>> models() async {
    try {
      final response = await _dio.get("$baseUrl/models");

      final data = response.data;

      final models = (data['data'] as List)
          .map((m) => m['id'].toString())
          .where((id) => id.contains('claude'))
          .toList();

      return models;
    } catch (e, trace) {
      Logger.root.severe('获取模型列表失败: $e, trace: $trace');
      // 返回预定义的模型列表作为后备
      return [];
    }
  }
}
