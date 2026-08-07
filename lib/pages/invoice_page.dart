import 'package:flutter/material.dart';
import '../services/app_data_store.dart';

class InvoicePage extends StatelessWidget {
  const InvoicePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppDataStore();
    final sampleInvoices = store.invoices.isNotEmpty
        ? store.invoices
        : [
            InvoiceModel(id: 'inv1', invoiceNumber: 'INV-2026-001', clientName: 'Tesla Motors', amount: 15000, status: 'Paid', issueDate: '01 Aug', dueDate: '15 Aug'),
            InvoiceModel(id: 'inv2', invoiceNumber: 'INV-2026-002', clientName: 'Apple Inc.', amount: 28000, status: 'Pending', issueDate: '03 Aug', dueDate: '18 Aug'),
            InvoiceModel(id: 'inv3', invoiceNumber: 'INV-2026-003', clientName: 'Amazon Web', amount: 9500, status: 'Overdue', issueDate: '15 Jul', dueDate: '30 Jul'),
          ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isDesktop = width >= 900;
        final bool isTablet = width >= 600 && width < 900;
        final double hPad = isDesktop ? 36 : isTablet ? 24 : 16;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Invoices & Billing', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            elevation: 2,
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                        ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Create Invoice'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ListView.builder(
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
