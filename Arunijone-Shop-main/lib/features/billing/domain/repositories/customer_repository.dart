import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/customer.dart';

abstract class CustomerRepository {
  Future<Either<Failure, Customer?>> getCustomerByPhone(String phone);
  Future<Either<Failure, void>> addCustomer(Customer customer);
  Future<Either<Failure, void>> updateCustomer(Customer customer);
  Future<Either<Failure, List<Customer>>> getAllCustomers();
}