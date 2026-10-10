import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:persian_number_utility/persian_number_utility.dart';

import '../models/invoice_models.dart';
import 'invoice_store.dart';

enum InvoicePdfTemplate { a4, thermal80mm }

class InvoicePdfService {
  static Future<Uint8List> build(
    Invoice invoice, {
    InvoicePdfTemplate template = InvoicePdfTemplate.a4,
  }) async {
    final regular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'));
    final bold =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Vazirmatn-Bold.ttf'));
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );
    final business = InvoiceStore.businessProfile.get('default') ??
        const BusinessProfile(name: 'نام کسب‌وکار');
    final pageFormat = template == InvoicePdfTemplate.a4
        ? PdfPageFormat.a4
        : const PdfPageFormat(80 * PdfPageFormat.mm, 260 * PdfPageFormat.mm);

    document.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.all(template == InvoicePdfTemplate.a4 ? 28 : 10),
        build: (context) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: template == InvoicePdfTemplate.a4
                ? _a4Content(invoice, business)
                : _receiptContent(invoice, business),
          ),
        ],
        footer: (_) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Align(
            alignment: pw.Alignment.center,
            child: pw.Text(
                business.footerNote.isEmpty
                    ? 'فاکتورساز | ${invoice.jalaliDate}'
                    : business.footerNote,
                style: const pw.TextStyle(fontSize: 8)),
          ),
        ),
      ),
    );
    return document.save();
  }

  static pw.Widget _a4Content(Invoice invoice, BusinessProfile business) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (business.logoBytes != null)
                      pw.Container(
                        width: 42,
                        height: 42,
                        margin: const pw.EdgeInsets.only(left: 8),
                        child: pw.Image(pw.MemoryImage(business.logoBytes!),
                            fit: pw.BoxFit.contain),
                      ),
                    pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(business.name,
                              style: pw.TextStyle(
                                  fontSize: 18,
                                  fontWeight: pw.FontWeight.bold)),
                          if (business.phone.isNotEmpty)
                            pw.Text('تلفن: ${business.phone}',
                                style: const pw.TextStyle(fontSize: 9)),
                          if (business.address.isNotEmpty)
                            pw.Text('نشانی: ${business.address}',
                                style: const pw.TextStyle(fontSize: 9)),
                        ]),
                  ]),
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(invoice.type,
                        style: pw.TextStyle(
                            fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Text('شماره: ${invoice.number}'),
                    pw.Text('تاریخ: ${invoice.jalaliDate}'),
                  ]),
            ],
          ),
          pw.Divider(thickness: 1.5),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Text('مشخصات خریدار',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 5),
                  pw.Text('نام: ${invoice.customerName}'),
                  if (invoice.customerPhone.isNotEmpty)
                    pw.Text('تلفن: ${invoice.customerPhone}'),
                  if (invoice.customerAddress.isNotEmpty)
                    pw.Text('نشانی: ${invoice.customerAddress}'),
                ]),
          ),
          pw.SizedBox(height: 16),
          _itemsTable(invoice, compact: false),
          pw.SizedBox(height: 12),
          _totals(invoice, compact: false),
          pw.SizedBox(height: 8),
          pw.Text('به حروف: ${_amountWords(invoice.total)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('وضعیت پرداخت: ${invoice.paymentStatus}'),
          if (business.footerNote.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text(business.footerNote),
          ],
          if (invoice.note.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text('یادداشت: ${invoice.note}'),
          ],
          pw.SizedBox(height: 28),
          pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('مهر و امضای فروشنده'),
                pw.Text('امضای خریدار'),
              ]),
        ],
      );

  static pw.Widget _receiptContent(Invoice invoice, BusinessProfile business) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Center(
              child: pw.Text(business.name,
                  style: pw.TextStyle(
                      fontSize: 15, fontWeight: pw.FontWeight.bold))),
          if (business.phone.isNotEmpty)
            pw.Center(
                child: pw.Text('تلفن: ${business.phone}',
                    style: const pw.TextStyle(fontSize: 9))),
          pw.Center(
              child: pw.Text(invoice.type,
                  style: const pw.TextStyle(fontSize: 10))),
          pw.Divider(),
          pw.Text('شماره: ${invoice.number}'),
          pw.Text('تاریخ: ${invoice.jalaliDate}'),
          pw.Text('مشتری: ${invoice.customerName}'),
          if (invoice.customerPhone.isNotEmpty)
            pw.Text('تلفن: ${invoice.customerPhone}'),
          pw.Divider(),
          _itemsTable(invoice, compact: true),
          pw.Divider(),
          _totals(invoice, compact: true),
          pw.SizedBox(height: 5),
          pw.Text('به حروف: ${_amountWords(invoice.total)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('پرداخت: ${invoice.paymentStatus}'),
          if (business.footerNote.isNotEmpty) pw.Text(business.footerNote),
          if (invoice.note.isNotEmpty) pw.Text('یادداشت: ${invoice.note}'),
          pw.SizedBox(height: 8),
          pw.Center(
              child: pw.Text('سپاس از خرید شما',
                  style: const pw.TextStyle(fontSize: 9))),
        ],
      );

  static pw.Widget _itemsTable(Invoice invoice, {required bool compact}) =>
      pw.TableHelper.fromTextArray(
        headers: compact
            ? ['شرح', 'تعداد', 'مبلغ']
            : ['ردیف', 'شرح کالا یا خدمت', 'تعداد', 'واحد', 'قیمت واحد', 'جمع'],
        data: [
          for (var i = 0; i < invoice.items.length; i++)
            compact
                ? [
                    invoice.items[i].title,
                    _quantity(invoice.items[i].quantity),
                    _money(invoice.items[i].total)
                  ]
                : [
                    '${i + 1}',
                    invoice.items[i].title,
                    _quantity(invoice.items[i].quantity),
                    invoice.items[i].unit,
                    _money(invoice.items[i].unitPrice),
                    _money(invoice.items[i].total),
                  ],
        ],
        headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold, fontSize: compact ? 8 : 9),
        cellStyle: pw.TextStyle(fontSize: compact ? 8 : 9),
        cellAlignment: pw.Alignment.center,
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
        cellPadding: pw.EdgeInsets.all(compact ? 4 : 7),
      );

  static pw.Widget _totals(Invoice invoice, {required bool compact}) {
    final fontSize = compact ? 8.5 : 10.5;
    pw.Widget row(String title, int amount, {bool emphasized = false}) =>
        pw.Padding(
          padding: pw.EdgeInsets.symmetric(vertical: compact ? 2 : 4),
          child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(title,
                    style: pw.TextStyle(
                        fontSize: fontSize,
                        fontWeight: emphasized ? pw.FontWeight.bold : null)),
                pw.Text('${_money(amount)} تومان',
                    style: pw.TextStyle(
                        fontSize: fontSize,
                        fontWeight: emphasized ? pw.FontWeight.bold : null)),
              ]),
        );
    return pw.Column(children: [
      row('جمع کل', invoice.subtotal),
      if (invoice.discount > 0) row('تخفیف', -invoice.discount),
      if (invoice.tax > 0)
        row('مالیات (${_quantity(invoice.taxRate)}٪)', invoice.tax),
      pw.Divider(),
      row('مبلغ نهایی', invoice.total, emphasized: true),
    ]);
  }

  static String _amountWords(int amount) =>
      '${NumberUtility.toWord('$amount', NumStrLanguage.Farsi)} تومان';

  static String _money(int amount) => amount.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => '٬',
      );

  static String _quantity(num value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}
