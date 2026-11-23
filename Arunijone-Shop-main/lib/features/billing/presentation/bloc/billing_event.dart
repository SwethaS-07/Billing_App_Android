part of 'billing_bloc.dart';

abstract class BillingEvent extends Equatable {
  const BillingEvent();
  @override
  List<Object> get props => [];
}

class ScanBarcodeEvent extends BillingEvent {
  final String barcode;
  const ScanBarcodeEvent(this.barcode);
  @override
  List<Object> get props => [barcode];
}

class AddProductToCartEvent extends BillingEvent {
  final Product product;
  const AddProductToCartEvent(this.product);
  @override
  List<Object> get props => [product];
}

class RemoveProductFromCartEvent extends BillingEvent {
  final String productId;
  const RemoveProductFromCartEvent(this.productId);
  @override
  List<Object> get props => [productId];
}

class UpdateQuantityEvent extends BillingEvent {
  final String productId;
  final int quantity;
  const UpdateQuantityEvent(this.productId, this.quantity);
  @override
  List<Object> get props => [productId, quantity];
}

class ClearCartEvent extends BillingEvent {}

class SetCustomerInfoEvent extends BillingEvent {
  final String name;
  final String phone;
  const SetCustomerInfoEvent({required this.name, required this.phone});
  @override
  List<Object> get props => [name, phone];
}

/// Skip entering customer details and save the sale as a walk-in customer.
class SkipCustomerDetailsEvent extends BillingEvent {
  const SkipCustomerDetailsEvent();
}

/// Look up an existing customer by phone number without creating a profile.
class LookupCustomerByPhoneEvent extends BillingEvent {
  final String phone;
  const LookupCustomerByPhoneEvent(this.phone);
  @override
  List<Object> get props => [phone];
}

/// Look up (or register) a customer by phone number.
class SetCustomerFromPhoneEvent extends BillingEvent {
  final String phone;
  final String name;
  const SetCustomerFromPhoneEvent({required this.phone, required this.name});
  @override
  List<Object> get props => [phone, name];
}

/// Add an amount to a customer's due balance.
class UpdateCustomerDueEvent extends BillingEvent {
  final String customerId;
  final double amount;
  const UpdateCustomerDueEvent({
    required this.customerId,
    required this.amount,
  });
  @override
  List<Object> get props => [customerId, amount];
}

/// Record a payment against a single saved bill.
class RecordBillPaymentEvent extends BillingEvent {
  final String transactionId;
  final double amount;
  const RecordBillPaymentEvent({
    required this.transactionId,
    required this.amount,
  });
  @override
  List<Object> get props => [transactionId, amount];
}

/// Record a payment against a customer's total outstanding due.
class RecordCustomerPaymentEvent extends BillingEvent {
  final String customerId;
  final double amount;
  const RecordCustomerPaymentEvent({
    required this.customerId,
    required this.amount,
  });
  @override
  List<Object> get props => [customerId, amount];
}

/// Override the price of a cart item for the current checkout only.
class SetCartItemPriceEvent extends BillingEvent {
  final String productId;
  final double price;
  const SetCartItemPriceEvent(this.productId, this.price);
  @override
  List<Object> get props => [productId, price];
}

/// Record a completed sale for daily profit tracking.
class RecordSaleEvent extends BillingEvent {
  final double total;
  final String? customerId;
  final String? customerPhone;
  final String customerName;
  final PaymentMethod paymentMethod;
  final double cashGiven;
  const RecordSaleEvent({
    required this.total,
    this.customerId,
    this.customerPhone,
    required this.customerName,
    required this.paymentMethod,
    required this.cashGiven,
  });
  @override
  List<Object> get props => [
    total,
    customerId ?? '',
    customerPhone ?? '',
    customerName,
    paymentMethod,
    cashGiven,
  ];
}

/// Admin sets an absolute due amount on a customer profile.
class SetCustomerAbsoluteDueEvent extends BillingEvent {
  final String customerId;
  final double dueAmount;
  final String name;
  final String phone;
  const SetCustomerAbsoluteDueEvent({
    required this.customerId,
    required this.dueAmount,
    required this.name,
    required this.phone,
  });
  @override
  List<Object> get props => [customerId, dueAmount, name, phone];
}

class SetPaymentMethodEvent extends BillingEvent {
  final PaymentMethod method;
  const SetPaymentMethodEvent(this.method);
  @override
  List<Object> get props => [method];
}

class SetCashGivenEvent extends BillingEvent {
  final double amount;
  const SetCashGivenEvent(this.amount);
  @override
  List<Object> get props => [amount];
}

class SendInvoiceEvent extends BillingEvent {}

class PrintReceiptEvent extends BillingEvent {
  final String shopName;
  final String address1;
  final String address2;
  final String phone;
  final String footer;

  const PrintReceiptEvent({
    required this.shopName,
    required this.address1,
    required this.address2,
    required this.phone,
    required this.footer,
  });

  @override
  List<Object> get props => [shopName, address1, address2, phone, footer];
}
