import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

/// Сервис для распознавания QR-кодов из галереи.
class GalleryScanner {
  final ImagePicker _picker = ImagePicker();
  final BarcodeScanner _barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.qrCode]);

  /// Открывает галерею, просит пользователя выбрать фото,
  /// и возвращает строку с текстом QR-кода (или null, если не нашли/отменили).
  Future<String?> scanQrFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return null;

      final inputImage = InputImage.fromFilePath(image.path);
      final barcodes = await _barcodeScanner.processImage(inputImage);

      if (barcodes.isNotEmpty) {
        return barcodes.first.rawValue;
      }
      return null;
    } catch (e) {
      print('Ошибка при сканировании из галереи: $e');
      return null;
    }
  }

  void dispose() {
    _barcodeScanner.close();
  }
}