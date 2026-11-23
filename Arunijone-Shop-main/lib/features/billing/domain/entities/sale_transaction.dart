class SaleTransactionItem {
  final String name;
  final int quantity;
  final double price;
  final double total;

  const SaleTransactionItem({
    required this.name,
    required this.quantity,
    required this.price,
    required this.total,
  });
}

class SaleTransactionPayment {
  final double amount;
  final DateTime date;

  const SaleTransactionPayment({required this.amount, required this.date});
}

class SaleTransaction {
  final String id;
  final String customerName;
  final String customerPhone;
  final String customerId;
  final DateTime date;
  final String paymentMethod;
  final double total;
  final double amountPaid;
  final double pendingAmount;
  final List<SaleTransactionItem> items;
  final List<SaleTransactionPayment> payments;

  const SaleTransaction({
    required this.id,
    required this.customerName,
    this.customerPhone = '',
    this.customerId = '',
    required this.date,
    required this.paymentMethod,
    required this.total,
    required this.amountPaid,
    required this.pendingAmount,
    this.items = const [],
    this.payments = const [],
  });

  bool get isQrPayment => paymentMethod == 'qr';
}
