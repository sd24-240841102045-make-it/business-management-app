import 'package:flutter/material.dart';
import 'package:business_managment_app/services/app_data_store.dart';

class FinancePage extends StatelessWidget {
  const FinancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppDataStore();
    
    // Dynamic calculations from real invoices and projects
    final paidInvoicesTotal = store.invoices
        .where((inv) => inv.status == 'Paid')
        .fold(0.0, (sum, inv) => sum + inv.amount);

    final projectBudgetsTotal = store.projects
        .fold(0.0, (sum, p) => sum + p.budget);

    final totalRevenue = paidInvoicesTotal + projectBudgetsTotal;

    final pendingInvoicesTotal = store.invoices
        .where((inv) => inv.status == 'Pending' || inv.status == 'Overdue')
        .fold(0.0, (sum, inv) => sum + inv.amount);

    final formattedRevenue = '\$${totalRevenue.toStringAsFixed(2)}';
    final formattedPending = '\$${pendingInvoicesTotal.toStringAsFixed(2)}';
    final formattedProjectBudgets = '\$${projectBudgetsTotal.toStringAsFixed(2)}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isDesktop = width >= 900;
        final bool isTablet = width >= 600 && width < 900;
        final double hPad = isDesktop ? 36 : isTablet ? 24 : 16;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Finance & Ledger', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.green,
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
                    const Text('Financial Overview & Revenue', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    
                    if (width < 650) ...[
                      _financeMetric('Total Revenue', formattedRevenue, Colors.green, Icons.trending_up),
                      const SizedBox(height: 12),
                      _financeMetric('Pending Invoices', formattedPending, Colors.orange, Icons.hourglass_empty),
                      const SizedBox(height: 12),
                      _financeMetric('Active Project Budgets', formattedProjectBudgets, Colors.blue, Icons.account_balance_wallet),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(child: _financeMetric('Total Revenue', formattedRevenue, Colors.green, Icons.trending_up)),
                          const SizedBox(width: 14),
                          Expanded(child: _financeMetric('Pending Invoices', formattedPending, Colors.orange, Icons.hourglass_empty)),
                          const SizedBox(width: 14),
                          Expanded(child: _financeMetric('Active Project Budgets', formattedProjectBudgets, Colors.blue, Icons.account_balance_wallet)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Recent Financial Ledger Transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const Divider(height: 24),
                            if (store.invoices.isEmpty && store.projects.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(20),
                                child: Center(
                                  child: Text('No ledger transactions recorded yet.', style: TextStyle(color: Colors.grey)),
                                ),
                              )
                            else ...[
                              ...store.invoices.map((inv) => _transactionTile(
                                'Invoice #${inv.invoiceNumber} - ${inv.clientName}',
                                inv.issueDate,
                                '\$${inv.amount.toStringAsFixed(2)} (${inv.status})',
                                inv.status == 'Paid' ? Colors.green : Colors.orange,
                              )),
                              ...store.projects.map((p) => _transactionTile(
                                'Project Allocated: ${p.name}',
                                p.deadline,
                                '\$${p.budget.toStringAsFixed(2)}',
                                Colors.blue,
                              )),
                            ],
                          ],
                        ),
                      ),
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

  Widget _financeMetric(String label, String amount, Color color, IconData icon) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(radius: 22, backgroundColor: color.withOpacity(0.12), child: Icon(icon, color: color, size: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(amount, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _transactionTile(String title, String date, String amount, Color amountColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: amountColor.withOpacity(0.12),
            child: Icon(amountColor == Colors.green ? Icons.arrow_downward : Icons.arrow_upward, color: amountColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(date, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(amount, style: TextStyle(color: amountColor, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}
