// ============================================
// PRODUCT MODEL - With Image Support
// lib/models/product_model.dart
// ============================================

class Product {
  final String id;
  final String name;
  final String sku;
  final int stock;
  final double price;
  final bool isActive;
  final String? imageUrl; // Image URL from Supabase Storage
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
    this.imageUrl,
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
      imageUrl: json['image_url'] as String?, // Parse image URL
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
      'image_url': imageUrl, // Include image URL when updating
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
    String? imageUrl,
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
      imageUrl: imageUrl ?? this.imageUrl,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Product(id: $id, name: $name, sku: $sku, stock: $stock, price: $price, isActive: $isActive, imageUrl: $imageUrl)';
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
  final String reason;
  final DateTime createdAt;

  StockHistory({
    required this.id,
    required this.productId,
    required this.productName,
    this.oldStock,
    required this.newStock,
    required this.reason,
    required this.createdAt,
  });

  factory StockHistory.fromJson(Map<String, dynamic> json) {
    print('🔧 Parsing StockHistory from: $json');

    try {
      // Handle product name - it could be in different places
      String productName = 'Unknown Product';

      if (json['products'] != null) {
        // If using .select('*, products!inner(name)')
        if (json['products'] is Map) {
          productName = json['products']['name'] as String? ?? 'Unknown';
        } else if (json['products'] is List && (json['products'] as List).isNotEmpty) {
          productName = json['products'][0]['name'] as String? ?? 'Unknown';
        }
      } else if (json['product_name'] != null) {
        // If product name is directly in the row
        productName = json['product_name'] as String;
      }

      print('  ✓ Product name: $productName');

      return StockHistory(
        id: json['id'] as String,
        productId: json['product_id'] as String,
        productName: productName,
        oldStock: json['old_stock'] as int?,
        newStock: json['new_stock'] as int,
        reason: json['reason'] as String? ?? 'No reason provided',
        createdAt: DateTime.parse(json['created_at'] as String),
      );
    } catch (e) {
      print('❌ Error parsing StockHistory: $e');
      print('   JSON was: $json');
      rethrow;
    }
  }

  bool get isRestock {
    if (oldStock == null) return true; // Initial stock is considered restock
    return newStock > oldStock!;
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
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
    return 'StockHistory(product: $productName, $oldStock → $newStock, reason: $reason)';
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