import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import 'equipment_item.dart';
import 'inventory_provider.dart';

/// Экран инвентаризации. Открывается по кнопке «Провести инвентаризацию».
///
/// Сверху — камера, снизу — список уже отсканированного.
/// Каждое новое срабатывание: парсим QR → добавляем в список (с дедупом) →
/// показываем snackbar. По тапу на позицию в списке или по «Подробнее» в
/// snackbar открывается карточка оборудования.
class InventoryScanScreen extends StatefulWidget {
  const InventoryScanScreen({super.key});

  @override
  State<InventoryScanScreen> createState() => _InventoryScanScreenState();
}

class _InventoryScanScreenState extends State<InventoryScanScreen> {
  final MobileScannerController controller = MobileScannerController(
    formats: [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  /// Защита от слишком частых срабатываний, если камера «поймала»
  /// один и тот же код несколько раз в пределах долей секунды.
  DateTime? _lastScanAt;

  @override
  void initState() {
    super.initState();
    // Провайдер трогаем после первого кадра — безопаснее, чем в initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<InventoryProvider>();
      if (provider.current == null) {
        provider.start();
      } else if (provider.current!.items.isEmpty) {
        // Пустая «брошенная» сессия (пользователь нажал и сразу вышел).
        // Пересоздаём, чтобы startedAt был актуальным.
        provider.cancel();
        provider.start();
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null) return;

    // 300 мс — достаточно, чтобы не долбить провайдер, но и не мешать
    // быстро переставлять камеру между соседними приборами.
    final now = DateTime.now();
    if (_lastScanAt != null &&
        now.difference(_lastScanAt!).inMilliseconds < 300) {
      return;
    }
    _lastScanAt = now;

    final item = EquipmentItem.fromQr(raw);

    if (!item.isValid) {
      _showSnack(
        'Не распознано: ${item.parseError}',
        isError: true,
      );
      return;
    }

    final added = context.read<InventoryProvider>().add(item);

    if (!added) {
      _showSnack('Уже в списке: ${item.name}');
    } else {
      _showSnack(
        'Добавлено: ${item.name}',
        actionLabel: 'Подробнее',
        onAction: () => _showDetails(item),
      );
    }
  }

  void _showSnack(
      String message, {
        bool isError = false,
        String? actionLabel,
        VoidCallback? onAction,
      }) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    // Убираем предыдущий snackbar: при быстром сканировании иначе
    // они выстраиваются в очередь и последний виден через 10 секунд.
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor:
        isError ? Colors.red.shade800 : const Color(0xFF1F1F1F),
        content: Text(message),
        action: actionLabel != null
            ? SnackBarAction(
          label: actionLabel,
          textColor: const Color(0xFFE60026),
          onPressed: onAction ?? () {},
        )
            : null,
      ),
    );
  }

  Future<void> _showDetails(EquipmentItem item) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EquipmentDetailsSheet(item: item),
    );
  }

  Future<void> _finish() async {
    final provider = context.read<InventoryProvider>();
    if (provider.current == null || provider.current!.items.isEmpty) {
      // Завершать нечего — просто выходим, чистя сессию.
      await provider.cancel();
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Завершить инвентаризацию?'),
        content: Text(
          'Отсканировано позиций: ${provider.current!.count}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Продолжить'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Завершить'),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      await provider.finish();
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _cancelSession() async {
    final provider = context.read<InventoryProvider>();
    if (provider.current == null || provider.current!.items.isEmpty) {
      await provider.cancel();
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отменить инвентаризацию?'),
        content: const Text(
            'Все отсканированные позиции будут потеряны безвозвратно.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Продолжить'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Отменить'),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      await provider.cancel();
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // watch — список и счётчик перерисовываются сами при добавлении.
    final provider = context.watch<InventoryProvider>();
    final items = provider.current?.items ?? [];

    return Scaffold(
      appBar: AppBar(
        // В заголовке — счётчик, чтобы не отвлекать взгляд от камеры.
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Инвентаризация', style: TextStyle(fontSize: 18)),
            Text(
              'Отсканировано: ${items.length}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFE60026),
        actions: [
          IconButton(
            tooltip: 'Отменить',
            icon: const Icon(Icons.close),
            onPressed: _cancelSession,
          ),
          IconButton(
            tooltip: 'Завершить',
            icon: const Icon(Icons.check),
            onPressed: _finish,
          ),
        ],
      ),
      body: Column(
        children: [
          // Верх: камера + подсказка.
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                MobileScanner(controller: controller, onDetect: _onDetect),
                const Positioned(
                  top: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      'Наведите камеру на QR-код оборудования',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        backgroundColor: Colors.black54,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Низ: список отсканированного. Тап по элементу → карточка.
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.grey.shade100,
              child: items.isEmpty
                  ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Пока ничего не отсканировано.\n'
                        'Наведите камеру на QR-код оборудования.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
                  : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                const Divider(height: 1),
                itemBuilder: (context, i) {
                  final item = items[i];
                  // Подзаголовок — только непустые поля, через " • ".
                  final subtitle = [
                    if (item.model != null) item.model!,
                    if (item.serial != null) 'S/N ${item.serial!}',
                    if (item.location != null) item.location!,
                  ].join(' • ');

                  return ListTile(
                    leading: const Icon(
                      Icons.inventory_2,
                      color: Color(0xFFE60026),
                    ),
                    title: Text(item.name),
                    subtitle: subtitle.isEmpty
                        ? null
                        : Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Подробнее',
                          icon: const Icon(Icons.info_outline),
                          onPressed: () => _showDetails(item),
                        ),
                        IconButton(
                          tooltip: 'Убрать из списка',
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent),
                          onPressed: () =>
                              provider.removeItem(item.id),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Карточка оборудования в модальном bottom sheet.
class _EquipmentDetailsSheet extends StatelessWidget {
  final EquipmentItem item;
  const _EquipmentDetailsSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2,
                    size: 32, color: Color(0xFFE60026)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (item.model != null) _field('Модель', item.model!),
            if (item.serial != null) _field('Серийный номер', item.serial!),
            if (item.location != null) _field('Расположение', item.location!),
            _field('ID', item.id),
            _field('Отсканировано', _fmt(item.scannedAt)),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year} '
        '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }
}