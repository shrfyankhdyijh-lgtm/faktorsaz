import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/invoice_models.dart';
import '../services/backup_file_exporter.dart';
import '../services/backup_service.dart';
import '../services/invoice_store.dart';
import 'business_profile_dialog.dart';
import 'invoice_editor_screen.dart';
import 'invoice_pdf_screen.dart';

const _ink = Color(0xFF172B4D);
const _teal = Color(0xFF087E78);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _searchController = TextEditingController();
  String _paymentFilter = 'همه';
  String _typeFilter = 'همه';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _edit({Invoice? invoice, bool duplicate = false}) async {
    final result = await Navigator.of(context).push<Invoice>(MaterialPageRoute(
      builder: (_) =>
          InvoiceEditorScreen(invoice: invoice, duplicate: duplicate),
    ));
    if (result != null) {
      await InvoiceStore.saveInvoice(result);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('فاکتور ذخیره شد')));
      }
    }
  }

  Future<void> _delete(Invoice invoice) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('حذف فاکتور'),
              content: Text('فاکتور شمارهٔ ${invoice.number} حذف شود؟'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('انصراف')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('حذف')),
              ],
            ));
    if (confirmed == true) await InvoiceStore.deleteInvoice(invoice.id);
  }

  Future<void> _pdf(Invoice invoice) async {
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => InvoicePdfScreen(invoice: invoice)));
  }

  Future<void> _editBusiness() async {
    final current = InvoiceStore.businessProfile.get('default') ??
        const BusinessProfile(name: 'نام کسب‌وکار');
    final updated = await showDialog<BusinessProfile>(
      context: context,
      builder: (_) => BusinessProfileDialog(initial: current),
    );
    if (updated != null) {
      await InvoiceStore.businessProfile.put('default', updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('مشخصات کسب‌وکار ذخیره شد')),
        );
      }
    }
  }

  Future<void> _createBackup() async {
    try {
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final saved = await saveBackupFile(
        BackupService.exportJson(),
        'faktorsaz-backup-$stamp.json',
      );
      if (mounted) {
        _showMessage(saved ? 'فایل پشتیبان آماده شد.' : 'ذخیرهٔ فایل لغو شد.');
      }
    } catch (error) {
      if (mounted) _showMessage('ساخت فایل پشتیبان ناموفق بود: $error');
    }
  }

  Future<void> _restoreBackup() async {
    try {
      final selection = await FilePicker.platform.pickFiles(
        dialogTitle: 'انتخاب فایل پشتیبان فاکتورساز',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
        allowMultiple: false,
      );
      final file = selection?.files.single;
      final bytes = file?.bytes;
      if (bytes == null) {
        if (selection != null && mounted) {
          _showMessage('خواندن فایل انتخاب‌شده ممکن نشد.');
        }
        return;
      }
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('بازیابی اطلاعات'),
          content: const Text(
            'اطلاعات فایل با داده‌های فعلی ادغام می‌شود؛ مواردی که شناسهٔ یکسان دارند جایگزین می‌شوند.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('ادغام و بازیابی'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      final summary = await BackupService.importJson(utf8.decode(bytes));
      if (mounted) {
        _showMessage(
          'بازیابی انجام شد: ${summary.customers} مشتری، ${summary.products} کالا و ${summary.invoices} فاکتور.',
        );
      }
    } on FormatException catch (error) {
      if (mounted) _showMessage('فایل پشتیبان معتبر نیست: ${error.message}');
    } catch (error) {
      if (mounted) _showMessage('بازیابی اطلاعات ناموفق بود: $error');
    }
  }

  Future<void> _openWebBusiness24() async {
    final uri = Uri.parse('https://webbusiness24.ir/');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      _showMessage('بازکردن وب‌سایت ممکن نشد.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  List<Invoice> _filter(List<Invoice> invoices) {
    final query = _searchController.text.trim().toLowerCase();
    return invoices.where((invoice) {
      final matchesQuery = query.isEmpty ||
          invoice.customerName.toLowerCase().contains(query) ||
          '${invoice.number}'.contains(query);
      final matchesPayment =
          _paymentFilter == 'همه' || invoice.paymentStatus == _paymentFilter;
      final matchesType = _typeFilter == 'همه' || invoice.type == _typeFilter;
      return matchesQuery && matchesPayment && matchesType;
    }).toList()
      ..sort((a, b) => b.gregorianDate.compareTo(a.gregorianDate));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        drawer: _settingsDrawer(),
        appBar: AppBar(
          title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('فاکتورساز',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                Text('فاکتورهای شما، همیشه در دسترس',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
              ]),
          actions: [
            IconButton(
                tooltip: 'مشخصات کسب‌وکار',
                onPressed: _editBusiness,
                icon: const Icon(Icons.storefront_outlined)),
            const SizedBox(width: 8),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(),
          backgroundColor: _teal,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('فاکتور جدید'),
        ),
        body: ValueListenableBuilder<Box<Invoice>>(
          valueListenable: InvoiceStore.invoices.listenable(),
          builder: (context, box, _) {
            final all = box.values.toList();
            final now = Jalali.now();
            final monthSales = all.where((invoice) {
              final date = Jalali.fromDateTime(invoice.gregorianDate);
              return date.year == now.year && date.month == now.month;
            }).fold<int>(0, (sum, invoice) => sum + invoice.total);
            final unpaid = all
                .where((invoice) => !['پرداخت شده', 'نقدی', 'کارت‌به‌کارت']
                    .contains(invoice.paymentStatus))
                .length;
            final visible = _filter(all);
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1060),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  children: [
                    _welcomeCard(),
                    const SizedBox(height: 18),
                    LayoutBuilder(builder: (context, constraints) {
                      final columns = constraints.maxWidth > 650 ? 3 : 1;
                      final width =
                          (constraints.maxWidth - (columns - 1) * 12) / columns;
                      return Wrap(spacing: 12, runSpacing: 12, children: [
                        SizedBox(
                            width: width,
                            child: _StatCard(
                                title: 'فروش این ماه',
                                value: '${_money(monthSales)} تومان',
                                icon: Icons.trending_up_rounded,
                                color: _teal)),
                        SizedBox(
                            width: width,
                            child: _StatCard(
                                title: 'فاکتورهای ثبت‌شده',
                                value: '${all.length}',
                                icon: Icons.receipt_long_rounded,
                                color: const Color(0xFF5265B4))),
                        SizedBox(
                            width: width,
                            child: _StatCard(
                                title: 'در انتظار پرداخت',
                                value: '$unpaid',
                                icon: Icons.schedule_rounded,
                                color: const Color(0xFFC47A1C))),
                      ]);
                    }),
                    const SizedBox(height: 26),
                    const Text('فاکتورها',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _ink)),
                    const SizedBox(height: 10),
                    _filters(),
                    const SizedBox(height: 10),
                    if (visible.isEmpty)
                      _EmptyInvoices(
                          onCreate: () => _edit(), isSearch: all.isNotEmpty)
                    else
                      ...visible.map((invoice) => _InvoiceTile(
                            invoice: invoice,
                            onEdit: () => _edit(invoice: invoice),
                            onDuplicate: () =>
                                _edit(invoice: invoice, duplicate: true),
                            onPdf: () => _pdf(invoice),
                            onDelete: () => _delete(invoice),
                          )),
                    const SizedBox(height: 22),
                    _developerCard(),
                  ],
                ),
              ),
            );
          },
        ),
      );

  Widget _filters() => LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth > 620;
        return Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                  width:
                      wide ? constraints.maxWidth * .42 : constraints.maxWidth,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                        hintText: 'جست‌وجوی مشتری یا شماره فاکتور',
                        prefixIcon: Icon(Icons.search)),
                  )),
              SizedBox(
                  width: wide ? 190 : (constraints.maxWidth - 10) / 2,
                  child: DropdownButtonFormField<String>(
                    value: _paymentFilter,
                    decoration:
                        const InputDecoration(labelText: 'وضعیت پرداخت'),
                    items: ['همه', 'پرداخت شده', 'نقدی', 'کارت‌به‌کارت', 'نسیه']
                        .map((value) =>
                            DropdownMenuItem(value: value, child: Text(value)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _paymentFilter = value ?? 'همه'),
                  )),
              SizedBox(
                  width: wide ? 190 : (constraints.maxWidth - 10) / 2,
                  child: DropdownButtonFormField<String>(
                    value: _typeFilter,
                    decoration: const InputDecoration(labelText: 'نوع فاکتور'),
                    items: ['همه', 'فاکتور فروش', 'پیش‌فاکتور', 'رسید نقدی']
                        .map((value) =>
                            DropdownMenuItem(value: value, child: Text(value)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _typeFilter = value ?? 'همه'),
                  )),
            ]);
      });

  Widget _welcomeCard() => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
                colors: [_ink, Color(0xFF244A67)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft)),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('امروز ${_today()}',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                const Text('فروش خود را\nمرتب و سریع ثبت کنید',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        height: 1.5,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                const Text('اطلاعات فقط روی همین دستگاه ذخیره می‌شود.',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
          const Icon(Icons.receipt_long_rounded,
              color: Colors.white24, size: 70),
        ]),
      );

  Widget _developerCard() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: const Color(0xFFE9F3F2),
            borderRadius: BorderRadius.circular(20)),
        child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('وب بیزینس',
                  style: TextStyle(color: _ink, fontWeight: FontWeight.w800)),
              SizedBox(height: 5),
              Text('خدمات تخصصی طراحی سایت فروشگاهی ، خدماتی ، طراحی اپلیکیشن  و طراحی اتوماسیون کسب‌وکار',
                  style: TextStyle(color: Colors.black54, fontSize: 12)),
            ]),
      );

  Widget _settingsDrawer() => Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_ink, Color(0xFF244A67)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    'تنظیمات و پشتیبان‌گیری',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: const Text('مشخصات کسب‌وکار'),
                onTap: () {
                  Navigator.pop(context);
                  _editBusiness();
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('ایجاد فایل پشتیبان'),
                subtitle: const Text('ذخیرهٔ محلی همهٔ اطلاعات در JSON'),
                onTap: () {
                  Navigator.pop(context);
                  _createBackup();
                },
              ),
              ListTile(
                leading: const Icon(Icons.restore_outlined),
                title: const Text('بازیابی اطلاعات از فایل'),
                subtitle: const Text('ادغام با اطلاعات ذخیره‌شدهٔ فعلی'),
                onTap: () {
                  Navigator.pop(context);
                  _restoreBackup();
                },
              ),
              const Divider(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Card(
                  color: const Color(0xFFE9F3F2),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text('طراحی و توسعه: وب بیزینس',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: _ink)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              height: 54,
                              width: 64,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Image.asset(
                                'assets/branding/logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          'خدمات تخصصی طراحی سایت فروشگاهی ، خدماتی ، طراحی اپلیکیشن  و طراحی اتوماسیون کسب‌وکار',
                          style: TextStyle(
                              fontSize: 12, height: 1.6, color: Colors.black54),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonalIcon(
                            onPressed: _openWebBusiness24,
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: const Text('مشاوره و ارتباط'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.title,
      required this.value,
      required this.icon,
      required this.color});
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE9EDF2))),
        child: Row(children: [
          Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: color.withOpacity(.1),
                  borderRadius: BorderRadius.circular(13)),
              child: Icon(icon, color: color)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 11, color: Colors.black54)),
                const SizedBox(height: 4),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16,
                        color: _ink,
                        fontWeight: FontWeight.w800)),
              ])),
        ]),
      );
}

