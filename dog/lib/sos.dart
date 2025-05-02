import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'mongo_service.dart';
import 'status.dart';

class SOSPage extends StatefulWidget {
  const SOSPage({super.key});

  @override
  State<SOSPage> createState() => _SOSPageState();
}

class _SOSPageState extends State<SOSPage> {
  List<dynamic> _pets = [];
  String? _selectedPetId;
  Position? _currentLocation;
  List<Map<String, dynamic>> _rescueHistory = [];

  @override
  void initState() {
    super.initState();
    _fetchUserPets();
    _fetchRescueHistory();
    _getCurrentLocation();
  }

  //Fetch user's pets from MongoDB**
  Future<void> _fetchUserPets() async {
    List<dynamic> pets = await MongoDatabase.getUserPets(userId);
    setState(() {
      _pets = pets;
    });
  }

  //Fetch rescue history**
  Future<void> _fetchRescueHistory() async {
    List<dynamic> pets = await MongoDatabase.getUserPets(userId);
    // 显式地将 List<dynamic> 转换为 List<Map<String, dynamic>>
    List<Map<String, dynamic>> typedPets = pets.cast<Map<String, dynamic>>();
    List<Map<String, dynamic>> history = typedPets
        .where((pet) =>
            pet["sos"] != null &&
            (pet["sos"] == "ing" || pet["sos"] == "cancel"))
        .map((pet) => {
              "pet_id": pet["pet_id"] as String,
              "petName": pet["name"] as String,
              "status": pet["sos"] as String,
              "location": pet["location"] as Map<String, dynamic>? ??
                  {"latitude": "N/A", "longitude": "N/A"},
            })
        .toList();

    setState(() {
      _rescueHistory = history;
    });
  }

  //Request location permission manually**
  Future<void> requestLocationPermission() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Location permission denied!")),
      );
      return;
    }
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                "❌ Location permissions are permanently denied. Enable them in settings.")),
      );
      return;
    }

    _getCurrentLocation(); // Re-fetch location after permission is granted
  }

  //Get current location**
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text("⚠️ Location services are disabled. Please enable them.")),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      requestLocationPermission();
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("❌ Location permissions are permanently denied.")),
      );
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentLocation = position;
    });
  }

  /// **🔹 Trigger SOS**
  Future<void> _triggerSOS() async {
    if (_selectedPetId == null || _currentLocation == null) return;

    await MongoDatabase.triggerSOS(
      userId,
      _selectedPetId!,
      _currentLocation!.latitude.toString(),
      _currentLocation!.longitude.toString(),
    );

    _fetchRescueHistory(); // Refresh history after sending SOS
  }

  /// **🔹 Cancel SOS**
  Future<void> _cancelSOS(String petId) async {
    await MongoDatabase.updateSOSStatus(userId, petId, "cancel");
    _fetchRescueHistory(); // Refresh history after canceling SOS
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("SOS canceled successfully")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Emergency SOS")),
      body: Column(
        children: [
          // **🔹 Large SOS Sign**
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                "SOS",
                style: TextStyle(
                    color: Colors.red,
                    fontSize: 80,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // **🔹 Pet Selection Dropdown**
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<String>(
              value: _selectedPetId,
              items: _pets.map((pet) {
                return DropdownMenuItem<String>(
                  value: pet["pet_id"],
                  child: Text(pet["name"]),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedPetId = newValue;
                });
              },
              decoration: const InputDecoration(
                  labelText: "Select Pet", border: OutlineInputBorder()),
            ),
          ),

          // **🔹 Current Location**
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  _currentLocation != null
                      ? "Location: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}"
                      : "Fetching location...",
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: requestLocationPermission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  child: const Text("Request Location Permission",
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),

          // **🔹 SOS Button**
          ElevatedButton(
            onPressed: _triggerSOS,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            ),
            child: const Text("Trigger SOS",
                style: TextStyle(fontSize: 18, color: Colors.white)),
          ),

          const SizedBox(height: 20),

          // **🔹 Rescue History Table**
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: _rescueHistory.map((rescue) {
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text("Pet: ${rescue["petName"]}"),
                      subtitle: Text(
                        "Status: ${rescue["status"]} | Location: ${rescue["location"]["latitude"]}, ${rescue["location"]["longitude"]}",
                      ),
                      tileColor: rescue["status"] == "ing"
                          ? Colors.orange[100]
                          : Colors.green[100],
                      trailing: rescue["status"] == "ing"
                          ? IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              onPressed: () {
                                final petId = rescue["pet_id"]?.toString();
                                if (petId != null) {
                                  _cancelSOS(petId);
                                }
                              },
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
