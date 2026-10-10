import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart' as pdt;
import 'package:persian_number_utility/persian_number_utility.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/invoice_models.dart';
import '../services/invoice_store.dart';

const _editorTeal = Color(0xFF087E78);
const _units = ['عدد', 'کیلوگرم', 'متر', 'ساعت', 'خدمات'];
const _invoiceTypes = ['فاکتور فروش', 'پیش‌فاکتور', 'رسید نقدی'];
const _paymentStatuses = ['پرداخت شده', 'نقدی', 'کارت‌به‌کارت', 'نسیه'];

class InvoiceEditorScreen extends StatefulWidget {
  const InvoiceEditorScreen({super.key, this.invoice, this.duplicate = false});

  final Invoice? invoice;
  final bool duplicate;

  @override
  State<InvoiceEditorScreen> createState() => _InvoiceEditorScreenState();
}

class _InvoiceEditorScreenState extends State<InvoiceEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _discountController = TextEditingController();
  final _noteController = TextEditingController();
  late final List<Customer> _customers;
  late final List<Product> _products;
  late final List<_DraftLine> _lines;
  late pdt.Jalali _date;
  Customer? _customer;
  String _type = _invoiceTypes.first;
  String _payment = _paymentStatuses.last;
  bool _discountPercent = false;
  double _taxRate = 0;

  Invoice? get _source => widget.invoice;

  @override
  void initState() {
    super.initState();
    _customers = InvoiceStore.customers.values.toList();
    _products = InvoiceStore.products.values.toList();
    final source = _source;
    _customer =
        _firstWhereOrNull(_customers, (item) => item.id == source?.customerId);
    _date = source == null
        ? pdt.Jalali.now()
        : pdt.Jalali.fromDateTime(source.gregorianDate);
    _type = source?.type ?? _invoiceTypes.first;
    _payment = source?.paymentStatus ?? _paymentStatuses.last;
    _discountPercent = source?.discountIsPercent ?? false;
    _taxRate = source?.taxRate ?? 0;
    _discountController.text = source == null || source.discountValue == 0
        ? ''
        : _numberInput(source.discountValue);
    _noteController.text = source?.note ?? '';
    _lines = source == null
        ? [_DraftLine()]
        : source.items
            .map((item) => _DraftLine(
                  product: _firstWhereOrNull(
                      _products, (product) => product.id == item.productId),
                  title: item.title,
                  unit: item.unit,
                  quantity: item.quantity,
                  unitPrice: item.unitPrice,
                ))
            .toList();
    if (_lines.isEmpty) _lines.add(_DraftLine());
    _discountController.addListener(_refresh);
  }

  @override
  void dispose() {
    _discountController.dispose();
    _noteController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  int get _subtotal => _lines.fold(0, (sum, line) => sum + line.total);
  int get _discount {
    final raw = _parseDecimal(_discountController.text);
    return _discountPercent
        ? (_subtotal * raw / 100).round().clamp(0, _subtotal)
        : raw.round().clamp(0, _subtotal);
  }

  int get _tax => ((_subtotal - _discount) * _taxRate / 100).round();
  int get _total => _subtotal - _discount + _tax;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(_source == null
              ? 'فاکتور جدید'
              : widget.duplicate
                  ? 'کپی فاکتور'
                  : 'ویرایش فاکتور'),
          actions: [
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('ذخیره'),
            ),
            const SizedBox(width: 10),
          ],
        ),
        body: Form(
          key: _formKey,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  _section('مشخصات فاکتور', Icons.receipt_long_outlined, [
                    Wrap(spacing: 12, runSpacing: 12, children: [
                      SizedBox(
                          width: _fieldWidth(context), child: _dateField()),
                      SizedBox(
                          width: _fieldWidth(context),
                          child: DropdownButtonFormField<String>(
                            value: _type,
                            decoration:
                                const InputDecoration(labelText: 'نوع فاکتور'),
                            items: _invoiceTypes
                                .map((value) => DropdownMenuItem(
                                    value: value, child: Text(value)))
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _type = value ?? _type),
                          )),
                      SizedBox(
                          width: _fieldWidth(context),
                          child: DropdownButtonFormField<String>(
                            value: _payment,
                            decoration: const InputDecoration(
                                labelText: 'وضعیت پرداخت'),
                            items: _paymentStatuses
                                .map((value) => DropdownMenuItem(
                                    value: value, child: Text(value)))
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _payment = value ?? _payment),
                          )),
                    ]),
                  ]),
                  _section('مشتری', Icons.person_outline, [
                    Row(children: [
                      Expanded(
                          child: DropdownButtonFormField<Customer>(
                        value: _customer,
                        decoration:
                            const InputDecoration(labelText: 'انتخاب مشتری'),
                        items: _customers
                            .map((customer) => DropdownMenuItem(
                                value: customer, child: Text(customer.name)))
                            .toList(),
                        onChanged: (value) => setState(() => _customer = value),
                        validator: (value) => value == null
                            ? 'مشتری را انتخاب یا اضافه کنید'
                            : null,
                      )),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'افزودن مشتری',
                        onPressed: _quickAddCustomer,
                        icon: const Icon(Icons.person_add_alt_1),
                      ),
                    ]),
                    if (_customer != null) ...[
                      const SizedBox(height: 8),
                      Text(
                          '${_customer!.phone}${_customer!.address.isEmpty ? '' : '  •  ${_customer!.address}'}',
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 12)),
                    ],
                  ]),
                  _section('کالا و خدمات', Icons.inventory_2_outlined, [
                    for (var i = 0; i < _lines.length; i++) _lineCard(i),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            setState(() => _lines.add(_DraftLine())),
                        icon: const Icon(Icons.add),
                        label: const Text('افزودن ردیف'),
                      ),
                    ),
                  ]),
                  _section('تخفیف و مالیات', Icons.percent_rounded, [
                    Row(children: [
                      Expanded(
                          child: TextFormField(
                        controller: _discountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: _discountPercent
                                ? 'درصد تخفیف'
                                : 'مبلغ تخفیف (تومان)'),
                      )),
                      const SizedBox(width: 10),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('مبلغ')),
                          ButtonSegment(value: true, label: Text('درصد')),
                        ],
                        selected: {_discountPercent},
                        onSelectionChanged: (value) =>
                            setState(() => _discountPercent = value.first),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    Row(children: [
                      const Expanded(child: Text('مالیات بر ارزش افزوده')),
                      SegmentedButton<double>(
                        segments: const [
                          ButtonSegment(value: 0, label: Text('۰٪')),
                          ButtonSegment(value: 10, label: Text('۱۰٪')),
                        ],
                        selected: {_taxRate},
                        onSelectionChanged: (value) =>
                            setState(() => _taxRate = value.first),
                      ),
                    ]),
                  ]),
                  _summaryCard(),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _noteController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        labelText: 'یادداشت و شرایط', alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check_rounded),
                    label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 13),
                        child: Text('ذخیره فاکتور')),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed: () => launchUrl(
                        Uri.parse('https://webbusiness24.ir/'),
                        mode: LaunchMode.externalApplication,
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black45,
                        textStyle: const TextStyle(fontSize: 11),
                      ),
                      child: const Text('طراحی و توسعه: وب بیزینس'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  double _fieldWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width > 700 ? 260 : double.infinity;

  Widget _dateField() => InkWell(
        onTap: _pickDate,
        borderRadius: BorderRadius.circular(14),
        child: InputDecorator(
          decoration: const InputDecoration(
              labelText: 'تاریخ شمسی',
              suffixIcon: Icon(Icons.calendar_month_outlined)),
          child: Text(_jalaliDate(_date)),
        ),
      );

  Future<void> _pickDate() async {
    final picked = await pdt.showPersianDatePicker(
      context: context,
      initialDate: _date,
      firstDate: pdt.Jalali(1300, 1, 1),
      lastDate: pdt.Jalali(1500, 12, 29),
      locale: const Locale('fa'),
      textDirection: TextDirection.rtl,
      confirmText: 'انتخاب',
      cancelText: 'انصراف',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Widget _lineCard(int index) {
    final line = _lines[index];
    final narrow = MediaQuery.sizeOf(context).width < 680;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8EDF2))),
      child: Column(children: [
        Row(children: [
          Expanded(
              child: DropdownButtonFormField<Product>(
            value: line.product,
            decoration: const InputDecoration(labelText: 'کالا یا خدمت'),
            items: _products
                .map((product) => DropdownMenuItem(
                    value: product, child: Text(product.title)))
                .toList(),
            onChanged: (product) => setState(() {
              line.product = product;
              if (product != null) {
                line.titleController.text = product.title;
                line.unit = product.unit;
                line.priceController.text = '${product.unitPrice}';
              }
            }),
          )),
          IconButton(
            tooltip: 'افزودن کالای جدید',
            onPressed: _quickAddProduct,
            icon: const Icon(Icons.add_box_outlined, color: _editorTeal),
          ),
          if (_lines.length > 1)
            IconButton(
              tooltip: 'حذف ردیف',
              onPressed: () => setState(() {
                _lines.removeAt(index).dispose();
              }),
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            ),
        ]),
        const SizedBox(height: 10),
        if (narrow)
          Row(children: [
            Expanded(
                child: _lineTextField(line.titleController, 'شرح',
                    onChanged: _refresh)),
            const SizedBox(width: 8),
            Expanded(child: _quantityField(line)),
          ])
        else
          Row(children: [
            Expanded(
                flex: 3,
                child: _lineTextField(line.titleController, 'شرح کالا یا خدمت',
                    onChanged: _refresh)),
            const SizedBox(width: 8),
            Expanded(child: _quantityField(line)),
          ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: _lineTextField(line.priceController, 'قیمت واحد (تومان)',
                  numeric: true, onChanged: _refresh)),
          const SizedBox(width: 8),
          SizedBox(
              width: 140,
              child: DropdownButtonFormField<String>(
                value: _units.contains(line.unit) ? line.unit : _units.last,
                decoration: const InputDecoration(labelText: 'واحد'),
                items: _units
                    .map((unit) =>
                        DropdownMenuItem(value: unit, child: Text(unit)))
                    .toList(),
                onChanged: (unit) =>
                    setState(() => line.unit = unit ?? line.unit),
              )),
          const SizedBox(width: 8),
          Flexible(
              child: Text('${_money(line.total)} تومان',
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: _editorTeal))),
        ]),
      ]),
    );
  }

  Widget _lineTextField(TextEditingController controller, String label,
          {bool numeric = false, required VoidCallback onChanged}) =>
      TextFormField(
        controller: controller,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label),
        onChanged: (_) => onChanged(),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'این فیلد الزامی است'
            : null,
      );

  Widget _quantityField(_DraftLine line) => TextFormField(
        controller: line.quantityController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'تعداد'),
        onChanged: (_) => _refresh(),
        validator: (value) =>
            _parseQuantity(value ?? '') <= 0 ? 'تعداد معتبر وارد کنید' : null,
      );

  Widget _summaryCard() {
    final words = NumberUtility.toWord('$_total', NumStrLanguage.Farsi);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: const Color(0xFFEAF4F3),
          borderRadius: BorderRadius.circular(18)),
      child: Column(children: [
        _summaryRow('جمع کل', _subtotal),
        if (_discount > 0) _summaryRow('تخفیف', -_discount),
        if (_tax > 0) _summaryRow('مالیات (${_taxRate.toInt()}٪)', _tax),
        const Divider(height: 20),
        _summaryRow('مبلغ نهایی', _total, prominent: true),
        const SizedBox(height: 8),
        Align(
            alignment: Alignment.centerRight,
            child: Text('به حروف: ${words.isEmpty ? 'صفر' : words} تومان',
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFF355E5A)))),
      ]),
    );
  }

  Widget _summaryRow(String label, int amount, {bool prominent = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontWeight:
                          prominent ? FontWeight.w800 : FontWeight.normal,
                      fontSize: prominent ? 16 : 13))),
          Text('${_money(amount)} تومان',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: prominent ? _editorTeal : null,
                  fontSize: prominent ? 18 : 13)),
        ]),
      );

  Widget _section(String title, IconData icon, List<Widget> children) =>
      Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE9EDF2))),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(icon, color: _editorTeal, size: 20),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: Color(0xFF172B4D)))
          ]),
          const SizedBox(height: 14),
          ...children,
        ]),
      );

  Future<void> _quickAddCustomer() async {
    final customer = await showDialog<Customer>(
        context: context, builder: (context) => const _CustomerDialog());
    if (customer == null) return;
    await InvoiceStore.saveCustomer(customer);
    setState(() {
      _customers.add(customer);
      _customer = customer;
    });
  }

  Future<void> _quickAddProduct() async {
    final product = await showDialog<Product>(
        context: context, builder: (context) => const _ProductDialog());
    if (product == null) return;
    await InvoiceStore.saveProduct(product);
    setState(() {
      _products.add(product);
      final empty = _lines.firstWhere(
          (line) => line.product == null && line.titleController.text.isEmpty,
          orElse: () => _DraftLine());
      if (!_lines.contains(empty)) _lines.add(empty);
      empty.product = product;
      empty.titleController.text = product.title;
      empty.unit = product.unit;
      empty.priceController.text = '${product.unitPrice}';
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_customer == null || _lines.isEmpty) return;
    final items = _lines
        .map((line) => InvoiceLine(
              productId: line.product?.id ?? '',
              title: line.titleController.text.trim(),
              unit: line.unit,
              quantity: _parseQuantity(line.quantityController.text),
              unitPrice: _parseAmount(line.priceController.text),
            ))
        .toList();
    final source = _source;
    final editing = source != null && !widget.duplicate;
    final invoice = Invoice(
      id: editing
          ? source.id
          : 'invoice-${DateTime.now().microsecondsSinceEpoch}',
      number: editing ? source.number : InvoiceStore.nextInvoiceNumber,
      jalaliDate: _jalaliDate(_date),
      gregorianDate: _date.toDateTime(),
      type: _type,
      customerId: _customer!.id,
      customerName: _customer!.name,
      customerPhone: _customer!.phone,
      customerAddress: _customer!.address,
      items: items,
      discountValue: _parseDecimal(_discountController.text),
      discountIsPercent: _discountPercent,
      taxRate: _taxRate,
      paymentStatus: _payment,
      note: _noteController.text.trim(),
    );
    Navigator.of(context).pop(invoice);
  }
}

