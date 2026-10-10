import 'dart:convert';

import 'package:file_picker/file_picker.dart';

Future<bool> saveBackupFile(String contents, String fileName) async {
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'ذخیره فایل پشتیبان',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: const ['json'],
    bytes: utf8.encode(contents),
  );
  return path != null;
}
