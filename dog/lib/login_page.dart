import 'package:flutter/material.dart';

import 'main.dart';
import 'mongo_service.dart'; // 替换 SQLite，使用 MongoDB
import 'register_page.dart'; // 导入注册页面
import 'status.dart';

String? currentUsername;

class LoginPage extends StatelessWidget {
  LoginPage({super.key});

  // 控制器，用于获取用户输入
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Log in"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Welcome!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: "User name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    final username = _usernameController.text;
                    final password = _passwordController.text;

                    if (username.isEmpty || password.isEmpty) {
                      _showMessage(
                          context, "Username and password cannot be empty!");
                      return;
                    }

                    // Validate
                    final isValid =
                        await MongoDatabase.loginUser(username, password);
                    if (isValid) {
                      currentUsername = username;
                      isLoggedIn = true;
                      userId = username;

                      _showMessage(context, "Success！");
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HomePage(),
                        ),
                      );
                    } else {
                      _showMessage(context, "Error！Wrong password!");
                    }
                  },
                  child: const Text("Log in"),
                ),
                ElevatedButton(
                  onPressed: () {
                    // To Register
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterPage(),
                      ),
                    );
                  },
                  child: const Text("Register"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  //Notify
  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
