class CartItem {
  final String productId;
  final String name;
  final String sku;
  final double price;
  int qty;
  final int availableStock;

  CartItem({
    required this.productId,
    required this.name,
    required this.sku,
    required this.price,
    required this.qty,
    required this.availableStock,
  });
}