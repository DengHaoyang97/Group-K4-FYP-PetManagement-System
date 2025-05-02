import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'mongo_service.dart';
import 'status.dart';

Future<String> getAIResponse(String message) async {
  final url = Uri.parse("https://api.siliconflow.cn/v1/chat/completions");

  final payload = json.encode({
    "model": "Qwen/QwQ-32B",
    "stream": false,
    "max_tokens": 1024,
    "temperature": 0.7,
    "top_p": 0.7,
    "top_k": 50,
    "frequency_penalty": 0.5,
    "n": 1,
    "messages": [
      {
        "content": message.length > 1000 ? message.substring(0, 1000) : message,
        "role": "user",
      }
    ]
  });

  final headers = {
    'Authorization':
        'Bearer sk-xojtxhrhcrpqolsrmuikdvoqdtkgtocofapehlepixhfkzva',
    'Content-Type': 'application/json',
  };

  try {
    final response =
        await http.post(url, headers: headers, body: payload).timeout(
              const Duration(seconds: 30),
              onTimeout: () => http.Response('Error: Request timed out', 408),
            );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['choices'][0]['message']['content'] ?? 'No reply from AI';
    } else {
      return 'Error: Failed to get AI response - Status: ${response.statusCode}, Body: ${response.body}';
    }
  } catch (e) {
    return 'Error: $e';
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadChatHistory(); // 进入页面时加载历史记录
  }

  // 加载历史聊天记录
  Future<void> _loadChatHistory() async {
    final history = await MongoDatabase.getAIChatHistory(userId);
    setState(() {
      _messages.addAll(history);
    });
    _scrollToBottom(); // 加载历史记录后滚动到最底部
  }

  // 发送消息并获取 AI 回复
  void _sendMessage(String message) async {
    if (message.trim().isEmpty) return;
    if (message.length > 1000) {
      setState(() {
        _messages.add({
          'text': 'Error: Message too long (max 1000 characters)',
          'sender': 'bot'
        });
        _scrollToBottom();
      });
      return;
    }

    // 添加用户消息到本地
    setState(() {
      _messages.add({'text': message, 'sender': 'user'});
      _scrollToBottom();
    });
    developer.log('User message: $message', name: 'ChatPage');

    // 保存用户消息到 MongoDB
    await MongoDatabase.saveAIChatMessage(userId, "user", message);

    _controller.clear();

    // 获取 AI 回复
    String aiResponse = await getAIResponse(message);
    setState(() {
      _messages.add({'text': aiResponse, 'sender': 'bot'});
      _scrollToBottom();
    });
    developer.log('AI reply: $aiResponse', name: 'ChatPage');

    // 保存 AI 回复到 MongoDB
    await MongoDatabase.saveAIChatMessage(userId, "bot", aiResponse);
  }

  // 滚动到最底部的方法
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat with AI'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message['sender'] == 'user';
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      message['text']!,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Enter your message...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (value) {
                      _sendMessage(value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    _sendMessage(_controller.text);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

void main() {
  runApp(const MaterialApp(
    home: ChatPage(),
  ));
}
