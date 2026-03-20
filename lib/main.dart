// ============================================================
//  EzzeExpense — Complete Single-File Flutter App
//  Stack: Provider + Hive + fl_chart
//  Theme: Blue/Indigo | Currency: BDT (৳)
// ============================================================

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

// ============================================================
// SECTION 1: CONSTANTS & THEME
// ============================================================

const String kAppName = 'EzzeExpense';
const String kExpenseBox = 'expenses';
const String kCategoryBox = 'categories';
const String kBudgetBox = 'budgets';
const String kSettingsBox = 'settings';

const List<String> kCurrencies = ['BDT', 'USD'];
const Map<String, String> kCurrencySymbols = {'BDT': '৳', 'USD': '\$'};

final List<Map<String, dynamic>> kDefaultCategories = [
  {'name': 'Food', 'icon': '🍔', 'color': 0xFFE53935},
  {'name': 'Transport', 'icon': '🚗', 'color': 0xFF1E88E5},
  {'name': 'Shopping', 'icon': '🛍️', 'color': 0xFF8E24AA},
  {'name': 'Bills', 'icon': '💡', 'color': 0xFFFB8C00},
  {'name': 'Health', 'icon': '💊', 'color': 0xFF00ACC1},
  {'name': 'Entertainment', 'icon': '🎬', 'color': 0xFF43A047},
  {'name': 'Education', 'icon': '📚', 'color': 0xFF6D4C41},
  {'name': 'Other', 'icon': '📦', 'color': 0xFF757575},
];

ThemeData buildTheme(bool isDark) {
  const Color primary = Color(0xFF3F51B5);
  const Color primaryDark = Color(0xFF5C6BC0);

  return ThemeData(
    useMaterial3: true,
    brightness: isDark ? Brightness.dark : Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: isDark ? primaryDark : primary,
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : primary,
      foregroundColor: Colors.white,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}

// ============================================================
// SECTION 2: MODELS
// ============================================================

class ExpenseModel {
  final String id;
  String title;
  double amount;
  String categoryId;
  DateTime date;
  String notes;

  ExpenseModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.categoryId,
    required this.date,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'amount': amount,
    'categoryId': categoryId,
    'date': date.toIso8601String(),
    'notes': notes,
  };

  factory ExpenseModel.fromMap(Map<dynamic, dynamic> map) => ExpenseModel(
    id: map['id'] ?? const Uuid().v4(),
    title: map['title'] ?? '',
    amount: (map['amount'] ?? 0).toDouble(),
    categoryId: map['categoryId'] ?? '',
    date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
    notes: map['notes'] ?? '',
  );
}

class CategoryModel {
  final String id;
  String name;
  String icon;
  int colorValue;
  bool isDefault;

  CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorValue,
    this.isDefault = false,
  });

  Color get color => Color(colorValue);

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'icon': icon,
    'colorValue': colorValue,
    'isDefault': isDefault,
  };

  factory CategoryModel.fromMap(Map<dynamic, dynamic> map) => CategoryModel(
    id: map['id'] ?? const Uuid().v4(),
    name: map['name'] ?? '',
    icon: map['icon'] ?? '📦',
    colorValue: map['colorValue'] ?? 0xFF757575,
    isDefault: map['isDefault'] ?? false,
  );
}

class BudgetModel {
  double monthlyTotal;
  Map<String, double> categoryBudgets;

  BudgetModel({
    this.monthlyTotal = 0,
    Map<String, double>? categoryBudgets,
  }) : categoryBudgets = categoryBudgets ?? {};

  Map<String, dynamic> toMap() => {
    'monthlyTotal': monthlyTotal,
    'categoryBudgets': categoryBudgets,
  };

  factory BudgetModel.fromMap(Map<dynamic, dynamic> map) => BudgetModel(
    monthlyTotal: (map['monthlyTotal'] ?? 0).toDouble(),
    categoryBudgets: Map<String, double>.from(
      (map['categoryBudgets'] as Map? ?? {}).map(
            (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
      ),
    ),
  );
}

// ============================================================
// SECTION 3: PROVIDERS
// ============================================================

class SettingsProvider extends ChangeNotifier {
  late Box _box;
  bool _isDark = false;
  String _currency = 'BDT';

  bool get isDark => _isDark;
  String get currency => _currency;
  String get currencySymbol => kCurrencySymbols[_currency] ?? '৳';

  Future<void> init() async {
    _box = Hive.box(kSettingsBox);
    _isDark = _box.get('isDark', defaultValue: false);
    _currency = _box.get('currency', defaultValue: 'BDT');
  }

  void toggleTheme() {
    _isDark = !_isDark;
    _box.put('isDark', _isDark);
    notifyListeners();
  }

  void setCurrency(String currency) {
    _currency = currency;
    _box.put('currency', currency);
    notifyListeners();
  }
}

class CategoryProvider extends ChangeNotifier {
  late Box _box;
  List<CategoryModel> _categories = [];

  List<CategoryModel> get categories => _categories;

  Future<void> init() async {
    _box = Hive.box(kCategoryBox);
    _load();
    if (_categories.isEmpty) _seedDefaults();
  }