class _DraftLine {
  _DraftLine({
    this.product,
    String title = '',
    this.unit = 'عدد',
    double quantity = 1,
    int unitPrice = 0,
  })  : titleController = TextEditingController(text: title),
        quantityController =
            TextEditingController(text: _numberInput(quantity)),
        priceController =
            TextEditingController(text: unitPrice == 0 ? '' : '$unitPrice');

  Product? product;
  String unit;
  final TextEditingController titleController;
  final TextEditingController quantityController;
  final TextEditingController priceController;

  double get quantity => _parseQuantity(quantityController.text);
  int get unitPrice => _parseAmount(priceController.text);
  int get total => (quantity * unitPrice).round();

  void dispose() {
    titleController.dispose();
    quantityController.dispose();
    priceController.dispose();
  }
}

class _CustomerDialog extends StatefulWidget {
  const _CustomerDialog();

  @override
  State<_CustomerDialog> createState() => _CustomerDialogState();
}

class _CustomerDialogState extends State<_CustomerDialog> {
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _code = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('افزودن مشتری'),
          content: Form(
              key: _key,
              child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                    controller: _name,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'نام مشتری'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'نام الزامی است'
                        : null),
                const SizedBox(height: 8),
                TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'تلفن')),
                const SizedBox(height: 8),
                TextFormField(
                    controller: _address,
                    decoration: const InputDecoration(labelText: 'نشانی')),
                const SizedBox(height: 8),
                TextFormField(
                    controller: _code,
                    decoration: const InputDecoration(
                        labelText: 'شناسه ملی / کد اقتصادی')),
              ]))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('انصراف')),
            FilledButton(
                onPressed: () {
                  if (!_key.currentState!.validate()) return;
                  Navigator.pop(
                      context,
                      Customer(
                          id: 'customer-${DateTime.now().microsecondsSinceEpoch}',
                          name: _name.text.trim(),
                          phone: _phone.text.trim(),
                          address: _address.text.trim(),
                          economicCode: _code.text.trim()));
                },
                child: const Text('ذخیره مشتری')),
          ],
        ),
      );
}

