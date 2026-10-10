import 'dart:convert';

import '../models/invoice_models.dart';
import 'invoice_store.dart';

class BackupService {
  static const _format = 'faktorsaz-backup';
  static const _version = 1;

  static String exportJson() {
    final profile = InvoiceStore.businessProfile.get('default') ??
        const BusinessProfile(name: 'نام کسب‌وکار');
    final data = <String, Object?>{
      'format': _format,
      'version': _version,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'customers': InvoiceStore.customers.values.map(_customerToJson).toList(),
      'products': InvoiceStore.products.values.map(_productToJson).toList(),
      'invoices': InvoiceStore.invoices.values.map(_invoiceToJson).toList(),
      'businessProfile': _businessToJson(profile),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  static Future<BackupImportSummary> importJson(String source) async {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != _format ||
        decoded['version'] != _version) {
      throw const FormatException('ساختار یا نسخهٔ فایل پشتیبان معتبر نیست.');
    }

    final customers =
        _parseList(decoded['customers'], 'customers', _customerFromJson);
    final products =
        _parseList(decoded['products'], 'products', _productFromJson);
    final invoices =
        _parseList(decoded['invoices'], 'invoices', _invoiceFromJson);
    final profileValue = decoded['businessProfile'];
    if (profileValue is! Map<String, dynamic>) {
      throw const FormatException('مشخصات کسب‌وکار در فایل وجود ندارد.');
    }
    final profile = _businessFromJson(profileValue);

    _ensureUnique(customers.map((item) => item.id), 'شناسهٔ مشتری تکراری است.');
    _ensureUnique(products.map((item) => item.id), 'شناسهٔ کالا تکراری است.');
    _ensureUnique(invoices.map((item) => item.id), 'شناسهٔ فاکتور تکراری است.');

    await InvoiceStore.customers
        .putAll({for (final item in customers) item.id: item});
    await InvoiceStore.products
        .putAll({for (final item in products) item.id: item});
    await InvoiceStore.invoices
        .putAll({for (final item in invoices) item.id: item});
    await InvoiceStore.businessProfile.put('default', profile);

    return BackupImportSummary(
      customers: customers.length,
      products: products.length,
      invoices: invoices.length,
    );
  }

  static Map<String, Object?> _customerToJson(Customer item) => {
        'id': item.id,
        'name': item.name,
        'phone': item.phone,
        'address': item.address,
        'economicCode': item.economicCode,
      };

  static Map<String, Object?> _productToJson(Product item) => {
        'id': item.id,
        'title': item.title,
        'unit': item.unit,
        'unitPrice': item.unitPrice,
      };

  static Map<String, Object?> _invoiceToJson(Invoice item) => {
        'id': item.id,
        'number': item.number,
        'jalaliDate': item.jalaliDate,
        'gregorianDate': item.gregorianDate.toIso8601String(),
        'type': item.type,
        'customerId': item.customerId,
        'customerName': item.customerName,
        'customerPhone': item.customerPhone,
        'customerAddress': item.customerAddress,
        'items': item.items
            .map((line) => {
                  'productId': line.productId,
                  'title': line.title,
                  'unit': line.unit,
                  'quantity': line.quantity,
                  'unitPrice': line.unitPrice,
                  'total': line.total,
                })
            .toList(),
        'discountValue': item.discountValue,
        'discountIsPercent': item.discountIsPercent,
        'taxRate': item.taxRate,
        'paymentStatus': item.paymentStatus,
        'note': item.note,
        'totals': {
          'subtotal': item.subtotal,
          'discount': item.discount,
          'tax': item.tax,
          'total': item.total,
        },
      };

  static Map<String, Object?> _businessToJson(BusinessProfile profile) => {
        'name': profile.name,
        'phone': profile.phone,
        'address': profile.address,
        'logoBase64':
            profile.logoBytes == null ? null : base64Encode(profile.logoBytes!),
        'footerNote': profile.footerNote,
      };

  static Customer _customerFromJson(Object? value) {
    final map = _object(value, 'مشتری');
    return Customer(
      id: _requiredString(map, 'id'),
      name: _requiredString(map, 'name'),
      phone: _optionalString(map, 'phone'),
      address: _optionalString(map, 'address'),
      economicCode: _optionalString(map, 'economicCode'),
    );
  }

  static Product _productFromJson(Object? value) {
    final map = _object(value, 'کالا');
    final price = _requiredInt(map, 'unitPrice');
    if (price < 0) {
      throw const FormatException('قیمت کالا نمی‌تواند منفی باشد.');
    }
    return Product(
      id: _requiredString(map, 'id'),
      title: _requiredString(map, 'title'),
      unit: _requiredString(map, 'unit'),
      unitPrice: price,
    );
  }

  static Invoice _invoiceFromJson(Object? value) {
    final map = _object(value, 'فاکتور');
    final rawLines = map['items'];
    if (rawLines is! List) {
      throw const FormatException('ردیف‌های فاکتور معتبر نیستند.');
    }
    final lines = rawLines.map((value) {
      final line = _object(value, 'ردیف فاکتور');
      final quantity = _requiredNumber(line, 'quantity').toDouble();
      final price = _requiredInt(line, 'unitPrice');
      if (!quantity.isFinite || quantity <= 0 || price < 0) {
        throw const FormatException('تعداد یا قیمت ردیف فاکتور معتبر نیست.');
      }
      final result = InvoiceLine(
        productId: _optionalString(line, 'productId'),
        title: _requiredString(line, 'title'),
        unit: _requiredString(line, 'unit'),
        quantity: quantity,
        unitPrice: price,
      );
      if (line['total'] != null &&
          _requiredInt(line, 'total') != result.total) {
        throw const FormatException(
            'جمع یکی از ردیف‌های فاکتور با محاسبه سازگار نیست.');
      }
      return result;
    }).toList();
    final discountValue = _requiredNumber(map, 'discountValue').toDouble();
    final taxRate = _requiredNumber(map, 'taxRate').toDouble();
    if (!discountValue.isFinite ||
        discountValue < 0 ||
        !taxRate.isFinite ||
        taxRate < 0 ||
        taxRate > 100) {
      throw const FormatException('تخفیف یا نرخ مالیات معتبر نیست.');
    }
    final invoice = Invoice(
      id: _requiredString(map, 'id'),
      number: _requiredInt(map, 'number'),
      jalaliDate: _requiredString(map, 'jalaliDate'),
      gregorianDate: DateTime.parse(_requiredString(map, 'gregorianDate')),
      type: _requiredString(map, 'type'),
      customerId: _optionalString(map, 'customerId'),
      customerName: _requiredString(map, 'customerName'),
      customerPhone: _optionalString(map, 'customerPhone'),
      customerAddress: _optionalString(map, 'customerAddress'),
      items: lines,
      discountValue: discountValue,
      discountIsPercent: _requiredBool(map, 'discountIsPercent'),
      taxRate: taxRate,
      paymentStatus: _requiredString(map, 'paymentStatus'),
      note: _optionalString(map, 'note'),
    );
    if (invoice.number <= 0 ||
        !RegExp(r'^\d{4}/\d{2}/\d{2}$').hasMatch(invoice.jalaliDate)) {
      throw const FormatException('شماره یا تاریخ شمسی فاکتور معتبر نیست.');
    }
    final totals = map['totals'];
    if (totals is Map<String, dynamic> &&
        (totals['subtotal'] != invoice.subtotal ||
            totals['discount'] != invoice.discount ||
            totals['tax'] != invoice.tax ||
            totals['total'] != invoice.total)) {
      throw const FormatException(
          'مجموع فاکتور با ردیف‌ها و تخفیف/مالیات سازگار نیست.');
    }
    return invoice;
  }

  static BusinessProfile _businessFromJson(Map<String, dynamic> map) {
    final encoded = map['logoBase64'];
    if (encoded != null && encoded is! String) {
      throw const FormatException('تصویر نشان کسب‌وکار معتبر نیست.');
    }
    return BusinessProfile(
      name: _requiredString(map, 'name'),
      phone: _optionalString(map, 'phone'),
      address: _optionalString(map, 'address'),
      logoBytes: encoded == null ? null : base64Decode(encoded as String),
      footerNote: _optionalString(map, 'footerNote'),
    );
  }

  static List<T> _parseList<T>(
      Object? value, String key, T Function(Object?) parse) {
    if (value is! List) throw FormatException('بخش $key در فایل معتبر نیست.');
    return value.map(parse).toList();
  }

  static Map<String, dynamic> _object(Object? value, String label) {
    if (value is! Map<String, dynamic>) {
      throw FormatException('ساختار $label معتبر نیست.');
    }
    return value;
  }

  static String _requiredString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('فیلد $key خالی یا نامعتبر است.');
    }
    return value;
  }

  static String _optionalString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return '';
    if (value is! String) throw FormatException('فیلد $key معتبر نیست.');
    return value;
  }

  static int _requiredInt(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! num || !value.isFinite || value != value.round()) {
      throw FormatException('فیلد $key باید عدد صحیح باشد.');
    }
    return value.toInt();
  }

  static num _requiredNumber(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! num || !value.isFinite) {
      throw FormatException('فیلد $key باید عددی باشد.');
    }
    return value;
  }

  static bool _requiredBool(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! bool) throw FormatException('فیلد $key معتبر نیست.');
    return value;
  }

  static void _ensureUnique(Iterable<String> ids, String message) {
    final seen = <String>{};
    for (final id in ids) {
      if (!seen.add(id)) throw FormatException(message);
    }
  }
}

class BackupImportSummary {
  const BackupImportSummary(
      {required this.customers,
      required this.products,
      required this.invoices});
  final int customers;
  final int products;
  final int invoices;
}