  void _load() {
    _categories = _box.values
        .map((e) => CategoryModel.fromMap(e as Map))
        .toList();
  }

  void _seedDefaults() {
    const uuid = Uuid();
    for (final c in kDefaultCategories) {
      final cat = CategoryModel(
        id: uuid.v4(),
        name: c['name'],
        icon: c['icon'],
        colorValue: c['color'],
        isDefault: true,
      );
      _box.put(cat.id, cat.toMap());
    }
    _load();
    notifyListeners();
  }

  CategoryModel? getById(String id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> addCategory(CategoryModel cat) async {
    await _box.put(cat.id, cat.toMap());
    _load();
    notifyListeners();
  }

  Future<void> updateCategory(CategoryModel cat) async {
    await _box.put(cat.id, cat.toMap());
    _load();
    notifyListeners();
  }

  Future<void> deleteCategory(String id) async {
    await _box.delete(id);
    _load();
    notifyListeners();
  }
}

class ExpenseProvider extends ChangeNotifier {
  late Box _box;
  List<ExpenseModel> _expenses = [];

  List<ExpenseModel> get expenses => List.unmodifiable(_expenses);

  List<ExpenseModel> get thisMonthExpenses {
    final now = DateTime.now();
    return _expenses
        .where((e) => e.date.month == now.month && e.date.year == now.year)
        .toList();
  }

  List<ExpenseModel> get todayExpenses {
    final now = DateTime.now();
    return _expenses
        .where((e) =>
    e.date.day == now.day &&
        e.date.month == now.month &&
        e.date.year == now.year)
        .toList();
  }

  double get totalThisMonth =>
      thisMonthExpenses.fold(0, (s, e) => s + e.amount);

  double get totalToday =>
      todayExpenses.fold(0, (s, e) => s + e.amount);

  Future<void> init() async {
    _box = Hive.box(kExpenseBox);
    _load();
  }

  void _load() {
    _expenses = _box.values
        .map((e) => ExpenseModel.fromMap(e as Map))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> addExpense(ExpenseModel expense) async {
    await _box.put(expense.id, expense.toMap());
    _load();
    notifyListeners();
  }

  Future<void> updateExpense(ExpenseModel expense) async {
    await _box.put(expense.id, expense.toMap());
    _load();
    notifyListeners();
  }

  Future<void> deleteExpense(String id) async {
    await _box.delete(id);
    _load();
    notifyListeners();
  }

  Future<void> clearAll() async {
    await _box.clear();
    _load();
    notifyListeners();
  }

  List<ExpenseModel> filter({
    String? query,
    String? categoryId,
    DateTime? from,
    DateTime? to,
    double? minAmount,
    double? maxAmount,
  }) {
    return _expenses.where((e) {
      if (query != null && query.isNotEmpty) {
        final q = query.toLowerCase();
        if (!e.title.toLowerCase().contains(q) &&
            !e.notes.toLowerCase().contains(q)) return false;
      }
      if (categoryId != null && categoryId.isNotEmpty && e.categoryId != categoryId) return false;
      if (from != null && e.date.isBefore(from)) return false;
      if (to != null && e.date.isAfter(to.add(const Duration(days: 1)))) return false;
      if (minAmount != null && e.amount < minAmount) return false;
      if (maxAmount != null && e.amount > maxAmount) return false;
      return true;
    }).toList();
  }

  Map<String, double> categoryTotals(List<ExpenseModel> list) {
    final map = <String, double>{};
    for (final e in list) {
      map[e.categoryId] = (map[e.categoryId] ?? 0) + e.amount;
    }
    return map;
  }

  // Weekly bar data: last 7 days
  List<double> weeklyTotals() {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      return _expenses
          .where((e) =>
      e.date.day == day.day &&
          e.date.month == day.month &&
          e.date.year == day.year)
          .fold(0.0, (s, e) => s + e.amount);
    });
  }

  // Monthly bar data: last 6 months
  List<double> monthlyTotals() {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final month = DateTime(now.year, now.month - (5 - i));
      return _expenses
          .where((e) => e.date.month == month.month && e.date.year == month.year)
          .fold(0.0, (s, e) => s + e.amount);
    });
  }

  String exportJson() {
    return jsonEncode(_expenses.map((e) => e.toMap()).toList());
  }

  void importJson(String jsonStr) {
    try {
      final list = jsonDecode(jsonStr) as List;
      _box.clear();
      for (final item in list) {
        final e = ExpenseModel.fromMap(item);
        _box.put(e.id, e.toMap());
      }
      _load();
      notifyListeners();
    } catch (_) {}
  }
}

class BudgetProvider extends ChangeNotifier {
  late Box _box;
  BudgetModel _budget = BudgetModel();

  BudgetModel get budget => _budget;

  Future<void> init() async {
    _box = Hive.box(kBudgetBox);
    final raw = _box.get('budget');
    if (raw != null) _budget = BudgetModel.fromMap(raw);
  }

  Future<void> setMonthlyBudget(double amount) async {
    _budget.monthlyTotal = amount;
    await _save();
  }

  Future<void> setCategoryBudget(String catId, double amount) async {
    _budget.categoryBudgets[catId] = amount;
    await _save();
  }

