import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'mongo_service.dart';
import 'status.dart';

class OCRReportPage extends StatefulWidget {
  OCRReportPage({super.key});

  @override
  State<OCRReportPage> createState() => _OCRReportPageState();
}

class _OCRReportPageState extends State<OCRReportPage> {
  String? _selectedPetId;
  File? _imageFile;
  String _ocrText = '';
  List<dynamic> _pets = [];
  bool _isProcessing = false;
  List<Map<String, String>> _parsedTable = [];
  String _selectedDate = DateTime.now().toIso8601String().split('T').first; // 默认日期为当前日期

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  Future<void> _loadPets() async {
    final pets = await MongoDatabase.getUserPets(userId);
    String? matchedPetId;

    for (var p in pets) {
      if (p['name'] == pet) {
        matchedPetId = p['pet_id'];
        break;
      }
    }

    setState(() {
      _pets = pets;
      _selectedPetId = matchedPetId;
    });
  }

  Future<void> _pickImage({bool append = false}) async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _isProcessing = true;
      });
      await _performOCR(_imageFile!, append: append);
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _performOCR(File imageFile, {bool append = false}) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.ocr.space/parse/image'),
      );
      request.headers['apikey'] = 'helloworld';
      request.fields['language'] = 'eng';
      request.fields['isTable'] = 'true';
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 20));
      final response = await http.Response.fromStream(streamedResponse);

      final result = json.decode(response.body);
      if (result["IsErroredOnProcessing"] == false) {
        final text = result["ParsedResults"][0]["ParsedText"] ?? "";
        final newTable = _parseTextToTable(text);
        setState(() {
          _ocrText += "\n" + text;
          _parsedTable = append ? [..._parsedTable, ...newTable] : newTable;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ OCR failed:")),
        );
      }
    } on SocketException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Network error, please check your connection.")),
      );
    } on TimeoutException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ OCR timed out, please try again.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Unexpected error: $e")),
      );
    }
  }

  List<Map<String, String>> _parseTextToTable(String text) {
    final lines = text.split('\n');
    final keywords = [
      'RBC', 'HCT', 'HGB', 'MCV', 'MCH', 'MCHC', 'RDW', '%RETIC', 'RETIC', 'RETIC-HGB',
      'WBC', '%NEU', '%LYM', '%MONO', '%EOS', '%BASO', 'NEU', 'BAND', 'LYM', 'MONO',
      'EOS', 'BASO', 'PLT', 'MPV', 'PDW', 'PCT', 'CREA', 'BUN', 'BUN/CREA', 'PHOS',
      'ALT', 'ALKP', 'Na', 'K', 'Na/K', 'Cl', 'GLU', 'TP', 'ALB', 'GLOB', 'ALB/GLOB',
      'CA', 'GGT', 'TBIL', 'CHOL', 'AMYL', 'LIPA', 'Osm Calc'
    ];

    List<Map<String, String>> table = [];
    for (String line in lines) {
      for (String key in keywords) {
        if (line.startsWith(key)) {
          final parts = line.split(RegExp(r'\s+'));
          if (parts.length >= 3) {
            table.add({
              'item': key,
              'value': parts.length > 1 ? parts[1] : '',
              'unit': parts.length > 2 ? parts[2] : '',
              'range': parts.length > 3 ? parts[3] : '',
              'status': parts.any((w) => w.toLowerCase().contains('high'))
                  ? 'HIGH'
                  : parts.any((w) => w.toLowerCase().contains('low'))
                  ? 'LOW'
                  : ''
            });
          }
        }
      }
    }
    return table;
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked.toIso8601String().split('T').first;
      });
    }
  }

  Future<void> _submitReport() async {
    if (_selectedPetId == null || _selectedDate.isEmpty || _ocrText.isEmpty) return;

    final report = {
      "report_id": DateTime.now().millisecondsSinceEpoch.toString(),
      "report_name": _selectedDate, // 使用选择的日期作为 report_name
      "timestamp": DateTime.now().toIso8601String(),
      "raw_text": _ocrText,
      "table": _parsedTable,
    };

    await MongoDatabase.addHealthReport(userId, _selectedPetId!, report);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Report submitted successfully!")),
    );

    setState(() {
      _ocrText = '';
      _imageFile = null;
      _parsedTable = [];
      _selectedDate = DateTime.now().toIso8601String().split('T').first; // 重置日期为当前日期
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("OCR Health Report")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedPetId,
              decoration: const InputDecoration(labelText: "Select Pet", border: OutlineInputBorder()),
              items: _pets.map((pet) {
                return DropdownMenuItem<String>(
                  value: pet['pet_id'],
                  child: Text(pet['name']),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedPetId = value),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: "Report Date",
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_selectedDate),
                    const Icon(Icons.calendar_today),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isProcessing ? null : () => _pickImage(append: false),
              child: _isProcessing
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("Upload First Page"),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isProcessing ? null : () => _pickImage(append: true),
              child: _isProcessing
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("Upload Next Page"),
            ),
            const SizedBox(height: 16),
            if (_parsedTable.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text("Item")),
                    DataColumn(label: Text("Value")),
                    DataColumn(label: Text("Unit")),
                    DataColumn(label: Text("Range")),
                    DataColumn(label: Text("Status")),
                  ],
                  rows: _parsedTable.asMap().entries.map((entry) {
                    final index = entry.key;
                    final row = entry.value;
                    return DataRow(cells: [
                      DataCell(Text(row['item'] ?? '')),
                      DataCell(TextFormField(
                        initialValue: row['value'],
                        onChanged: (val) => _parsedTable[index]['value'] = val,
                      )),
                      DataCell(TextFormField(
                        initialValue: row['unit'],
                        onChanged: (val) => _parsedTable[index]['unit'] = val,
                      )),
                      DataCell(TextFormField(
                        initialValue: row['range'],
                        onChanged: (val) => _parsedTable[index]['range'] = val,
                      )),
                      DataCell(TextFormField(
                        initialValue: row['status'],
                        onChanged: (val) => _parsedTable[index]['status'] = val,
                      )),
                    ]);
                  }).toList(),
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submitReport,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              child: const Text("Submit Report", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }
}