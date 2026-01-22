// ============================================
// SUPABASE SERVICE - Part 1 (Top Half)
// lib/services/supabase_service.dart
// ============================================

import 'dart:io';
import 'dart:typed_data';
import 'package:izc_inventory/services/session_service.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../dashboard/receipt_page.dart';
import '../models/cart_item_model.dart';
import '../models/customer_model.dart';
import '../models/detail_sale_item.dart';
import '../models/product_model.dart';
import '../models/sales_model.dart';
import 'dart:async';

class SupabaseService {
  // Singleton pattern
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  // Supabase client
  final _supabase = Supabase.instance.client;

  // Stream controllers for manual realtime updates
  final _productsController = StreamController<List<Product>>.broadcast();
  final _stockHistoryController = StreamController<List<StockHistory>>.broadcast();

  // ============================================
  // IMAGE UPLOAD METHODS
  // ============================================

  /// Upload product image to Supabase Storage
  /// Returns the public URL of the uploaded image
  Future<String> uploadProductImage(Uint8List imageFile, String productSku) async {
    try {
      // Generate unique filename using SKU and timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final fileName = '${productSku}_$timestamp.jpg';
      final filePath = 'products/$fileName';

      print('📤 Uploading image: $filePath');

      // Upload to Supabase Storage
      await _supabase.storage
          .from('products')
          .uploadBinary(filePath, imageFile);

      // Get public URL
      final publicUrl = _supabase.storage
          .from('products')
          .getPublicUrl(filePath);

      print('✅ Image uploaded: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('❌ Image upload failed: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Delete product image from Supabase Storage
  Future<void> deleteProductImage(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return;

    try {
      // Extract file path from URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;

      // Find the index of 'product-images' in the path
      final bucketIndex = pathSegments.indexOf('products');
      if (bucketIndex == -1) {
        print('⚠️ Could not find bucket in URL: $imageUrl');
        return;
      }

      // Get the path after the bucket name
      final filePath = pathSegments.sublist(bucketIndex + 1).join('/');

      print('🗑️ Deleting image: $filePath');

      // Delete from storage
      await _supabase.storage
          .from('products')
          .remove([filePath]);

      print('✅ Image deleted successfully');
    } catch (e) {
      print('⚠️ Error deleting image: $e');
      // Don't throw error, just log it
    }
  }

  /// Update existing product image
  /// Deletes old image and uploads new one
  Future<String> updateProductImage(
      String? oldImageUrl,
      Uint8List newImageFile,
      String productSku,
      ) async {
    // Delete old image if exists
    if (oldImageUrl != null) {
      await deleteProductImage(oldImageUrl);
    }

    // Upload new image
    return await uploadProductImage(newImageFile, productSku);
  }

  // ============================================
  // USER PROFILE OPERATIONS (UPDATED)
  // ============================================

  /// Get current user ID from SessionService
  String? getCurrentUserId() {
    return SessionService.getUserId();
  }

  /// Get current user email from SessionService
  String? getCurrentUserEmail() {
    return SessionService.getEmail();
  }

  /// Check if current user is admin from SessionService
  Future<bool> isCurrentUserAdmin() async {
    return SessionService.isAdmin();
  }

  /// Get current user profile (if you still need this method)
  Future<UserProfile?> getCurrentUserProfile() async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) return null;

      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  // ============================================
  // PRODUCT OPERATIONS (UPDATED WITH IMAGE SUPPORT)
  // ============================================

  /// Fetch all products from database
  Future<List<Product>> fetchProducts() async {
    try {
      final response = await _supabase
          .from('products')
          .select()
          .order('created_at', ascending: false);

      final products = (response as List)
          .map((json) => Product.fromJson(json))
          .toList();

      // Emit to stream controller
      _productsController.add(products);

      return products;
    } catch (e) {
      print('Error fetching products: $e');
      throw Exception('Failed to load products: ${e.toString()}');
    }
  }

  /// Add new product with optional image (Admin only - enforced by RLS)
  Future<Product> addProduct(Product product, {Uint8List? imageFile}) async {
    try {
      String? imageUrl;

      // Upload image if provided
      if (imageFile != null) {
        imageUrl = await uploadProductImage(imageFile, product.sku);
      }

      // Create product with image URL
      final productData = product.toJson();
      productData['created_by'] = getCurrentUserId();
      if (imageUrl != null) {
        productData['image_url'] = imageUrl;
      }

      final response = await _supabase
          .from('products')
          .insert(productData)
          .select()
          .single();

      final newProduct = Product.fromJson(response);

      // Refresh products list
      await fetchProducts();

      return newProduct;
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

  /// Update existing product with optional new image (Admin only - enforced by RLS)
  Future<Product> updateProduct(
      String id,
      Product product, {
        Uint8List? newImageBytes,
      }) async {
    try {
      String? imageUrl = product.imageUrl;

      // If new image provided, upload it and delete old one
      if (newImageBytes != null) {
        imageUrl = await updateProductImage(
          product.imageUrl,
          newImageBytes,
          product.sku,
        );
      }

      // Update product data
      final productData = product.toJson();
      productData['image_url'] = imageUrl;

      final response = await _supabase
          .from('products')
          .update(productData)
          .eq('id', id)
          .select()
          .single();

      final updatedProduct = Product.fromJson(response);

      // Refresh products list
      await fetchProducts();

      return updatedProduct;
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

  /// Delete product and its image (Admin only - enforced by RLS)
  Future<void> deleteProduct(String id) async {
    try {
      // Get product to find image URL
      final response = await _supabase
          .from('products')
          .select()
          .eq('id', id)
          .single();

      final product = Product.fromJson(response);

      // Delete image if exists
      if (product.imageUrl != null) {
        await deleteProductImage(product.imageUrl);
      }

      // Delete product from database
      await _supabase
          .from('products')
          .delete()
          .eq('id', id);

      // Refresh products list
      await fetchProducts();
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

      // Refresh both products and stock history
      await fetchProducts();
      await fetchStockHistory();

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
      print('🔍 Fetching from stock_history table...');

      final response = await _supabase
          .from('stock_history')
          .select('*, products(name)')
          .order('created_at', ascending: false)
          .limit(limit);

      print('📦 Raw response from stock_history: $response');
      print('📦 Number of records: ${(response as List).length}');

      if ((response as List).isEmpty) {
        print('⚠️ No records in stock_history table');
        _stockHistoryController.add([]);
        return [];
      }

      final historyList = (response as List).map((item) {
        print('Processing history item: $item');

        String productName = 'Unknown';
        if (item['products'] != null) {
          productName = item['products']['name'] as String;
        }

        return StockHistory(
          id: item['id'] as String,
          productId: item['product_id'] as String,
          productName: productName,
          oldStock: item['old_stock'] as int?,
          newStock: item['new_stock'] as int,
          reason: item['reason'] as String? ?? 'No reason',
          createdAt: DateTime.parse(item['created_at'] as String),
        );
      }).toList();

      print('✅ Successfully converted ${historyList.length} history items');

      // Emit to stream controller
      _stockHistoryController.add(historyList);

      return historyList;
    } catch (e) {
      print('❌ Error fetching stock_history: $e');
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
  // REAL-TIME SUBSCRIPTIONS (FIXED)
  // ============================================

  /// Listen to product changes in real-time
  /// Using polling instead of websockets to avoid realtime errors
  Stream<List<Product>> watchProducts() {
    // Start periodic polling
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        await fetchProducts();
      } catch (e) {
        print('Error polling products: $e');
      }
    });

    return _productsController.stream;
  }

  /// Listen to stock history changes in real-time
  /// Using polling instead of websockets to avoid realtime errors
  Stream<List<StockHistory>> watchStockHistory({int limit = 10}) {
    print('👀 Setting up stock_history polling...');

    // Start periodic polling
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        await fetchStockHistory(limit: limit);
      } catch (e) {
        print('Error polling stock history: $e');
      }
    });

    return _stockHistoryController.stream;
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
          'role': 'user',
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
    buffer.writeln('Product,SKU,Stock,Price,Status,Image URL,Created At');

    for (final product in products) {
      final status = product.isOutOfStock
          ? 'Out of Stock'
          : (product.isActive ? 'Active' : 'Inactive');

      final createdAt = product.createdAt?.toIso8601String() ?? 'N/A';
      final imageUrl = product.imageUrl ?? 'No Image';

      buffer.writeln(
          '"${product.name}","${product.sku}",${product.stock},"${product.priceFormatted}","$status","$imageUrl","$createdAt"');
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
          '"${entry.productName}",${entry.oldStock ?? 'N/A'},${entry.newStock},,"${entry.reason}","$type","$date"');
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
  // CUSTOMER MANAGEMENT
  // ============================================

  /// Find customer by phone or create new one
  Future<Customer> findOrCreateCustomer(String name, String phone) async {
    try {
      final existingCustomers = await _supabase
          .from('customers')
          .select()
          .eq('phone', phone)
          .limit(1);

      if (existingCustomers.isNotEmpty) {
        print('Existing customer found: $phone');
        return Customer.fromJson(existingCustomers.first);
      }

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
  // SALES PROCESSING
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

      for (final item in items) {
        print('Processing item: ${item.name} x ${item.qty}');

        if (item.name.isEmpty) {
          throw Exception('Product name is missing for item with ID: ${item.productId}');
        }

        await _supabase.from('sale_items').insert({
          'sale_id': saleId,
          'product_id': item.productId,
          'quantity': item.qty,
          'price': item.price,
          'total': item.price * item.qty,
        });

        final product = await _supabase
            .from('products')
            .select('stock, name')
            .eq('id', item.productId)
            .single();

        final currentStock = product['stock'] as int;
        final productName = product['name'] as String;
        final newStock = currentStock - item.qty;

        print('Updating stock for $productName: $currentStock -> $newStock');

        await _supabase
            .from('products')
            .update({'stock': newStock})
            .eq('id', item.productId);

        await _supabase.from('stock_history').insert({
          'product_id': item.productId,
          'product_name': productName,
          'old_stock': currentStock,
          'new_stock': newStock,
          'change_amount': -item.qty,
          'reason': 'Sale #$saleId',
          'is_restock': false,
        });
      }

      print('Sale completed successfully!');

      // Refresh data after sale
      await fetchProducts();
      await fetchStockHistory();

      return saleId;
    } catch (e) {
      print('Error creating sale: $e');
      throw Exception('Failed to create sale: ${e.toString()}');
    }
  }

  // ============================================
  // SALES QUERIES - UPDATED WITH IMAGE URL
  // ============================================

  /// Get sales history - WITH IMAGE URL
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
                sku,
                image_url
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

  /// Get sales by customer - WITH IMAGE URL
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
                sku,
                image_url
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

  /// Get sales history by date range
  Future<List<Map<String, dynamic>>> getSalesHistoryByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    int limit = 100,
  }) async {
    final response = await _supabase
        .from('sales')
        .select('*, customers(*)')
        .gte('sale_date', startDate.toIso8601String())
        .lte('sale_date', endDate.toIso8601String())
        .order('sale_date', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response as List);
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

  /// Get best selling products - WITH IMAGE URL
  Future<List<Map<String, dynamic>>> getBestSellingProducts({int limit = 10}) async {
    try {
      final sales = await getSalesHistory(limit: 1000);
      final Map<String, Map<String, dynamic>> productSales = {};

      for (var sale in sales) {
        final items = sale['sale_items'] as List;
        for (var item in items) {
          final productId = item['product_id'];
          final quantity = item['quantity'] as int;
          final total = (item['total'] as num).toDouble();
          final productData = item['products'];
          final productName = productData['name'];
          final productSku = productData['sku'];
          final productImageUrl = productData['image_url'] as String?; // Get image URL

          if (productSales.containsKey(productId)) {
            productSales[productId]!['total_quantity'] += quantity;
            productSales[productId]!['total_revenue'] += total;
          } else {
            productSales[productId] = {
              'product_id': productId,
              'product_name': productName,
              'product_sku': productSku,
              'product_image_url': productImageUrl, // Include image URL
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
  // SALE DETAILS
  // ============================================

  /// Get sale by ID
  Future<Sale> getSaleById(String saleId) async {
    try {
      final response = await _supabase
          .from('sales')
          .select()
          .eq('id', saleId)
          .single();
      return Sale.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch sale: $e');
    }
  }

  /// Get detailed sale items from the view
  Future<List<DetailedSaleItem>> getDetailedSaleItems(String saleId) async {
    try {
      final response = await _supabase
          .from('detailed_sale_items')
          .select()
          .eq('sale_id', saleId);
      return (response as List)
          .map((item) => DetailedSaleItem.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch sale items: $e');
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