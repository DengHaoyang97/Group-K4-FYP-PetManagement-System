import 'package:mongo_dart/mongo_dart.dart';

class MongoDatabase {
  static Db? _db;
  static DbCollection? userCollection;
  static const String mongoUrl =
      "mongodb+srv://billydeng97:dhyaaaa@petmanagement.fbbuxnk.mongodb.net/?retryWrites=true&w=majority&appName=PetManagement"; // Mongo Link Here
  static const String collectionName = "users";

  //Initialize MongoDB connection
  static Future<void> connect() async {
    if (_db != null && _db!.isConnected) return;
    try {
      _db = await Db.create(mongoUrl);
      await _db!.open();
      userCollection = _db!.collection(collectionName);
      print("✅ Successfully connected to MongoDB!");
    } catch (e) {
      print("❌ Failed to connect to MongoDB: $e");
    }
  }

  //Validate user login
  static Future<bool> loginUser(String username, String password) async {
    await connect();
    if (userCollection == null) return false;

    var user = await userCollection!.findOne({
      "username": username,
      "password":
          password, // ⚠️ Plain text comparison (consider hashing in production)
    });

    return user != null;
  }

  //Add a new user
  static Future<String> addUser(String username, String password) async {
    await connect();
    if (userCollection == null) return "❌ Database not connected";

    var existingUser = await userCollection!.findOne({"username": username});
    if (existingUser != null) {
      return "⚠️ User already exists";
    }

    await userCollection!.insertOne({
      "username": username,
      "password": password, // Stored in plain text
      "pets": [], // Keep original pets array
      "chat": [], // Initialize chat history as an empty array
    });

    return "✅ User added successfully!";
  }

  //Store chat messages (with category `user` or `worker`)
  static Future<void> addChatMessage(
    String username,
    String category,
    String message,
  ) async {
    await connect();
    if (userCollection == null) return;

    var chatMessage = {
      "category": category, // "user" or "worker"
      "message": message,
      "timestamp": DateTime.now().toIso8601String(),
    };

    await userCollection!.updateOne(
      {"username": username},
      {
        "\$push": {
          "chat": chatMessage, // Add new chat message
        },
      },
    );

    print("✅ Chat message stored successfully!");
  }

  //Retrieve chat history
  static Future<List<dynamic>> getChatHistory(String username) async {
    await connect();
    if (userCollection == null) return [];

    var user = await userCollection!.findOne({"username": username});
    return user?["chat"] ?? [];
  }

  /// **🔹 5. Clear chat history**
  static Future<void> clearChatHistory(String username) async {
    await connect();
    if (userCollection == null) return;

    await userCollection!.updateOne(
      {"username": username},
      {
        "\$set": {"chat": []}, // Reset chat history
      },
    );

    print("✅ Chat history cleared successfully!");
  }

  //Retaining Original Pet-Related Functions
  static Future<void> addPet(
    String username,
    Map<String, dynamic> petData,
  ) async {
    await connect();
    if (userCollection == null) return;

    await userCollection!.updateOne(
      {"username": username},
      {
        "\$push": {
          "pets": petData, // Add pet to pets array
        },
      },
    );

    print("✅ Pet added successfully!");
  }

  static Future<List<dynamic>> getPets(String username) async {
    await connect();
    if (userCollection == null) return [];

    var user = await userCollection!.findOne({"username": username});
    return user?["pets"] ?? [];
  }

  static Future<void> addHealthReport(
    String username,
    String petId,
    Map<String, dynamic> report,
  ) async {
    await connect();
    if (userCollection == null) return;

    await userCollection!.updateOne(
      {"username": username, "pets.pet_id": petId},
      {
        "\$push": {
          "pets.\$.health_reports": report, // Keep original `$` syntax
        },
      },
    );

    print("✅ Health report added successfully!");
  }

  static Future<List<dynamic>> getHealthReports(
    String username,
    String petId,
  ) async {
    await connect();
    if (userCollection == null) return [];

    var user = await userCollection!.findOne({"username": username});
    if (user == null) return [];

    List<dynamic> pets = user["pets"];
    var pet = pets.firstWhere((p) => p["pet_id"] == petId, orElse: () => null);

    return pet?["health_reports"] ?? [];
  }

