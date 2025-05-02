import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'mongo_service.dart';
import 'status.dart';

class NewPetPage extends StatefulWidget {
  const NewPetPage({super.key});

  @override
  State<NewPetPage> createState() => _NewPetPageState();
}

class _NewPetPageState extends State<NewPetPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _breedController = TextEditingController();
  final TextEditingController _speciesController = TextEditingController();
  final TextEditingController _doctorController = TextEditingController();
  final TextEditingController _telController = TextEditingController();

  File? _avatarImage;
  File? _ocrImage;

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      String avatarBase64 = _avatarImage != null
          ? base64Encode(await _avatarImage!.readAsBytes())
          : "";

      final petData = {
        "pet_id": DateTime.now().millisecondsSinceEpoch.toString(),
        "name": _nameController.text,
        "age": _ageController.text,
        "gender": _genderController.text,
        "weight": _weightController.text,
        "breed": _breedController.text,
        "species": _speciesController.text,
        "doctor": _doctorController.text,
        "tel": _telController.text,
        "avatar": avatarBase64, // Store avatar as base64
        "health_reports": []
      };

      await MongoDatabase.addPet(userId, petData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pet added successfully!")),
      );

      Navigator.pop(context);
    }
  }

  Future<void> _pickAvatar() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _avatarImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickOCRImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _ocrImage = File(pickedFile.path);
      });
      await _performOCR(_ocrImage!);
    }
  }

  Future<void> _performOCR(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final response = await http.post(
      Uri.parse("https://api.ocr.space/parse/image"),
      headers: {
        "apikey": "helloworld",
      },
      body: {
        "base64Image": "data:image/jpeg;base64,$base64Image",
        "language": "eng",
      },
    );

    final result = json.decode(response.body);
    if (result["IsErroredOnProcessing"] == false) {
      final text = result["ParsedResults"][0]["ParsedText"] ?? "";
      _parseOCRText(text);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("OCR failed to extract text.")),
      );
    }
  }

  void _parseOCRText(String text) {
    final lines = text.split('\n');
    for (final line in lines) {
      if (line.contains("Client:")) {
        _nameController.text = line.replaceAll("Client:", "").trim().split("(")[0];
      } else if (line.contains("Doctor:")) {
        _doctorController.text = line.replaceAll("Doctor:", "").trim();
      } else if (line.contains("Gender:")) {
        _genderController.text = line.replaceAll("Gender:", "").trim();
      } else if (line.contains("Age:")) {
        _ageController.text = line.replaceAll("Age:", "").trim();
      } else if (line.contains("Weight:")) {
        _weightController.text = line.replaceAll("Weight:", "").trim();
      } else if (line.contains("Tel:")) {
        _telController.text = line.replaceAll("Tel:", "").trim();
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _genderController.dispose();
    _weightController.dispose();
    _breedController.dispose();
    _speciesController.dispose();
    _doctorController.dispose();
    _telController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add New Pet")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildField("Name", _nameController),
              _buildField("Age", _ageController),
              _buildField("Gender", _genderController),
              _buildField("Weight", _weightController),
              _buildField("Breed", _breedController),
              _buildField("Species", _speciesController),
              _buildField("Doctor", _doctorController),
              _buildField("Owner Tel", _telController),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _pickOCRImage,
                child: const Text("Upload Health Report for OCR"),
              ),

              const SizedBox(height: 20),
              if (_avatarImage != null)
                Image.file(_avatarImage!, height: 100),
              ElevatedButton(
                onPressed: _pickAvatar,
                child: const Text("Choose Avatar Image"),
              ),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submit,
                child: const Text("Submit"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {bool required = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: required
            ? (value) => (value == null || value.isEmpty) ? "Please enter $label" : null
            : null,
      ),
    );
  }
}