import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models.dart';
import '../storage.dart';
import '../date_utils.dart';
import '../widgets/account_picker.dart';

class VoucherEntryScreen extends StatefulWidget {
  final Voucher? existing;
  const VoucherEntryScreen({super.key, this.existing});

  @override
  State<VoucherEntryScreen> createState() => _VoucherEntryScreenState();
}

class _LineRow {
  AccountNode? account;
  final TextEditingController descCtrl;
  final TextEditingController debitCtrl;
  final TextEditingController creditCtrl;
  final String id;

  _LineRow({this.account, String description = '', int debit = 0, int credit = 0, String? id})
      : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        descCtrl = TextEditingController(text: description),
        debitCtrl = TextEditingController(text: debit == 0 ? '' : debit.toString()),
        creditCtrl = TextEditingController(text: credit == 0 ? '' : credit.toString());

  int get debit => int.tryParse(debitCtrl.text.trim()) ?? 0;
  int get credit => int.tryParse(creditCtrl.text.trim()) ?? 0;
}

class _VoucherEntryScreenState extends State<VoucherEntryScreen> {
  final _storage = AppStorage();
  final _dateCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  List<AccountNode> _accounts = [];
  final List<_LineRow> _rows = [];
  bool _loading = true;
  bool _saving = false;

  bool get _isReadOnly => widget.existing?.status == VoucherStatus.permanent;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _accounts = await _storage.loadAccounts();
    final existing = widget.existing;
    if (existing != null) {
      _dateCtrl.text = existing.date;
      _descCtrl.text = existing.description;
      for (final l in existing.lines) {
        AccountNode? acc;
        for (final a in _accounts) {
          if (a.id == l.accountId) acc = a;
        }
        _rows.add(_LineRow(
          account: acc,
          description: l.description,
          debit: l.debit,
          credit: l.credit,
          id: l.id,
        ));
      }
    } else {
      _dateCtrl.text = todayJalali();
      _rows.add(_LineRow());
      _rows.add(_LineRow());
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _descCtrl.dispose();
    for (final r in _rows) {
      r.descCtrl.dispose();
      r.debitCtrl.dispose();
      r.creditCtrl.dispose();
    }
    super.dispose();
  }

  int get _totalDebit => _rows.fold(0, (s, r) => s + r.debit);
  int get _totalCredit => _rows.fold(0, (s, r) => s + r.credit);
  int get _diff => _totalDebit - _totalCredit;

  Future<void> _pickAccount(_LineRow row) async {
    final picked = await pickTafsiliAccount(context, allAccounts: _accounts);
    if (picked != null) setState(() => row.account = picked);
  }

  void _addRow() => setState(() => _rows.add(_LineRow()));

