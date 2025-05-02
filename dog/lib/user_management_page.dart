import 'package:flutter/material.dart';

import 'login_page.dart';
import 'main.dart'; // ✅ 添加这行：导入 HomePage 所在的文件
import 'pet_manage.dart';
import 'status.dart';

class UserManagementPage extends StatelessWidget {
  const UserManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("User Management"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 40,
                  child: Icon(Icons.person, size: 40),
                ),
                const SizedBox(width: 16),
                Text(
                  "Welcome $currentUsername",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // 图片框
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey),
              ),
              child: const Center(
                child: Text(
                  "Pic",
                  style: TextStyle(fontSize: 18, color: Colors.black54),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // 功能菜单
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: const Icon(Icons.pets, color: Colors.blue),
                    title: const Text("Manage pets"),
                    onTap: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const PetManagePage()),
                        (route) => false,
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings, color: Colors.blue),
                    title: const Text("Settings"),
                    onTap: () {
                      print("Settings clicked");
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.info, color: Colors.blue),
                    title: const Text("About us"),
                    onTap: () {
                      print("About us clicked");
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      "Log Out",
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      isLoggedIn = false;
                      Navigator.popUntil(context, (route) => route.isFirst);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Successfully logged out")),
                      );
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const HomePage()),
                        (route) => false,
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.home, color: Colors.green),
                    title: const Text("Back to Homepage"),
                    onTap: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const HomePage()),
                        (route) => false,
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
}
