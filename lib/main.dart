import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import 'equipment_request.dart';
import 'history_provider.dart';
import 'history_screen.dart';
import 'inventory_provider.dart';
import 'inventory_scan_screen.dart';
import 'issue_confirm_screen.dart';
import 'inventory_history_screen.dart';
import 'gallery_scanner.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Добавлен второй провайдер для инвентаризации
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HistoryProvider()..load()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()..load()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: const Text(
          'Терминал лаборанта',
          style: TextStyle(fontSize: 24, color: Colors.black),
        ),
        backgroundColor: const Color(0xFFE60026),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _MainButton(
                icon: Icons.qr_code_scanner,
                label: 'Сканировать QR',
                onTap: () => _openScanner(context),
              ),
              const SizedBox(height: 12),
              _MainButton(
                icon: Icons.photo_library,
                label: 'Фото из галереи',
                onTap: () async {
                  final scanner = GalleryScanner();
                  final raw = await scanner.scanQrFromGallery();
                  scanner.dispose();

                  if (raw == null) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('QR-код не найден на фото')),
                      );
                    }
                    return;
                  }

                  final req = EquipmentRequest.fromQr(raw);

                  if (!context.mounted) return;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => IssueConfirmScreen(request: req),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _MainButton(
                icon: Icons.history,
                label: 'История выдач',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _MainButton(
                icon: Icons.inventory,
                label: 'Инвентаризация',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const InventoryHistoryScreen()), // ← ведёт на историю,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Метод для открытия сканера заявок
  Future<void> _openScanner(BuildContext context) async {
    final rawValue = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (rawValue != null && context.mounted) {
      final req = EquipmentRequest.fromQr(rawValue);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Выдано по заявке: ${req.id}'),
          backgroundColor: const Color(0xFFE60026),
        ),
      );
    }
  }
}

// Класс для большой кнопки
class _MainButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MainButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 110,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE60026),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black, size: 36),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Сканер для заявок
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController controller = MobileScannerController(
    formats: [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool isScanning = true;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!isScanning || capture.barcodes.isEmpty) return;
    final rawValue = capture.barcodes.first.rawValue;
    if (rawValue == null) return;

    setState(() => isScanning = false);

    final request = EquipmentRequest.fromQr(rawValue);
    final issued = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => IssueConfirmScreen(request: request)),
    );

    if (!mounted) return;
    if (issued == true) {
      Navigator.of(context).pop(request.id);
    } else {
      setState(() => isScanning = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GSTU Сканер'),
        backgroundColor: const Color(0xFFE60026),
      ),
      body: Stack(
        children: [
          MobileScanner(controller: controller, onDetect: _onDetect),
          const Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Наведите камеру на QR-код заявки',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}