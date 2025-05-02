import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'ReportViewPage.dart';
import 'chat.dart';
import 'image_classification.dart';
import 'login_page.dart';
import 'mongo_service.dart';
import 'ocr.dart';
import 'sos.dart';
import 'status.dart';
import 'theme.dart';
import 'under_development_page.dart';
import 'user_management_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MongoDatabase.connect();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter UI Demo',
      theme: appTheme,
      home: const HomePage(),
    );
  }
}

// 模拟调用 DeepSeek API
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
        "content": message,
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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _displayedUserId = userId;
  List<dynamic> _pets = [];
  String? _selectedPetAvatar;
  String? _petId;
  List<FlSpot> _indicatorSpots = [];
  List<String> _reportLabels = [];
  List<DateTime> _reportDates = [];
  String _selectedIndicator = 'WBC';
  List<Map<String, dynamic>> _allReports = [];
  Map<String, dynamic>? _selectedReport;
  bool _isLoadingAI = false;
  String _aiSuggestion =
      'No AI suggestion yet. Click "AI Suggestion" to generate.';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isLoggedIn) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginPage()),
        );
      } else {
        _fetchAndSetInitialPet();
      }
    });
  }

  Future<void> _fetchAndSetInitialPet() async {
    final pets = await MongoDatabase.getUserPets(userId);
    setState(() {
      _pets = pets;
    });
    if (pets.isNotEmpty && pet.isEmpty) {
      setState(() {
        pet = pets.first['name'] ?? '';
        _petId = pets.first['pet_id']?.toString();
        _selectedPetAvatar = pets.first['avatar'];
      });
    }
    _fetchIndicatorData();
    _fetchAllReports();
  }

  Future<void> _fetchIndicatorData() async {
    if (_petId == null) {
      print("No pet ID available, cannot fetch indicator data");
      setState(() {
        _indicatorSpots = [];
        _reportLabels = [];
        _reportDates = [];
      });
      return;
    }

    print("Step 1: Fetching $_selectedIndicator data for pet ID: $_petId");
    // 查询 MongoDB 中用户对应宠物的 health_reports 数据
    final userData = await MongoDatabase.getUserData(userId);
    print("Step 2: User data fetched: $userData");

    List<dynamic> pets = userData['pets'] ?? [];
    print("Step 3: Pets list: $pets");

    var selectedPet = pets.firstWhere(
      (p) => p['pet_id'].toString() == _petId,
      orElse: () => null,
    );

    if (selectedPet == null) {
      print("Step 4: Selected pet not found for pet ID: $_petId");
      setState(() {
        _indicatorSpots = [];
        _reportLabels = [];
        _reportDates = [];
      });
      return;
    }
    print("Step 4: Selected pet found: $selectedPet");

    List<Map<String, dynamic>> reportData = [];
    List<dynamic> healthReports = selectedPet['health_reports'] ?? [];
    print("Step 5: Health reports: $healthReports");

    if (healthReports.isEmpty) {
      print("Step 6: No health reports available for pet ID: $_petId");
      setState(() {
        _indicatorSpots = [];
        _reportLabels = [];
        _reportDates = [];
      });
      return;
    }

    for (var report in healthReports) {
      print("Step 6: Processing report: $report");
      if (report is Map<String, dynamic>) {
        final reportName = report['report_name']?.toString();
        final timestampStr = report['timestamp']?.toString();
        final rawText = report['raw_text']?.toString();

        print(
            "Step 7: Report details - report_name: $reportName, timestamp: $timestampStr, raw_text: $rawText");

        if (reportName == null || timestampStr == null || rawText == null) {
          print(
              "Step 8: Missing required fields (report_name, timestamp, or raw_text). Skipping report.");
          continue;
        }

        // Extract WBC RBC
        double? parsedValue;
        try {
          RegExp regex = RegExp(
              r'^(WBC|RBC)\s*(\d*\.?\d+)\s*(?:K/pL|M/pL|MlpL|MIpL|MlPL|KIPL)',
              multiLine: true);
          var matches = regex.allMatches(rawText);
          for (var match in matches) {
            if (match.group(1) == _selectedIndicator) {
              parsedValue = double.tryParse(match.group(2) ?? '');
              print("Step 9: Matched $_selectedIndicator: $parsedValue");
              break;
            }
          }

          if (parsedValue == null) {
            print(
                "Step 9: Failed to extract $_selectedIndicator from raw_text: $rawText");
            continue;
          }

          if (reportName.isNotEmpty) {
            try {
              // 解析 timestamp（如 "2025-03-31T08:08:23.426615"）
              final date = DateTime.parse(timestampStr);
              reportData.add({
                'value': parsedValue,
                'report_name': reportName,
                'timestamp': date,
              });
              print(
                  "Step 10: Added report to reportData - value: $parsedValue, report_name: $reportName, timestamp: $date");
            } catch (e) {
              print("Step 10: Error parsing timestamp $timestampStr: $e");
            }
          } else {
            print("Step 10: Report name is empty, skipping report.");
          }
        } catch (e) {
          print("Step 9: Error parsing raw_text for $_selectedIndicator: $e");
        }
      } else {
        print("Step 7: Report is not a Map<String, dynamic>, skipping.");
      }
    }

    if (reportData.isEmpty) {
      print("Step 11: No valid report data extracted for $_selectedIndicator");
      setState(() {
        _indicatorSpots = [];
        _reportLabels = [];
        _reportDates = [];
      });
      return;
    }

    // 按时间排序
    reportData.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));
    print("Step 12: Sorted reportData: $reportData");

    // Max 5 Timepoints
    reportData = reportData.take(5).toList();
    print("Step 13: Limited reportData to 5 entries: $reportData");

    List<FlSpot> spots = [];
    List<String> labels = [];
    List<DateTime> dates = [];
    for (int i = 0; i < reportData.length; i++) {
      final data = reportData[i];
      spots.add(FlSpot(i.toDouble(), data['value']));
      labels.add(data['report_name'] as String);
      dates.add(data['timestamp'] as DateTime);
      print(
          "Step 14: Added spot: x=$i, y=${data['value']}, label=${data['report_name']}");
    }

    setState(() {
      _indicatorSpots = spots;
      _reportLabels = labels;
      _reportDates = dates;
    });
    print("Step 15: Final spots: $_indicatorSpots");
    print("Step 16: Final labels: $_reportLabels");
    print("Step 17: Final dates: $_reportDates");
  }

  Future<void> _fetchAllReports() async {
    if (_petId == null) {
      print("No pet ID available, cannot fetch reports");
      setState(() {
        _allReports = [];
        _selectedReport = null;
      });
      return;
    }

    print("Fetching all reports for pet ID: $_petId");
    final reports = await MongoDatabase.getAllReports(userId, _petId!);
    setState(() {
      _allReports = reports;
      _selectedReport = _allReports.isNotEmpty ? _allReports.first : null;
    });
    print("Fetched all reports: $_allReports");
  }

  Future<void> _fetchAISuggestion() async {
    if (_selectedReport == null) {
      setState(() {
        _aiSuggestion = 'Error: No report selected.';
      });
      return;
    }

    setState(() {
      _isLoadingAI = true;
      _aiSuggestion = 'Generating AI suggestion...';
    });

    try {
      final rawText = _selectedReport!['raw_text']?.toString() ?? '';
      final textSnippet =
          rawText.length > 100 ? rawText.substring(0, 100) : rawText;
      final prompt =
          "Based on the following pet health report snippet (first 100 characters): '$textSnippet', provide a detailed health diagnosis and dietary suggestions for the pet in 3 points diet, caring,activity. At the end, summarize the diagnosis and suggestions in three short sentences Max output 150 words, Don't mention max word used, Output in English.";
      final response = await getAIResponse(prompt);
      setState(() {
        _aiSuggestion = response;
      });
    } catch (e) {
      setState(() {
        _aiSuggestion = 'Error: Failed to fetch AI suggestion - $e';
      });
    } finally {
      setState(() {
        _isLoadingAI = false;
      });
    }
  }

  Widget _buildPetAvatar(String? base64) {
    if (base64 != null && base64.isNotEmpty) {
      try {
        return CircleAvatar(backgroundImage: MemoryImage(base64Decode(base64)));
      } catch (_) {}
    }
    try {
      return const CircleAvatar(
          backgroundImage: AssetImage("assets/default_pet.png"));
    } catch (e) {
      print("Failed to load default pet image: $e");
      return const CircleAvatar(
        backgroundColor: Colors.grey,
        child: Icon(Icons.pets, color: Colors.white),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Home"),
        actions: [
          PopupMenuButton(
            tooltip: "Select Pet",
            icon: _buildPetAvatar(_selectedPetAvatar),
            itemBuilder: (context) => _pets.map((petItem) {
              return PopupMenuItem(
                value: petItem,
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: _buildPetAvatar(petItem['avatar']),
                    ),
                    Text(petItem['name'] ?? 'Unnamed'),
                  ],
                ),
              );
            }).toList(),
            onSelected: (selected) {
              final petMap = selected as Map<String, dynamic>;
              setState(() {
                pet = petMap['name'];
                _petId = petMap['pet_id']?.toString();
                _selectedPetAvatar = petMap['avatar'];
                _aiSuggestion =
                    'No AI suggestion yet. Click "AI Suggestion" to generate.';
              });
              _fetchIndicatorData();
              _fetchAllReports();
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  const Text("Hello,",
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Text(_displayedUserId,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold)),
                  const Text("Welcome to the",
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const Text("Pet Management System.",
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 40),
            _buildFeatureButton(
                icon: Icons.description,
                label: "Document OCR",
                onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => OCRReportPage()));
                }),
            const SizedBox(height: 20),
            _buildFeatureButton(
                icon: Icons.medical_services,
                label: "Brand Identify",
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              const ImageClassificationPage()));
                }),
            const SizedBox(height: 20),
            _buildFeatureButton(
                icon: Icons.sos,
                label: "SOS",
                onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => const SOSPage()));
                }),
            const SizedBox(height: 30),
            if (_petId != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "$pet's $_selectedIndicator Trend Chart",
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        DropdownButton<String>(
                          value: _selectedIndicator,
                          items: <String>['WBC', 'RBC'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedIndicator = newValue;
                              });
                              _fetchIndicatorData();
                            }
                          },
                        ),
                      ],
                    ),
                    _indicatorSpots.isNotEmpty
                        ? SizedBox(
                            height: 200,
                            child: LineChart(
                              LineChartData(
                                minX: 0,
                                maxX: _indicatorSpots.isNotEmpty
                                    ? (_indicatorSpots.length - 1).toDouble()
                                    : 0,
                                minY: 0,
                                maxY: _indicatorSpots.isNotEmpty
                                    ? _indicatorSpots
                                            .map((spot) => spot.y)
                                            .reduce((a, b) => a > b ? a : b) *
                                        1.1
                                    : 0,
                                titlesData: FlTitlesData(
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 40,
                                      interval: 1,
                                      getTitlesWidget: (value, meta) {
                                        final index = value.toInt();
                                        if (index >= 0 &&
                                            index < _reportLabels.length &&
                                            value == index.toDouble()) {
                                          return SideTitleWidget(
                                            axisSide: meta.axisSide,
                                            space: 8,
                                            child: Text(
                                              _reportLabels[index],
                                              style:
                                                  const TextStyle(fontSize: 10),
                                            ),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 40,
                                      getTitlesWidget: (value, meta) {
                                        return Text(value.toStringAsFixed(1),
                                            style:
                                                const TextStyle(fontSize: 10));
                                      },
                                    ),
                                  ),
                                  topTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                ),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: _indicatorSpots,
                                    isCurved: true,
                                    color: Colors.blue,
                                    barWidth: 3,
                                    dotData: FlDotData(show: true),
                                  )
                                ],
                              ),
                            ),
                          )
                        : Text(
                            "No $_selectedIndicator data available for $pet",
                            style: const TextStyle(
                                fontSize: 16, color: Colors.grey),
                          ),
                    const SizedBox(height: 20),
                    if (_allReports.isNotEmpty)
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              DropdownButton<Map<String, dynamic>>(
                                value: _selectedReport,
                                hint: const Text("Select a report"),
                                items: _allReports.map((report) {
                                  return DropdownMenuItem<Map<String, dynamic>>(
                                    value: report,
                                    child: Text(
                                        report['report_name']?.toString() ??
                                            'Unnamed Report'),
                                  );
                                }).toList(),
                                onChanged: (Map<String, dynamic>? newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      _selectedReport = newValue;
                                      _aiSuggestion =
                                          'No AI suggestion yet. Click "AI Suggestion" to generate.';
                                    });
                                  }
                                },
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: _selectedReport != null
                                    ? () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ReportViewPage(
                                              reportName: _selectedReport![
                                                          'report_name']
                                                      ?.toString() ??
                                                  'Health Report',
                                              rawText:
                                                  _selectedReport!['raw_text']
                                                          ?.toString() ??
                                                      '',
                                            ),
                                          ),
                                        );
                                      }
                                    : null,
                                child: const Text("View"),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed:
                                    _selectedReport != null && !_isLoadingAI
                                        ? _fetchAISuggestion
                                        : null,
                                child: const Text("AI Suggestion"),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (_isLoadingAI)
                            const Center(
                              child: CircularProgressIndicator(),
                            ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Text(
                              _aiSuggestion,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      )
                    else
                      const Text(
                        "No reports available for this pet",
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    const SizedBox(height: 20),
                    // 重新添加医生建议模块
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Doctor Suggestions",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: MongoDatabase.getDoctorSuggestions(
                              userId, _petId!),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            } else if (snapshot.hasError) {
                              return const Text(
                                "Error loading suggestions",
                                style:
                                    TextStyle(fontSize: 16, color: Colors.red),
                              );
                            } else if (!snapshot.hasData ||
                                snapshot.data!.isEmpty) {
                              return const Text(
                                "No doctor suggestions available",
                                style:
                                    TextStyle(fontSize: 16, color: Colors.grey),
                              );
                            } else {
                              final suggestions = snapshot.data!;
                              return Container(
                                height: 150,
                                child: ListView.builder(
                                  itemCount: suggestions.length,
                                  itemBuilder: (context, index) {
                                    final suggestion = suggestions[index];
                                    final text =
                                        suggestion['text']?.toString() ??
                                            'No suggestion text';
                                    final timestamp =
                                        suggestion['timestamp'] != null
                                            ? DateTime.parse(
                                                    suggestion['timestamp'])
                                                .toLocal()
                                            : null;
                                    return Card(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              text,
                                              style:
                                                  const TextStyle(fontSize: 14),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              timestamp != null
                                                  ? "Added on: ${timestamp.toString().split('.')[0]}"
                                                  : "No timestamp",
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(icon: const Icon(Icons.home), onPressed: () {}),
            IconButton(
                icon: const Icon(Icons.chat),
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ChatSelectionPage()));
                }),
            IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const UnderDevelopmentPage()));
                }),
            IconButton(
                icon: const Icon(Icons.person),
                onPressed: () {
                  if (isLoggedIn) {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const UserManagementPage()));
                  } else {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) => LoginPage()));
                  }
                }),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureButton(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return SizedBox(
      width: 250,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.red),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
    );
  }
}
