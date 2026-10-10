import 'package:hive/hive.dart';
import 'dart:typed_data';

class BusinessProfile {
  const BusinessProfile({
    required this.name,
    this.phone = '',
    this.address = '',
    this.logoBytes,
    this.footerNote = '',
  });

  final String name;
  final String phone;
  final String address;
  final Uint8List? logoBytes;
  final String footerNote;
}

class Customer {
  const Customer({
    required this.id,
    required this.name,
    this.phone = '',
    this.address = '',
    this.economicCode = '',
  });

  final String id;
  final String name;
  final String phone;
  final String address;
  final String economicCode;
}

class Product {
  const Product({
    required this.id,
    required this.title,
    required this.unit,
    required this.unitPrice,
  });

  final String id;
  final String title;
  final String unit;
  final int unitPrice;
}

class InvoiceLine {
  const InvoiceLine({
    required this.productId,
    required this.title,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
  });

  final String productId;
  final String title;
  final String unit;
  final double quantity;
  final int unitPrice;

  int get total => (quantity * unitPrice).round();
}

class Invoice {
  const Invoice({
    required this.id,
    required this.number,
    required this.jalaliDate,
    required this.gregorianDate,
    required this.type,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    required this.items,
    required this.discountValue,
    required this.discountIsPercent,
    required this.taxRate,
    required this.paymentStatus,
    required this.note,
  });

  final String id;
  final int number;
  final String jalaliDate;
  final DateTime gregorianDate;
  final String type;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final List<InvoiceLine> items;
  final double discountValue;
  final bool discountIsPercent;
  final double taxRate;
  final String paymentStatus;
  final String note;

  int get subtotal => items.fold(0, (sum, item) => sum + item.total);
  int get discount => discountIsPercent
      ? (subtotal * discountValue / 100).round().clamp(0, subtotal).toInt()
      : discountValue.round().clamp(0, subtotal).toInt();
  int get tax => ((subtotal - discount) * taxRate / 100).round();
  int get total => subtotal - discount + tax;
}

class CustomerAdapter extends TypeAdapter<Customer> {
  @override
  int get typeId => 31;

  @override
  Customer read(BinaryReader reader) {
    final fields = _readFields(reader);
    return Customer(
      id: fields[0] as String,
      name: fields[1] as String,
      phone: fields[2] as String? ?? '',
      address: fields[3] as String? ?? '',
      economicCode: fields[4] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, Customer obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.phone)
      ..writeByte(3)
      ..write(obj.address)
      ..writeByte(4)
      ..write(obj.economicCode);
  }
}

class ProductAdapter extends TypeAdapter<Product> {
  @override
  int get typeId => 32;

  @override
  Product read(BinaryReader reader) {
    final fields = _readFields(reader);
    return Product(
      id: fields[0] as String,
      title: fields[1] as String,
      unit: fields[2] as String,
      unitPrice: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Product obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.unit)
      ..writeByte(3)
      ..write(obj.unitPrice);
  }
}

class InvoiceLineAdapter extends TypeAdapter<InvoiceLine> {
  @override
  int get typeId => 33;

  @override
  InvoiceLine read(BinaryReader reader) {
    final fields = _readFields(reader);
    return InvoiceLine(
      productId: fields[0] as String,
      title: fields[1] as String,
      unit: fields[2] as String,
      quantity: (fields[3] as num).toDouble(),
      unitPrice: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, InvoiceLine obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.productId)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.unit)
      ..writeByte(3)
      ..write(obj.quantity)
      ..writeByte(4)
      ..write(obj.unitPrice);
  }
}

class InvoiceAdapter extends TypeAdapter<Invoice> {
  @override
  int get typeId => 34;

  @override
  Invoice read(BinaryReader reader) {
    final fields = _readFields(reader);
    return Invoice(
      id: fields[0] as String,
      number: fields[1] as int,
      jalaliDate: fields[2] as String,
      gregorianDate: DateTime.parse(fields[3] as String),
      type: fields[4] as String,
      customerId: fields[5] as String,
      customerName: fields[6] as String,
      customerPhone: fields[7] as String? ?? '',
      customerAddress: fields[8] as String? ?? '',
      items: (fields[9] as List).cast<InvoiceLine>(),
      discountValue: (fields[10] as num).toDouble(),
      discountIsPercent: fields[11] as bool,
      taxRate: (fields[12] as num).toDouble(),
      paymentStatus: fields[13] as String,
      note: fields[14] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, Invoice obj) {
    final values = <Object?>[
      obj.id,
      obj.number,
      obj.jalaliDate,
      obj.gregorianDate.toIso8601String(),
      obj.type,
      obj.customerId,
      obj.customerName,
      obj.customerPhone,
      obj.customerAddress,
      obj.items,
      obj.discountValue,
      obj.discountIsPercent,
      obj.taxRate,
      obj.paymentStatus,
      obj.note,
    ];
    writer.writeByte(values.length);
    for (var i = 0; i < values.length; i++) {
      writer
        ..writeByte(i)
        ..write(values[i]);
    }
  }
}

class BusinessProfileAdapter extends TypeAdapter<BusinessProfile> {
  @override
  int get typeId => 35;

  @override
  BusinessProfile read(BinaryReader reader) {
    final fields = _readFields(reader);
    return BusinessProfile(
      name: fields[0] as String? ?? 'کسب‌وکار من',
      phone: fields[1] as String? ?? '',
      address: fields[2] as String? ?? '',
      logoBytes: fields[3] as Uint8List?,
      footerNote: fields[4] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, BusinessProfile obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.phone)
      ..writeByte(2)
      ..write(obj.address)
      ..writeByte(3)
      ..write(obj.logoBytes)
      ..writeByte(4)
      ..write(obj.footerNote);
  }
}

Map<int, dynamic> _readFields(BinaryReader reader) {
  final fields = <int, dynamic>{};
  final count = reader.readByte();
  for (var i = 0; i < count; i++) {
    fields[reader.readByte()] = reader.read();
  }
  return fields;
}
