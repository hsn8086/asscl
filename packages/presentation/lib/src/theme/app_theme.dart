import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() => ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.light,
      );

  static ThemeData dark() => ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.dark,
      );
}
