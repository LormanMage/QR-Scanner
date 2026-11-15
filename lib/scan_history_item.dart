
/// Одна запись в истории выдач.
///
/// Отличается от [EquipmentRequest] тем, что это уже СОСТОЯНИЕ:
/// мы зафиксировали факт выдачи и теперь можем отметить возврат.
/// Хранится в SharedPreferences в виде JSON
class ScanHistoryItem{
  /// Внутренний id записи (не путать с requestId — id заявки).
  /// Нужен, чтобы можно было удалить/обновить конкретную запись.
  final String id;

  /// id заявки из QR — по нему можно найти исходные данные.
  final String requestId;


  final String? studentName;


  final String? group;


  final List<String> equipment;

  /// Когда выдали (ставится автоматически в момент подтверждения).
  final DateTime issuedAt;

  /// Крайний срок возврата (из заявки, может быть null).
  final DateTime? dueAt;

  /// Когда фактически вернули. null — ещё не вернули.
  final DateTime? returnedAt;


  ScanHistoryItem({
    required this.id,
    required this.requestId,
    required this.issuedAt,
    this.studentName,
    this.group,
    this.equipment = const [],
    this.dueAt,
    this.returnedAt,
});

  bool get isReturned => returnedAt != null;

  /// Просрочено = не возвращено И срок уже прошёл.
  /// возвращённое вовремя оборудование не станет
  /// «просроченным» задним числом — важно для отчётности.
  bool get isOverdue =>
      !isReturned && dueAt != null && DateTime.now().isAfter(dueAt!);

  /// Текст для отображения статуса в списке истории.
  String get statusLabel {
    if(isReturned) return 'Возвращено';
    if(isOverdue) return 'Просрочено';

    return 'Выдано';
  }

  Map<String, dynamic> toJson() => {
    'id' : id,
    'requestId': requestId,
    'studentName': studentName,
    'group': group,
    'equipment': equipment,
    'issuedAt': issuedAt.toIso8601String(),
    'dueAt': dueAt?.toIso8601String(),
    'returnedAt': returnedAt?.toIso8601String(),
  };

  factory ScanHistoryItem.fromJson(Map<String, dynamic> json) => ScanHistoryItem(
    id: json['id'] as String,
    requestId: json['requestId'] as String,
    studentName: json['studentName'] as String?,
    group: json['group'] as String?,
    equipment: (json['equipment'] as List?)
        ?.map((e) => e.toString())
        .toList() ??
        const [],

    // issuedAt обязателен — если его нет, запись битая.
    // Такие записи отсеиваются при загрузке (try/catch в провайдере).
    issuedAt: DateTime.parse(json['issuedAt'] as String),
    dueAt: json['dueAt'] != null
        ? DateTime.parse(json['dueAt'] as String)
        : null,
    returnedAt: json['returnedAt'] != null
        ? DateTime.parse(json['returnedAt'] as String)
        : null,
  );
  /// Создаёт копию с изменённым returnedAt.
  /// Иммутабельная модель — не меняем поля напрямую, а заменяем объект.
  ScanHistoryItem copyWith({DateTime? returnedAt}) => ScanHistoryItem(
    id: id,
    requestId: requestId,
    studentName: studentName,
    group: group,
    equipment: equipment,
    issuedAt: issuedAt,
    dueAt: dueAt,
    returnedAt: returnedAt ?? this.returnedAt,
  );
}