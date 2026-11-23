import 'package:hive/hive.dart';
import '../../../billing/domain/entities/customer.dart';

part 'customer_model.g.dart'; // Hive generator

@HiveType(typeId: 2)
class CustomerModel extends Customer {
  @override
  @HiveField(0)
  final String id;
  @override
  @HiveField(1)
  final String name;
  @override
  @HiveField(2)
  final String phone;
  @override
  @HiveField(3)
  final double dueAmount;

  const CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    this.dueAmount = 0.0,
  }) : super(
          id: id,
          name: name,
          phone: phone,
          dueAmount: dueAmount,
        );

  factory CustomerModel.fromEntity(Customer customer) {
    return CustomerModel(
      id: customer.id,
      name: customer.name,
      phone: customer.phone,
      dueAmount: customer.dueAmount,
    );
  }

  Customer toEntity() {
    return Customer(
      id: id,
      name: name,
      phone: phone,
      dueAmount: dueAmount,
    );
  }
}