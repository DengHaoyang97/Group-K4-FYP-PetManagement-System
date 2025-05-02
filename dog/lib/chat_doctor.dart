import 'dart:async';

import 'package:flutter/material.dart';

import 'chat.dart';
import 'mongo_service.dart';
import 'status.dart';

class ChatDoctorPage extends StatefulWidget {
  const ChatDoctorPage({super.key});

  @override
  State<ChatDoctorPage> createState() => _ChatDoctorPageState();
}

class _ChatDoctorPageState extends State<ChatDoctorPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _messages = [];
  Timer? _chatRefreshTimer;
  bool _initialReportSent = false;
  String? _petId;
  bool _hasSentStopMessage = false;

  @override
  void initState() {
    super.initState();
    _fetchPetIdAndLoadChat();
    _startAutoRefresh();
  }

  Future<void> _fetchPetIdAndLoadChat() async {
    final pets = await MongoDatabase.getUserPets(userId);
    final selectedPet = pets.firstWhere(
      (p) => p['name'] == pet,
      orElse: () => null,
    );

    if (selectedPet != null) {
      setState(() {
        _petId = selectedPet['pet_id']?.toString();
      });
    }

    // Load His
    await _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    List<dynamic> chatHistory = await MongoDatabase.getChatHistory(userId);
    setState(() {
      _messages = chatHistory;
    });
    _scrollToBottom();

    if (!_initialReportSent) {
      _initialReportSent = true;
      await _sendInitialPetReport();
    }
  }

  void _startAutoRefresh() {
    _chatRefreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _loadChatHistory();
    });
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;
    await MongoDatabase.addChatMessage(userId, "user", message);
    await _loadChatHistory();
    _scrollToBottom();
  }

  void _sendManualMessage() {
    String message = _controller.text.trim();
    if (message.isEmpty) return;
    _controller.clear();
    _sendMessage(message);
  }

  Future<void> _endConsultation() async {
    if (_hasSentStopMessage) return;
    final endMessage = "***currentpet:$pet    Stop consulting！***";
    await _sendMessage(endMessage);
    _hasSentStopMessage = true;
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const ChatSelectionPage()),
        (Route<dynamic> route) => false,
      );
    }
  }

  Future<void> _sendInitialPetReport() async {
    if (pet == null || pet.isEmpty) {
      await _sendMessage("No pet selected.");
      return;
    }

    if (_petId == null) {
      await _sendMessage("Cannot find pet ID for $pet.");
      return;
    }

    // 第一步：发送 pet 值
    final petMessage = "***currentpet:$pet, start consulting!***";
    await _sendMessage(petMessage);

    final reports = await MongoDatabase.getAllReports(userId, _petId!);
    if (reports.isEmpty) {
      await _sendMessage("No health reports available for this pet.");
      return;
    }

    reports
        .sort((a, b) => (b["timestamp"] ?? "").compareTo(a["timestamp"] ?? ""));
    final latestReport = reports.first;
    final latestReportName =
        latestReport['report_name']?.toString() ?? 'Unnamed Report';

    await _sendMessage("Latest Report: $latestReportName");

    // Load WBC RBC
    final rbcReports = await MongoDatabase.getIndicatorReports(
        userId, _petId!, "RBC",
        limit: 5);
    final wbcReports =
        await MongoDatabase.getWBCReports(userId, _petId!, limit: 5);

    Map<String, dynamic>? latestRBC;
    Map<String, dynamic>? latestWBC;

    for (var report in rbcReports) {
      if (report['report_name'] == latestReportName) {
        latestRBC = report;
        break;
      }
    }

    for (var report in wbcReports) {
      if (report['report_name'] == latestReportName) {
        latestWBC = report;
        break;
      }
    }

    final buffer = StringBuffer();
    buffer.writeln("***RBC and WBC Values from $latestReportName:***\n");

    if (latestRBC == null && latestWBC == null) {
      await _sendMessage(
          "No RBC or WBC data available in the latest report: $latestReportName.");
      return;
    }

    if (latestRBC != null) {
      buffer.writeln(
          "RBC: ${latestRBC['value']} (Timestamp: ${latestRBC['timestamp']})");
    } else {
      buffer.writeln("RBC: Not available in this report");
    }

    if (latestWBC != null) {
      buffer.writeln(
          "WBC: ${latestWBC['value']} (Timestamp: ${latestWBC['timestamp']})");
    } else {
      buffer.writeln("WBC: Not available in this report");
    }

    await _sendMessage(buffer.toString());
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    if (!_hasSentStopMessage) {
      _sendStopMessageOnDispose();
    }
    _controller.dispose();
    _scrollController.dispose();
    _chatRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendStopMessageOnDispose() async {
    final endMessage = "***currentpet:$pet    Stop consulting！***";
    await MongoDatabase.addChatMessage(userId, "user", endMessage);
    _hasSentStopMessage = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat with Doctor"),
        actions: [
          IconButton(
            icon: const Icon(Icons.stop_circle, color: Colors.white),
            tooltip: "End Consultation",
            onPressed: _endConsultation,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final isUser = message["category"] == "user";
                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isUser ? Colors.blue[100] : Colors.green[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        message["message"] ?? "",
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  );
                },
              ),
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
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: _sendManualMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
