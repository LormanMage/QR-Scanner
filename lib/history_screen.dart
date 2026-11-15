import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'history_provider.dart';
import 'scan_history_item.dart';

/// История выдач оборудования.
///
/// Показывает все записи из [HistoryProvider]. Фильтр «Только выданное»
/// переключается чипом прямо на экране — стартовое состояние «показать всё».
///
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  /// false — показываем все записи; true — только невозвращённые.
  bool _showOnlyIssued = false;

  @override
  Widget build(BuildContext context) {
    // watch — экран перерисуется при любом изменении истории
    // (добавили выдачу, отметили возврат, очистили).
    final provider = context.watch<HistoryProvider>();
    final all = provider.items;
    final items =
    _showOnlyIssued ? all.where((e) => !e.isReturned).toList() : all;

    return Scaffold(
      appBar: AppBar(
        title: const Text('История выдач'),
        backgroundColor: const Color(0xFFE60026),
        centerTitle: true,
        actions: [
          // Кнопка очистки скрыта, если чистить нечего.
          if (all.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Очистить историю',
              onPressed: () => _confirmClear(context),
            ),
        ],
      ),
      // Пока данные грузятся — спиннер, а не «История пуста».
      body: !provider.isLoaded
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Только выданное'),
                  selected: _showOnlyIssued,
                  onSelected: (v) =>
                      setState(() => _showOnlyIssued = v),
                ),
                const Spacer(),
                // Счётчик считает уже отфильтрованное — так понятнее,
                // что видит пользователь.
                Text(
                  'Всего: ${items.length}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
              child: Text(
                _showOnlyIssued
                    ? 'Нет выданного оборудования'
                    : 'История пуста',
                style: const TextStyle(color: Colors.grey),
              ),
            )
                : ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, i) =>
                  _HistoryTile(item: items[i]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Очистить историю?'),
        content: const Text('Все записи будут удалены безвозвратно.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
    // context.mounted — после await виджет мог быть уничтожен
    // (например, пользователь ушёл назад, пока открыт диалог).
    if (ok == true && context.mounted) {
      context.read<HistoryProvider>().clear();
    }
  }
}

/// Карточка одной записи. Вынесена в отдельный виджет, чтобы не раздувать
/// build у HistoryScreen и не пересоздавать всю вёрстку списка.
class _HistoryTile extends StatelessWidget {
  final ScanHistoryItem item;
  const _HistoryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    // Цвет статуса:
    // серый — вернули (уже не актуально),
    // оранжевый — просрочили (требует внимания),
    // красный — выдано и всё нормально.
    final color = item.isReturned
        ? Colors.grey
        : item.isOverdue
        ? Colors.orange
        : const Color(0xFFE60026);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Icon(Icons.qr_code_2, color: color, size: 36),
        // Если ФИО нет (например, QR содержал только id) — показываем id.
        title: Text(
          item.studentName ?? item.requestId,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.group != null) Text('Группа: ${item.group}'),
              if (item.equipment.isNotEmpty)
                Text('Оборудование: ${item.equipment.join(', ')}'),
              Text('Выдано: ${_fmt(item.issuedAt)}'),
              if (item.dueAt != null) Text('Вернуть до: ${_fmt(item.dueAt!)}'),
              if (item.isReturned)
                Text('Возвращено: ${_fmt(item.returnedAt!)}'),
              const SizedBox(height: 4),
              Text(
                item.statusLabel,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        isThreeLine: true,
        // Меню действий: возврат доступен только для невозвращённого,
        // удаление — всегда.
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'return') {
              await context.read<HistoryProvider>().markReturned(item.id);
            } else if (v == 'delete') {
              await context.read<HistoryProvider>().remove(item.id);
            }
          },
          itemBuilder: (_) => [
            if (!item.isReturned)
              const PopupMenuItem(
                value: 'return',
                child: Text('Отметить возврат'),
              ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Удалить'),
            ),
          ],
        ),
      ),
    );
  }

  /// Формат «дд.мм.гггг чч:мм» — привычный для наших пользователей.
  String _fmt(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }
}