  static Future<void> deletePet(String username, String petId) async {
    await connect();
    if (userCollection == null) return;

    await userCollection!.updateOne(
      {"username": username},
      {
        "\$pull": {
          "pets": {"pet_id": petId},
        },
      },
    );

    print("✅ Pet deleted successfully!");
  }

  static Future<void> deleteHealthReport(
    String username,
    String petId,
    String reportId,
  ) async {
    await connect();
    if (userCollection == null) return;

    await userCollection!.updateOne(
      {"username": username, "pets.pet_id": petId},
      {
        "\$pull": {
          "pets.\$.health_reports": {"report_id": reportId},
        },
      },
    );

    print("✅ Health report deleted successfully!");
  }

  //Get all pets for a user
  static Future<List<dynamic>> getUserPets(String username) async {
    await connect();
    if (userCollection == null) return [];

    var user = await userCollection!.findOne({"username": username});
    return user?["pets"] ?? [];
  }

  //Trigger SOS for a pet
  static Future<void> triggerSOS(
    String username,
    String petId,
    String latitude,
    String longitude,
  ) async {
    await connect();
    if (userCollection == null) return;

    await userCollection!.updateOne(
      {"username": username, "pets.pet_id": petId},
      {
        "\$set": {
          "pets.\$.sos": "ing",
          "pets.\$.location": {"latitude": latitude, "longitude": longitude},
        },
      },
    );

    print("🚨 SOS activated for pet ID: $petId!");
  }

