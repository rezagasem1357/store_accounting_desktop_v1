import 'package:flutter/material.dart';
import '../models.dart';

/// دیالوگ انتخاب حساب تفصیلی (برگ درخت) برای استفاده در ردیف‌های سند.
/// مسیر کامل حساب (کل ← معین ← تفصیلی) برای وضوح بیشتر نمایش داده می‌شود.
Future<AccountNode?> pickTafsiliAccount(
  BuildContext context, {
  required List<AccountNode> allAccounts,
}) async {
  final tafsiliList = allAccounts.where((a) => a.level == AccountLevel.tafsili).toList();

  String pathFor(AccountNode leaf) {
    final moin = allAccounts.firstWhere(
      (a) => a.id == leaf.parentId,
      orElse: () => leaf,
    );
    final kol = allAccounts.firstWhere(
      (a) => a.id == moin.parentId,
      orElse: () => moin,
    );
    if (kol.id == moin.id) return '${moin.name} / ${leaf.name}';
    return '${kol.name} / ${moin.name} / ${leaf.name}';
  }

  return showDialog<AccountNode>(
    context: context,
    builder: (context) {
      String query = '';
      return StatefulBuilder(
        builder: (context, setState) {
          final filtered = tafsiliList.where((a) {
            if (query.isEmpty) return true;
            final hay = '${a.code} ${a.name} ${pathFor(a)}';
            return hay.contains(query);
          }).toList();
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('انتخاب حساب تفصیلی'),
            content: SizedBox(
              width: 460,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    textDirection: TextDirection.rtl,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'جستجو بر اساس نام یا کد حساب...',
                    ),
                    onChanged: (v) => setState(() => query = v.trim()),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('حسابی یافت نشد'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final a = filtered[i];
                              return ListTile(
                                dense: true,
                                title: Text('${a.code} — ${a.name}'),
                                subtitle: Text(
                                  pathFor(a),
                                  style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                                ),
                                onTap: () => Navigator.pop(context, a),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('انصراف'),
              ),
            ],
          );
        },
      );
    },
  );
}
