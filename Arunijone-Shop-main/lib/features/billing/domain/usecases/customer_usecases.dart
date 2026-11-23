import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/customer.dart';
import '../repositories/customer_repository.dart';

class GetCustomerByPhoneUseCase implements UseCase<Customer?, String> {
  final CustomerRepository repository;
  GetCustomerByPhoneUseCase(this.repository);

  @override
  Future<Either<Failure, Customer?>> call(String params) {
    return repository.getCustomerByPhone(params);
  }
}

class AddCustomerUseCase implements UseCase<void, Customer> {
  final CustomerRepository repository;
  AddCustomerUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(Customer params) {
    return repository.addCustomer(params);
  }
}

class UpdateCustomerUseCase implements UseCase<void, Customer> {
  final CustomerRepository repository;
  UpdateCustomerUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(Customer params) {
    return repository.updateCustomer(params);
  }
}

class GetAllCustomersUseCase implements UseCase<List<Customer>, NoParams> {
  final CustomerRepository repository;
  GetAllCustomersUseCase(this.repository);

  @override
  Future<Either<Failure, List<Customer>>> call(NoParams params) {
    return repository.getAllCustomers();
  }
}