  Future<void> removeCategoryBudget(String catId) async {
    _budget.categoryBudgets.remove(catId);
    await _save();
  }

  Future<void> _save() async {
    await _box.put('budget', _budget.toMap());
    notifyListeners();
  }
}

// ============================================================
// SECTION 4: MAIN + APP ROOT
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox(kExpenseBox);
  await Hive.openBox(kCategoryBox);
  await Hive.openBox(kBudgetBox);
  await Hive.openBox(kSettingsBox);

  final settings = SettingsProvider();
  final categories = CategoryProvider();
  final expenses = ExpenseProvider();
  final budgets = BudgetProvider();

  await settings.init();
  await categories.init();
  await expenses.init();
  await budgets.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: categories),
        ChangeNotifierProvider.value(value: expenses),
        ChangeNotifierProvider.value(value: budgets),
      ],
      child: const EzzeExpenseApp(),
    ),
  );
}

class EzzeExpenseApp extends StatelessWidget {
  const EzzeExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(false),
      darkTheme: buildTheme(true),
      themeMode: settings.isDark ? ThemeMode.dark : ThemeMode.light,
      home: const MainShell(),
    );
  }
}

// ============================================================
// SECTION 5: MAIN SHELL (Bottom Navigation)
// ============================================================

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    StatsScreen(),
    BudgetScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Stats'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Budget'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
        onPressed: () => _openAddExpense(context),
        child: const Icon(Icons.add),
      )
          : null,
    );
  }

  void _openAddExpense(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditExpenseScreen()));
  }
}

// ============================================================
// SECTION 6: REUSABLE WIDGETS
// ============================================================

class SummaryCard extends StatelessWidget {
  final String label;
  final String amount;
  final IconData icon;
  final Color color;

  const SummaryCard({
    super.key,
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
            const SizedBox(height: 4),
            Text(amount,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                )),
          ],
        ),
      ),
    );
  }
}

class ExpenseTile extends StatelessWidget {
  final ExpenseModel expense;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ExpenseTile({
    super.key,
    required this.expense,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cats = context.read<CategoryProvider>();
    final settings = context.read<SettingsProvider>();
    final cat = cats.getById(expense.categoryId);
    final sym = settings.currencySymbol;

    return Dismissible(
      key: Key(expense.id),
      background: Container(
        decoration: BoxDecoration(color: Colors.green.shade400, borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.edit, color: Colors.white),
      ),
      secondaryBackground: Container(
        decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onEdit();
          return false;
        } else {
          return await _confirmDelete(context);
        }
      },
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cat != null ? Color(cat.colorValue).withOpacity(0.15) : Colors.grey.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(cat?.icon ?? '📦', style: const TextStyle(fontSize: 22))),
          ),
          title: Text(expense.title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            '${cat?.name ?? 'Unknown'} • ${_formatDate(expense.date)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: Text(
            '$sym ${expense.amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          onTap: onEdit,
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    if (d.day == now.day && d.month == now.month && d.year == now.year) return 'Today';
    if (d.day == now.day - 1 && d.month == now.month && d.year == now.year) return 'Yesterday';
    return '${d.day}/${d.month}/${d.year}';
  }
}

class CategoryChip extends StatelessWidget {
  final CategoryModel cat;
  final bool selected;
  final VoidCallback onTap;

  const CategoryChip({super.key, required this.cat, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: Text(cat.icon, style: const TextStyle(fontSize: 14)),
      label: Text(cat.name),
      selectedColor: Color(cat.colorValue).withOpacity(0.25),
      checkmarkColor: Color(cat.colorValue),
    );
  }
}

// ============================================================
// SECTION 7: HOME SCREEN
// ============================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategoryId = '';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expenses = context.watch<ExpenseProvider>();
    final categories = context.watch<CategoryProvider>();
    final settings = context.watch<SettingsProvider>();
    final sym = settings.currencySymbol;

    final filtered = expenses.filter(
      query: _searchQuery,
      categoryId: _selectedCategoryId,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            title: const Text(kAppName, style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => _openSearch(context),
              ),
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () => _openFilter(context),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primary.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: SummaryCard(
                          label: 'This Month',
                          amount: '$sym ${expenses.totalThisMonth.toStringAsFixed(0)}',
                          icon: Icons.calendar_month,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SummaryCard(
                          label: 'Today',
                          amount: '$sym ${expenses.totalToday.toStringAsFixed(0)}',
                          icon: Icons.today,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Search bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search expenses...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                      : null,
                ),
              ),
            ),
          ),

          // Category chips
          SliverToBoxAdapter(
            child: SizedBox(
              height: 50,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: const Text('All'),
                      selected: _selectedCategoryId.isEmpty,
                      onSelected: (_) => setState(() => _selectedCategoryId = ''),
                    ),
                  ),
                  ...categories.categories.map((cat) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: CategoryChip(
                      cat: cat,
                      selected: _selectedCategoryId == cat.id,
                      onTap: () => setState(() =>
                      _selectedCategoryId = _selectedCategoryId == cat.id ? '' : cat.id),
                    ),
                  )),
                ],
              ),
            ),
          ),

          // Transactions header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  Text(
                    filtered.isEmpty ? 'No transactions' : '${filtered.length} transactions',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          // Transactions list
          filtered.isEmpty
              ? SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('💸', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text('No expenses yet', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('Tap + to add your first expense',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          )
              : SliverList(
            delegate: SliverChildBuilderDelegate(
                  (_, i) => ExpenseTile(
                expense: filtered[i],
                onEdit: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddEditExpenseScreen(expense: filtered[i]),
                  ),
                ),
                onDelete: () => expenses.deleteExpense(filtered[i].id),
              ),
              childCount: filtered.length,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  void _openSearch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const SearchFilterSheet(),
    );
  }

  void _openFilter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const SearchFilterSheet(),
    );
  }
}

