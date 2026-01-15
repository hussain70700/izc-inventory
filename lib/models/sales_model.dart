class Sale {
  final String? id;
  final String customerId;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final String paymentMethod;
  final DateTime saleDate;
  final String? notes;

  Sale({
    this.id,
    required this.customerId,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.paymentMethod,
    required this.saleDate,
    this.notes,
  });

  factory Sale.fromJson(Map<String, dynamic> json) => Sale(
    id: json['id'],
    customerId: json['customer_id'],
    subtotal: (json['subtotal'] as num).toDouble(),
    discount: (json['discount'] as num).toDouble(),
    tax: (json['tax'] as num).toDouble(),
    total: (json['total'] as num).toDouble(),
    paymentMethod: json['payment_method'],
    saleDate: DateTime.parse(json['sale_date']),
    notes: json['notes'],
  );
}