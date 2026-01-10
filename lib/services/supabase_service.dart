// ============================================
// SUPABASE SERVICE
// lib/services/supabase_service.dart
// ============================================

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';

class SupabaseService {
  // Singleton pattern
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  // Supabase client
  final _supabase = Supabase.instance.client;

  // ============================================
  // USER PROFILE OPERATIONS
  // ============================================

  /// Get current user profile from profiles table
  Future<UserProfile?> getCurrentUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  /// Check if current user is admin
  Future<bool> isCurrentUserAdmin() async {
    final profile = await getCurrentUserProfile();
    return profile?.isAdmin ?? false;
  }

  /// Get current user ID
  String? getCurrentUserId() {
    return _supabase.auth.currentUser?.id;
  }

  /// Get current user email
  String? getCurrentUserEmail() {
    return _supabase.auth.currentUser?.email;
  }

  // ============================================
  // PRODUCT OPERATIONS
  // ============================================

  /// Fetch all products from database
  Future<List<Product>> fetchProducts() async {
    try {
      final response = await _supabase
          .from('products')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Product.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching products: $e');
      throw Exception('Failed to load products: ${e.toString()}');
    }
  }

  /// Add new product (Admin only - enforced by RLS)
  Future<Product> addProduct(Product product) async {
    try {
      final response = await _supabase
          .from('products')
          .insert({
        ...product.toJson(),
        'created_by': getCurrentUserId(),
      })
          .select()
          .single();

      return Product.fromJson(response);
    } catch (e) {
      print('Error adding product: $e');

      // Check if it's a permission error
      if (e.toString().toLowerCase().contains('permission') ||
          e.toString().toLowerCase().contains('policy') ||
          e.toString().toLowerCase().contains('rls')) {
        throw Exception('Only admins can add products');
      }

      // Check for duplicate SKU
      if (e.toString().toLowerCase().contains('duplicate') ||
          e.toString().toLowerCase().contains('unique')) {
        throw Exception('SKU already exists');
      }

      throw Exception('Failed to add product: ${e.toString()}');
    }
  }

  /// Update existing product (Admin only - enforced by RLS)
  Future<Product> updateProduct(String id, Product product) async {
    try {
      final response = await _supabase
          .from('products')
          .update(product.toJson())
          .eq('id', id)
          .select()
          .single();

      return Product.fromJson(response);
    } catch (e) {
      print('Error updating product: $e');

      if (e.toString().toLowerCase().contains('permission') ||
          e.toString().toLowerCase().contains('policy') ||
          e.toString().toLowerCase().contains('rls')) {
        throw Exception('Only admins can update products');
      }

      if (e.toString().toLowerCase().contains('duplicate') ||
          e.toString().toLowerCase().contains('unique')) {
        throw Exception('SKU already exists');
      }

      throw Exception('Failed to update product: ${e.toString()}');
    }
  }

  /// Delete product (Admin only - enforced by RLS)
  Future<void> deleteProduct(String id) async {
    try {
      await _supabase
          .from('products')
          .delete()
          .eq('id', id);
    } catch (e) {
      print('Error deleting product: $e');

      if (e.toString().toLowerCase().contains('permission') ||
          e.toString().toLowerCase().contains('policy') ||
          e.toString().toLowerCase().contains('rls')) {
        throw Exception('Only admins can delete products');
      }

      throw Exception('Failed to delete product: ${e.toString()}');
    }
  }

  /// Update product stock (for restock functionality)
  Future<Product> updateProductStock(String id, int newStock, String reason) async {
    try {
      // Update only the stock
      final response = await _supabase
          .from('products')
          .update({'stock': newStock})
          .eq('id', id)
          .select()
          .single();

      // The stock history will be automatically logged by the database trigger

      return Product.fromJson(response);
    } catch (e) {
      print('Error updating stock: $e');

      if (e.toString().toLowerCase().contains('permission') ||
          e.toString().toLowerCase().contains('policy') ||
          e.toString().toLowerCase().contains('rls')) {
        throw Exception('Only admins can update stock');
      }

      throw Exception('Failed to update stock: ${e.toString()}');
    }
  }

  // ============================================
  // STOCK HISTORY OPERATIONS
  // ============================================

  /// Fetch stock history with optional limit
  Future<List<StockHistory>> fetchStockHistory({int limit = 10}) async {
    try {
      final response = await _supabase
          .from('stock_history')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => StockHistory.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching stock history: $e');
      return [];
    }
  }