// ============================================================
// SECTION 8: ADD / EDIT EXPENSE SCREEN
// ============================================================

class AddEditExpenseScreen extends StatefulWidget {
  final ExpenseModel? expense;

  const AddEditExpenseScreen({super.key, this.expense});

  @override
  State<AddEditExpenseScreen> createState() => _AddEditExpenseScreenState();
}

class _AddEditExpenseScreenState extends State<AddEditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _notesCtrl;
  late DateTime _selectedDate;
  String _selectedCategoryId = '';

  bool get isEdit => widget.expense != null;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _amountCtrl = TextEditingController(text: e != null ? e.amount.toStringAsFixed(0) : '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _selectedDate = e?.date ?? DateTime.now();
    _selectedCategoryId = e?.categoryId ?? '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectedCategoryId.isEmpty) {
      final cats = context.read<CategoryProvider>().categories;
      if (cats.isNotEmpty) _selectedCategoryId = cats.first.id;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryProvider>().categories;
    final settings = context.read<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Expense' : 'Add Expense'),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title',
                prefixIcon: Icon(Icons.title),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => v == null || v.isEmpty ? 'Please enter a title' : null,
            ),
            const SizedBox(height: 16),

            // Amount
            TextFormField(
              controller: _amountCtrl,
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixIcon: const Icon(Icons.payments_outlined),
                prefixText: '${settings.currencySymbol} ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please enter an amount';
                if (double.tryParse(v) == null) return 'Invalid amount';
                if (double.parse(v) <= 0) return 'Amount must be greater than 0';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Category
            Text('Category', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((cat) {
                final selected = _selectedCategoryId == cat.id;
                return ChoiceChip(
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedCategoryId = cat.id),
                  avatar: Text(cat.icon, style: const TextStyle(fontSize: 14)),
                  label: Text(cat.name),
                  selectedColor: cat.color.withOpacity(0.25),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Date picker
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(_formatDate(_selectedDate)),
              ),
            ),
            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                prefixIcon: Icon(Icons.note_outlined),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),

            // Save button
            FilledButton.icon(
              onPressed: _save,
              icon: Icon(isEdit ? Icons.save : Icons.add),
              label: Text(isEdit ? 'Update Expense' : 'Save Expense'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    final ep = context.read<ExpenseProvider>();
    final expense = ExpenseModel(
      id: widget.expense?.id ?? const Uuid().v4(),
      title: _titleCtrl.text.trim(),
      amount: double.parse(_amountCtrl.text),
      categoryId: _selectedCategoryId,
      date: _selectedDate,
      notes: _notesCtrl.text.trim(),
    );

    if (isEdit) {
      ep.updateExpense(expense);
    } else {
      ep.addExpense(expense);
    }

    Navigator.pop(context);
  }

  void _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      context.read<ExpenseProvider>().deleteExpense(widget.expense!.id);
      Navigator.pop(context);
    }
  }

  String _formatDate(DateTime d) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

// ============================================================
// SECTION 9: SEARCH & FILTER BOTTOM SHEET
// ============================================================

class SearchFilterSheet extends StatefulWidget {
  const SearchFilterSheet({super.key});

  @override
  State<SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<SearchFilterSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _categoryId = '';
  String _dateFilter = 'all';
  DateTime? _customFrom;
  DateTime? _customTo;
  double? _minAmount;
  double? _maxAmount;
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryProvider>().categories;
    final expenses = context.watch<ExpenseProvider>();
    final settings = context.read<SettingsProvider>();

    DateTime? from;
    DateTime? to;
    final now = DateTime.now();
    switch (_dateFilter) {
      case 'today':
        from = DateTime(now.year, now.month, now.day);
        to = now;
        break;
      case 'week':
        from = now.subtract(const Duration(days: 7));
        to = now;
        break;
      case 'month':
        from = DateTime(now.year, now.month, 1);
        to = now;
        break;
      case 'custom':
        from = _customFrom;
        to = _customTo;
        break;
    }

