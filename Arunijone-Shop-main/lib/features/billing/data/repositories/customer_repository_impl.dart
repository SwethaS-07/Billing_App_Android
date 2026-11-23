import 'package:fpdart/fpdart.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/customer.dart';
import '../../domain/repositories/customer_repository.dart';
import '../models/customer_model.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  @override
  Future<Either<Failure, Customer?>> getCustomerByPhone(String phone) async {
    try {
      final box = HiveDatabase.customerBox;
      final customer = box.values.firstWhere(
        (element) => element.phone == phone,
        orElse: () => throw Exception('Customer not found'),
      );
      return Right(customer.toEntity());
    } catch (e) {
      return const Right(null);
    }
  }

  @override
  Future<Either<Failure, void>> addCustomer(Customer customer) async {
    try {
      final box = HiveDatabase.customerBox;
      final model = CustomerModel.fromEntity(customer);
      await box.put(model.id, model);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateCustomer(Customer customer) async {
    try {
      final box = HiveDatabase.customerBox;
      final model = CustomerModel.fromEntity(customer);
      await box.put(model.id, model);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Customer>>> getAllCustomers() async {
    try {
      final box = HiveDatabase.customerBox;
      final customers = box.values.map((e) => e.toEntity()).toList();
      return Right(customers);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}