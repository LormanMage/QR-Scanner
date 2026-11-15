import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'equipment_item.dart';
import 'inventory_session.dart';
///состояние инвентаризации
class InventoryProvider extends ChangeNotifier {
  static const _currentKey = 'inventory_current';
  static const _historyKey = 'inventory_history'; // ← новый ключ

  InventorySession? _current;
  List<InventorySession> _pastSessions = []; // ← история
  bool _loaded = false;

  InventorySession? get current => _current;
  bool get hasActiveSession => _current != null;
  List<InventorySession> get pastSessions => List.unmodifiable(_pastSessions); // ← getter
  bool get isLoaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    // Загружаем текущую (незавершённую) сессию
    final rawCurrent = prefs.getString(_currentKey);
    if (rawCurrent != null && rawCurrent.isNotEmpty) {
      try {
        _current = InventorySession.fromJson(jsonDecode(rawCurrent));
      } catch (e) {
        debugPrint('Ошибка загрузки текущей сессии: $e');
      }
    }

    // Загружаем историю завершённых сессий
    final rawHistory = prefs.getString(_historyKey);
    if (rawHistory != null && rawHistory.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawHistory) as List;
        _pastSessions = decoded
            .map((e) => InventorySession.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Ошибка загрузки истории инвентаризаций: $e');
      }
    }

    _loaded = true;
    notifyListeners();
  }

  void start() {
    _current = InventorySession(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      startedAt: DateTime.now(),
    );
    _persistCurrent();
    notifyListeners();
  }

  bool add(EquipmentItem item) {
    if (_current == null) return false;
    if (_current!.items.any((e) => e.id == item.id)) return false;
    _current!.items.add(item);
    _persistCurrent();
    notifyListeners();
    return true;
  }

  void removeItem(String id) {
    if (_current == null) return;
    _current!.items.removeWhere((e) => e.id == id);
    _persistCurrent();
    notifyListeners();
  }

  /// Завершить сессию и сохранить её в историю
  Future<void> finish() async {
    if (_current != null) {
      _pastSessions.insert(0, _current!); // добавляем в начало списка
      _current = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentKey);
      await prefs.setString(
        _historyKey,
        jsonEncode(_pastSessions.map((e) => e.toJson()).toList()),
      );
    }
    notifyListeners();
  }

  /// Отменить сессию (без сохранения в историю)
  Future<void> cancel() async {
    _current = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentKey);
    notifyListeners();
  }

  /// Удалить сессию из архива
  Future<void> removePastSession(String id) async {
    _pastSessions.removeWhere((e) => e.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _historyKey,
      jsonEncode(_pastSessions.map((e) => e.toJson()).toList()),
    );
    notifyListeners();
  }

  Future<void> _persistCurrent() async {
    if (_current == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentKey, jsonEncode(_current!.toJson()));
  }
}