    final results = expenses.filter(
      query: _query,
      categoryId: _categoryId,
      from: from,
      to: to,
      minAmount: _minAmount,
      maxAmount: _maxAmount,
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('Search & Filter', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(onPressed: _reset, child: const Text('Reset')),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Search
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Search by title or note...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 16),

                // Date filters
                Text('Date Range', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _dateChip('All', 'all'),
                    _dateChip('Today', 'today'),
                    _dateChip('This Week', 'week'),
                    _dateChip('This Month', 'month'),
                    _dateChip('Custom', 'custom'),
                  ],
                ),
                if (_dateFilter == 'custom') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(_customFrom != null ? _fmt(_customFrom!) : 'From'),
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _customFrom ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (d != null) setState(() => _customFrom = d);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(_customTo != null ? _fmt(_customTo!) : 'To'),
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _customTo ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (d != null) setState(() => _customTo = d);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),

                // Category filter
                Text('Category', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _categoryId.isEmpty,
                      onSelected: (_) => setState(() => _categoryId = ''),
                    ),
                    ...categories.map((c) => FilterChip(
                      avatar: Text(c.icon),
                      label: Text(c.name),
                      selected: _categoryId == c.id,
                      selectedColor: c.color.withOpacity(0.2),
                      onSelected: (_) => setState(() => _categoryId = _categoryId == c.id ? '' : c.id),
                    )),
                  ],
                ),
                const SizedBox(height: 16),

                // Amount range
                Text('Amount Range', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Min',
                          prefixText: '${settings.currencySymbol} ',
                        ),
                        onChanged: (v) => setState(() => _minAmount = double.tryParse(v)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _maxCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Max',
                          prefixText: '${settings.currencySymbol} ',
                        ),
                        onChanged: (v) => setState(() => _maxAmount = double.tryParse(v)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Results
                Text('${results.length} results', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                ...results.map((e) {
                  final cat = context.read<CategoryProvider>().getById(e.categoryId);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Text(cat?.icon ?? '📦', style: const TextStyle(fontSize: 24)),
                      title: Text(e.title),
                      subtitle: Text(_fmt(e.date)),
                      trailing: Text('${settings.currencySymbol} ${e.amount.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => AddEditExpenseScreen(expense: e)),
                        );
                      },
                    ),
                  );
                }),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateChip(String label, String value) {
    return FilterChip(
      label: Text(label),
      selected: _dateFilter == value,
      onSelected: (_) => setState(() => _dateFilter = value),
    );
  }

  void _reset() {
    _searchCtrl.clear();
    _minCtrl.clear();
    _maxCtrl.clear();
    setState(() {
      _query = '';
      _categoryId = '';
      _dateFilter = 'all';
      _customFrom = null;
      _customTo = null;
      _minAmount = null;
      _maxAmount = null;
    });
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

// ============================================================
// SECTION 10: STATS SCREEN
// ============================================================

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with SingleTickerProviderStateMixin {
  String _period = 'monthly';
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats & Analytics'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'Analytics'),
            Tab(text: 'Monthly Summary'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _AnalyticsTab(period: _period, onPeriodChange: (p) => setState(() => _period = p)),
          const _MonthlySummaryTab(),
        ],
      ),
    );
  }
}

class _AnalyticsTab extends StatelessWidget {
  final String period;
  final ValueChanged<String> onPeriodChange;

  const _AnalyticsTab({required this.period, required this.onPeriodChange});