class _InvoiceTile extends StatelessWidget {
  const _InvoiceTile(
      {required this.invoice,
      required this.onEdit,
      required this.onDuplicate,
      required this.onPdf,
      required this.onDelete});
  final Invoice invoice;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onPdf;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final paid =
        ['پرداخت شده', 'نقدی', 'کارت‌به‌کارت'].contains(invoice.paymentStatus);
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE9EDF2))),
      child: ListTile(
        onTap: onPdf,
        leading: CircleAvatar(
            backgroundColor: const Color(0xFFE9F3F2),
            child: Text('${invoice.number}',
                style: const TextStyle(
                    color: _teal, fontWeight: FontWeight.bold))),
        title: Text(invoice.customerName,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${invoice.jalaliDate}  •  ${invoice.type}'),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${_money(invoice.total)} تومان',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: _ink)),
                Text(invoice.paymentStatus,
                    style: TextStyle(
                        fontSize: 11,
                        color: paid ? _teal : const Color(0xFFC47A1C))),
              ]),
          PopupMenuButton<String>(
            tooltip: 'عملیات فاکتور',
            onSelected: (action) {
              switch (action) {
                case 'edit':
                  onEdit();
                case 'duplicate':
                  onDuplicate();
                case 'pdf':
                  onPdf();
                case 'delete':
                  onDelete();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('ویرایش')),
              PopupMenuItem(value: 'duplicate', child: Text('کپی فاکتور')),
              PopupMenuItem(value: 'pdf', child: Text('پیش‌نمایش و چاپ PDF')),
              PopupMenuItem(value: 'delete', child: Text('حذف')),
            ],
          ),
        ]),
      ),
    );
  }
}

class _EmptyInvoices extends StatelessWidget {
  const _EmptyInvoices({required this.onCreate, required this.isSearch});
  final VoidCallback onCreate;
  final bool isSearch;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE9EDF2))),
        child: Column(children: [
          const Icon(Icons.receipt_long_outlined,
              size: 42, color: Color(0xFF9AA7B5)),
          const SizedBox(height: 10),
          Text(
              isSearch
                  ? 'فاکتوری با این مشخصات پیدا نشد'
                  : 'هنوز فاکتوری ثبت نشده',
              style: const TextStyle(fontWeight: FontWeight.bold, color: _ink)),
          if (!isSearch) ...[
            const SizedBox(height: 5),
            const Text('برای شروع، اولین فاکتور خود را بسازید.',
                style: TextStyle(color: Colors.black54, fontSize: 12)),
            const SizedBox(height: 14),
            OutlinedButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('ساخت اولین فاکتور')),
          ],
        ]),
      );
}

String _money(int value) => value
    .toString()
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '٬');

String _today() {
  final date = Jalali.now();
  const months = [
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند'
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
