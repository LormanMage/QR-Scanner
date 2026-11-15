import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'equipment_request.dart';
import 'scan_history_item.dart';

/// Единственный источник правды по истории выдач.
///
/// Зачем provider, а не просто список в HomeScreen:
/// - историю открывают из нескольких экранов (главный, инвентаризация);
/// - при добавлении записи все открытые экраны должны обновиться сами;
/// - данные нужно сохранять на диск при каждом изменении.
class HistoryProvider extends ChangeNotifier {
  /// v2 в имени ключа — если схема хранения поменяется, старые данные
  /// не сломают новую версию: просто читаем по новому ключу.
  static const _storageKey = 'scan_history_v2';

  // Внутренний изменяемый список. Наружу отдаём копию через getter,
  // чтобы никто снаружи случайно не изменил его в обход notifyListeners.
  final List<ScanHistoryItem> _items = [];

  bool _loaded = false;

  List<ScanHistoryItem> get items => List.unmodifiable(_items);

  /// Пока false — экран истории показывает спиннер.
  /// Без этого флага на старте мелькнёт «История пуста», хотя данные есть.
  bool get isLoaded => _loaded;

  /// Загружает историю с диска. Вызывается один раз при старте приложения
  /// (в main через `HistoryProvider()..load()`).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        _items
          ..clear()
          ..addAll(decoded.map(
                  (e) => ScanHistoryItem.fromJson(e as Map<String, dynamic>)));
      } catch (e) {
        // Если одна запись битая — не роняем всё приложение.
        // В идеале тут можно фильтровать по одной, но для учебного
        // проекта достаточно залогировать и начать с пустой истории.
        debugPrint('Ошибка загрузки истории: $e');
      }
    }
    _loaded = true;
    notifyListeners();
  }

  /// Фиксирует выдачу оборудования. Возвращает созданную запись —
  /// может пригодиться, если после выдачи нужно показать что-то ещё.
  ///
  /// Вызывается ТОЛЬКО после подтверждения лаборантом
  /// (см. IssueConfirmScreen). Не в _onDetect сканера — иначе в историю
  /// попадут все случайно отсканированные коды.
  Future<ScanHistoryItem> issue(EquipmentRequest request) async {
    final item = ScanHistoryItem(
      // microsecondsSinceEpoch — практичнее, чем счётчик:
      // не нужно хранить отдельный индекс, id всегда уникален.
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      requestId: request.id,
      studentName: request.studentName,
      group: request.group,
      equipment: request.equipment,
      issuedAt: DateTime.now(),
      dueAt: request.until,
    );

    // insert(0, ...) — новые записи сверху списка.
    _items.insert(0, item);
    notifyListeners();          // экраны перерисуются
    await _persist();           // и данные уйдут на диск
    return item;
  }

  /// Отмечает оборудование возвращённым.
  /// Повторный вызов для уже возвращённой записи — no-op (защита от
  /// двойного тапа по меню).
  Future<void> markReturned(String id) async {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx == -1 || _items[idx].isReturned) return;

    _items[idx] = _items[idx].copyWith(returnedAt: DateTime.now());
    notifyListeners();
    await _persist();
  }

  Future<void> remove(String id) async {
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> clear() async {
    _items.clear();
    notifyListeners();
    await _persist();
  }

  /// Сериализует весь список в JSON и пишет в SharedPreferences.
  /// Вызывается после каждого изменения — так данные не потеряются,
  /// даже если приложение убьют из памяти.
  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_items.map((e) => e.toJson()).toList()),
    );
  }
}
