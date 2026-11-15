import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'equipment_item.dart';
import 'inventory_session.dart';

/// Состояние инвентаризации.
///
/// Особенности:
/// - сессия сохраняется на диск при каждом изменении — если приложение
///   убьют из памяти посреди инвентаризации, при следующем запуске
///   можно продолжить;
/// - дубликаты по id оборудования отсекаются (см. [add]);
/// - метод [finish] сейчас просто очищает сессию. Если понадобится
///   архив завершённых инвентаризаций — сюда легко добавить список
///   `_completed` и ещё один ключ в SharedPreferences.
class InventoryProvider extends ChangeNotifier {
  static const _currentKey = 'inventory_current';

  InventorySession? _current;
  bool _loaded = false;

  InventorySession? get current => _current;
  bool get hasActiveSession => _current != null;
  bool get isLoaded => _loaded;

  /// Вызывается один раз при старте приложения (в main).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_currentKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _current = InventorySession.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      } catch (e) {
        debugPrint('Ошибка загрузки сессии инвентаризации: $e');
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
    _persist();
    notifyListeners();
  }

  /// Возвращает true, если позиция добавлена впервые.
  /// Повторный скан того же id (или уже добавленного вручную) — false.
  bool add(EquipmentItem item) {
    if (_current == null) return false;
    if (_current!.items.any((e) => e.id == item.id)) return false;

    _current!.items.add(item);
    _persist();
    notifyListeners();
    return true;
  }

  /// Убрать ошибочно отсканированную позицию.
  void removeItem(String id) {
    if (_current == null) return;
    _current!.items.removeWhere((e) => e.id == id);
    _persist();
    notifyListeners();
  }

  /// Завершить сессию. Сейчас — просто очищаем.
  /// Точка расширения под «сохранить в историю инвентаризаций».
  Future<void> finish() async {
    _current = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentKey);
    notifyListeners();
  }

  /// Отменить сессию (выбросить всё отсканированное).
  Future<void> cancel() async {
    _current = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentKey);
    notifyListeners();
  }

  Future<void> _persist() async {
    if (_current == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentKey, jsonEncode(_current!.toJson()));
  }
}