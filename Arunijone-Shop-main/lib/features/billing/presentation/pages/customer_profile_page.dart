import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/usecase/usecase.dart';
import '../bloc/billing_bloc.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/sale_transaction.dart';
import '../../domain/usecases/customer_usecases.dart';
import '../widgets/collect_payment_dialog.dart';
import '../widgets/customer_details_sheet.dart';

class CustomerProfilePage extends StatefulWidget {
  const CustomerProfilePage({super.key});

  @override
  State<CustomerProfilePage> createState() => _CustomerProfilePageState();
}

class _CustomerProfilePageState extends State<CustomerProfilePage> {
  late final ValueListenable<Box> _transactionsListenable;
  late final ValueListenable<Box> _customersListenable;

  List<Customer> _customers = const [];
  List<SaleTransaction> _transactions = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _transactionsListenable = HiveDatabase.transactionBox.listenable();
    _transactionsListenable.addListener(_load);
    _customersListenable = HiveDatabase.customerBox.listenable();
    _customersListenable.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _transactionsListenable.removeListener(_load);
    _customersListenable.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final billingBloc = context.read<BillingBloc>();
      final customersResult = await GetIt.instance<GetAllCustomersUseCase>()(
        NoParams(),
      );
      final transactions = await billingBloc.getRecentTransactions();

      if (!mounted) return;

      customersResult.fold(
        (failure) => setState(() {
          _error = failure.message;
          _isLoading = false;
        }),
        (customers) => setState(() {
          _customers = customers;
          _transactions = transactions;
          _error = null;
          _isLoading = false;
        }),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load customers: $e';
        _isLoading = false;
      });
    }
  }

  String _displayName(Customer customer) {
    return customer.name.trim().isNotEmpty
        ? customer.name.trim()
        : customer.phone;
  }

  bool _belongsToCustomer(SaleTransaction transaction, Customer customer) {
    if (customer.id.isNotEmpty && transaction.customerId == customer.id) {
      return true;
    }
    return customer.phone.isNotEmpty &&
        transaction.customerPhone == customer.phone;
  }

  List<SaleTransaction> _transactionsFor(Customer customer) {
    return _transactions
        .where((transaction) => _belongsToCustomer(transaction, customer))
        .toList();
  }

  void _editDue(BuildContext context, Customer customer) {
    final controller = TextEditingController(
      text: customer.dueAmount.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Due Amount'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Customer: ${customer.name.isNotEmpty ? customer.name : customer.phone}',
              ),
              Text('Phone: ${customer.phone}'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Due Amount',
                  prefixText: '\u20B9 ',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final newDue = double.tryParse(controller.text.trim()) ?? 0;
                context.read<BillingBloc>().add(
                  SetCustomerAbsoluteDueEvent(
                    customerId: customer.id,
                    dueAmount: newDue,
                    name: customer.name,
                    phone: customer.phone,
                  ),
                );
                Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Customer Profiles',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 40, color: Colors.red[400]),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_customers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              const Text(
                'No customers yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Customers are created automatically when you enter a new '
                'phone number during billing.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: _customers.length,
        itemBuilder: (context, index) {
          final customer = _customers[index];
          final transactions = _transactionsFor(customer);
          final totalPurchase = transactions.fold<double>(
            0,
            (sum, transaction) => sum + transaction.total,
          );

          return _buildCustomerCard(customer, transactions, totalPurchase);
        },
      ),
    );
  }

  Widget _buildCustomerCard(
    Customer customer,
    List<SaleTransaction> transactions,
    double totalPurchase,
  ) {
    final displayName = _displayName(customer);
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final transactionPending = transactions.fold<double>(
      0,
      (sum, transaction) => sum + transaction.pendingAmount,
    );
    final pendingDue = customer.dueAmount > 0
        ? customer.dueAmount
        : transactionPending;
    final hasDue = pendingDue > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => CustomerDetailsSheet.show(context, customer),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppTheme.primaryColor.withValues(
                        alpha: 0.1,
                      ),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 16,
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
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            customer.phone,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: Colors.blue,
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _editDue(context, customer),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildMiniStat(
                          'Total Purchase',
                          '\u20B9${totalPurchase.toStringAsFixed(2)}',
                          AppTheme.primaryColor,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: const Color(0xFFE5E7EB),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMiniStat(
                          'Pending Due',
                          '\u20B9${pendingDue.toStringAsFixed(2)}',
                          hasDue ? Colors.red[700]! : Colors.green[700]!,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasDue) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _collectPayment(context, customer, pendingDue),
                      icon: const Icon(Icons.payments_outlined, size: 18),
                      label: const Text('Collect Payment'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: BorderSide(
                          color: AppTheme.primaryColor.withValues(alpha: 0.4),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.grey[500],
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