class _ProductDialog extends StatefulWidget {
  const _ProductDialog();

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  final _key = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _price = TextEditingController();
  String _unit = _units.first;

  @override
  void dispose() {
    _title.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('افزودن کالا یا خدمت'),
          content: Form(
              key: _key,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                    controller: _title,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'عنوان'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'عنوان الزامی است'
                        : null),
                const SizedBox(height: 8),
                TextFormField(
                    controller: _price,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'قیمت واحد (تومان)'),
                    validator: (value) => _parseAmount(value ?? '') <= 0
                        ? 'قیمت معتبر وارد کنید'
                        : null),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                    value: _unit,
                    decoration: const InputDecoration(labelText: 'واحد'),
                    items: _units
                        .map((unit) =>
                            DropdownMenuItem(value: unit, child: Text(unit)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _unit = value ?? _unit)),
              ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('انصراف')),
            FilledButton(
                onPressed: () {
                  if (!_key.currentState!.validate()) return;
                  Navigator.pop(
                      context,
                      Product(
                          id: 'product-${DateTime.now().microsecondsSinceEpoch}',
                          title: _title.text.trim(),
                          unit: _unit,
                          unitPrice: _parseAmount(_price.text)));
                },
                child: const Text('ذخیره کالا')),
          ],
        ),
      );
}

String _jalaliDate(pdt.Jalali date) =>
    '${date.year.toString().padLeft(4, '0')}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

String _numberInput(num number) => number == number.roundToDouble()
    ? number.toInt().toString()
    : number.toString();

double _parseQuantity(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.')) ?? 0;

int _parseAmount(String text) =>
    int.tryParse(text.replaceAll(',', '').replaceAll('٬', '').trim()) ?? 0;

double _parseDecimal(String text) =>
    double.tryParse(text.replaceAll(',', '').replaceAll('٬', '').trim()) ?? 0;

T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T) test) {
  for (final value in values) {
    if (test(value)) return value;
  }
  return null;
}

String _money(int value) => value
    .toString()
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '٬');
