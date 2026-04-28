// ============================================================
//  screens/add_edit/add_edit_screen.dart — Dark Vault edition
//  Purpose: Handles both creation and modification of expenses
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/expense_model.dart';
import '../../models/category_model.dart';

class AddEditExpenseScreen extends StatefulWidget {
  final ExpenseModel? expense;

  const AddEditExpenseScreen({super.key, this.expense});

  @override
  State<AddEditExpenseScreen> createState() => _AddEditExpenseScreenState();
}

class _AddEditExpenseScreenState extends State<AddEditExpenseScreen> {
  // ── State Management Variables ──────────────────────────────
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _loanPersonCtrl;

  late DateTime _selectedDate;
  String _selectedCategoryId  = '';
  String _selectedSubCategory = '';

  // ── Helpers & Getters ────────────────────────────────────────
  bool get isEdit => widget.expense != null;

  /// Retrieves the name of the currently selected category
  String _getCategoryName(List<CategoryModel> cats) {
    try {
      return cats.firstWhere((c) => c.id == _selectedCategoryId).name;
    } catch (_) {
      return '';
    }
  }

  // ── Lifecycle Methods ───────────────────────────────────────
  @override
  void initState() {
    super.initState();
    final e = widget.expense;

    // Initialize controllers with existing data if editing
    _titleCtrl      = TextEditingController(text: e?.title ?? '');
    _amountCtrl     = TextEditingController(
        text: e != null ? e.amount.toStringAsFixed(0) : '');
    _notesCtrl      = TextEditingController(text: e?.notes ?? '');
    _loanPersonCtrl = TextEditingController(text: e?.subCategory ?? '');

    _selectedDate        = e?.date ?? DateTime.now();
    _selectedCategoryId  = e?.categoryId ?? '';
    _selectedSubCategory = e?.subCategory ?? '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Default to the first available category if none selected
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
    _loanPersonCtrl.dispose();
    super.dispose();
  }

  // ── Build Method ────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final t          = EzzeTheme.of(context);
    final categories = context.watch<CategoryProvider>().categories;
    final settings   = context.read<SettingsProvider>();

    // Logic for conditional fields
    final catName = _getCategoryName(categories);
    final isBills = catName == kCatBills;
    final isOther = catName == kCatOther;
    final isLoan  = catName == kCatFriendlyLoan;

