import 'package:flutter/material.dart';

class CollectPaymentDialog extends StatefulWidget {
  final double due;
  final String title;

  const CollectPaymentDialog({
    super.key,
    required this.due,
    this.title = 'Collect Payment',
  });

  static Future<double?> show(
    BuildContext context, {
    required double due,
    String title = 'Collect Payment',
  }) {
    return showDialog<double>(
      context: context,
      builder: (_) => CollectPaymentDialog(due: due, title: title),
    );
  }

  @override
  State<CollectPaymentDialog> createState() => _CollectPaymentDialogState();
}

class _CollectPaymentDialogState extends State<CollectPaymentDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.due.toStringAsFixed(2));
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_controller.text.trim());
    if (amount == null || !amount.isFinite || amount <= 0) {
      setState(() => _error = 'Enter an amount greater than zero');
      return;
    }
    if (amount > widget.due) {
      setState(
        () => _error = 'Amount cannot exceed ₹${widget.due.toStringAsFixed(2)}',
      );
      return;
    }
    Navigator.pop(context, amount);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Outstanding: ₹${widget.due.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '₹ ',
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) {
                setState(() => _error = null);
              }
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 10),
          Text(
            'Keep the full amount to clear the due, or enter a smaller amount '
            'for a partial payment.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('Collect')),
      ],
    );
  }
}
