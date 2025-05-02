import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(const RGBClassifier());

class RGBClassifier extends StatelessWidget {
  const RGBClassifier({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ImageClassificationPage(),
    );
  }
}

class ImageClassificationPage extends StatefulWidget {
  const ImageClassificationPage({super.key});

  @override
  _ImageClassificationPageState createState() => _ImageClassificationPageState();
}

class _ImageClassificationPageState extends State<ImageClassificationPage> {
  File? _image;
  String _result = "Please choose a picture";

  final ImagePicker _picker = ImagePicker();

  Future<void> _classifyImageRemotely(File image) async {
    try {
      var request = http.MultipartRequest(
        "POST",
        Uri.parse("http://192.168.43.194:8000/predict"), // 改成你本地 FastAPI 服务器地址
      );

      request.files.add(await http.MultipartFile.fromPath('file', image.path));
      var response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final Map<String, dynamic> jsonResult = json.decode(responseBody);
        setState(() {
          _result = "Result: ${jsonResult['label']} (Confidence: ${jsonResult['confidence']})";
        });
      } else {
        setState(() {
          _result = "Server error: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _result = "Failed to classify: $e";
      });
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final image = File(pickedFile.path);
      setState(() {
        _image = image;
        _result = "Uploading...";
      });

      await _classifyImageRemotely(image);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dog Food Brand Classifier (Remote)"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_image != null)
              Image.file(_image!, height: 200, fit: BoxFit.cover)
            else
              const Text("No image selected"),
            const SizedBox(height: 20),
            Text(
              _result,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickImage,
              child: const Text("Upload Picture"),
            ),
          ],
        ),
      ),
    );
  }
}
