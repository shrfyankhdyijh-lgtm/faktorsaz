import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<String?> saveInvoiceFile(
  Uint8List bytes,
  String fileName, {
  required bool isImage,
}) async {
  return FilePicker.platform.saveFile(
    dialogTitle: 'ذخیره فایل فاکتور',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: [isImage ? 'png' : 'pdf'],
    bytes: bytes,
  );
}
