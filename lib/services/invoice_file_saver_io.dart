import 'package:flutter/services.dart';

const _channel = MethodChannel('com.factorsaze.faktorsaz/invoice_export');

Future<String?> saveInvoiceFile(
  Uint8List bytes,
  String fileName, {
  required bool isImage,
}) =>
    _channel.invokeMethod<String>('saveInvoiceFile', {
      'bytes': bytes,
      'fileName': fileName,
      'mimeType': isImage ? 'image/png' : 'application/pdf',
      'isImage': isImage,
    });