  /// Fetch stock history for a specific product
  Future<List<StockHistory>> fetchProductStockHistory(String productId, {int limit = 20}) async {
    try {
      final response = await _supabase
          .from('stock_history')
          .select()
          .eq('product_id', productId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => StockHistory.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching product stock history: $e');
      return [];
    }
  }

  // ============================================
  // REAL-TIME SUBSCRIPTIONS
  // ============================================

  /// Listen to product changes in real-time
  Stream<List<Product>> watchProducts() {
    return _supabase
        .from('products')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => Product.fromJson(json)).toList());
  }

  /// Listen to stock history changes in real-time
  Stream<List<StockHistory>> watchStockHistory({int limit = 10}) {
    return _supabase
        .from('stock_history')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(limit)
        .map((data) => data.map((json) => StockHistory.fromJson(json)).toList());
  }

  // ============================================
  // STATISTICS & ANALYTICS
  // ============================================

  /// Calculate total inventory value
  Future<double> calculateTotalInventoryValue() async {
    try {
      final products = await fetchProducts();
      return products.fold<double>(0.0, (sum, product) => sum + (product.price * product.stock));
    } catch (e) {
      print('Error calculating inventory value: $e');
      return 0.0;
    }
  }

  /// Get low stock products count
  Future<int> getLowStockCount() async {
    try {
      final products = await fetchProducts();
      return products.where((p) => p.isLowStock).length;
    } catch (e) {
      print('Error getting low stock count: $e');
      return 0;
    }
  }

  /// Get out of stock products count
  Future<int> getOutOfStockCount() async {
    try {
      final products = await fetchProducts();
      return products.where((p) => p.isOutOfStock).length;
    } catch (e) {
      print('Error getting out of stock count: $e');
      return 0;
    }
  }

  /// Get active products count
  Future<int> getActiveProductsCount() async {
    try {
      final products = await fetchProducts();
      return products.where((p) => p.isActive).length;
    } catch (e) {
      print('Error getting active products count: $e');
      return 0;
    }
  }

  /// Get inactive products count
  Future<int> getInactiveProductsCount() async {
    try {
      final products = await fetchProducts();
      return products.where((p) => !p.isActive).length;
    } catch (e) {
      print('Error getting inactive products count: $e');
      return 0;
    }
  }

  // ============================================
  // AUTHENTICATION
  // ============================================

  /// Sign out current user
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
      throw Exception('Failed to sign out: ${e.toString()}');
    }
  }

  /// Check if user is authenticated
  bool isAuthenticated() {
    return _supabase.auth.currentUser != null;
  }

  /// Get current session
  Session? getCurrentSession() {
    return _supabase.auth.currentSession;
  }

  /// Sign in with email and password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      print('Error signing in: $e');
      throw Exception('Failed to sign in: ${e.toString()}');
    }
  }

  /// Sign up with email and password
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'role': 'user', // Default role
        },
      );
      return response;
    } catch (e) {
      print('Error signing up: $e');
      throw Exception('Failed to sign up: ${e.toString()}');
    }
  }

  // ============================================
  // EXPORT FUNCTIONALITY
  // ============================================

  /// Generate CSV string from products
  String generateProductsCSV(List<Product> products) {
    final buffer = StringBuffer();
    buffer.writeln('Product,SKU,Stock,Price,Status,Created At');

    for (final product in products) {
      final status = product.isOutOfStock
          ? 'Out of Stock'
          : (product.isActive ? 'Active' : 'Inactive');

      final createdAt = product.createdAt?.toIso8601String() ?? 'N/A';

      buffer.writeln(
          '"${product.name}","${product.sku}",${product.stock},"${product.priceFormatted}","$status","$createdAt"');
    }

    return buffer.toString();
  }

  /// Generate CSV string from stock history
  String generateStockHistoryCSV(List<StockHistory> history) {
    final buffer = StringBuffer();
    buffer.writeln('Product,Old Stock,New Stock,Change,Reason,Type,Date');

    for (final entry in history) {
      final type = entry.isRestock ? 'Restock' : 'Sale/Update';
      final date = entry.createdAt.toIso8601String();

      buffer.writeln(
          '"${entry.productName}",${entry.oldStock ?? 'N/A'},${entry.newStock},${entry.changeAmount},"${entry.reason}","$type","$date"');
    }

    return buffer.toString();
  }

  // ============================================
  // SEARCH & FILTER OPERATIONS
  // ============================================

  /// Search products by name or SKU
  Future<List<Product>> searchProducts(String query) async {
    try {
      final response = await _supabase
          .from('products')
          .select()
          .or('name.ilike.%$query%,sku.ilike.%$query%')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Product.fromJson(json))
          .toList();
    } catch (e) {
      print('Error searching products: $e');
      return [];
    }
  }

  /// Filter products by status
  Future<List<Product>> filterProductsByStatus({
    bool? isActive,
    bool? isOutOfStock,
    bool? isLowStock,
  }) async {
    try {
      var query = _supabase.from('products').select();

      if (isActive != null) {
        query = query.eq('is_active', isActive);
      }

      if (isOutOfStock != null && isOutOfStock) {
        query = query.eq('stock', 0);
      }

      final response = await query.order('created_at', ascending: false);

      var products = (response as List)
          .map((json) => Product.fromJson(json))
          .toList();

      // Filter for low stock (can't do this in SQL easily with the current schema)
      if (isLowStock != null && isLowStock) {
        products = products.where((p) => p.isLowStock).toList();
      }

      return products;
    } catch (e) {
      print('Error filtering products: $e');
      return [];
    }
  }

  // ============================================
  // BULK OPERATIONS
  // ============================================

  /// Bulk update product status
  Future<void> bulkUpdateProductStatus(List<String> productIds, bool isActive) async {
    try {
      await _supabase
          .from('products')
          .update({'is_active': isActive})
          .inFilter('id', productIds);
    } catch (e) {
      print('Error bulk updating products: $e');
      throw Exception('Failed to bulk update products: ${e.toString()}');
    }
  }

  /// Bulk delete products
  Future<void> bulkDeleteProducts(List<String> productIds) async {
    try {
      await _supabase
          .from('products')
          .delete()
          .inFilter('id', productIds);
    } catch (e) {
      print('Error bulk deleting products: $e');
      throw Exception('Failed to bulk delete products: ${e.toString()}');
    }
  }

  // ============================================
  // UTILITY METHODS
  // ============================================

  /// Check database connection
  Future<bool> checkConnection() async {
    try {
      await _supabase.from('products').select().limit(1);
      return true;
    } catch (e) {
      print('Database connection error: $e');
      return false;
    }
  }

  /// Get Supabase client (for advanced usage)
  SupabaseClient get client => _supabase;
}