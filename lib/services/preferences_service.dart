import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  PreferencesService(this._prefs);

  final SharedPreferences _prefs;

  static const _darkModeKey = 'pref_dark_mode';
  static const _studentNameKey = 'pref_student_name';

  bool getDarkMode() => _prefs.getBool(_darkModeKey) ?? false;

  Future<void> setDarkMode(bool value) => _prefs.setBool(_darkModeKey, value);

  String getStudentName() => _prefs.getString(_studentNameKey) ?? '';

  Future<void> setStudentName(String value) =>
      _prefs.setString(_studentNameKey, value.trim());
}