    return Scaffold(
      backgroundColor: t.bgBase,
      appBar: _buildAppBar(context, t),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Section: Basic Info
            _label(context, '📝  Title'),
            const SizedBox(height: 8),
            _buildTitleField(t),
            const SizedBox(height: 18),

            _label(context, '💵  Amount'),
            const SizedBox(height: 8),
            _buildAmountField(t, settings),
            const SizedBox(height: 18),

            // Section: Classification
            _label(context, '🏷️  Category'),
            const SizedBox(height: 10),
            _buildCategorySelector(categories, t),
            const SizedBox(height: 18),

            // Section: Conditional Sub-Categories
            if (isBills) ...[
              _label(context, '⚡  Bill Type'),
              const SizedBox(height: 8),
              _buildBillsDropdown(context),
              const SizedBox(height: 18),
            ],

            if (isOther) ...[
              _label(context, '📂  Sub-Category'),
              const SizedBox(height: 8),
              _buildOtherDropdown(context),
              const SizedBox(height: 18),
            ],

            if (isLoan) ...[
              _label(context, '🤝  Person Name'),
              const SizedBox(height: 8),
              _buildLoanField(t),
              const SizedBox(height: 18),
            ],

            // Section: Meta Info
            _label(context, '📅  Date'),
            const SizedBox(height: 8),
            _buildDatePicker(t),
            const SizedBox(height: 18),

            _label(context, '📌  Notes (optional)'),
            const SizedBox(height: 8),
            _buildNotesField(t),

            const SizedBox(height: 32),

            // Section: Actions
            _buildSaveButton(t),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── UI Components (Widgets) ─────────────────────────────────

  /// Main App Bar with Delete functionality for Edit mode
  PreferredSizeWidget _buildAppBar(BuildContext context, EzzeTheme t) {
    return AppBar(
      backgroundColor: t.bgBase,
      title: Text(isEdit ? '✏️  Edit Expense' : '➕  New Expense',
          style: TextStyle(
              color: t.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Icon(Icons.arrow_back_ios_new_rounded, color: t.textSecond, size: 18),
      ),
      actions: [
        if (isEdit)
          GestureDetector(
            onTap: _delete,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kDanger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: kDanger.withOpacity(0.3)),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: kDanger, size: 18),
            ),
          ),
      ],
    );
  }

  Widget _buildTitleField(EzzeTheme t) {
    return TextFormField(
      controller: _titleCtrl,
      style: TextStyle(color: t.textPrimary),
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        hintText: 'e.g. Lunch at Dhaba',
        prefixIcon: Icon(Icons.title_rounded, size: 20),
      ),
      validator: (v) => v == null || v.isEmpty ? 'Please enter a title' : null,
    );
  }

  Widget _buildAmountField(EzzeTheme t, SettingsProvider settings) {
    return TextFormField(
      controller: _amountCtrl,
      style: const TextStyle(color: kAccent, fontSize: 18, fontWeight: FontWeight.w700),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
      decoration: InputDecoration(
        hintText: '0',
        prefixText: '${settings.currencySymbol}  ',
        prefixStyle: const TextStyle(color: kAccent, fontSize: 16, fontWeight: FontWeight.w600),
        prefixIcon: const Icon(Icons.payments_outlined, size: 20),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Please enter an amount';
        final val = double.tryParse(v);
        if (val == null) return 'Invalid amount';
        if (val <= 0) return 'Must be greater than 0';
        return null;
      },
    );
  }

  Widget _buildCategorySelector(List<CategoryModel> categories, EzzeTheme t) {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: categories.map((cat) {
        final selected = _selectedCategoryId == cat.id;
        final color    = Color(cat.colorValue);
        return GestureDetector(
          onTap: () => setState(() {
            _selectedCategoryId  = cat.id;
            _selectedSubCategory = '';
            _loanPersonCtrl.clear();
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? color.withOpacity(0.15) : t.bgCardAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? color.withOpacity(0.6) : t.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(cat.icon, style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 6),
              Text(cat.name,
                  style: TextStyle(
                    color: selected ? color : t.textSecond,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  )),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDatePicker(EzzeTheme t) {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: t.bgInput,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.border),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_rounded, color: t.textSecond, size: 18),
          const SizedBox(width: 12),
          Text(_formatDate(_selectedDate), style: TextStyle(color: t.textPrimary, fontSize: 14)),
          const Spacer(),
          Icon(Icons.chevron_right_rounded, color: t.textHint, size: 18),
        ]),
      ),
    );
  }

  Widget _buildNotesField(EzzeTheme t) {
    return TextFormField(
      controller: _notesCtrl,
      style: TextStyle(color: t.textPrimary),
      textCapitalization: TextCapitalization.sentences,
      maxLines: 3,
      decoration: const InputDecoration(
        hintText: 'Add a note...',
        prefixIcon: Icon(Icons.notes_rounded, size: 20),
        alignLabelWithHint: true,
      ),
    );
  }

  Widget _buildSaveButton(EzzeTheme t) {
    return GestureDetector(
      onTap: _save,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: kAccentGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: kAccent.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isEdit ? Icons.save_rounded : Icons.add_rounded, color: t.bgDeep, size: 20),
              const SizedBox(width: 8),
              Text(
                isEdit ? 'Update Expense' : '💾  Save Expense',
                style: TextStyle(color: t.bgDeep, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Logic Handlers ──────────────────────────────────────────

  /// Handles the saving/updating logic
  void _save() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️  Please select a category')));
      return;
    }

    final cats    = context.read<CategoryProvider>().categories;
    final catName = _getCategoryName(cats);

    // Determine the subcategory value based on category type
    final subCat = catName == kCatFriendlyLoan
        ? _loanPersonCtrl.text.trim() : _selectedSubCategory;

    final ep = context.read<ExpenseProvider>();
    final expense = ExpenseModel(
      id:          widget.expense?.id ?? const Uuid().v4(),
      title:       _titleCtrl.text.trim(),
      amount:      double.parse(_amountCtrl.text),
      categoryId:  _selectedCategoryId,
      date:        _selectedDate,
      notes:       _notesCtrl.text.trim(),
      subCategory: subCat,
    );

    if (isEdit) ep.updateExpense(expense);
    else        ep.addExpense(expense);

    Navigator.pop(context);
  }

  /// Shows confirmation and handles deletion
  void _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final t = EzzeTheme.of(ctx);
        return AlertDialog(
          backgroundColor: t.bgCard,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: t.border)),
          title: const Text('Delete Expense', style: TextStyle(fontSize: 17)),
          content: const Text('This action cannot be undone.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel', style: TextStyle(color: t.textSecond))),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: kDanger),
                child: const Text('Delete')),
          ],
        );
      },
    );

    if (confirm == true && mounted) {
      context.read<ExpenseProvider>().deleteExpense(widget.expense!.id);
      Navigator.pop(context);
    }
  }

  // ── Reusable Sub-Widgets ────────────────────────────────────

  Widget _label(BuildContext context, String text) {
    final t = EzzeTheme.of(context);
    return Text(text,
        style: TextStyle(
          color: t.textSecond,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ));
  }

  Widget _buildBillsDropdown(BuildContext context) {
    return _styledDropdown(context,
      value: kBillsSubCategories.contains(_selectedSubCategory)
          ? _selectedSubCategory : kBillsSubCategories.first,
      items: kBillsSubCategories,
      icon:  Icons.receipt_outlined,
      hint:  'Select bill type',
      onChanged: (v) => setState(() => _selectedSubCategory = v ?? ''),
    );
  }

  Widget _buildOtherDropdown(BuildContext context) {
    return _styledDropdown(context,
      value: kOtherSubCategories.contains(_selectedSubCategory)
          ? _selectedSubCategory : kOtherSubCategories.first,
      items: kOtherSubCategories,
      icon:  Icons.folder_outlined,
      hint:  'Select sub-category',
      onChanged: (v) => setState(() => _selectedSubCategory = v ?? ''),
    );
  }

  Widget _buildLoanField(EzzeTheme t) {
    return TextFormField(
      controller: _loanPersonCtrl,
      style: TextStyle(color: t.textPrimary),
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(
        hintText: 'Who did you lend to?',
        prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
      ),
    );
  }

  Widget _styledDropdown(BuildContext context, {
    required String value,
    required List<String> items,
    required IconData icon,
    required String hint,
    required ValueChanged<String?> onChanged,
  }) {
    final t = EzzeTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: t.bgInput,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: t.bgCard,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: t.textSecond),
          style: TextStyle(color: t.textPrimary, fontSize: 14),
          items: items.map((s) => DropdownMenuItem(
            value: s,
            child: Row(children: [
              Icon(icon, color: t.textSecond, size: 16),
              const SizedBox(width: 10),
              Text(s),
            ]),
          )).toList(),
          onChanged: onChanged,
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
      builder: (ctx, child) {
        final t = EzzeTheme.of(ctx);
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.dark(
              primary: kAccent,
              onPrimary: t.bgDeep,
              surface: t.bgCard,
              onSurface: t.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  String _formatDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}