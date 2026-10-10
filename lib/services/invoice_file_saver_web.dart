import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<String?> saveInvoiceFile(
  Uint8List bytes,
  String fileName, {
  required bool isImage,
}) async {
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: isImage ? 'image/png' : 'application/pdf'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  await Future<void>.delayed(const Duration(seconds: 1));
  web.URL.revokeObjectURL(url);
  return 'Downloads/$fileName';
}
