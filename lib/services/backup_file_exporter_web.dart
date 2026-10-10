import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<bool> saveBackupFile(String contents, String fileName) async {
  final bytes = utf8.encode(contents).toJS;
  final parts = <JSAny>[bytes].toJS;
  final blob = web.Blob(
    parts,
    web.BlobPropertyBag(type: 'application/json;charset=utf-8'),
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
  return true;
}
