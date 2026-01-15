// ============================================
// SUPABASE SERVICE - Updated with Sales Integration
// lib/services/supabase_service.dart
// ============================================

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cart_item_model.dart';
import '../models/customer_model.dart';
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
  // CUSTOMER MANAGEMENT (NEW)
  // ============================================

  /// Find customer by phone or create new one
  Future<Customer> findOrCreateCustomer(String name, String phone) async {
    try {
      // First, try to find existing customer by phone
      final existingCustomers = await _supabase
          .from('customers')
          .select()
          .eq('phone', phone)
          .limit(1);

      if (existingCustomers.isNotEmpty) {
        // Customer exists, return it
        print('Existing customer found: $phone');
        return Customer.fromJson(existingCustomers.first);
      }

      // Customer doesn't exist, create new one
      print('Creating new customer: $name - $phone');
      final newCustomer = await _supabase
          .from('customers')
          .insert({
        'name': name,
        'phone': phone,
      })
          .select()
          .single();

      return Customer.fromJson(newCustomer);
    } catch (e) {
      print('Error processing customer: $e');
      throw Exception('Failed to process customer: ${e.toString()}');
    }
  }

  /// Get all customers
  Future<List<Customer>> getAllCustomers() async {
    try {
      final response = await _supabase
          .from('customers')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Customer.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching customers: $e');
      throw Exception('Failed to fetch customers: ${e.toString()}');
    }
  }

  /// Search customers by name or phone
  Future<List<Customer>> searchCustomers(String query) async {
    try {
      final response = await _supabase
          .from('customers')
          .select()
          .or('name.ilike.%$query%,phone.ilike.%$query%')
          .order('name');

      return (response as List)
          .map((json) => Customer.fromJson(json))
          .toList();
    } catch (e) {
      print('Error searching customers: $e');
      return [];
    }
  }

  // ============================================
  // SALES PROCESSING (NEW)
  // ============================================

  /// Create a sale and update inventory
  Future<String> createSale({
    required String customerId,
    required List<CartItem> items,
    required double subtotal,
    required double discount,
    required double tax,
    required double total,
    required String paymentMethod,
    String? notes,
  }) async {
    try {
      print('Creating sale for customer: $customerId');
      print('Items count: ${items.length}');
      print('Total: \$${total.toStringAsFixed(2)}');

      // 1. Create the sale record
      final saleData = await _supabase
          .from('sales')
          .insert({
        'customer_id': customerId,
        'subtotal': subtotal,
        'discount': discount,
        'tax': tax,
        'total': total,
        'payment_method': paymentMethod,
        'notes': notes,
        'sale_date': DateTime.now().toIso8601String(),
      })
          .select()
          .single();

      final saleId = saleData['id'];
      print('Sale created with ID: $saleId');

      // 2. Create sale items and update inventory
      for (final item in items) {
        print('Processing item: ${item.name} x ${item.qty}');

        // Validate that product name exists
        if (item.name.isEmpty) {
          throw Exception('Product name is missing for item with ID: ${item.productId}');
        }

        // Insert sale item
        await _supabase.from('sale_items').insert({
          'sale_id': saleId,
          'product_id': item.productId,
          'quantity': item.qty,
          'price': item.price,
          'total': item.price * item.qty,
        });

        // Get current product stock AND name from database to ensure consistency
        final product = await _supabase
            .from('products')
            .select('stock, name')
            .eq('id', item.productId)
            .single();

        final currentStock = product['stock'] as int;
        final productName = product['name'] as String;
        final newStock = currentStock - item.qty;

        print('Updating stock for $productName: $currentStock -> $newStock');

        // Update product stock
        await _supabase
            .from('products')
            .update({'stock': newStock})
            .eq('id', item.productId);

        // Add to stock history with verified product name from database
        await _supabase.from('stock_history').insert({
          'product_id': item.productId,
          'product_name': productName,  // Use name from database, not from cart
          'old_stock': currentStock,
          'new_stock': newStock,
          'change_amount': -item.qty,  // Correct column name
          'reason': 'Sale #$saleId',
          'is_restock': false,
        });
      }

      print('Sale completed successfully!');
      return saleId;
    } catch (e) {
      print('Error creating sale: $e');
      throw Exception('Failed to create sale: ${e.toString()}');
    }
  }
  /// Get sales history
  Future<List<Map<String, dynamic>>> getSalesHistory({int limit = 50}) async {
    try {
      final response = await _supabase
          .from('sales')
          .select('''
            *,
            customers (
              name,
              phone
            ),
            sale_items (
              *,
              products (
                name,
                sku
              )
            )
          ''')
          .order('sale_date', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching sales history: $e');
      throw Exception('Failed to fetch sales history: ${e.toString()}');
    }
  }

  /// Get sales by customer
  Future<List<Map<String, dynamic>>> getSalesByCustomer(String customerId) async {
    try {
      final response = await _supabase
          .from('sales')
          .select('''
            *,
            sale_items (
              *,
              products (
                name,
                sku
              )
            )
          ''')
          .eq('customer_id', customerId)
          .order('sale_date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching customer sales: $e');
      throw Exception('Failed to fetch customer sales: ${e.toString()}');
    }
  }

  /// Get daily sales total
  Future<double> getDailySalesTotal() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final response = await _supabase
          .from('sales')
          .select('total')
          .gte('sale_date', startOfDay.toIso8601String());

      double total = 0;
      for (var sale in response) {
        total += (sale['total'] as num).toDouble();
      }

      return total;
    } catch (e) {
      print('Error calculating daily sales: $e');
      return 0.0;
    }
  }

  /// Get monthly sales total
  Future<double> getMonthlySalesTotal() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);

      final response = await _supabase
          .from('sales')
          .select('total')
          .gte('sale_date', startOfMonth.toIso8601String());

      double total = 0;
      for (var sale in response) {
        total += (sale['total'] as num).toDouble();
      }

      return total;
    } catch (e) {
      print('Error calculating monthly sales: $e');
      return 0.0;
    }
  }

  /// Get sales count today
  Future<int> getTodaySalesCount() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final response = await _supabase
          .from('sales')
          .select('id')
          .gte('sale_date', startOfDay.toIso8601String());

      return response.length;
    } catch (e) {
      print('Error getting today sales count: $e');
      return 0;
    }
  }

  /// Get best selling products
  Future<List<Map<String, dynamic>>> getBestSellingProducts({int limit = 10}) async {
    try {
      // This would ideally be done with a SQL query, but we'll process it in Dart
      final sales = await getSalesHistory(limit: 1000);
      final Map<String, Map<String, dynamic>> productSales = {};

      for (var sale in sales) {
        final items = sale['sale_items'] as List;
        for (var item in items) {
          final productId = item['product_id'];
          final quantity = item['quantity'] as int;
          final total = (item['total'] as num).toDouble();
          final productName = item['products']['name'];
          final productSku = item['products']['sku'];

          if (productSales.containsKey(productId)) {
            productSales[productId]!['total_quantity'] += quantity;
            productSales[productId]!['total_revenue'] += total;
          } else {
            productSales[productId] = {
              'product_id': productId,
              'product_name': productName,
              'product_sku': productSku,
              'total_quantity': quantity,
              'total_revenue': total,
            };
          }
        }
      }

      final sortedProducts = productSales.values.toList()
        ..sort((a, b) => (b['total_quantity'] as int).compareTo(a['total_quantity'] as int));

      return sortedProducts.take(limit).toList();
    } catch (e) {
      print('Error getting best selling products: $e');
      return [];
    }
  }

  // ============================================
  // SALES EXPORT
  // ============================================

  /// Generate CSV string from sales
  String generateSalesCSV(List<Map<String, dynamic>> sales) {
    final buffer = StringBuffer();
    buffer.writeln('Sale ID,Date,Customer,Phone,Subtotal,Discount,Tax,Total,Payment Method');

    for (final sale in sales) {
      final customer = sale['customers'];
      final saleDate = DateTime.parse(sale['sale_date']).toString();

      buffer.writeln(
          '"${sale['id']}","$saleDate","${customer['name']}","${customer['phone']}",${sale['subtotal']},${sale['discount']},${sale['tax']},${sale['total']},"${sale['payment_method']}"');
    }

    return buffer.toString();
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