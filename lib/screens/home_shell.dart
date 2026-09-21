import 'package:flutter/material.dart';
import '../theme.dart';
import '../storage.dart';
import '../models.dart';
import '../date_utils.dart';
import 'voucher_list_screen.dart';
import 'voucher_entry_screen.dart';
import 'chart_of_accounts_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

/// پوسته اصلی اپ: یک نوار کناری ثابت (شبیه منوی سپیدار) + لوگوی فروشگاه در
/// بالای نوار کناری + محتوای صفحه انتخاب‌شده در کنار آن.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selected = 0;
  String _storeName = 'فروشگاه';

  @override
  void initState() {
    super.initState();
    AppStorage().loadStoreName().then((n) {
      if (mounted) setState(() => _storeName = n);
    });
  }

  final _pages = const [
    _DashboardBody(),
    VoucherListScreen(),
    ChartOfAccountsScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 760;
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: wide ? 220 : 76,
            color: AppColors.primaryGreen,
            child: Column(
              children: [
                const SizedBox(height: 22),
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(image: AssetImage('assets/images/logo.png'), fit: BoxFit.cover),
                  ),
                ),
                if (wide) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      _storeName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                const Divider(color: Colors.white24, height: 1, indent: 16, endIndent: 16),
                Expanded(
                  child: NavigationRail(
                    backgroundColor: AppColors.primaryGreen,
                    selectedIndex: _selected,
                    onDestinationSelected: (i) => setState(() => _selected = i),
                    labelType: wide ? NavigationRailLabelType.none : NavigationRailLabelType.none,
                    extended: wide,
                    minExtendedWidth: 220,
                    useIndicator: true,
                    selectedIconTheme: const IconThemeData(color: AppColors.gold),
                    unselectedIconTheme: const IconThemeData(color: Colors.white70),
                    selectedLabelTextStyle: const TextStyle(color: AppColors.gold, fontFamily: 'Vazir', fontWeight: FontWeight.bold),
                    unselectedLabelTextStyle: const TextStyle(color: Colors.white70, fontFamily: 'Vazir'),
                    destinations: const [
                      NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), label: Text('داشبورد')),
                      NavigationRailDestination(icon: Icon(Icons.receipt_long_outlined), label: Text('اسناد حسابداری')),
                      NavigationRailDestination(icon: Icon(Icons.account_tree_outlined), label: Text('حساب‌ها')),
                      NavigationRailDestination(icon: Icon(Icons.bar_chart_outlined), label: Text('گزارش‌ها')),
                      NavigationRailDestination(icon: Icon(Icons.settings_outlined), label: Text('تنظیمات')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _selected,
              children: _pages,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardBody extends StatefulWidget {
  const _DashboardBody();

  @override
  State<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<_DashboardBody> {
  final _storage = AppStorage();
  int _temporaryCount = 0;
  int _permanentCount = 0;
  int _accountsCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final vouchers = await _storage.loadVouchers();
    final accounts = await _storage.loadAccounts();
    if (!mounted) return;
    setState(() {
      _temporaryCount = vouchers.where((v) => v.status == VoucherStatus.temporary).length;
      _permanentCount = vouchers.where((v) => v.status == VoucherStatus.permanent).length;
      _accountsCount = accounts.where((a) => a.level == AccountLevel.tafsili).length;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('داشبورد')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Text('امروز ${toPersianDigits(todayJalali())}', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      _statCard('اسناد موقت', _temporaryCount, Icons.hourglass_empty, Colors.orange),
                      _statCard('اسناد دائم', _permanentCount, Icons.verified_outlined, Colors.green),
                      _statCard('حساب‌های تفصیلی', _accountsCount, Icons.account_tree_outlined, Colors.blueGrey),
                    ],
                  ),
                  const SizedBox(height: 26),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const VoucherEntryScreen()),
                      );
                      _load();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('ثبت سند حسابداری جدید'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _statCard(String title, int value, IconData icon, Color color) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: color.withOpacity(0.15), child: Icon(icon, color: color)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(toPersianDigits(value.toString()), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}
