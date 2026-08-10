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
  late List<InvoiceModel> _invoices;

  @override
  void initState() {
    super.initState();
    _invoices = List.from(_store.invoices);
  }

  void _showCreateInvoiceDialog() {
    final numCtrl = TextEditingController(text: 'INV-2026-00${_invoices.length + 1}');
    final amountCtrl = TextEditingController();
    final dueDateCtrl = TextEditingController();
    String selectedClientName = _store.clients.isNotEmpty ? _store.clients.first.name : 'General Client';
    String selectedStatus = 'Pending';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Create New Client Invoice', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: numCtrl,
                      decoration: InputDecoration(
                        labelText: 'Invoice Number',
                        prefixIcon: const Icon(Icons.receipt),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: selectedClientName,
                      decoration: InputDecoration(
                        labelText: 'Client Account',
                        prefixIcon: const Icon(Icons.business),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: (_store.clients.isNotEmpty ? _store.clients.map((c) => c.name).toList() : ['General Client']).map((name) {
                        return DropdownMenuItem(value: name, child: Text(name));
                      }).toList(),
                      onChanged: (val) => setModalState(() => selectedClientName = val!),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount (\$)',
                        prefixIcon: const Icon(Icons.attach_money),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: dueDateCtrl,
                      decoration: InputDecoration(
                        labelText: 'Due Date (e.g. 20 Dec)',
                        prefixIcon: const Icon(Icons.event),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: InputDecoration(
                        labelText: 'Payment Status',
                        prefixIcon: const Icon(Icons.payment),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                        DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                        DropdownMenuItem(value: 'Overdue', child: Text('Overdue')),
                      ],
                      onChanged: (val) => setModalState(() => selectedStatus = val!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final amt = double.tryParse(amountCtrl.text.trim()) ?? 1000.0;
                    final newInv = InvoiceModel(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      invoiceNumber: numCtrl.text.trim(),
                      clientName: selectedClientName,
                      amount: amt,
                      status: selectedStatus,
                      issueDate: 'Today',
                      dueDate: dueDateCtrl.text.trim().isNotEmpty ? dueDateCtrl.text.trim() : 'Next Month',
                    );
                    setState(() {
                      _invoices.insert(0, newInv);
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Generate Invoice'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sampleInvoices = _invoices;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isDesktop = width >= 900;
        final bool isTablet = width >= 600 && width < 900;
        final double hPad = isDesktop ? 36 : isTablet ? 24 : 16;

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Invoices & Billing', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const HeroBanner(
                      title: 'Client Invoices & Billing',
                      subtitle: 'Generate client statements, issue new invoices, and track payment statuses',
                      badge: 'Billing Operations',
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Client Invoices Overview',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GoldButton(
                          label: 'Create Invoice',
                          icon: Icons.add,
                          onPressed: _showCreateInvoiceDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    sampleInvoices.isEmpty
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(40),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.receipt_long_outlined, size: 60, color: Colors.grey),
                                const SizedBox(height: 12),
                                const Text('No invoices recorded yet.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _showCreateInvoiceDialog,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Create First Invoice'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: sampleInvoices.length,
                      itemBuilder: (context, index) {
                        final inv = sampleInvoices[index];
                        final statusColor = inv.status == 'Paid'
                            ? Colors.green
                            : (inv.status == 'Pending' ? Colors.orange : Colors.red);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: LayoutBuilder(
                              builder: (context, tileBox) {
                                if (tileBox.maxWidth < 450) {
                                  // Compact layout for narrow mobile screens
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const CircleAvatar(
                                            radius: 18,
                                            backgroundColor: Color(0xFFEDE7F6),
                                            child: Icon(Icons.receipt_long, color: Colors.purple, size: 18),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              inv.invoiceNumber,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                            ),
                                          ),
                                          Chip(
                                            label: Text(inv.status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                                            backgroundColor: statusColor.withOpacity(0.12),
                                            padding: EdgeInsets.zero,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(inv.clientName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Due: ${inv.dueDate}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          Text('\$${inv.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.purple)),
                                        ],
                                      ),
                                    ],
                                  );
                                }

                                // Wide layout for tablet & desktop
                                return Row(
                                  children: [
                                    const CircleAvatar(
                                      backgroundColor: Color(0xFFEDE7F6),
                                      child: Icon(Icons.receipt_long, color: Colors.purple),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('${inv.invoiceNumber} • ${inv.clientName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                          const SizedBox(height: 2),
                                          Text('Due: ${inv.dueDate} • Issued: ${inv.issueDate}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('\$${inv.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        const SizedBox(height: 4),
                                        Chip(
                                          label: Text(inv.status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                                          backgroundColor: statusColor.withOpacity(0.12),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
