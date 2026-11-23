part of 'billing_bloc.dart';

enum PaymentMethod { cash, qr }

class BillingState extends Equatable {
  final List<CartItem> cartItems;
  final String? error;
  final bool isPrinting;
  final bool printSuccess;
  final String customerName;
  final String customerPhone;
  final String? customerId; // ID of the recognized/registered customer
  final double customerDue; // current due amount of the selected customer
  final Customer? lookedUpCustomer; // customer matching the typed phone number
  final PaymentMethod paymentMethod;
  final double cashGiven;
  final bool invoiceSuccess;

  const BillingState({
    this.cartItems = const [],
    this.error,
    this.isPrinting = false,
    this.printSuccess = false,
    this.customerName = '',
    this.customerPhone = '',
    this.customerId,
    this.customerDue = 0.0,
    this.lookedUpCustomer,
    this.paymentMethod = PaymentMethod.cash,
    this.cashGiven = 0,
    this.invoiceSuccess = false,
  });

  double get totalAmount => cartItems.fold(0, (sum, item) => sum + item.total);

  /// Change to return to the customer when paying by cash.
  double get cashChange =>
      cashGiven > totalAmount ? cashGiven - totalAmount : 0;

  /// Amount still due when cash given is less than the total.
  double get cashDue => cashGiven < totalAmount ? totalAmount - cashGiven : 0;

  BillingState copyWith({
    List<CartItem>? cartItems,
    String? error,
    bool clearError = false,
    bool? isPrinting,
    bool? printSuccess,
    String? customerName,
    String? customerPhone,
    String? customerId,
    bool clearCustomerId = false,
    double? customerDue,
    Customer? lookedUpCustomer,
    bool clearLookedUpCustomer = false,
    PaymentMethod? paymentMethod,
    double? cashGiven,
    bool? invoiceSuccess,
  }) {
    return BillingState(
      cartItems: cartItems ?? this.cartItems,
      error: clearError ? null : (error ?? this.error),
      isPrinting: isPrinting ?? this.isPrinting,
      printSuccess: printSuccess ?? this.printSuccess,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerId: clearCustomerId ? null : (customerId ?? this.customerId),
      customerDue: customerDue ?? this.customerDue,
      lookedUpCustomer: clearLookedUpCustomer
          ? null
          : (lookedUpCustomer ?? this.lookedUpCustomer),
      paymentMethod: paymentMethod ?? this.paymentMethod,
      cashGiven: cashGiven ?? this.cashGiven,
      invoiceSuccess: invoiceSuccess ?? this.invoiceSuccess,
    );
  }

  @override
  List<Object?> get props => [
    cartItems,
    error,
    isPrinting,
    printSuccess,
    customerName,
    customerPhone,
    customerId,
    customerDue,
    lookedUpCustomer,
    paymentMethod,
    cashGiven,
    invoiceSuccess,
  ];
}
