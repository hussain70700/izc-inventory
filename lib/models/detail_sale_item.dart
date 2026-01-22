class DetailedSaleItem {
  final String id;
  final String saleId;
  final DateTime saleDate;
  final String customerId;
  final String customerName;
  final String productId;
  final String productName;
  final String sku;
  final String? productImageUrl; // Added image URL field
  final int quantity;
  final double price;
  final double total;

  DetailedSaleItem({
    required this.id,
    required this.saleId,
    required this.saleDate,
    required this.customerId,
    required this.customerName,
    required this.productId,
    required this.productName,
    required this.sku,
    this.productImageUrl, // Optional parameter
    required this.quantity,
    required this.price,
    required this.total,
  });

  factory DetailedSaleItem.fromJson(Map<String, dynamic> json) {
    return DetailedSaleItem(
      id: json['id'],
      saleId: json['sale_id'],
      saleDate: DateTime.parse(json['sale_date']),
      customerId: json['customer_id'],
      customerName: json['customer_name'],
      productId: json['product_id'],
      productName: json['product_name'],
      sku: json['sku'],
      productImageUrl: json['product_image_url'] as String?, // Parse image URL
      quantity: json['quantity'] as int,
      price: (json['price'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
    );
  }

  // Helper method to check if product has an image
  bool get hasImage => productImageUrl != null && productImageUrl!.isNotEmpty;

  // Convert to JSON (useful for serialization)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sale_id': saleId,
      'sale_date': saleDate.toIso8601String(),
      'customer_id': customerId,
      'customer_name': customerName,
      'product_id': productId,
      'product_name': productName,
      'sku': sku,
      'product_image_url': productImageUrl,
      'quantity': quantity,
      'price': price,
      'total': total,
    };
  }

  // Create a copy with updated fields
  DetailedSaleItem copyWith({
    String? id,
    String? saleId,
    DateTime? saleDate,
    String? customerId,
    String? customerName,
    String? productId,
    String? productName,
    String? sku,
    String? productImageUrl,
    int? quantity,
    double? price,
    double? total,
  }) {
    return DetailedSaleItem(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      saleDate: saleDate ?? this.saleDate,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      sku: sku ?? this.sku,
      productImageUrl: productImageUrl ?? this.productImageUrl,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      total: total ?? this.total,
    );
  }
}