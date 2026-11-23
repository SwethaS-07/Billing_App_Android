import 'package:equatable/equatable.dart';

class Product extends Equatable {
  final String
      id; // Using barcode as ID usually, but keeping separate ID is safer
  final String name;
  final String? barcode; // Made nullable so products without barcode can persist
  final double price;
  final int stock; // Optional implementation detail
  final String? imageUrl; // Optional product image (asset path or network URL)

  const Product({
    required this.id,
    required this.name,
    this.barcode,
    required this.price,
    this.stock = 0,
    this.imageUrl,
  });

  @override
  List<Object?> get props => [id, name, barcode, price, stock, imageUrl];
}
