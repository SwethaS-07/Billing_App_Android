import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/cart_item.dart';

import 'package:billing_app/features/product/domain/entities/product.dart';
import 'package:billing_app/features/product/domain/usecases/product_usecases.dart';
import 'package:billing_app/features/billing/domain/usecases/customer_usecases.dart';
import 'package:billing_app/features/billing/domain/entities/customer.dart';
import 'package:billing_app/features/billing/domain/entities/sale_transaction.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/printer_helper.dart';
import '../../../../core/data/hive_database.dart';

import 'package:intl/intl.dart';

part 'billing_event.dart';
part 'billing_state.dart';

class BillingBloc extends Bloc<BillingEvent, BillingState> {
  final GetProductByBarcodeUseCase getProductByBarcodeUseCase;
  final GetCustomerByPhoneUseCase getCustomerByPhoneUseCase;
  final AddCustomerUseCase addCustomerUseCase;
  final UpdateCustomerUseCase updateCustomerUseCase;

  BillingBloc({
    required this.getProductByBarcodeUseCase,
    required this.getCustomerByPhoneUseCase,
    required this.addCustomerUseCase,
    required this.updateCustomerUseCase,
  }) : super(const BillingState()) {
    on<ScanBarcodeEvent>(_onScanBarcode);
    on<AddProductToCartEvent>(_onAddProductToCart);
    on<RemoveProductFromCartEvent>(_onRemoveProductFromCart);
    on<UpdateQuantityEvent>(_onUpdateQuantity);
    on<ClearCartEvent>(_onClearCart);
    on<SetCustomerInfoEvent>(_onSetCustomerInfo);
    on<SkipCustomerDetailsEvent>(_onSkipCustomerDetails);
    on<LookupCustomerByPhoneEvent>(
      _onLookupCustomerByPhone,
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
    on<SetCustomerFromPhoneEvent>(_onSetCustomerFromPhone);
    on<UpdateCustomerDueEvent>(_onUpdateCustomerDue);
    on<RecordBillPaymentEvent>(
      _onRecordBillPayment,
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
    on<RecordCustomerPaymentEvent>(
      _onRecordCustomerPayment,
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
    on<SetCartItemPriceEvent>(_onSetCartItemPrice);
    on<SetPaymentMethodEvent>(_onSetPaymentMethod);
    on<SetCashGivenEvent>(_onSetCashGiven);
    on<SendInvoiceEvent>(_onSendInvoice);
    on<PrintReceiptEvent>(_onPrintReceipt);
    on<RecordSaleEvent>(_onRecordSale);
    on<SetCustomerAbsoluteDueEvent>(_onSetCustomerAbsoluteDue);
  }

  Future<void> _onScanBarcode(
    ScanBarcodeEvent event,
    Emitter<BillingState> emit,
  ) async {
    final result = await getProductByBarcodeUseCase(event.barcode);
    result.fold(
      (failure) =>
          emit(state.copyWith(error: 'Product not found: ${event.barcode}')),
      (product) {
        add(AddProductToCartEvent(product));
      },
    );
  }

  void _onAddProductToCart(
    AddProductToCartEvent event,
    Emitter<BillingState> emit,
  ) {
    // Clear error when adding
    final cleanState = state.copyWith(error: null);

    final existingIndex = cleanState.cartItems.indexWhere(
      (item) => item.product.id == event.product.id,
    );
    if (existingIndex >= 0) {
      final existingItem = cleanState.cartItems[existingIndex];
      final backendItems = List<CartItem>.from(cleanState.cartItems);
      backendItems[existingIndex] = existingItem.copyWith(
        quantity: existingItem.quantity + 1,
      );
      emit(cleanState.copyWith(cartItems: backendItems, error: null));
    } else {
      final newItem = CartItem(product: event.product);
      emit(
        cleanState.copyWith(
          cartItems: [...cleanState.cartItems, newItem],
          error: null,
        ),
      );
    }
  }

  void _onRemoveProductFromCart(
    RemoveProductFromCartEvent event,
    Emitter<BillingState> emit,
  ) {
    final updatedList = state.cartItems
        .where((item) => item.product.id != event.productId)
        .toList();
    emit(state.copyWith(cartItems: updatedList));
  }

  void _onUpdateQuantity(
    UpdateQuantityEvent event,
    Emitter<BillingState> emit,
  ) {
    if (event.quantity <= 0) {
      add(RemoveProductFromCartEvent(event.productId));
      return;
    }

    final index = state.cartItems.indexWhere(
      (item) => item.product.id == event.productId,
    );
    if (index >= 0) {
      final items = List<CartItem>.from(state.cartItems);
      items[index] = items[index].copyWith(quantity: event.quantity);
      emit(state.copyWith(cartItems: items));
    }
  }

  void _onClearCart(ClearCartEvent event, Emitter<BillingState> emit) {
    // Keep customer info but reset the cart and payment fields for a new sale.
    emit(
      state.copyWith(
        cartItems: const [],
        cashGiven: 0,
        paymentMethod: PaymentMethod.cash,
        isPrinting: false,
        printSuccess: false,
        invoiceSuccess: false,
        error: null,
      ),
    );
  }

  void _onSetCustomerInfo(
    SetCustomerInfoEvent event,
    Emitter<BillingState> emit,
  ) {
    emit(
      state.copyWith(
        customerName: event.name,
        customerPhone: event.phone,
        error: null,
      ),
    );
  }

  void _onSkipCustomerDetails(
    SkipCustomerDetailsEvent event,
    Emitter<BillingState> emit,
  ) {
    emit(
      state.copyWith(
        clearCustomerId: true,
        customerName: 'Walk-in Customer',
        customerPhone: '',
        customerDue: 0,
        clearLookedUpCustomer: true,
        error: null,
      ),
    );
  }

  void _onSetPaymentMethod(
    SetPaymentMethodEvent event,
    Emitter<BillingState> emit,
  ) {
    emit(state.copyWith(paymentMethod: event.method));
  }

  void _onSetCashGiven(SetCashGivenEvent event, Emitter<BillingState> emit) {
    emit(state.copyWith(cashGiven: event.amount));
  }

  /// Sum of unpaid amounts across a customer's saved bills.
  double _pendingBillDue(Customer customer) {
    final box = HiveDatabase.transactionBox;
    double total = 0;

    for (final key in box.keys) {
      final value = box.get(key);
      if (value is! Map) continue;

      final pending = (value['pendingAmount'] as num?)?.toDouble() ?? 0;
      if (pending <= 0) continue;

      final customerId = (value['customerId'] as String?) ?? '';
      final customerPhone = (value['customerPhone'] as String?) ?? '';
      final matchesId = customer.id.isNotEmpty && customerId == customer.id;
      final matchesPhone =
          customer.phone.isNotEmpty && customerPhone == customer.phone;

      if (matchesId || matchesPhone) total += pending;
    }

    return total;
  }

  /// Due amount to use for a customer. Prefer the stored balance, falling
  /// back to unpaid bills when the profile balance is zero.
  double _currentDueFor(Customer customer) {
    if (customer.dueAmount > 0) return customer.dueAmount;
    return _pendingBillDue(customer);
  }

  Customer? _findCustomer(String customerId, String phone) {
    if (customerId.isNotEmpty) {
      final model = HiveDatabase.customerBox.get(customerId);
      if (model != null) return model.toEntity();
    }
    if (phone.isNotEmpty) {
      for (final customer in HiveDatabase.customerBox.values) {
        if (customer.phone == phone) return customer.toEntity();
      }
    }
    return null;
  }

  Customer? _selectedOrStoredCustomer(String customerId) {
    final model = HiveDatabase.customerBox.get(customerId);
    if (model != null) return model.toEntity();
    if (state.customerId == customerId) {
      return Customer(
        id: customerId,
        name: state.customerName,
        phone: state.customerPhone,
        dueAmount: state.customerDue,
      );
    }
    return null;
  }

  /// Apply a payment to one bill, returning the amount actually applied.
  Future<double> _applyBillPayment(String transactionId, double amount) async {
    final box = HiveDatabase.transactionBox;
    final raw = box.get(transactionId);
    if (raw is! Map || !amount.isFinite || amount <= 0) return 0;

    final pending = (raw['pendingAmount'] as num?)?.toDouble() ?? 0;
    if (pending <= 0) return 0;

    final applied = amount > pending ? pending : amount;
    final amountPaid = (raw['amountPaid'] as num?)?.toDouble() ?? 0;

    final payments = <Map<String, dynamic>>[];
    final existingPayments = raw['payments'];
    if (existingPayments is List) {
      for (final payment in existingPayments) {
        if (payment is Map) {
          payments.add(Map<String, dynamic>.from(payment));
        }
      }
    }
    payments.add({'amount': applied, 'date': DateTime.now().toIso8601String()});

    final updated = Map<String, dynamic>.from(raw);
    updated['amountPaid'] = amountPaid + applied;
    updated['pendingAmount'] = pending - applied;
    updated['payments'] = payments;
    await box.put(transactionId, updated);
    return applied;
  }

  Future<void> _onRecordBillPayment(
    RecordBillPaymentEvent event,
    Emitter<BillingState> emit,
  ) async {
    final raw = HiveDatabase.transactionBox.get(event.transactionId);
    if (raw is! Map) {
      emit(state.copyWith(error: 'Bill not found.'));
      return;
    }

    final pending = (raw['pendingAmount'] as num?)?.toDouble() ?? 0;
    if (pending <= 0) {
      emit(state.copyWith(error: 'This bill is already fully paid.'));
      return;
    }
    if (!event.amount.isFinite || event.amount <= 0) {
      emit(state.copyWith(error: 'Enter a payment amount greater than zero.'));
      return;
    }

    final applied = await _applyBillPayment(event.transactionId, event.amount);
    if (applied <= 0) {
      emit(state.copyWith(error: 'Failed to record the payment.'));
      return;
    }

    final customer = _findCustomer(
      (raw['customerId'] as String?) ?? '',
      (raw['customerPhone'] as String?) ?? '',
    );
    if (customer == null) return;

    final newDue = customer.dueAmount > 0
        ? (customer.dueAmount > applied ? customer.dueAmount - applied : 0.0)
        : _pendingBillDue(customer);
    final result = await updateCustomerUseCase(
      customer.copyWith(dueAmount: newDue),
    );
    result.fold(
      (failure) => emit(
        state.copyWith(
          error:
              'Payment saved, but customer due update failed: '
              '${failure.message}',
        ),
      ),
      (_) {
        if (state.customerId == customer.id) {
          emit(state.copyWith(customerDue: newDue));
        }
      },
    );
  }

  Future<void> _onRecordCustomerPayment(
    RecordCustomerPaymentEvent event,
    Emitter<BillingState> emit,
  ) async {
    final customer = _selectedOrStoredCustomer(event.customerId);
    if (customer == null) {
      emit(state.copyWith(error: 'Customer not found.'));
      return;
    }

    final bills =
        getTransactionsForCustomer(customer)
            .where((transaction) => transaction.pendingAmount > 0)
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final billPending = bills.fold<double>(
      0,
      (sum, transaction) => sum + transaction.pendingAmount,
    );
    final effectiveDue = customer.dueAmount > 0
        ? customer.dueAmount
        : billPending;

    if (effectiveDue <= 0) {
      emit(state.copyWith(error: 'No pending due for this customer.'));
      return;
    }
    if (!event.amount.isFinite || event.amount <= 0) {
      emit(state.copyWith(error: 'Enter a payment amount greater than zero.'));
      return;
    }

    final amount = event.amount > effectiveDue ? effectiveDue : event.amount;
    var remaining = amount;
    for (final bill in bills) {
      if (remaining <= 0) break;
      final applied = await _applyBillPayment(bill.id, remaining);
      remaining -= applied;
    }

    final newDue = effectiveDue > amount ? effectiveDue - amount : 0.0;
    final result = await updateCustomerUseCase(
      customer.copyWith(dueAmount: newDue),
    );
    result.fold(
      (failure) => emit(
        state.copyWith(
          error: 'Failed to update customer due: ${failure.message}',
        ),
      ),
      (_) {
        if (state.customerId == customer.id) {
          emit(state.copyWith(customerDue: newDue));
        }
      },
    );
  }

  /// Look up an existing customer without creating a new profile.
  Future<void> _onLookupCustomerByPhone(
    LookupCustomerByPhoneEvent event,
    Emitter<BillingState> emit,
  ) async {
    final phone = event.phone.trim();
    if (phone.isEmpty) {
      emit(state.copyWith(clearLookedUpCustomer: true));
      return;
    }

    final result = await getCustomerByPhoneUseCase(phone);
    result.fold(
      (failure) => emit(state.copyWith(clearLookedUpCustomer: true)),
      (customer) {
        Customer? matchedCustomer;
        if (customer != null) {
          matchedCustomer = customer.copyWith(
            dueAmount: _currentDueFor(customer),
          );
        }
        emit(
          state.copyWith(
            lookedUpCustomer: matchedCustomer,
            clearLookedUpCustomer: matchedCustomer == null,
          ),
        );
      },
    );
  }

  /// Look up an existing customer by phone or register a new one.
  Future<void> _onSetCustomerFromPhone(
    SetCustomerFromPhoneEvent event,
    Emitter<BillingState> emit,
  ) async {
    final phone = event.phone.trim();
    if (phone.isEmpty) return;

    final result = await getCustomerByPhoneUseCase(phone);

    String? lookupFailure;
    Customer? foundCustomer;
    result.fold(
      (failure) {
        lookupFailure = failure.message;
      },
      (customer) {
        foundCustomer = customer;
      },
    );

    if (lookupFailure != null) {
      emit(state.copyWith(error: 'Failed to look up customer: $lookupFailure'));
      return;
    }

    final existingCustomer = foundCustomer;
    if (existingCustomer != null) {
      var customer = existingCustomer.copyWith(
        dueAmount: _currentDueFor(existingCustomer),
      );
      if (customer.name.trim().isEmpty && event.name.isNotEmpty) {
        customer = customer.copyWith(name: event.name);
        await updateCustomerUseCase(customer);
      }

      // Heal the stored profile if unpaid bills exceed its due.
      if (customer.dueAmount > existingCustomer.dueAmount) {
        await updateCustomerUseCase(customer);
      }

      // Existing customer recognized
      emit(
        state.copyWith(
          customerId: customer.id,
          customerName: customer.name,
          customerPhone: customer.phone,
          customerDue: customer.dueAmount,
          lookedUpCustomer: customer,
          error: null,
        ),
      );
      return;
    }

    // New phone number -> register as a new customer with the given name
    final newCustomer = Customer(
      id: const Uuid().v4(),
      name: event.name.isNotEmpty ? event.name : '',
      phone: phone,
      dueAmount: 0.0,
    );
    final addResult = await addCustomerUseCase(newCustomer);
    addResult.fold(
      (failure) => emit(
        state.copyWith(error: 'Failed to create customer: ${failure.message}'),
      ),
      (_) => emit(
        state.copyWith(
          customerId: newCustomer.id,
          customerName: newCustomer.name,
          customerPhone: newCustomer.phone,
          customerDue: 0.0,
          lookedUpCustomer: newCustomer,
          error: null,
        ),
      ),
    );
  }

  /// Add an amount to a customer's due balance and persist it.
  Future<void> _onUpdateCustomerDue(
    UpdateCustomerDueEvent event,
    Emitter<BillingState> emit,
  ) async {
    final existingCustomer = _selectedOrStoredCustomer(event.customerId);
    if (existingCustomer == null) return;

    final updatedCustomer = existingCustomer.copyWith(
      dueAmount: existingCustomer.dueAmount + event.amount,
    );

    final result = await updateCustomerUseCase(updatedCustomer);
    result.fold(
      (failure) => emit(
        state.copyWith(
          error: 'Failed to update customer due: ${failure.message}',
        ),
      ),
      (_) {
        if (state.customerId == event.customerId) {
          emit(state.copyWith(customerDue: updatedCustomer.dueAmount));
        }
      },
    );
  }

  void _onSetCartItemPrice(
    SetCartItemPriceEvent event,
    Emitter<BillingState> emit,
  ) {
    final index = state.cartItems.indexWhere(
      (item) => item.product.id == event.productId,
    );
    if (index >= 0) {
      final items = List<CartItem>.from(state.cartItems);
      items[index] = items[index].copyWith(overridePrice: event.price);
      emit(state.copyWith(cartItems: items));
    }
  }

  void _onSendInvoice(SendInvoiceEvent event, Emitter<BillingState> emit) {
    emit(state.copyWith(invoiceSuccess: false));
    // Invoice wiring to be implemented later; mark success for now.
    emit(state.copyWith(invoiceSuccess: true));
  }

  Future<void> _onPrintReceipt(
    PrintReceiptEvent event,
    Emitter<BillingState> emit,
  ) async {
    final printerHelper = PrinterHelper();

    if (!printerHelper.isConnected) {
      final savedMac = HiveDatabase.settingsBox.get('printer_mac');
      if (savedMac != null) {
        final connected = await printerHelper.connect(savedMac);
        if (!connected) {
          emit(
            state.copyWith(
              error: 'Failed to auto-connect to printer!',
              clearError: false,
            ),
          );
          emit(state.copyWith(clearError: true));
          return;
        }
      } else {
        emit(
          state.copyWith(
            error: 'Printer not connected & no saved printer found!',
            clearError: false,
          ),
        );
        emit(state.copyWith(clearError: true));
        return;
      }
    }

    emit(
      state.copyWith(isPrinting: true, printSuccess: false, clearError: true),
    );

    try {
      final items = state.cartItems
          .map(
            (item) => {
              'name': item.product.name,
              'qty': item.quantity,
              'price': item.overridePrice ?? item.product.price,
              'total': item.total,
            },
          )
          .toList();

      await printerHelper.printReceipt(
        shopName: event.shopName,
        address1: event.address1,
        address2: event.address2,
        phone: event.phone,
        items: items,
        total: state.totalAmount,
        footer: event.footer,
      );

      emit(state.copyWith(isPrinting: false, printSuccess: true));
    } catch (e) {
      emit(
        state.copyWith(
          isPrinting: false,
          error: 'Print failed: $e',
          clearError: false,
        ),
      );
      // Reset error instantly avoids sticky error
      emit(state.copyWith(clearError: true));
    }
  }

  /// Record a completed sale for daily profit tracking, then clear the cart.
  Future<void> _onRecordSale(
    RecordSaleEvent event,
    Emitter<BillingState> emit,
  ) async {
    final transactionBox = HiveDatabase.transactionBox;
    final key = DateTime.now().millisecondsSinceEpoch.toString();

    final isQrPayment = event.paymentMethod == PaymentMethod.qr;
    final amountPaid = isQrPayment
        ? event.total
        : (event.cashGiven < event.total ? event.cashGiven : event.total);
    final pendingAmount = event.total - amountPaid;
    final customerId = (event.customerId?.isNotEmpty ?? false)
        ? event.customerId!
        : state.customerId;

    // Capture cart items before the async write; other events (like
    // ClearCartEvent) may be processed concurrently by the bloc.
    final items = state.cartItems
        .map(
          (item) => {
            'name': item.product.name,
            'qty': item.quantity,
            'price': item.overridePrice ?? item.product.price,
            'total': item.total,
          },
        )
        .toList();

    await transactionBox.put(key, {
      'total': event.total,
      'customerId': customerId,
      'customerPhone': event.customerPhone,
      'customerName': event.customerName,
      'paymentMethod': isQrPayment ? 'qr' : 'cash',
      'amountPaid': amountPaid,
      'pendingAmount': pendingAmount,
      'items': items,
      'date': DateTime.now().toIso8601String(),
    });

    // If there was a cash due, add it to the customer's profile. Use the
    // bill's pending amount rather than the (possibly reset) bloc state.
    if (pendingAmount > 0 && customerId != null && customerId.isNotEmpty) {
      add(
        UpdateCustomerDueEvent(customerId: customerId, amount: pendingAmount),
      );
    }

    emit(
      state.copyWith(
        isPrinting: false,
        printSuccess: false,
        invoiceSuccess: false,
        cashGiven: 0,
      ),
    );
  }

  /// Admin sets an absolute due amount on a customer profile and persists it.
  void _onSetCustomerAbsoluteDue(
    SetCustomerAbsoluteDueEvent event,
    Emitter<BillingState> emit,
  ) {
    final updated = Customer(
      id: event.customerId,
      name: event.name,
      phone: event.phone,
      dueAmount: event.dueAmount,
    );
    updateCustomerUseCase(updated);

    // If this is the currently selected customer, refresh the state's due.
    if (state.customerId == event.customerId) {
      emit(state.copyWith(customerDue: event.dueAmount));
    }
  }

  /// Total profit (sales) for today, computed from persisted transactions.
  Future<double> getTodayProfit() async {
    final box = HiveDatabase.transactionBox;
    final today = DateTime.now();
    final dateFormatter = DateFormat('yyyy-MM-dd');
    final todayStr = dateFormatter.format(today);

    double total = 0;
    for (final key in box.keys) {
      final value = box.get(key);
      if (value is Map) {
        final dateStr = value['date'] as String?;
        if (dateStr != null) {
          try {
            final saleDate = DateTime.parse(dateStr);
            if (dateFormatter.format(saleDate) == todayStr) {
              total += (value['total'] as num?)?.toDouble() ?? 0;
            }
          } catch (_) {}
        }
      }
    }
    return total;
  }

  /// Completed sales, newest first. Pass [limit] to cap the number returned.
  Future<List<SaleTransaction>> getRecentTransactions({int? limit}) async {
    return _readTransactions(limit: limit);
  }

  /// A single saved bill, or null when it no longer exists.
  SaleTransaction? getTransactionById(String id) {
    final value = HiveDatabase.transactionBox.get(id);
    if (value is! Map) return null;
    return _parseTransaction(id, value);
  }

  /// Saved bills belonging to [customer], newest first.
  List<SaleTransaction> getTransactionsForCustomer(
    Customer customer, {
    int? limit,
  }) {
    final transactions = _readTransactions().where((transaction) {
      if (customer.id.isNotEmpty && transaction.customerId == customer.id) {
        return true;
      }
      return customer.phone.isNotEmpty &&
          transaction.customerPhone == customer.phone;
    }).toList();
    return limit == null ? transactions : transactions.take(limit).toList();
  }

  List<SaleTransaction> _readTransactions({int? limit}) {
    final box = HiveDatabase.transactionBox;
    final transactions = <SaleTransaction>[];

    for (final key in box.keys) {
      final value = box.get(key);
      if (value is! Map) continue;
      final transaction = _parseTransaction(key.toString(), value);
      if (transaction != null) transactions.add(transaction);
    }

    transactions.sort((a, b) => b.date.compareTo(a.date));
    return limit == null ? transactions : transactions.take(limit).toList();
  }

  SaleTransaction? _parseTransaction(String id, Map value) {
    final dateStr = value['date'] as String?;
    final date = dateStr == null ? null : DateTime.tryParse(dateStr);
    if (date == null) return null;

    final total = (value['total'] as num?)?.toDouble() ?? 0;
    final pendingAmount = (value['pendingAmount'] as num?)?.toDouble() ?? 0;
    final amountPaid =
        (value['amountPaid'] as num?)?.toDouble() ?? (total - pendingAmount);

    final items = <SaleTransactionItem>[];
    final rawItems = value['items'];
    if (rawItems is List) {
      for (final rawItem in rawItems) {
        if (rawItem is! Map) continue;
        final quantity = (rawItem['qty'] as num?)?.toInt() ?? 0;
        final price = (rawItem['price'] as num?)?.toDouble() ?? 0;
        items.add(
          SaleTransactionItem(
            name: (rawItem['name'] as String?) ?? '',
            quantity: quantity,
            price: price,
            total: (rawItem['total'] as num?)?.toDouble() ?? quantity * price,
          ),
        );
      }
    }

    final payments = <SaleTransactionPayment>[];
    final rawPayments = value['payments'];
    if (rawPayments is List) {
      for (final rawPayment in rawPayments) {
        if (rawPayment is! Map) continue;
        final paymentDateStr = rawPayment['date'] as String?;
        final paymentDate = paymentDateStr == null
            ? null
            : DateTime.tryParse(paymentDateStr);
        if (paymentDate == null) continue;
        payments.add(
          SaleTransactionPayment(
            amount: (rawPayment['amount'] as num?)?.toDouble() ?? 0,
            date: paymentDate,
          ),
        );
      }
    }

    return SaleTransaction(
      id: id,
      customerName: (value['customerName'] as String?) ?? '',
      customerPhone: (value['customerPhone'] as String?) ?? '',
      customerId: (value['customerId'] as String?) ?? '',
      date: date,
      paymentMethod: (value['paymentMethod'] as String?) ?? 'cash',
      total: total,
      amountPaid: amountPaid,
      pendingAmount: pendingAmount,
      items: items,
      payments: payments,
    );
  }

  /// Outstanding amount across all persisted bills.
  Future<double> getTotalDue() async {
    final box = HiveDatabase.transactionBox;
    double total = 0;

    for (final key in box.keys) {
      final value = box.get(key);
      if (value is Map) {
        total += (value['pendingAmount'] as num?)?.toDouble() ?? 0;
      }
    }

    return total;
  }
}
