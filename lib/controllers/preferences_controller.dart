import 'package:flutter/material.dart';
import '../services/preferences_service.dart';

class PreferencesController extends ChangeNotifier {
  PreferencesController(this._service) {
    _darkMode = _service.getDarkMode();
    _studentName = _service.getStudentName();
  }

  final PreferencesService _service;
  bool _darkMode = false;
  String _studentName = '';

  bool get darkMode => _darkMode;
  String get studentName => _studentName;
  ThemeMode get themeMode => _darkMode ? ThemeMode.dark : ThemeMode.light;

  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    notifyListeners();
    await _service.setDarkMode(value);
  }

  Future<void> setStudentName(String value) async {
    _studentName = value.trim();
    notifyListeners();
    await _service.setStudentName(_studentName);
  }
}
