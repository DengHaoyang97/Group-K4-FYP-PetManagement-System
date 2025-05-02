import 'package:flutter/material.dart';
import 'mongo_service.dart'; // Import MongoDB service

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Register"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Create Account",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),

            // Username input
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: "Username",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Password input
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Confirm Password input
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Confirm Password",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),

            // Register Button
            Center(
              child: ElevatedButton(
                onPressed: _registerUser,
                child: const Text("Register"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// **🔹 Register User Function**
  void _registerUser() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // Validation
    if (username.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showMessage("All fields are required!");
      return;
    }
    if (password != confirmPassword) {
      _showMessage("Passwords do not match!");
      return;
    }

    try {
      // Store in MongoDB
      String result = await MongoDatabase.addUser(username, password);

      // Show result message
      _showMessage(result);
      if (result == "✅ User registered successfully!") {
        Navigator.pop(context); // Return to login page after success
      }
    } catch (e) {
      _showMessage("❌ Registration failed: $e");
    }
  }

  /// **🔹 Show SnackBar Message**
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
