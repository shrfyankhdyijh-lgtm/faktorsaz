import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/invoice_models.dart';

class BusinessProfileDialog extends StatefulWidget {
  const BusinessProfileDialog({super.key, required this.initial});

  final BusinessProfile initial;

  @override
  State<BusinessProfileDialog> createState() => _BusinessProfileDialogState();
}

class _BusinessProfileDialogState extends State<BusinessProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _footer;
  Uint8List? _logoBytes;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial.name);
    _phone = TextEditingController(text: widget.initial.phone);
    _address = TextEditingController(text: widget.initial.address);
    _footer = TextEditingController(text: widget.initial.footerNote);
    _logoBytes = widget.initial.logoBytes;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _footer.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: false,
    );
    final bytes = result?.files.single.bytes;
    if (bytes != null) setState(() => _logoBytes = bytes);
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('مشخصات کسب‌وکار'),
          content: SizedBox(
            width: 440,
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    if (_logoBytes != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(_logoBytes!,
                            width: 64, height: 64, fit: BoxFit.cover),
                      )
                    else
                      Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                              color: const Color(0xFFEAF4F3),
                              borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.storefront_outlined,
                              color: Color(0xFF087E78))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: OutlinedButton.icon(
                            onPressed: _pickLogo,
                            icon: const Icon(Icons.image_outlined),
                            label: const Text('انتخاب نشان کسب‌وکار'))),
                    if (_logoBytes != null)
                      IconButton(
                          tooltip: 'حذف نشان',
                          onPressed: () => setState(() => _logoBytes = null),
                          icon: const Icon(Icons.delete_outline)),
                  ]),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: _name,
                      decoration:
                          const InputDecoration(labelText: 'نام کسب‌وکار'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'نام کسب‌وکار الزامی است'
                              : null),
                  const SizedBox(height: 8),
                  TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'تلفن')),
                  const SizedBox(height: 8),
                  TextFormField(
                      controller: _address,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'نشانی')),
                  const SizedBox(height: 8),
                  TextFormField(
                      controller: _footer,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText: 'یادداشت پای فاکتور')),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('انصراف')),
            FilledButton(
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                Navigator.pop(
                    context,
                    BusinessProfile(
                      name: _name.text.trim(),
                      phone: _phone.text.trim(),
                      address: _address.text.trim(),
                      logoBytes: _logoBytes,
                      footerNote: _footer.text.trim(),
                    ));
              },
              child: const Text('ذخیره مشخصات'),
            ),
          ],
        ),
      );
}
