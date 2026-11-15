import 'dart:convert';

/// Заявка, распарсенная из QR-кода.
///
/// Пока бэкенда нет, QR содержит JSON целиком. Формат:
/// {
///   "id": "REQ-2025-0042",
///   "studentName": "Иванов И.И.",
///   "group": "ИВТ-21",
///   "equipment": ["Осциллограф", "Мультиметр"],
///   "until": "2025-11-20"
/// }
///
/// Когда появится бэкенд — QR можно сократить до одного `id`,
/// а метод [EquipmentRequest.fromQr] заменить на GET-запрос через dio.
class EquipmentRequest {
  /// Уникальный идентификатор заявки (из поля "id" в JSON или вся строка,
  /// если распарсить не удалось).
  final String id;

  /// Сырая строка из QR — сохраняем, чтобы показать лаборанту при ошибке
  /// и чтобы можно было разобраться, что именно отсканировали.
  final String raw;

  final String? studentName;
  final String? group;
  final List<String> equipment;

  /// Срок возврата. Может быть null, если в заявке не указан.
  final DateTime? until;

  /// false — QR не похож на заявку (не JSON, нет поля id и т.п.).
  /// Такие записи НЕ сохраняются в историю, показывается экран ошибки.
  final bool isValid;

  /// Человекочитаемая причина, почему [isValid] == false.
  final String? parseError;

  EquipmentRequest({
    required this.id,
    required this.raw,
    this.studentName,
    this.group,
    this.equipment = const [],
    this.until,
    this.isValid = true,
    this.parseError,
  });

  /// Парсит строку из QR. Никогда не бросает исключений — при любой
  /// проблеме возвращает объект с isValid = false и текстом ошибки.
  /// Так сканеру не нужно оборачивать вызов в try/catch.
  factory EquipmentRequest.fromQr(String raw) {
    try {
      final decoded = jsonDecode(raw);

      // QR может содержать что угодно: число, строку, массив.
      // Нам нужен именно объект с полями.
      if (decoded is! Map) {
        return EquipmentRequest(
          id: raw,
          raw: raw,
          isValid: false,
          parseError: 'QR не содержит JSON-объект',
        );
      }

      final map = decoded as Map<String, dynamic>;
      final type = map['type']?.toString();

// ← новый блок: QR не от заявки, а от оборудования
      if (type == 'equipment') {
        return EquipmentRequest(
          id: raw,
          raw: raw,
          isValid: false,
          parseError:
          'Это QR оборудования, а не заявки.\n'
              'Откройте «Провести инвентаризацию».',
        );
      }


      final id = map['id']?.toString();

      // Без id заявка бессмысленна — не сможем отличить одну от другой.
      if (id == null || id.isEmpty) {
        return EquipmentRequest(
          id: raw,
          raw: raw,
          isValid: false,
          parseError: 'В заявке отсутствует поле "id"',
        );
      }

      return EquipmentRequest(
        id: id,
        raw: raw,
        studentName: map['studentName'] as String?,
        group: map['group'] as String?,
        // Приводим каждый элемент к строке на случай, если в JSON числа.
        equipment: (map['equipment'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
            const [],
        // tryParse вернёт null при некорректной дате — не падаем.
        until: map['until'] != null
            ? DateTime.tryParse(map['until'].toString())
            : null,
      );
    } catch (_) {
      // jsonDecode бросил FormatException — значит, это не JSON вообще.
      return EquipmentRequest(
        id: raw,
        raw: raw,
        isValid: false,
        parseError: 'QR не является корректной заявкой',
      );
    }
  }
}
