import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/invoice_models.dart';
import '../services/invoice_file_saver.dart';
import '../services/invoice_pdf_service.dart';

class InvoicePdfScreen extends StatefulWidget {
  const InvoicePdfScreen({super.key, required this.invoice});

  final Invoice invoice;

  @override
  State<InvoicePdfScreen> createState() => _InvoicePdfScreenState();
}

class _InvoicePdfScreenState extends State<InvoicePdfScreen> {
  InvoicePdfTemplate _template = InvoicePdfTemplate.a4;
  bool _busy = false;

  Future<void> _print() async {
    setState(() => _busy = true);
    try {
      await Printing.layoutPdf(
        name: 'factor-${widget.invoice.number}.pdf',
        onLayout: (_) =>
            InvoicePdfService.build(widget.invoice, template: _template),
      );
    } catch (error) {
      _message('چاپ PDF انجام نشد: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final bytes =
          await InvoicePdfService.build(widget.invoice, template: _template);
      await Share.shareXFiles(
        [
          XFile.fromData(bytes,
              mimeType: 'application/pdf',
              name: 'factor-${widget.invoice.number}.pdf')
        ],
        subject: 'فاکتور ${widget.invoice.number}',
        text: 'فاکتور شماره ${widget.invoice.number}',
      );
    } catch (error) {
      _message('اشتراک‌گذاری PDF انجام نشد: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadPdf() async {
    setState(() => _busy = true);
    try {
      final bytes =
          await InvoicePdfService.build(widget.invoice, template: _template);
      final fileName = 'factor-${widget.invoice.number}.pdf';
      final path = await saveInvoiceFile(bytes, fileName, isImage: false);
      _message(path == null ? 'ذخیره PDF لغو شد.' : 'PDF ذخیره شد: $path');
    } catch (error) {
      _message('ذخیره PDF انجام نشد: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadImage() async {
    setState(() => _busy = true);
    try {
      final pdfBytes = await InvoicePdfService.build(
        widget.invoice,
        template: InvoicePdfTemplate.a4,
      );
      Uint8List? pngBytes;
      await for (final page in Printing.raster(
        pdfBytes,
        pages: const [0],
        dpi: 240,
      )) {
        pngBytes = await page.toPng();
        break;
      }
      if (pngBytes == null) {
        throw StateError('تصویری از فاکتور ساخته نشد.');
      }
      final fileName = 'factor-${widget.invoice.number}.png';
      final path = await saveInvoiceFile(pngBytes, fileName, isImage: true);
      _message(path == null
          ? 'ذخیره تصویر لغو شد.'
          : 'تصویر فاکتور ذخیره شد: $path');
    } catch (error) {
      _message('ساخت یا ذخیره تصویر انجام نشد: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('پیش‌نمایش فاکتور ${widget.invoice.number}'),
          actions: [
            IconButton(
                tooltip: 'ذخیره یا اشتراک PDF',
                onPressed: _busy ? null : _share,
                icon: const Icon(Icons.share_outlined)),
          ],
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<InvoicePdfTemplate>(
              segments: const [
                ButtonSegment(
                    value: InvoicePdfTemplate.a4,
                    label: Text('A4'),
                    icon: Icon(Icons.description_outlined)),
                ButtonSegment(
                    value: InvoicePdfTemplate.thermal80mm,
                    label: Text('رسید ۸۰ میلی‌متر'),
                    icon: Icon(Icons.receipt_outlined)),
              ],
              selected: {_template},
              onSelectionChanged: (value) =>
                  setState(() => _template = value.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: _exportButton(
                    label: 'دانلود PDF',
                    icon: Icons.download_outlined,
                    onPressed: _downloadPdf,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _exportButton(
                    label: 'دانلود تصویر',
                    icon: Icons.image_outlined,
                    onPressed: _downloadImage,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _exportButton(
                    label: 'چاپ',
                    icon: Icons.print_outlined,
                    onPressed: _print,
                  ),
                ),
              ],
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: PdfPreview(
              build: (_) =>
                  InvoicePdfService.build(widget.invoice, template: _template),
              canChangePageFormat: false,
              canChangeOrientation: false,
              allowPrinting: false,
              allowSharing: false,
              pdfFileName: 'factor-${widget.invoice.number}.pdf',
              loadingWidget: const Center(child: CircularProgressIndicator()),
              onError: (context, error) => Center(
                  child: Text('ساخت پیش‌نمایش PDF ناموفق بود: $error',
                      textDirection: TextDirection.rtl)),
            ),
          ),
        ]),
      );

  Widget _exportButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) =>
      FilledButton.tonalIcon(
        onPressed: _busy ? null : onPressed,
        icon: Icon(icon, size: 18),
        label: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      );
}
