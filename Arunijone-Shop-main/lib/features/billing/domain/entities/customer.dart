import 'package:equatable/equatable.dart';

class Customer extends Equatable {
  final String id;
  final String name;
  final String phone;
  final double dueAmount;

  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.dueAmount = 0.0,
  });

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    double? dueAmount,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      dueAmount: dueAmount ?? this.dueAmount,
    );
  }

  @override
  List<Object?> get props => [id, name, phone, dueAmount];
}