import 'package:hive_flutter/hive_flutter.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../models/invoice_models.dart';

class InvoiceStore {
  static const legacyInvoiceBoxName = 'invoices';

  static Future<void> initialize() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(31)) {
      Hive.registerAdapter(CustomerAdapter());
    }
    if (!Hive.isAdapterRegistered(32)) {
      Hive.registerAdapter(ProductAdapter());
    }
    if (!Hive.isAdapterRegistered(33)) {
      Hive.registerAdapter(InvoiceLineAdapter());
    }
    if (!Hive.isAdapterRegistered(34)) {
      Hive.registerAdapter(InvoiceAdapter());
    }
    if (!Hive.isAdapterRegistered(35)) {
      Hive.registerAdapter(BusinessProfileAdapter());
    }

    final legacy = await Hive.openBox<Map>(legacyInvoiceBoxName);
    final invoices = await Hive.openBox<Invoice>('invoiceRecords');
    await Hive.openBox<Customer>('customers');
    await Hive.openBox<Product>('products');
    final business = await Hive.openBox<BusinessProfile>('businessProfile');
    final metadata = await Hive.openBox('appMetadata');

    if (metadata.get('legacyInvoiceMigrationV1') != true && legacy.isNotEmpty) {
      for (final old in legacy.values) {
        final date =
            DateTime.tryParse('${old['date'] ?? ''}') ?? DateTime.now();
        final amount = (old['amount'] as num?)?.toInt() ?? 0;
        final number = (old['number'] as num?)?.toInt() ?? invoices.length + 1;
        final customer = '${old['customer'] ?? 'مشتری'}';
        final jalali = Jalali.fromDateTime(date);
        final invoice = Invoice(
          id: 'legacy-$number-${date.microsecondsSinceEpoch}',
          number: number,
          jalaliDate: _jalaliDate(jalali),
          gregorianDate: date,
          type: 'فاکتور فروش',
          customerId: '',
          customerName: customer,
          customerPhone: '',
          customerAddress: '',
          items: [
            InvoiceLine(
              productId: '',
              title: 'فاکتور ثبت‌شده',
              unit: 'خدمات',
              quantity: 1,
              unitPrice: amount,
            ),
          ],
          discountValue: 0,
          discountIsPercent: false,
          taxRate: 0,
          paymentStatus: old['paid'] == true ? 'پرداخت شده' : 'نسیه',
          note: '',
        );
        await invoices.put(invoice.id, invoice);
      }
    }
    await metadata.put('legacyInvoiceMigrationV1', true);
    if (business.isEmpty) {
      await business.put(
          'default', const BusinessProfile(name: 'نام کسب‌وکار'));
    }
  }

  static Box<Invoice> get invoices => Hive.box<Invoice>('invoiceRecords');
  static Box<Customer> get customers => Hive.box<Customer>('customers');
  static Box<Product> get products => Hive.box<Product>('products');
  static Box<BusinessProfile> get businessProfile =>
      Hive.box<BusinessProfile>('businessProfile');

  static int get nextInvoiceNumber {
    if (invoices.isEmpty) return 1;
    return invoices.values
            .map((invoice) => invoice.number)
            .reduce((a, b) => a > b ? a : b) +
        1;
  }

  static Future<void> saveInvoice(Invoice invoice) =>
      invoices.put(invoice.id, invoice);
  static Future<void> deleteInvoice(String id) => invoices.delete(id);
  static Future<void> saveCustomer(Customer customer) =>
      customers.put(customer.id, customer);
  static Future<void> saveProduct(Product product) =>
      products.put(product.id, product);
}

String _jalaliDate(Jalali date) =>
    '${date.year.toString().padLeft(4, '0')}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
