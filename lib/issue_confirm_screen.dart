import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'equipment_request.dart';
import 'history_provider.dart';

/// Экран подтверждения выдачи. Открывается из сканера вместо старого
/// AlertDialog с сырым кодом — лаборанту нужно видеть, ЧТО и КОМУ он выдаёт.
///
/// Возвращает:
///   true  — выдача подтверждена, запись добавлена в историю;
///   false — отмена (или QR оказался невалидным).
class IssueConfirmScreen extends StatefulWidget {
  final EquipmentRequest request;
  const IssueConfirmScreen({super.key, required this.request});

  @override
  State<IssueConfirmScreen> createState() => _IssueConfirmScreenState();
}

class _IssueConfirmScreenState extends State<IssueConfirmScreen> {
  /// Блокирует кнопку на время записи в SharedPreferences,
  /// чтобы двойной тап не создал две записи.
  bool _issuing = false;

  Future<void> _confirm() async {
    setState(() => _issuing = true);
    try {
      await context.read<HistoryProvider>().issue(widget.request);
      // pop(true) — сканер по этому результату закроется и вернёт
      // requestId на главный экран для снекбара.
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _issuing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Подтверждение выдачи'),
        backgroundColor: const Color(0xFFE60026),
      ),
      // Две ветки: валидная заявка (карточка с деталями + кнопки)
      // и невалидная (ошибка + сырая строка QR).
      body: widget.request.isValid
          ? _buildValid(context)
          : _buildInvalid(context),
    );
  }

  Widget _buildValid(BuildContext context) {
    final r = widget.request;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Expanded + SingleChildScrollView — карточка занимает всё
          // свободное место и скроллится, если оборудование длинное,
          // а кнопки всегда прижаты к низу.
          Expanded(
            child: SingleChildScrollView(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row(Icons.person, 'Студент', r.studentName ?? '—'),
                      _row(Icons.group, 'Группа', r.group ?? '—'),
                      _row(Icons.confirmation_number, 'Заявка', r.id),
                      if (r.until != null)
                        _row(Icons.event, 'Вернуть до', _fmtDate(r.until!)),
                      const Divider(height: 24),
                      const Text('Оборудование:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      // Если список пуст — показываем прочерк,
                      // а не пустое место.
                      if (r.equipment.isEmpty)
                        const Text('—')
                      else
                        ...r.equipment.map(
                              (e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.check,
                                    size: 18, color: Colors.green),
                                const SizedBox(width: 8),
                                Expanded(child: Text(e)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  // На время сохранения отключаем и отмену —
                  // чтобы не получилось «отменил, но запись уже создалась».
                  onPressed: _issuing
                      ? null
                      : () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Отмена'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _issuing ? null : _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE60026),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  // Пока идёт запись — спиннер вместо текста,
                  // чтобы пользователь видел, что тап сработал.
                  child: _issuing
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black),
                  )
                      : const Text('Подтвердить выдачу',
                      style: TextStyle(
                          color: Colors.black, fontSize: 16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvalid(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            const Text('Не удалось распознать заявку',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(widget.request.parseError ?? 'Неизвестная ошибка',
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            // Показываем сырую строку — лаборанту проще понять,
            // что отсканировали (например, QR от другого сервиса).
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                widget.request.raw,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 24),
            // pop(false) — сканер снова включит камеру (см. _onDetect).
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE60026),
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Сканировать снова',
                  style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  /// Строка «иконка + подпись + значение». Вынесено,
  /// чтобы не дублировать вёрстку для каждого поля заявки.
  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Text('$label: ', style: const TextStyle(color: Colors.grey)),
          // Expanded + ellipsis — длинное ФИО не вылезет за границы.
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year}';
  }
}