  void _removeRow(_LineRow row) {
    if (_rows.length <= 2) {
      _showMsg('سند حسابداری حداقل باید ۲ ردیف داشته باشد.');
      return;
    }
    setState(() => _rows.remove(row));
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _save({required bool asPermanent}) async {
    if (_dateCtrl.text.trim().isEmpty) {
      _showMsg('تاریخ سند را وارد کنید.');
      return;
    }
    final activeRows = _rows.where((r) => r.account != null && (r.debit > 0 || r.credit > 0)).toList();
    if (activeRows.length < 2) {
      _showMsg('سند باید حداقل ۲ ردیف با حساب و مبلغ معتبر داشته باشد.');
      return;
    }
    if (_totalDebit != _totalCredit || _totalDebit == 0) {
      _showMsg('جمع بدهکار و بستانکار باید برابر و بزرگ‌تر از صفر باشد (مغایرت: ${_diff.abs()} ریال).');
      return;
    }

    setState(() => _saving = true);
    try {
      final vouchers = await _storage.loadVouchers();
      final lines = activeRows
          .map((r) => VoucherLine(
                id: r.id,
                accountId: r.account!.id,
                description: r.descCtrl.text.trim(),
                debit: r.debit,
                credit: r.credit,
              ))
          .toList();

      if (widget.existing != null) {
        final idx = vouchers.indexWhere((v) => v.id == widget.existing!.id);
        if (idx != -1) {
          vouchers[idx].date = _dateCtrl.text.trim();
          vouchers[idx].description = _descCtrl.text.trim();
          vouchers[idx].lines = lines;
          if (asPermanent) vouchers[idx].status = VoucherStatus.permanent;
        }
      } else {
        vouchers.add(Voucher(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          number: 0, // با renumberVouchersByDate مقداردهی می‌شود
          date: _dateCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          status: asPermanent ? VoucherStatus.permanent : VoucherStatus.temporary,
          lines: lines,
        ));
      }

      final renumbered = renumberVouchersByDate(vouchers);
      await _storage.saveVouchers(renumbered);
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final balanced = _diff == 0 && _totalDebit > 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null
            ? 'سند حسابداری جدید'
            : 'سند شماره ${toPersianDigits(widget.existing!.number.toString())}'),
        actions: [
          if (_isReadOnly)
            const Padding(
              padding: EdgeInsets.only(left: 16),
              child: Center(
                child: Chip(
                  label: Text('دائم — غیرقابل ویرایش', style: TextStyle(color: Colors.white)),
                  backgroundColor: Colors.black26,
                ),
              ),
            ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _isReadOnly,
        child: Opacity(
          opacity: _isReadOnly ? 0.75 : 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _dateCtrl,
                        textDirection: TextDirection.rtl,
                        decoration: const InputDecoration(
                          labelText: 'تاریخ سند (مثال: 1403/07/01)',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _descCtrl,
                        textDirection: TextDirection.rtl,
                        decoration: const InputDecoration(labelText: 'شرح سند'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(width: 40, child: Text('#', textAlign: TextAlign.center)),
                      Expanded(flex: 3, child: Text('حساب', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 3, child: Text('شرح ردیف', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('بدهکار', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Expanded(flex: 2, child: Text('بستانکار', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      SizedBox(width: 40),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _rows.length,
                    itemBuilder: (context, i) {
                      final row = _rows[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(width: 40, child: Text('${i + 1}', textAlign: TextAlign.center)),
                            Expanded(
                              flex: 3,
                              child: InkWell(
                                onTap: () => _pickAccount(row),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade400),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    row.account == null ? 'انتخاب حساب...' : '${row.account!.code} — ${row.account!.name}',
                                    style: TextStyle(
                                      color: row.account == null ? Colors.grey : null,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: row.descCtrl,
                                textDirection: TextDirection.rtl,
                                decoration: const InputDecoration(isDense: true, hintText: 'شرح'),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: row.debitCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(isDense: true, hintText: '۰'),
                                onChanged: (v) {
                                  if (v.isNotEmpty) row.creditCtrl.clear();
                                  setState(() {});
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: row.creditCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(isDense: true, hintText: '۰'),
                                onChanged: (v) {
                                  if (v.isNotEmpty) row.debitCtrl.clear();
                                  setState(() {});
                                },
                              ),
                            ),
                            SizedBox(
                              width: 40,
                              child: IconButton(
                                icon: const Icon(Icons.close, size: 18, color: Colors.red),
                                onPressed: () => _removeRow(row),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if (!_isReadOnly)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _addRow,
                      icon: const Icon(Icons.add),
                      label: const Text('افزودن ردیف'),
                    ),
                  ),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'جمع بدهکار: ${toPersianDigits(_totalDebit.toString())} ریال',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'جمع بستانکار: ${toPersianDigits(_totalCredit.toString())} ریال',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        balanced ? '✅ تراز است' : '⚠️ مغایرت: ${toPersianDigits(_diff.abs().toString())} ریال',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: balanced ? Colors.green.shade700 : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!_isReadOnly)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving ? null : () => _save(asPermanent: false),
                          child: const Text('ذخیره به‌عنوان موقت'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saving ? null : () => _save(asPermanent: true),
                          child: const Text('ذخیره و تبدیل به سند دائم'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