  static Future<List<dynamic>> getRescueHistory(String username) async {
    await connect();
    if (userCollection == null) return [];

    try {
      // 获取用户信息
      var user = await userCollection!.findOne({"username": username});

      if (user == null || user["pets"] == null) return [];

      List<dynamic> pets = user["pets"];
      List<dynamic> rescueHistory = [];

      for (var pet in pets) {
        if (pet is Map<String, dynamic> && pet.containsKey("sos")) {
          rescueHistory.add({
            "petName": pet["name"] ?? "Unknown Pet",
            "status": pet["sos"] ?? "unknown",
            "location": pet.containsKey("location") &&
                    pet["location"] is Map<String, dynamic>
                ? pet["location"]
                : {"latitude": "N/A", "longitude": "N/A"},
          });
        }
      }

      return rescueHistory;
    } catch (e) {
      print("❌ Error fetching rescue history: $e");
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getLatestHealthReports(
    String userId,
    String petId, {
    int limit = 2,
  }) async {
    await connect();
    if (userCollection == null) return [];

    final user = await userCollection!.findOne({"_id": userId});
    if (user == null || user["pets"] == null) return [];

    final List<Map<String, dynamic>> pets = List<Map<String, dynamic>>.from(
      user["pets"],
    );
    final Map<String, dynamic>? pet =
        pets.cast<Map<String, dynamic>?>().firstWhere(
              (p) => p != null && p["pet_id"] == petId,
              orElse: () => null,
            );

    if (pet == null || pet["health_reports"] == null) return [];

    final reports = List<Map<String, dynamic>>.from(pet["health_reports"]);
    reports.sort(
      (a, b) => (b["timestamp"] ?? "").compareTo(a["timestamp"] ?? ""),
    );
    return reports.take(limit).toList();
  }

  /// 🔍 Get WBC values from pet's health reports
  static Future<List<Map<String, dynamic>>> getWBCReports(
    String username,
    String petId, {
    int limit = 5,
  }) async {
    await connect();
    if (userCollection == null) return [];

    final user = await userCollection!.findOne({"username": username});
    if (user == null || user["pets"] == null) return [];

    final List<Map<String, dynamic>> pets = List<Map<String, dynamic>>.from(
      user["pets"],
    );
    final Map<String, dynamic>? pet =
        pets.cast<Map<String, dynamic>?>().firstWhere(
              (p) => p != null && p["pet_id"] == petId,
              orElse: () => null,
            );

    if (pet == null || pet["health_reports"] == null) return [];

    final reports = List<Map<String, dynamic>>.from(pet["health_reports"]);
    reports.sort(
      (a, b) => (b["timestamp"] ?? "").compareTo(a["timestamp"] ?? ""),
    );

    // 只提取WBC相关
    final wbcReports = reports
        .take(limit)
        .where(
          (report) =>
              report.containsKey("table") &&
              (report["table"] as List).any((row) => row["item"] == "WBC"),
        )
        .map((report) {
      final table = report["table"] as List;
      final wbcRow = table.firstWhere((row) => row["item"] == "WBC");
      return {
        "value": wbcRow["value"],
        "report_name": report["report_name"] ?? "Unnamed",
        "timestamp": report["timestamp"] ?? "",
      };
    }).toList();

    return wbcReports;
  }

  static Future<List<Map<String, dynamic>>> getIndicatorReports(
    String username,
    String petId,
    String indicator, {
    int limit = 5,
  }) async {
    await connect();
    if (userCollection == null) return [];

    final user = await userCollection!.findOne({"username": username});
    if (user == null || user["pets"] == null) return [];

    final List<Map<String, dynamic>> pets = List<Map<String, dynamic>>.from(
      user["pets"],
    );
    final Map<String, dynamic>? pet =
        pets.cast<Map<String, dynamic>?>().firstWhere(
              (p) => p != null && p["pet_id"] == petId,
              orElse: () => null,
            );

    if (pet == null || pet["health_reports"] == null) return [];

    final reports = List<Map<String, dynamic>>.from(pet["health_reports"]);
    reports.sort(
      (a, b) => (b["timestamp"] ?? "").compareTo(a["timestamp"] ?? ""),
    );

    final filtered = reports
        .take(limit)
        .where(
          (report) =>
              report.containsKey("table") &&
              (report["table"] as List).any(
                (row) => row["item"] == indicator,
              ),
        )
        .map((report) {
      final table = report["table"] as List;
      final row = table.firstWhere((r) => r["item"] == indicator);
      return {
        "value": row["value"],
        "report_name": report["report_name"] ?? "Unnamed",
        "timestamp": report["timestamp"] ?? "",
      };
    }).toList();

    return filtered;
  }

  static Future<List<Map<String, dynamic>>> getAllReports(
    String username,
    String petId,
  ) async {
    await connect();
    if (userCollection == null) return [];

    try {
      //Search User
      final user = await userCollection!.findOne({"username": username});
      if (user == null || user["pets"] == null) {
        return [];
      }

      // Search Pet from list
      final List<Map<String, dynamic>> pets = List<Map<String, dynamic>>.from(
        user["pets"],
      );
      final Map<String, dynamic>? pet =
          pets.cast<Map<String, dynamic>?>().firstWhere(
                (p) => p != null && p["pet_id"] == petId,
                orElse: () => null,
              );

      if (pet == null || pet["health_reports"] == null) return [];

      // 获取该宠物的所有体检报告
      List<Map<String, dynamic>> reports = List<Map<String, dynamic>>.from(
        pet["health_reports"],
      );

      return reports; // 返回所有体检报告
    } catch (e) {
      print("❌ Error fetching all reports: $e");
      return [];
    }
  }

  static Future<void> updatePet(
    String username,
    Map<String, dynamic> updatedPet,
  ) async {
    await connect();
    if (userCollection == null) return;

    try {
      final petId = updatedPet["pet_id"];
      if (petId == null) {
        print("❌ Pet ID is required for update");
        return;
      }

      await userCollection!.updateOne(
        {"username": username, "pets.pet_id": petId},
        {
          "\$set": {
            "pets.\$": updatedPet,
          },
        },
      );
      print("✅ Pet updated successfully!");
    } catch (e) {
      print("❌ Error updating pet: $e");
    }
  }

  static Future<List<Map<String, dynamic>>> getLatestHealthReportsByUsername(
    String username,
    String petId, {
    int limit = 2,
  }) async {
    await connect();
    if (userCollection == null) {
      print("❌ Database not connected");
      return [];
    }

    try {
      final user = await userCollection!.findOne({"username": username});
      if (user == null || user["pets"] == null) {
        print("❌ User or pets not found for username: $username");
        return [];
      }

      // 找到指定 petId 的宠物
      final List<Map<String, dynamic>> pets = List<Map<String, dynamic>>.from(
        user["pets"],
      );
      final Map<String, dynamic>? pet =
          pets.cast<Map<String, dynamic>?>().firstWhere(
                (p) => p != null && p["pet_id"] == petId,
                orElse: () => null,
              );

      if (pet == null) {
        print("❌ Pet not found for petId: $petId");
        return [];
      }

      if (pet["health_reports"] == null ||
          (pet["health_reports"] as List).isEmpty) {
        print("❌ No health reports found for petId: $petId");
        return [];
      }

      // Get Time Stamp
      final reports = List<Map<String, dynamic>>.from(pet["health_reports"]);
      reports.sort(
        (a, b) => (b["timestamp"] ?? "").compareTo(a["timestamp"] ?? ""),
      );

      print(
        "✅ Successfully fetched ${reports.length} health reports for petId: $petId",
      );
      return reports.take(limit).toList();
    } catch (e) {
      print("❌ Error fetching health reports: $e");
      return [];
    }
  }

  //Save History
  static Future<void> saveAIChatMessage(
    String username,
    String sender,
    String text,
  ) async {
    await connect();
    if (userCollection == null) {
      print("❌ Database not connected");
      return;
    }

    try {
      await userCollection!.updateOne(
        {"username": username},
        {
          "\$push": {
            "ai_chat_history": {
              "sender": sender,
              "text": text,
              "timestamp": DateTime.now().toIso8601String(),
            },
          },
        },
        upsert: true,
      );
      print("✅ AI chat message saved for username: $username");
    } catch (e) {
      print("❌ Error saving AI chat message: $e");
    }
  }

  // AI Chat History
  static Future<List<Map<String, String>>> getAIChatHistory(
    String username,
  ) async {
    await connect();
    if (userCollection == null) {
      print("❌ Database not connected");
      return [];
    }

    try {
      final user = await userCollection!.findOne({"username": username});
      if (user == null || user["ai_chat_history"] == null) {
        print("❌ No AI chat history found for username: $username");
        return [];
      }

      final history = List<Map<String, dynamic>>.from(user["ai_chat_history"]);
      // 将聊天记录转换为 ChatPage 所需的格式
      final messages = history
          .map(
            (msg) => {
              "sender": msg["sender"] as String,
              "text": msg["text"] as String,
            },
          )
          .toList();
      print(
        "✅ Fetched ${messages.length} AI chat messages for username: $username",
      );
      return messages.cast<Map<String, String>>();
    } catch (e) {
      print("❌ Error fetching AI chat history: $e");
      return [];
    }
  }

  /// **🔹 Update SOS status for a pet**
  static Future<void> updateSOSStatus(
    String username,
    String petId,
    String newStatus,
  ) async {
    await connect();
    if (userCollection == null) return;

    try {
      await userCollection!.updateOne(
        {"username": username, "pets.pet_id": petId},
        {
          "\$set": {"pets.\$.sos": newStatus},
        },
      );
      print("✅ SOS status updated to $newStatus for petId: $petId");
    } catch (e) {
      print("❌ Error updating SOS status: $e");
    }
  }

  // 获取医生建议
  static Future<List<Map<String, dynamic>>> getDoctorSuggestions(
    String userId,
    String petId,
  ) async {
    await connect();
    if (userCollection == null) return [];

    final user = await userCollection!.findOne({"username": userId});
    if (user != null && user["pets"] != null) {
      final List<Map<String, dynamic>> pets = List<Map<String, dynamic>>.from(
        user["pets"],
      );
      final Map<String, dynamic>? pet =
          pets.cast<Map<String, dynamic>?>().firstWhere(
                (p) => p != null && p["pet_id"].toString() == petId,
                orElse: () => null,
              );
      if (pet != null && pet["sugg"] != null) {
        return List<Map<String, dynamic>>.from(pet["sugg"]);
      }
    }
    return [];
  }

  // 修改：基于 username 查询用户
  static Future<Map<String, dynamic>> getUserData(String username) async {
    await connect();
    if (_db == null) {
      throw Exception('Database not initialized. Call connect() first.');
    }
    final collection = _db!.collection('users');
    final userData = await collection.findOne(where.eq('username', username));
    if (userData == null) {
      throw Exception('User not found for username: $username');
    }
    return userData;
  }
}
