import 'dart:convert';
import 'dart:io'; // 用于处理 File

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // 引入 image_picker 包

import 'mongo_service.dart';
import 'newpet.dart';
import 'status.dart';
import 'user_management_page.dart';

class PetManagePage extends StatefulWidget {
  const PetManagePage({super.key});

  @override
  State<PetManagePage> createState() => _PetManagePageState();
}

class _PetManagePageState extends State<PetManagePage> {
  List<Map<String, dynamic>> _pets = [];

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  Future<void> _loadPets() async {
    final pets = await MongoDatabase.getUserPets(userId);
    setState(() {
      _pets = pets.map((pet) {
        final petMap = (pet as Map).cast<String, dynamic>();
        return {...petMap, 'isEditing': false};
      }).toList();
    });
  }

  Future<void> _deletePet(String petId) async {
    await MongoDatabase.deletePet(userId, petId);
    _loadPets();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Pet deleted successfully")),
    );
  }

  Future<void> _updatePet(Map<String, dynamic> pet) async {
    await MongoDatabase.updatePet(userId, pet);
    _loadPets();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Pet updated successfully")),
    );
  }

  Widget _buildPetItem(Map<String, dynamic> pet) {
    final avatarBase64 = pet["avatar"];
    Image avatarImage;

    if (avatarBase64 != null &&
        avatarBase64 is String &&
        avatarBase64.isNotEmpty) {
      try {
        avatarImage =
            Image.memory(base64Decode(avatarBase64), fit: BoxFit.cover);
      } catch (e) {
        avatarImage = Image.asset("assets/default_pet.png", fit: BoxFit.cover);
      }
    } else {
      avatarImage = Image.asset("assets/default_pet.png", fit: BoxFit.cover);
    }

    final isEditing = pet['isEditing'] as bool? ?? false;

    final nameController =
        TextEditingController(text: pet["name"]?.toString() ?? "Unnamed");
    final ageController =
        TextEditingController(text: pet["age"]?.toString() ?? "");
    final genderController =
        TextEditingController(text: pet["gender"]?.toString() ?? "");
    final weightController =
        TextEditingController(text: pet["weight"]?.toString() ?? "");
    final breedController =
        TextEditingController(text: pet["breed"]?.toString() ?? "");
    final speciesController =
        TextEditingController(text: pet["species"]?.toString() ?? "");
    final doctorController =
        TextEditingController(text: pet["doctor"]?.toString() ?? "");
    final telController =
        TextEditingController(text: pet["tel"]?.toString() ?? "");

    // 选择新图像的方法
    Future<void> _pickImage() async {
      final picker = ImagePicker();
      final pickedFile =
          await picker.pickImage(source: ImageSource.gallery); // 从图库选择图片

      if (pickedFile != null) {
        final bytes = await File(pickedFile.path).readAsBytes();
        final base64Image = base64Encode(bytes);
        setState(() {
          pet["avatar"] = base64Image;
        });
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 60,
                  width: 60,
                  child: avatarImage,
                ),
              ),
              title: isEditing
                  ? TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: "Name"),
                    )
                  : Text(pet["name"]?.toString() ?? "Unnamed"),
              subtitle: isEditing
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: ageController,
                          decoration: const InputDecoration(labelText: "Age"),
                          keyboardType: TextInputType.number,
                        ),
                        TextFormField(
                          controller: genderController,
                          decoration:
                              const InputDecoration(labelText: "Gender"),
                        ),
                        TextFormField(
                          controller: weightController,
                          decoration:
                              const InputDecoration(labelText: "Weight (kg)"),
                          keyboardType: TextInputType.number,
                        ),
                        TextFormField(
                          controller: breedController,
                          decoration: const InputDecoration(labelText: "Breed"),
                        ),
                        TextFormField(
                          controller: speciesController,
                          decoration:
                              const InputDecoration(labelText: "Species"),
                        ),
                        TextFormField(
                          controller: doctorController,
                          decoration:
                              const InputDecoration(labelText: "Doctor"),
                        ),
                        TextFormField(
                          controller: telController,
                          decoration:
                              const InputDecoration(labelText: "Owner Tel"),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.image),
                          label: const Text("Re-upload Image"),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Age: ${pet["age"]?.toString() ?? ''}"),
                        Text("Gender: ${pet["gender"]?.toString() ?? ''}"),
                        Text("Weight: ${pet["weight"]?.toString() ?? ''} kg"),
                        Text("Breed: ${pet["breed"]?.toString() ?? ''}"),
                        Text("Species: ${pet["species"]?.toString() ?? ''}"),
                        Text("Doctor: ${pet["doctor"]?.toString() ?? ''}"),
                        Text("Owner Tel: ${pet["tel"]?.toString() ?? ''}"),
                      ],
                    ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(isEditing ? Icons.save : Icons.edit),
                    onPressed: () {
                      if (isEditing) {
                        pet["name"] = nameController.text;
                        pet["age"] =
                            int.tryParse(ageController.text) ?? pet["age"];
                        pet["gender"] = genderController.text;
                        pet["weight"] =
                            double.tryParse(weightController.text) ??
                                pet["weight"];
                        pet["breed"] = breedController.text;
                        pet["species"] = speciesController.text;
                        pet["doctor"] = doctorController.text;
                        pet["tel"] = telController.text;
                        _updatePet(pet);
                      }
                      setState(() {
                        pet['isEditing'] = !pet['isEditing'];
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("Confirm Delete"),
                          content: const Text(
                              "Are you sure you want to delete this pet?"),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Cancel"),
                            ),
                            TextButton(
                              onPressed: () {
                                final petId = pet["pet_id"]?.toString();
                                if (petId != null) {
                                  _deletePet(petId);
                                  Navigator.pop(context);
                                }
                              },
                              child: const Text("Delete"),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pet Management"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // 返回到 UserManagementPage
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => const UserManagementPage()),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NewPetPage()),
          );
          _loadPets();
        },
        child: const Icon(Icons.add),
        tooltip: "Add New Pet",
      ),
      body: _pets.isEmpty
          ? const Center(child: Text("No pets found."))
          : ListView.builder(
              itemCount: _pets.length,
              itemBuilder: (context, index) => _buildPetItem(_pets[index]),
            ),
    );
  }
}

void main() {
  runApp(const MaterialApp(home: PetManagePage()));
}
