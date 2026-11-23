import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/app_validators.dart';
import '../../../../core/widgets/input_label.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/entities/customer.dart';
import '../bloc/billing_bloc.dart';

class CustomerInfoPage extends StatefulWidget {
  const CustomerInfoPage({super.key});

  @override
  State<CustomerInfoPage> createState() => _CustomerInfoPageState();
}

class _CustomerInfoPageState extends State<CustomerInfoPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Timer? _lookupDebounce;
  Customer? _matchedCustomer;
  String? _autoFilledName;

  @override
  void initState() {
    super.initState();
    // Reset any customer matched during a previous bill.
    context.read<BillingBloc>().add(const LookupCustomerByPhoneEvent(''));
  }

  @override
  void dispose() {
    _lookupDebounce?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onPhoneChanged(String value) {
    _lookupDebounce?.cancel();
    final phone = value.trim();

    if (_matchedCustomer != null) {
      setState(() => _matchedCustomer = null);
    }

    if (phone.isEmpty) {
      context.read<BillingBloc>().add(const LookupCustomerByPhoneEvent(''));
      return;
    }

    _lookupDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      context.read<BillingBloc>().add(LookupCustomerByPhoneEvent(phone));
    });
  }

  void _handleLookupResult(BillingState state) {
    final customer = state.lookedUpCustomer;

    if (customer != null) {
      if (customer.name.trim().isNotEmpty) {
        _autoFilledName = customer.name;
        _nameController.value = TextEditingValue(
          text: customer.name,
          selection: TextSelection.collapsed(offset: customer.name.length),
        );
      } else {
        if (_autoFilledName != null &&
            _nameController.text.trim() == _autoFilledName) {
          _nameController.clear();
        }
        _autoFilledName = null;
      }
      setState(() => _matchedCustomer = customer);
      return;
    }

    if (_autoFilledName != null &&
        _nameController.text.trim() == _autoFilledName) {
      _nameController.clear();
    }
    _autoFilledName = null;
    setState(() => _matchedCustomer = null);
  }

  void _skipCustomerDetails() {
    context.read<BillingBloc>().add(const SkipCustomerDetailsEvent());
    context.push('/checkout');
  }

  void _continue() {
    _lookupDebounce?.cancel();
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    context.read<BillingBloc>().add(
      SetCustomerFromPhoneEvent(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
      ),
    );
    context.push('/checkout');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Customer Details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocListener<BillingBloc, BillingState>(
        listenWhen: (previous, current) =>
            previous.lookedUpCustomer != current.lookedUpCustomer,
        listener: (context, state) => _handleLookupResult(state),
        child: BlocListener<BillingBloc, BillingState>(
          listenWhen: (previous, current) => previous.error != current.error,
          listener: (context, state) {
            if (state.error != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.error!),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const InputLabel(text: 'Customer Name'),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'Enter customer name',
                    ),
                    validator: AppValidators.required(
                      'Please enter customer name',
                    ),
                  ),
                  const SizedBox(height: 20),
                  const InputLabel(text: 'Phone Number'),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    onChanged: _onPhoneChanged,
                    onFieldSubmitted: (value) {
                      _lookupDebounce?.cancel();
                      final phone = value.trim();
                      if (phone.isNotEmpty) {
                        context.read<BillingBloc>().add(
                          LookupCustomerByPhoneEvent(phone),
                        );
                      }
                    },
                    decoration: const InputDecoration(
                      hintText: 'Enter phone number',
                    ),
                    validator: AppValidators.required(
                      'Please enter phone number',
                    ),
                  ),
                  if (_matchedCustomer != null) ...[
                    const SizedBox(height: 12),
                    _buildCustomerMatchCard(_matchedCustomer!),
                  ],
                  const SizedBox(height: 24),
                  PrimaryButton(
                    onPressed: _continue,
                    label: 'Continue',
                    icon: Icons.arrow_forward,
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _skipCustomerDetails,
                        icon: const Icon(Icons.skip_next, size: 18),
                        label: const Text('Skip Customer Details'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          foregroundColor: Colors.grey[700],
                          side: BorderSide(color: Colors.grey[300]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerMatchCard(Customer customer) {
    final hasDue = customer.dueAmount > 0;
    final displayName = customer.name.trim().isNotEmpty
        ? customer.name.trim()
        : customer.phone;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, size: 18, color: Colors.green[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Existing customer: $displayName',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.green[800],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Due ₹${customer.dueAmount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: hasDue ? Colors.red[700] : Colors.green[700],
            ),
          ),
        ],
      ),
    );
  }
}
