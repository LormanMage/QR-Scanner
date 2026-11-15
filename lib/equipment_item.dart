import 'dart:convert';

/// Физическая единица оборудования, распарсенная из QR.
///
/// Обязательны только "id" и "name", остальное — по желанию.
/// Поле "type" помогает отличить QR оборудования от QR заявки студента:
/// если его нет, парсим как оборудование (для совместимости).
class EquipmentItem {
  final String id;
  final String name;
  final String? model;
  final String? serial;
  final String? location;

  /// Сырая строка из QR — на случай ошибки или отладки.
  final String raw;

  /// Когда физически отсканировали (для журнала инвентаризации).
  final DateTime scannedAt;

  /// false — QR не похож на оборудование (или это QR заявки).
  final bool isValid;

  /// Человекочитаемая причина, если [isValid] == false.
  final String? parseError;

  EquipmentItem({
    required this.id,
    required this.name,
    required this.raw,
    required this.scannedAt,
    this.model,
    this.serial,
    this.location,
    this.isValid = true,
    this.parseError,
  });

  /// Приватный конструктор для ошибочных случаев — чтобы не дублировать
  /// кучу пустых полей в каждом return.
  EquipmentItem._error({
    required this.raw,
    required this.scannedAt,
    required this.parseError,
  })  : id = '',
        name = '',
        model = null,
        serial = null,
        location = null,
        isValid = false;

  factory EquipmentItem.fromQr(String raw, {DateTime? scannedAt}) {
    final ts = scannedAt ?? DateTime.now();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return EquipmentItem._error(
          raw: raw,
          scannedAt: ts,
          parseError: 'QR не содержит JSON-объект',
        );
      }

      final map = decoded as Map<String, dynamic>;
      final type = map['type']?.toString();

      // Явно чужой тип: подсказываем пользователю, что он не туда зашёл.
      if (type == 'request') {
        return EquipmentItem._error(
          raw: raw,
          scannedAt: ts,
          parseError:
          'Это QR заявки студента. Используйте «Сканировать QR».',
        );
      }
      if (type != null && type != 'equipment') {
        return EquipmentItem._error(
          raw: raw,
          scannedAt: ts,
          parseError: 'Неизвестный тип QR: "$type"',
        );
      }

      final id = map['id']?.toString();
      final name = map['name']?.toString();
      if (id == null || id.isEmpty) {
        return EquipmentItem._error(
          raw: raw,
          scannedAt: ts,
          parseError: 'В QR нет поля "id"',
        );
      }
      if (name == null || name.isEmpty) {
        return EquipmentItem._error(
          raw: raw,
          scannedAt: ts,
          parseError: 'В QR нет поля "name"',
        );
      }

      return EquipmentItem(
        id: id,
        name: name,
        model: map['model'] as String?,
        serial: map['serial'] as String?,
        location: map['location'] as String?,
        raw: raw,
        scannedAt: ts,
      );
    } catch (_) {
      return EquipmentItem._error(
        raw: raw,
        scannedAt: ts,
        parseError: 'Некорректный JSON в QR',
      );
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'model': model,
    'serial': serial,
    'location': location,
    'raw': raw,
    'scannedAt': scannedAt.toIso8601String(),
  };

  factory EquipmentItem.fromJson(Map<String, dynamic> json) => EquipmentItem(
    id: json['id'] as String,
    name: json['name'] as String,
    model: json['model'] as String?,
    serial: json['serial'] as String?,
    location: json['location'] as String?,
    raw: json['raw'] as String? ?? '',
    scannedAt: DateTime.parse(json['scannedAt'] as String),
  );
}