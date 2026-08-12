import 'package:flutter/material.dart';
import 'package:business_managment_app/services/app_data_store.dart';
import 'package:business_managment_app/core/premium_theme.dart';

class InvoicePage extends StatefulWidget {
  const InvoicePage({super.key});

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  final AppDataStore _store = AppDataStore();
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreUpdate);
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreUpdate);
    super.dispose();
  }

  void _onStoreUpdate() {
    if (mounted) setState(() {});
  }

  List<InvoiceModel> get _filteredInvoices {
    switch (_selectedFilter) {
      case 'Paid':
        return _store.invoices.where((inv) => inv.status == 'Paid').toList();
      case 'Pending':
        return _store.invoices.where((inv) => inv.status == 'Pending').toList();
      case 'Overdue':
        return _store.invoices.where((inv) => inv.status == 'Overdue').toList();
      default:
        return _store.invoices.toList();
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Paid':
        return kPremiumSuccess;
      case 'Overdue':
        return kPremiumDanger;
      default:
        return kPremiumWarning;
    }
  }

  void _showCreateInvoiceDialog() {
    final numCtrl = TextEditingController(
        text: 'INV-2026-00${_store.invoices.length + 1}');
    final amountCtrl = TextEditingController();
    String selectedClientName =
        _store.clients.isNotEmpty ? _store.clients.first.name : 'General Client';
    String selectedStatus = 'Pending';
    DateTime? selectedDueDate;
    String dueDateDisplay = 'Tap to pick a date';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF121C31), Color(0xFF0B1220)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: kPremiumBorder),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: kPremiumGold.withOpacity(0.16),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.receipt_long_outlined,
                                color: kPremiumGold),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Create Invoice',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800)),
                                SizedBox(height: 4),
                                Text(
                                    'Add a polished invoice for the selected client account.',
                                    style: TextStyle(
                                        color: kPremiumMuted, fontSize: 12.5)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: numCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Invoice Number',
                          prefixIcon: Icon(Icons.receipt_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: selectedClientName,
                        decoration: const InputDecoration(
                          labelText: 'Client Account',
                          prefixIcon: Icon(Icons.business_outlined),
                        ),
                        items: (_store.clients.isNotEmpty
                                ? _store.clients.map((c) => c.name).toList()
                                : ['General Client'])
                            .map((name) {
                          return DropdownMenuItem(
                              value: name, child: Text(name));
                        }).toList(),
                        onChanged: (val) =>
                            setModalState(() => selectedClientName = val!),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Amount (₹)',
                          prefixIcon: Icon(Icons.currency_rupee),
                        ),
                      ),
                      const SizedBox(height: 14),
                      StatefulBuilder(
                        builder: (ctx, setPickerState) {
                          return GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: DateTime.now().add(const Duration(days: 30)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setPickerState(() {
                                  selectedDueDate = picked;
                                  dueDateDisplay =
                                      '${picked.day.toString().padLeft(2, '0')} ${_monthName(picked.month)} ${picked.year}';
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 16),
                              decoration: BoxDecoration(
                                border: Border.all(color: kPremiumBorder),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.event_available_outlined,
                                      color: kPremiumMuted, size: 20),
                                  const SizedBox(width: 12),
                                  Text(
                                    dueDateDisplay,
                                    style: TextStyle(
                                      color: selectedDueDate != null
                                          ? kPremiumText
                                          : kPremiumMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Payment Status',
                          prefixIcon: Icon(Icons.payment_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'Pending', child: Text('Pending')),
                          DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                          DropdownMenuItem(
                              value: 'Overdue', child: Text('Overdue')),
                        ],
                        onChanged: (val) =>
                            setModalState(() => selectedStatus = val!),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel')),
                          const SizedBox(width: 8),
                          GoldButton(
                            label: 'Generate Invoice',
                            icon: Icons.check_circle_outline,
                            onPressed: () {
                              final amt =
                                  double.tryParse(amountCtrl.text.trim()) ??
                                      1000.0;
                              final today = DateTime.now();
                              final issueDateStr =
                                  '${today.day} ${_monthName(today.month)} ${today.year}';
                              final dueDateStr = selectedDueDate != null
                                  ? '${selectedDueDate!.year}-${selectedDueDate!.month.toString().padLeft(2, '0')}-${selectedDueDate!.day.toString().padLeft(2, '0')}'
                                  : DateTime.now().add(const Duration(days: 30)).toIso8601String().substring(0, 10);
                              final newInv = InvoiceModel(
                                id: DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString(),
                                invoiceNumber: numCtrl.text.trim(),
                                clientName: selectedClientName,
                                amount: amt,
                                status: selectedStatus,
                                issueDate: issueDateStr,
                                dueDate: dueDateStr,
                              );
                              _store.addInvoice(newInv);
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _monthName(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month];
  }

  Widget _summaryCard(
      {required String title,
      required String value,
      required IconData icon,
      required Color color,
      bool expand = false}) {
    final card = GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: kPremiumMuted, fontSize: 12.5)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );

    return expand ? Expanded(child: card) : card;
  }

  @override
  Widget build(BuildContext context) {
    final invoices = _store.invoices;
    final totalValue =
        invoices.fold<double>(0.0, (sum, inv) => sum + inv.amount);
    final paidValue = invoices
        .where((inv) => inv.status == 'Paid')
        .fold<double>(0.0, (sum, inv) => sum + inv.amount);
    final outstandingValue = invoices
        .where((inv) => inv.status != 'Paid')
        .fold<double>(0.0, (sum, inv) => sum + inv.amount);
    final overdueCount =
        invoices.where((inv) => inv.status == 'Overdue').length;

    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Invoices & Billing',
              style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumGold)),
          backgroundColor: kPremiumBg,
          foregroundColor: kPremiumGold,
          elevation: 0,
        ),
        body: SafeArea(
          bottom: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double width = constraints.maxWidth;
              final bool isDesktop = width >= 900;
              final bool isTablet = width >= 600 && width < 900;
              final double hPad = isDesktop ? 36 : isTablet ? 24 : 16;

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const HeroBanner(
                          title: 'Billing Command Center',
                          subtitle:
                              'Create polished invoices, track payment progress, and keep client accounts healthy.',
                          badge: 'Invoice & Billing',
                        ),
                        const SizedBox(height: 20),
                        LayoutBuilder(
                          builder: (context, metricsConstraints) {
                            final compact =
                                metricsConstraints.maxWidth < 720;
                            if (compact) {
                              return Column(
                                children: [
                                  _summaryCard(
                                      title: 'Total Value',
                                      value:
                                          '₹${totalValue.toStringAsFixed(2)}',
                                      icon: Icons.receipt_long,
                                      color: kPremiumGold,
                                      expand: false),
                                  const SizedBox(height: 12),
                                  _summaryCard(
                                      title: 'Collected',
                                      value:
                                          '₹${paidValue.toStringAsFixed(2)}',
                                      icon: Icons.check_circle_outline,
                                      color: kPremiumSuccess,
                                      expand: false),
                                  const SizedBox(height: 12),
                                  _summaryCard(
                                      title: 'Outstanding',
                                      value:
                                          '₹${outstandingValue.toStringAsFixed(2)}',
                                      icon: Icons.pending_actions_outlined,
                                      color: kPremiumWarning,
                                      expand: false),
                                  const SizedBox(height: 12),
                                  _summaryCard(
                                      title: 'Overdue',
                                      value: '$overdueCount invoices',
                                      icon: Icons.warning_amber_rounded,
                                      color: kPremiumDanger,
                                      expand: false),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                _summaryCard(
                                    title: 'Total Value',
                                    value:
                                        '₹${totalValue.toStringAsFixed(2)}',
                                    icon: Icons.receipt_long,
                                    color: kPremiumGold,
                                    expand: true),
                                const SizedBox(width: 12),
                                _summaryCard(
                                    title: 'Collected',
                                    value:
                                        '₹${paidValue.toStringAsFixed(2)}',
                                    icon: Icons.check_circle_outline,
                                    color: kPremiumSuccess,
                                    expand: true),
                                const SizedBox(width: 12),
                                _summaryCard(
                                    title: 'Outstanding',
                                    value:
                                        '₹${outstandingValue.toStringAsFixed(2)}',
                                    icon: Icons.pending_actions_outlined,
                                    color: kPremiumWarning,
                                    expand: true),
                                const SizedBox(width: 12),
                                _summaryCard(
                                    title: 'Overdue',
                                    value: '$overdueCount invoices',
                                    icon: Icons.warning_amber_rounded,
                                    color: kPremiumDanger,
                                    expand: true),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        GlassCard(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Client Invoices Overview',
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w800)),
                                        SizedBox(height: 4),
                                        Text(
                                            'Review invoices by payment state and stay on top of collections.',
                                            style: TextStyle(
                                                color: kPremiumMuted,
                                                fontSize: 12.5)),
                                      ],
                                    ),
                                  ),
                                  GoldButton(
                                      label: 'Create Invoice',
                                      icon: Icons.add,
                                      onPressed: _showCreateInvoiceDialog),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: ['All', 'Pending', 'Paid', 'Overdue']
                                    .map((filter) {
                                  final selected = _selectedFilter == filter;
                                  return ChoiceChip(
                                    label: Text(filter),
                                    selected: selected,
                                    onSelected: (_) => setState(
                                        () => _selectedFilter = filter),
                                    selectedColor:
                                        kPremiumGold.withOpacity(0.18),
                                    backgroundColor:
                                        Colors.white.withOpacity(0.05),
                                    side: BorderSide(
                                        color: selected
                                            ? kPremiumGold
                                            : kPremiumBorder),
                                    labelStyle: TextStyle(
                                        color: selected
                                            ? kPremiumGold
                                            : kPremiumText,
                                        fontWeight: FontWeight.w700),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (invoices.isEmpty)
                          GlassCard(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              children: [
                                const Icon(Icons.receipt_long_outlined,
                                    size: 60, color: kPremiumGold),
                                const SizedBox(height: 12),
                                const Text('No invoices recorded yet.',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                const Text(
                                    'Create your first invoice and keep billing moving smoothly.',
                                    style: TextStyle(
                                        color: kPremiumMuted,
                                        fontSize: 13.5)),
                                const SizedBox(height: 18),
                                GoldButton(
                                    label: 'Create First Invoice',
                                    icon: Icons.add,
                                    onPressed: _showCreateInvoiceDialog),
                              ],
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _filteredInvoices.length,
                            itemBuilder: (context, index) {
                              final inv = _filteredInvoices[index];
                              final statusColor = _statusColor(inv.status);

                              final bool isTileCompact = width < 520;
                              return GlassCard(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                child: isTileCompact
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: kPremiumGold
                                                      .withOpacity(0.14),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          14),
                                                ),
                                                child: const Icon(
                                                    Icons.receipt_long,
                                                    color: kPremiumGold,
                                                    size: 18),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  inv.invoiceNumber,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 15),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: statusColor
                                                      .withOpacity(0.16),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          999),
                                                ),
                                                child: Text(
                                                  inv.status,
                                                  style: TextStyle(
                                                      color: statusColor,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 11),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Text(inv.clientName,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14)),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Due: ${inv.dueDate}',
                                                  style: const TextStyle(
                                                      fontSize: 12.5,
                                                      color: kPremiumMuted)),
                                              Text(
                                                  '₹${inv.amount.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 16,
                                                      color: kPremiumText)),
                                            ],
                                          ),
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color:
                                                  kPremiumGold.withOpacity(0.14),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: const Icon(Icons.receipt_long,
                                                color: kPremiumGold),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                    '${inv.invoiceNumber} • ${inv.clientName}',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        fontSize: 15)),
                                                const SizedBox(height: 3),
                                                Text(
                                                    'Due: ${inv.dueDate} • Issued: ${inv.issueDate}',
                                                    style: const TextStyle(
                                                        fontSize: 12.5,
                                                        color: kPremiumMuted)),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                  '₹${inv.amount.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 16)),
                                              const SizedBox(height: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 10, vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: statusColor
                                                      .withOpacity(0.16),
                                                  borderRadius:
                                                      BorderRadius.circular(999),
                                                ),
                                                child: Text(
                                                  inv.status,
                                                  style: TextStyle(
                                                      color: statusColor,
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 11),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
