class Customer {
  final String? id;
  final String name;
  final String phone;
  final DateTime? createdAt;

  Customer({
    this.id,
    required this.name,
    required this.phone,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
  };

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: json['id'],
    name: json['name'],
    phone: json['phone'],
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'])
        : null,
  );
}