import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/sale_transaction.dart';
import '../bloc/billing_bloc.dart';
import 'collect_payment_dialog.dart';
import 'transaction_card.dart';

class CustomerDetailsSheet extends StatelessWidget {
  final Customer customer;

  const CustomerDetailsSheet({super.key, required this.customer});

  static Future<void> show(BuildContext context, Customer customer) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomerDetailsSheet(customer: customer),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        HiveDatabase.customerBox.listenable(),
        HiveDatabase.transactionBox.listenable(),
      ]),
      builder: (context, _) {
        final currentCustomer =
            HiveDatabase.customerBox.get(customer.id)?.toEntity() ?? customer;
        final transactions = context
            .read<BillingBloc>()
            .getTransactionsForCustomer(currentCustomer);
        return _buildSheet(context, currentCustomer, transactions);
      },
    );
  }

  Widget _buildSheet(
    BuildContext context,
    Customer customer,
    List<SaleTransaction> transactions,
  ) {
    final displayName = customer.name.trim().isNotEmpty
        ? customer.name.trim()
        : customer.phone;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final totalPurchase = transactions.fold<double>(
      0,
      (sum, transaction) => sum + transaction.total,
    );
    final transactionPending = transactions.fold<double>(
      0,
      (sum, transaction) => sum + transaction.pendingAmount,
    );
    final pendingDue = customer.dueAmount > 0
        ? customer.dueAmount
        : transactionPending;
    final recentTransactions = transactions.take(5).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Customer Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCustomerCard(customer, displayName, initial),
                    const SizedBox(height: 16),
                    _buildStatsRow(totalPurchase, pendingDue),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Transactions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${transactions.length} total',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (recentTransactions.isEmpty)
                      _buildEmptyTransactions()
                    else
                      ...recentTransactions.map(
                        (transaction) =>
                            TransactionCard(transaction: transaction),
                      ),
                  ],
                ),
              ),
            ),
            if (pendingDue > 0) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _collectPayment(context, customer, pendingDue),
                    icon: const Icon(Icons.payments_outlined),
                    label: Text(
                      'Collect Payment · ₹${pendingDue.toStringAsFixed(2)}',
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _collectPayment(
    BuildContext context,
    Customer customer,
    double due,
  ) async {
    final amount = await CollectPaymentDialog.show(context, due: due);
    if (amount == null || !context.mounted) return;
    context.read<BillingBloc>().add(
      RecordCustomerPaymentEvent(customerId: customer.id, amount: amount),
    );
  }

  Widget _buildCustomerCard(
    Customer customer,
    String displayName,
    String initial,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  customer.phone,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(double totalPurchase, double pendingDue) {
    final hasDue = pendingDue > 0;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            label: 'Total Purchase',
            value: '₹${totalPurchase.toStringAsFixed(2)}',
            color: AppTheme.primaryColor,
            icon: Icons.shopping_bag_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'Pending Due',
            value: '₹${pendingDue.toStringAsFixed(2)}',
            color: hasDue ? Colors.red[700]! : Colors.green[700]!,
            icon: Icons.account_balance_wallet_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTransactions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 28, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            'No purchases yet.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