  @override
  Widget build(BuildContext context) {
    final expenses = context.watch<ExpenseProvider>();
    final categories = context.watch<CategoryProvider>();
    final settings = context.read<SettingsProvider>();
    final sym = settings.currencySymbol;

    final now = DateTime.now();
    List<ExpenseModel> periodExpenses;
    if (period == 'weekly') {
      final from = now.subtract(const Duration(days: 7));
      periodExpenses = expenses.filter(from: from, to: now);
    } else if (period == 'yearly') {
      periodExpenses = expenses.filter(from: DateTime(now.year, 1, 1), to: now);
    } else {
      periodExpenses = expenses.thisMonthExpenses;
    }

    final catTotals = expenses.categoryTotals(periodExpenses);
    final totalSpent = periodExpenses.fold(0.0, (s, e) => s + e.amount);
    final avgDaily = periodExpenses.isEmpty
        ? 0.0
        : totalSpent / (period == 'weekly' ? 7 : period == 'monthly' ? 30 : 365);

    String topCatName = '—';
    if (catTotals.isNotEmpty) {
      final topId = catTotals.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      topCatName = categories.getById(topId)?.name ?? '—';
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Period selector
        Row(
          children: [
            _periodBtn(context, 'weekly', 'Weekly'),
            const SizedBox(width: 8),
            _periodBtn(context, 'monthly', 'Monthly'),
            const SizedBox(width: 8),
            _periodBtn(context, 'yearly', 'Yearly'),
          ],
        ),
        const SizedBox(height: 16),

        // Insights cards
        Row(
          children: [
            Expanded(
              child: _InsightCard(
                title: 'Top Category',
                value: topCatName,
                icon: Icons.category,
                color: Colors.purple,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _InsightCard(
                title: 'Daily Average',
                value: '$sym ${avgDaily.toStringAsFixed(0)}',
                icon: Icons.show_chart,
                color: Colors.teal,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _InsightCard(
                title: 'Transactions',
                value: '${periodExpenses.length}',
                icon: Icons.receipt_long,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Pie chart
        if (catTotals.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('By Category', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 220,
                    child: PieChart(
                      PieChartData(
                        sections: catTotals.entries.map((entry) {
                          final cat = categories.getById(entry.key);
                          final pct = totalSpent > 0 ? (entry.value / totalSpent * 100) : 0.0;
                          return PieChartSectionData(
                            value: entry.value,
                            title: '${pct.toStringAsFixed(0)}%',
                            color: cat != null ? Color(cat.colorValue) : Colors.grey,
                            radius: 80,
                            titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          );
                        }).toList(),
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: catTotals.entries.map((entry) {
                      final cat = categories.getById(entry.key);
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: cat != null ? Color(cat.colorValue) : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text('${cat?.name ?? '?'}: $sym ${entry.value.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 12)),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Bar chart
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  period == 'weekly' ? 'Last 7 Days' : 'Last 6 Months',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  child: _buildBarChart(context, expenses, period, sym),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _periodBtn(BuildContext context, String value, String label) {
    final selected = period == value;
    return Expanded(
      child: FilledButton.tonal(
        onPressed: () => onPeriodChange(value),
        style: FilledButton.styleFrom(
          backgroundColor: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          foregroundColor: selected ? Colors.white : null,
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buildBarChart(BuildContext context, ExpenseProvider ep, String p, String sym) {
    final data = p == 'weekly' ? ep.weeklyTotals() : ep.monthlyTotals();
    final maxY = data.reduce(max);
    final now = DateTime.now();
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    return BarChart(
      BarChartData(
        maxY: maxY == 0 ? 100 : maxY * 1.2,
        barGroups: data.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value,
                color: Theme.of(context).colorScheme.primary,
                width: 18,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                String label;
                if (p == 'weekly') {
                  final day = now.subtract(Duration(days: 6 - i));
                  label = weekDays[day.weekday - 1];
                } else {
                  final month = DateTime(now.year, now.month - (5 - i));
                  label = months[month.month - 1];
                }
                return Text(label, style: const TextStyle(fontSize: 10));
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (_, __, rod, ___) => BarTooltipItem(
              '$sym ${rod.toY.toStringAsFixed(0)}',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _InsightCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text(title, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _MonthlySummaryTab extends StatefulWidget {
  const _MonthlySummaryTab();

  @override
  State<_MonthlySummaryTab> createState() => _MonthlySummaryTabState();
}

class _MonthlySummaryTabState extends State<_MonthlySummaryTab> {
  DateTime _selectedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final expenses = context.watch<ExpenseProvider>();
    final categories = context.watch<CategoryProvider>();
    final settings = context.read<SettingsProvider>();
    final sym = settings.currencySymbol;

    final current = expenses.filter(
      from: DateTime(_selectedMonth.year, _selectedMonth.month, 1),
      to: DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0),
    );
    final prevMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    final previous = expenses.filter(
      from: DateTime(prevMonth.year, prevMonth.month, 1),
      to: DateTime(prevMonth.year, prevMonth.month + 1, 0),
    );

    final total = current.fold(0.0, (s, e) => s + e.amount);
    final prevTotal = previous.fold(0.0, (s, e) => s + e.amount);
    final diff = total - prevTotal;
    final catTotals = expenses.categoryTotals(current);

    String topCat = '—';
    if (catTotals.isNotEmpty) {
      final topId = catTotals.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      topCat = categories.getById(topId)?.name ?? '—';
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Month navigator
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () => setState(
                      () => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1)),
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              _monthName(_selectedMonth),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            IconButton(
              onPressed: _selectedMonth.month == DateTime.now().month &&
                  _selectedMonth.year == DateTime.now().year
                  ? null
                  : () => setState(
                      () => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Summary cards
        Row(
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text('Total Spent', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text('$sym ${total.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text('vs Last Month', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            diff > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                            color: diff > 0 ? Colors.red : Colors.green,
                            size: 16,
                          ),
                          Text(
                            '$sym ${diff.abs().toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: diff > 0 ? Colors.red : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.emoji_events, color: Colors.amber),
            title: const Text('Top Spending Category'),
            trailing: Text(topCat, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.receipt_long, color: Colors.blue),
            title: const Text('Total Transactions'),
            trailing: Text('${current.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),

        const SizedBox(height: 16),
        // Category breakdown
        if (catTotals.isNotEmpty) ...[
          Text('Category Breakdown',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...catTotals.entries.map((entry) {
            final cat = categories.getById(entry.key);
            final pct = total > 0 ? entry.value / total : 0.0;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Text(cat?.icon ?? '📦', style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(cat?.name ?? '?', style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('$sym ${entry.value.toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: pct,
                            backgroundColor: Colors.grey.withOpacity(0.2),
                            color: cat != null ? Color(cat.colorValue) : Colors.blue,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  String _monthName(DateTime d) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[d.month - 1]} ${d.year}';
  }
}

// ============================================================
// SECTION 11: BUDGET SCREEN
// ============================================================

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final budget = context.watch<BudgetProvider>().budget;
    final expenses = context.watch<ExpenseProvider>();
    final categories = context.watch<CategoryProvider>();
    final settings = context.read<SettingsProvider>();
    final sym = settings.currencySymbol;

    final monthSpent = expenses.totalThisMonth;
    final catTotals = expenses.categoryTotals(expenses.thisMonthExpenses);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _editMonthlyBudget(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Monthly overview
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Monthly Budget', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (budget.monthlyTotal <= 0)
                    OutlinedButton.icon(
                      onPressed: () => _editMonthlyBudget(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Set Monthly Budget'),
                    )
                  else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$sym ${monthSpent.toStringAsFixed(0)} spent',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('of $sym ${budget.monthlyTotal.toStringAsFixed(0)}',
                            style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _BudgetProgressBar(
                      spent: monthSpent,
                      total: budget.monthlyTotal,
                    ),
                    if (monthSpent >= budget.monthlyTotal * 0.8)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(
                              monthSpent >= budget.monthlyTotal ? Icons.cancel : Icons.warning_amber,
                              color: monthSpent >= budget.monthlyTotal ? Colors.red : Colors.orange,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              monthSpent >= budget.monthlyTotal
                                  ? '❌ Budget exceeded!'
                                  : '⚠️ 80% of budget used',
                              style: TextStyle(
                                color: monthSpent >= budget.monthlyTotal ? Colors.red : Colors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Category budgets
          Row(
            children: [
              Text('Category Budgets',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _addCategoryBudget(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (budget.categoryBudgets.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      const Text('🎯', style: TextStyle(fontSize: 36)),
                      const SizedBox(height: 8),
                      Text('No category budgets set', style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 4),
                      Text('Tap "Add" to set limits per category', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            )
          else
            ...budget.categoryBudgets.entries.map((entry) {
              final cat = categories.getById(entry.key);
              final spent = catTotals[entry.key] ?? 0;
              final pct = entry.value > 0 ? spent / entry.value : 0.0;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(cat?.icon ?? '📦', style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(cat?.name ?? '?', style: const TextStyle(fontWeight: FontWeight.w600)),
                                    Row(
                                      children: [
                                        Text('$sym ${spent.toStringAsFixed(0)} / $sym ${entry.value.toStringAsFixed(0)}',
                                            style: const TextStyle(fontSize: 12)),
                                        const SizedBox(width: 4),
                                        InkWell(
                                          onTap: () => _editCatBudget(context, entry.key, entry.value),
                                          child: const Icon(Icons.edit, size: 14, color: Colors.grey),
                                        ),
                                        const SizedBox(width: 4),
                                        InkWell(
                                          onTap: () => context.read<BudgetProvider>().removeCategoryBudget(entry.key),
                                          child: const Icon(Icons.close, size: 14, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                _BudgetProgressBar(spent: spent, total: entry.value),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (pct >= 0.8)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Icon(
                                pct >= 1 ? Icons.cancel : Icons.warning_amber,
                                color: pct >= 1 ? Colors.red : Colors.orange,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                pct >= 1
                                    ? 'You are overspending on ${cat?.name}!'
                                    : 'Almost at budget limit for ${cat?.name}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: pct >= 1 ? Colors.red : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  void _editMonthlyBudget(BuildContext context) {
    final ctrl = TextEditingController(
      text: context.read<BudgetProvider>().budget.monthlyTotal > 0
          ? context.read<BudgetProvider>().budget.monthlyTotal.toStringAsFixed(0)
          : '',
    );
    final sym = context.read<SettingsProvider>().currencySymbol;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Set Monthly Budget'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Amount', prefixText: '$sym '),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text);
              if (v != null && v > 0) {
                context.read<BudgetProvider>().setMonthlyBudget(v);
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _addCategoryBudget(BuildContext context) {
    final cats = context.read<CategoryProvider>().categories;
    final budget = context.read<BudgetProvider>().budget;
    final available = cats.where((c) => !budget.categoryBudgets.containsKey(c.id)).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All categories have budgets')));
      return;
    }
    String? selectedId = available.first.id;
    final ctrl = TextEditingController();
    final sym = context.read<SettingsProvider>().currencySymbol;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Category Budget'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedId,
                items: available
                    .map((c) => DropdownMenuItem(value: c.id, child: Text('${c.icon} ${c.name}')))
                    .toList(),
                onChanged: (v) => set(() => selectedId = v),
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Budget amount', prefixText: '$sym '),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final v = double.tryParse(ctrl.text);
                if (v != null && v > 0 && selectedId != null) {
                  context.read<BudgetProvider>().setCategoryBudget(selectedId!, v);
                }
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _editCatBudget(BuildContext context, String catId, double current) {
    final ctrl = TextEditingController(text: current.toStringAsFixed(0));
    final sym = context.read<SettingsProvider>().currencySymbol;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Category Budget'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Amount', prefixText: '$sym '),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text);
              if (v != null && v > 0) {
                context.read<BudgetProvider>().setCategoryBudget(catId, v);
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _BudgetProgressBar extends StatelessWidget {
  final double spent;
  final double total;

  const _BudgetProgressBar({required this.spent, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (spent / total).clamp(0.0, 1.0) : 0.0;
    Color color;
    if (pct >= 1.0) {
      color = Colors.red;
    } else if (pct >= 0.8) {
      color = Colors.orange;
    } else {
      color = Colors.green;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: pct,
        minHeight: 10,
        backgroundColor: Colors.grey.withOpacity(0.2),
        color: color,
      ),
    );
  }
}

// ============================================================
// SECTION 12: CATEGORY MANAGEMENT SCREEN
// ============================================================

class CategoryManagementScreen extends StatelessWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryProvider>().categories;

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: categories.length,
        itemBuilder: (_, i) {
          final cat = categories[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cat.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text(cat.icon, style: const TextStyle(fontSize: 22))),
              ),
              title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: cat.isDefault ? const Text('Default category') : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editCategory(context, cat),
                  ),
                  if (!cat.isDefault)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteCategory(context, cat),
                    ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addCategory(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _addCategory(BuildContext context) => _showCategoryDialog(context, null);
  void _editCategory(BuildContext context, CategoryModel cat) => _showCategoryDialog(context, cat);

  void _showCategoryDialog(BuildContext context, CategoryModel? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final icons = ['🍔', '🚗', '🛍️', '💡', '💊', '🎬', '📚', '📦', '✈️', '🏠', '🎮', '💼', '🐾', '⚽', '🎵', '🍕'];
    final colors = [
      0xFFE53935, 0xFF1E88E5, 0xFF8E24AA, 0xFFFB8C00,
      0xFF00ACC1, 0xFF43A047, 0xFF6D4C41, 0xFF757575,
      0xFFE91E63, 0xFF009688, 0xFFFF5722, 0xFF3F51B5,
    ];
    String selectedIcon = existing?.icon ?? icons[0];
    int selectedColor = existing?.colorValue ?? colors[0];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(existing != null ? 'Edit Category' : 'New Category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Category Name'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                const Text('Icon', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: icons.map((ic) {
                    final sel = selectedIcon == ic;
                    return GestureDetector(
                      onTap: () => set(() => selectedIcon = ic),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: sel ? Theme.of(context).colorScheme.primaryContainer : null,
                          border: sel ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(ic, style: const TextStyle(fontSize: 20)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                const Text('Color', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: colors.map((c) {
                    final sel = selectedColor == c;
                    return GestureDetector(
                      onTap: () => set(() => selectedColor = c),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: sel ? Border.all(color: Colors.black, width: 2) : null,
                        ),
                        child: sel ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                final cat = CategoryModel(
                  id: existing?.id ?? const Uuid().v4(),
                  name: nameCtrl.text.trim(),
                  icon: selectedIcon,
                  colorValue: selectedColor,
                  isDefault: existing?.isDefault ?? false,
                );
                if (existing != null) {
                  context.read<CategoryProvider>().updateCategory(cat);
                } else {
                  context.read<CategoryProvider>().addCategory(cat);
                }
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteCategory(BuildContext context, CategoryModel cat) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Delete "${cat.name}"? Expenses in this category will remain.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              context.read<CategoryProvider>().deleteCategory(cat.id);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SECTION 13: SETTINGS SCREEN
// ============================================================

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Appearance
          _sectionHeader(context, 'Appearance'),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('Dark Mode'),
            subtitle: Text(settings.isDark ? 'Dark theme active' : 'Light theme active'),
            value: settings.isDark,
            onChanged: (_) => settings.toggleTheme(),
          ),

          // Currency
          _sectionHeader(context, 'Currency'),
          ...kCurrencies.map((c) => RadioListTile<String>(
            secondary: Text(kCurrencySymbols[c] ?? c,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            title: Text(c),
            subtitle: Text(c == 'BDT' ? 'Bangladeshi Taka' : 'US Dollar'),
            value: c,
            groupValue: settings.currency,
            onChanged: (v) => settings.setCurrency(v!),
          )),

          // Data
          _sectionHeader(context, 'Data Management'),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Manage Categories'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryManagementScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Export Data'),
            subtitle: const Text('Save as JSON backup'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _exportData(context),
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Import Data'),
            subtitle: const Text('Restore from JSON backup'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _importData(context),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Clear All Data', style: TextStyle(color: Colors.red)),
            subtitle: const Text('Permanently delete all expenses'),
            onTap: () => _clearData(context),
          ),

          // About
          _sectionHeader(context, 'About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('App Version'),
            trailing: const Text('1.0.0', style: TextStyle(color: Colors.grey)),
          ),
          ListTile(
            leading: const Icon(Icons.favorite_outline, color: Colors.red),
            title: const Text('Made with Flutter'),
            subtitle: const Text('EzzeExpense © 2024'),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    try {
      final ep = context.read<ExpenseProvider>();
      final jsonStr = ep.exportJson();
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/ezze_backup_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonStr);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'EzzeExpense Backup',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _importData(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Import Data'),
        content: const Text('This will replace ALL current data. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    try {
      // Simple text input for JSON import
      final ctrl = TextEditingController();
      final result = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Paste JSON Backup'),
          content: TextField(
            controller: ctrl,
            maxLines: 6,
            decoration: const InputDecoration(hintText: 'Paste your JSON backup here...'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Import')),
          ],
        ),
      );
      if (result != null && result.isNotEmpty && context.mounted) {
        context.read<ExpenseProvider>().importJson(result);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data imported successfully!')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }

  Future<void> _clearData(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text('⚠️ This will permanently delete ALL expenses. This cannot be undone!'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      context.read<ExpenseProvider>().clearAll();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All data cleared.')));
    }
  }
}