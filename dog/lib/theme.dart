import 'package:flutter/material.dart';

final ThemeData appTheme = ThemeData(
  colorScheme: ColorScheme.fromSwatch(
    primarySwatch: Colors.green, // 主颜色
  ).copyWith(
    primary: Color(0xFF2E7D32),    // 深绿
    secondary: Color(0xFF81C784), // 浅绿
    surface: Color(0xFFFFF9C4), // 背景色
    error: Color(0xFFFF8A65),      // 错误色
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: Color(0xFF2E7D32), // 深绿
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 20,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Color(0xFF81C784), // 按钮背景色
    ),
  ),
);

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: appTheme,
      home: Scaffold(
        appBar: AppBar(
          title: Text("Flutter Theme Example"),
        ),
        body: Center(
          child: ElevatedButton(
            onPressed: () {},
            child: Text("Press Me"),
          ),
        ),
      ),
    );
  }
}
