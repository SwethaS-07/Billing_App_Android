import 'package:equatable/equatable.dart';
import 'package:billing_app/features/product/domain/entities/product.dart';

class CartItem extends Equatable {
  final Product product;
  final int quantity;
  /// Optional price override for the current checkout only.
  /// When set, the item total uses this price instead of the product's base price.
  final double? overridePrice;

  const CartItem({
    required this.product,
    this.quantity = 1,
    this.overridePrice,
  });

  double get total => (overridePrice ?? product.price) * quantity;

  CartItem copyWith({
    Product? product,
    int? quantity,
    double? overridePrice,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      overridePrice: overridePrice ?? this.overridePrice,
    );
  }

  @override
  List<Object?> get props => [product, quantity, overridePrice];
}
