
class Product {
  final String id;
  final String name;
  final String sku;
  final int stock;
  final double price;
  final bool isActive;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.stock,
    required this.price,
    required this.isActive,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  // Computed properties
  bool get isLowStock => stock > 0 && stock <= 10;
  bool get isOutOfStock => stock == 0;
  String get priceFormatted => '\$${price.toStringAsFixed(2)}';

  // Create Product from JSON (from Supabase)
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      sku: json['sku'] as String,
      stock: json['stock'] as int,
      price: (json['price'] as num).toDouble(),
      isActive: json['is_active'] as bool,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  // Convert Product to JSON (for Supabase)
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'sku': sku,
      'stock': stock,
      'price': price,
      'is_active': isActive,
    };
  }

  // Create a copy of Product with updated fields
  Product copyWith({
    String? id,
    String? name,
    String? sku,
    int? stock,
    double? price,
    bool? isActive,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      stock: stock ?? this.stock,
      price: price ?? this.price,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Product(id: $id, name: $name, sku: $sku, stock: $stock, price: $price, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// ============================================
// STOCK HISTORY MODEL
// ============================================

class StockHistory {
  final String id;
  final String productId;
  final String productName;
  final int? oldStock;
  final int newStock;
  final int changeAmount;
  final String reason;
  final bool isRestock;
  final String? changedBy;
  final DateTime createdAt;

  StockHistory({
    required this.id,
    required this.productId,
    required this.productName,
    this.oldStock,
    required this.newStock,
    required this.changeAmount,
    required this.reason,
    required this.isRestock,
    this.changedBy,
    required this.createdAt,
  });

  // Create StockHistory from JSON
  factory StockHistory.fromJson(Map<String, dynamic> json) {
    return StockHistory(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      oldStock: json['old_stock'] as int?,
      newStock: json['new_stock'] as int,
      changeAmount: json['change_amount'] as int,
      reason: json['reason'] as String,
      isRestock: json['is_restock'] as bool,
      changedBy: json['changed_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_name': productName,
      'old_stock': oldStock,
      'new_stock': newStock,
      'change_amount': changeAmount,
      'reason': reason,
      'is_restock': isRestock,
    };
  }

  // Get human-readable time ago
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '${years}y ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    } else if (difference.inDays > 0) {
      return difference.inDays == 1 ? 'Yesterday' : '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  String toString() {
    return 'StockHistory(productName: $productName, change: $changeAmount, reason: $reason)';
  }
}

// ============================================
// USER PROFILE MODEL
// ============================================

class UserProfile {
  final String id;
  final String email;
  final String? fullName;
  final String role;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserProfile({
    required this.id,
    required this.email,
    this.fullName,
    required this.role,
    this.createdAt,
    this.updatedAt,
  });

  // Role checks
  bool get isAdmin => role == 'admin';
  bool get isManager => role == 'manager';
  bool get isUser => role == 'user';

  // Create UserProfile from JSON
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      role: json['role'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role,
    };
  }

  // Create a copy with updated fields
  UserProfile copyWith({
    String? id,
    String? email,
    String? fullName,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'UserProfile(id: $id, email: $email, role: $role)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}