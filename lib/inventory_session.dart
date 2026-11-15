import 'equipment_item.dart';

/// Одна сессия инвентаризации — от нажатия «Провести инвентаризацию»
/// до нажатия «Завершить». Хранит список отсканированного.
class InventorySession {
  final String id;
  final DateTime startedAt;
  final List<EquipmentItem> items;

  InventorySession({
    required this.id,
    required this.startedAt,
    List<EquipmentItem>? items,
  }) : items = items ?? [];

  int get count => items.length;

  Map<String, dynamic> toJson() => {
    'id': id,
    'startedAt': startedAt.toIso8601String(),
    'items': items.map((e) => e.toJson()).toList(),
  };

  factory InventorySession.fromJson(Map<String, dynamic> json) =>
      InventorySession(
        id: json['id'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
        items: (json['items'] as List?)
            ?.map((e) =>
            EquipmentItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
            [],
      );
}