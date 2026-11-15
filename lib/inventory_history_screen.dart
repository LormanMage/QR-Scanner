import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'inventory_provider.dart';
import 'inventory_scan_screen.dart';
import 'inventory_session.dart';

/// Экран со списком всех завершённых инвентаризаций.
/// Отсюда же можно начать новую.
class InventoryHistoryScreen extends StatelessWidget {
  const InventoryHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventoryProvider>();
    final sessions = provider.pastSessions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Инвентаризация'),
        backgroundColor: const Color(0xFFE60026),
        centerTitle: true,
      ),
      body: !provider.isLoaded
          ? const Center(child: CircularProgressIndicator())
          : sessions.isEmpty
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'История инвентаризаций пуста.\nНажмите кнопку ниже, чтобы начать.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.only(bottom: 80), // отступ для FAB
        itemCount: sessions.length,
        itemBuilder: (context, index) {
          final session = sessions[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              leading: const Icon(Icons.inventory, color: Color(0xFFE60026)),
              title: Text('Инвентаризация от ${_fmtDate(session.startedAt)}'),
              subtitle: Text('Отсканировано единиц: ${session.count}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => provider.removePastSession(session.id),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InventorySessionDetailsScreen(session: session),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const InventoryScanScreen()),
          );
        },
        backgroundColor: const Color(0xFFE60026),
        icon: const Icon(Icons.qr_code_scanner, color: Colors.black),
        label: const Text('Начать', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }
}

/// Экран с подробностями одной сессии (список отсканированного).
class InventorySessionDetailsScreen extends StatelessWidget {
  final InventorySession session;
  const InventorySessionDetailsScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали инвентаризации'),
        backgroundColor: const Color(0xFFE60026),
      ),
      body: ListView.separated(
        itemCount: session.items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final item = session.items[i];
          final subtitle = [
            if (item.model != null) item.model!,
            if (item.serial != null) 'S/N ${item.serial!}',
            if (item.location != null) item.location!,
          ].join(' • ');

          return ListTile(
            leading: const Icon(Icons.inventory_2, color: Color(0xFFE60026)),
            title: Text(item.name),
            subtitle: subtitle.isEmpty ? null : Text(subtitle),
          );
        },
      ),
    );
  }
}