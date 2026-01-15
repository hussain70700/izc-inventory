import 'package:flutter/material.dart';
import '../models/cart_item_model.dart';
import '../models/customer_model.dart';
import '../models/product_model.dart';
import '../models/promo_code_model.dart';
import '../services/supabase_service.dart';
import '../services/promo_code_service.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final _supabaseService = SupabaseService();
  final _promoCodeService = PromoCodeService();

  // Cart items
  final List<CartItem> cart = [];

  // Search and products
  final TextEditingController _searchController = TextEditingController();
  List<Product> _searchResults = [];
  bool _isSearching = false;
  bool _showSearchResults = false;

  // Customer
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  Customer? _selectedCustomer;
  bool _isLoadingCustomer = false;

  // Promo Code
  final TextEditingController _promoCodeController = TextEditingController();
  PromoCodeValidation? _appliedPromo;
  bool _isValidatingPromo = false;

  // Payment
  String? _selectedPaymentMethod;

  double get subtotal => cart.fold(0, (sum, item) => sum + item.price * item.qty);

  double get discount {
    double baseDiscount = 0.0;
    if (_appliedPromo != null && _appliedPromo!.isValid) {
      baseDiscount = subtotal * (_appliedPromo!.discountPercentage / 100);
    }
    return baseDiscount;
  }

  double get tax => (subtotal - discount) * 0.085;
  double get total => subtotal - discount + tax;

  @override
  void dispose() {
    _searchController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _promoCodeController.dispose();
    super.dispose();
  }

  // Search products from inventory
  Future<void> _searchProducts(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final products = await _supabaseService.searchProducts(query);
      setState(() {
        _searchResults = products.where((p) => p.isActive).toList();
        _showSearchResults = true;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      _showError('Failed to search products: $e');
    }
  }

  // Add product to cart
  void _addToCart(Product product) {
    setState(() {
      final existingIndex = cart.indexWhere((item) => item.productId == product.id);

      if (existingIndex != -1) {
        if (cart[existingIndex].qty < product.stock) {
          cart[existingIndex].qty++;
        } else {
          _showError('Cannot add more. Available stock: ${product.stock}');
        }
      } else {
        if (product.stock > 0) {
          cart.add(CartItem(
            productId: product.id,
            name: product.name,
            sku: product.sku,
            price: product.price,
            qty: 1,
            availableStock: product.stock,
          ));
        } else {
          _showError('Product is out of stock');
        }
      }

      _searchController.clear();
      _searchResults = [];
      _showSearchResults = false;
    });
  }

  // Search or create customer
  Future<void> _handleCustomer() async {
    final name = _customerNameController.text.trim();
    final phone = _customerPhoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      _showError('Please enter customer name and phone number');
      return;
    }

    setState(() => _isLoadingCustomer = true);

    try {
      final customer = await _supabaseService.findOrCreateCustomer(name, phone);

      setState(() {
        _selectedCustomer = customer;
        _isLoadingCustomer = false;
      });

      _showSuccess(customer.id != null
          ? 'Customer found!'
          : 'New customer registered!');
    } catch (e) {
      setState(() => _isLoadingCustomer = false);
      _showError('Failed to process customer: $e');
    }
  }

  void _clearCustomerSelection() {
    setState(() {
      _selectedCustomer = null;
      _customerNameController.clear();
      _customerPhoneController.clear();
      _promoCodeController.clear();
      _appliedPromo = null;
    });
  }

  // Validate and apply promo code
  Future<void> _applyPromoCode() async {
    final code = _promoCodeController.text.trim().toUpperCase();

    if (code.isEmpty) {
      _showError('Please enter a promo code');
      return;
    }

    setState(() => _isValidatingPromo = true);

    try {
      final validation = await _promoCodeService.validatePromoCode(code);

      setState(() {
        _appliedPromo = validation;
        _isValidatingPromo = false;
      });

      if (validation.isValid) {
        _showSuccess('Promo code applied! ${validation.discountPercentage}% discount');
      } else {
        _showError(validation.message);
      }
    } catch (e) {
      setState(() => _isValidatingPromo = false);
      _showError('Failed to validate promo code: $e');
    }
  }

  void _removePromoCode() {
    setState(() {
      _promoCodeController.clear();
      _appliedPromo = null;
    });
    _showSuccess('Promo code removed');
  }

  void _handlePaymentMethodSelected(String methodLabel) {
    setState(() => _selectedPaymentMethod = methodLabel);
  }

  // Process sale
  Future<void> _processSale() async {
    if (cart.isEmpty) {
      _showError('Cart is empty');
      return;
    }

    if (_selectedCustomer == null) {
      _showError('Please select a customer');
      return;
    }

    if (_selectedPaymentMethod == null) {
      _showError('Please select a payment method');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Sale'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${_selectedCustomer!.name}'),
            Text('Total Amount: \$${total.toStringAsFixed(2)}'),
            if (_appliedPromo != null && _appliedPromo!.isValid)
              Text(
                'Promo Applied: ${_appliedPromo!.discountPercentage}% OFF',
                style: const TextStyle(color: Color(0xffFE691E), fontWeight: FontWeight.bold),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xffFE691E),
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _supabaseService.createSale(
        customerId: _selectedCustomer!.id!,
        items: cart,
        subtotal: subtotal,
        discount: discount,
        tax: tax,
        total: total,
        paymentMethod: _selectedPaymentMethod!,
      );

      _showSuccess('Sale completed successfully!');

      setState(() {
        cart.clear();
        _clearCustomerSelection();
        _selectedPaymentMethod = null;
      });
    } catch (e) {
      _showError('Failed to process sale: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < 900;
        final bool isMobile = constraints.maxWidth < 600;

        return Scaffold(
          backgroundColor: const Color(0xfff5f6f8),
          body: isNarrow
              ? SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                children: [
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    color: Colors.white,
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: _searchBar(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: isMobile ? 400 : 500,
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          Container(
                            color: Colors.grey.shade200,
                            padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                              child: _cartHeader(),
                            ),
                          ),
                          const Divider(height: 1, thickness: 1),
                          Expanded(
                            child: Container(
                              color: Colors.white,
                              child: _cartList(),
                            ),
                          ),
                          Container(
                            color: Colors.grey.shade200,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                              child: _cartActions(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    color: Colors.white,
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _summaryPanel(),
                    ),
                  ),
                ],
              ),
            ),
          )
              : Row(
            children: [
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        color: Colors.white,
                        margin: EdgeInsets.zero,
                        clipBehavior: Clip.antiAlias,
                        child: _searchBar(),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          margin: EdgeInsets.zero,
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              Container(
                                color: Colors.grey.shade200,
                                padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                                  child: _cartHeader(),
                                ),
                              ),
                              const Divider(height: 1, thickness: 1),
                              Expanded(
                                child: Container(
                                  color: Colors.white,
                                  child: _cartList(),
                                ),
                              ),
                              Container(
                                color: Colors.grey.shade200,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                                  child: _cartActions(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: constraints.maxWidth < 1200 ? 350 : 400,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 8,
                        color: Colors.black12,
                      )
                    ],
                  ),
                  child: _summaryPanel(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _searchProducts,
                    decoration: InputDecoration(
                      hintText: 'Search products by name or SKU',
                      prefixIcon: _isSearching
                          ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                          : const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _showSearchResults = false;
                          });
                        },
                      )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_showSearchResults && _searchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final product = _searchResults[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        product.name[0].toUpperCase(),
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(product.name),
                    subtitle: Text('SKU: ${product.sku} • Stock: ${product.stock}'),
                    trailing: Text(
                      product.priceFormatted,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    onTap: () => _addToCart(product),
                  );
                },
              ),
            ),
          if (_showSearchResults && _searchResults.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'No products found',
                style: TextStyle(color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cartHeader() {
    return const Row(
      children: [
        Expanded(flex: 4, child: Text('PRODUCT')),
        Expanded(child: Text('PRICE')),
        Expanded(child: Text('        QTY')),
        Expanded(child: Text('TOTAL')),
      ],
    );
  }

  Widget _cartList() {
    if (cart.isEmpty) {
      return const Center(
        child: Text(
          'Cart is empty\nSearch and add products',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      itemCount: cart.length,
      separatorBuilder: (_, __) => const Divider(indent: 16, endIndent: 16),
      itemBuilder: (_, i) {
        final item = cart[i];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('SKU: ${item.sku}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Expanded(child: Text('\$${item.price.toStringAsFixed(2)}')),
              Expanded(
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.grey),
                      onPressed: () {
                        if (item.qty > 1) {
                          setState(() => item.qty--);
                        }
                      },
                    ),
                    Text(item.qty.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: Colors.grey),
                      onPressed: () {
                        if (item.qty < item.availableStock) {
                          setState(() => item.qty++);
                        } else {
                          _showError('Cannot exceed available stock: ${item.availableStock}');
                        }
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Text(
                  '\$${(item.price * item.qty).toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _cartActions() {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade400, width: 1),
          ),
          child: TextButton(
            style: ButtonStyle(
              splashFactory: NoSplash.splashFactory,
              overlayColor: MaterialStateProperty.all(Colors.transparent),
              foregroundColor: MaterialStateProperty.all(Colors.black),
            ),
            onPressed: () {},
            child: const Text('Add Note', style: TextStyle(color: Colors.black)),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade400, width: 1),
          ),
          child: TextButton(
            style: ButtonStyle(
              splashFactory: NoSplash.splashFactory,
              overlayColor: MaterialStateProperty.all(Colors.transparent),
              foregroundColor: MaterialStateProperty.all(Colors.black),
            ),
            onPressed: () {},
            child: const Text('Discount Item', style: TextStyle(color: Colors.black)),
          ),
        ),
        const Spacer(),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade400, width: 1),
          ),
          child: TextButton(
            style: ButtonStyle(
              splashFactory: NoSplash.splashFactory,
              overlayColor: MaterialStateProperty.all(Colors.transparent),
              foregroundColor: MaterialStateProperty.all(Colors.black),
            ),
            onPressed: () => setState(cart.clear),
            child: const Text('Clear Cart', style: TextStyle(color: Colors.red)),
          ),
        ),
      ],
    );
  }

  Widget _summaryPanel() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, color: Colors.grey.shade600),
              const Text('Customer Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 20),

          // Customer Input Form
          if (_selectedCustomer == null)
            Card(
              color: Colors.white,
              margin: EdgeInsets.zero,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CUSTOMER INFO', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _customerNameController,
                      decoration: const InputDecoration(
                        labelText: 'Customer Name',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _customerPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Customer Phone',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ButtonStyle(
                          backgroundColor: MaterialStateProperty.all(const Color(0xffFE691E)),
                        ),
                        onPressed: _isLoadingCustomer ? null : _handleCustomer,
                        child: _isLoadingCustomer
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                            : const Text('Submit', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_selectedCustomer == null) const SizedBox(height: 16),

          // Selected Customer Display
          if (_selectedCustomer != null)
            Card(
              color: Colors.white,
              margin: EdgeInsets.zero,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SELECTED CUSTOMER', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        foregroundColor: Colors.blue.shade800,
                        child: Text(
                          _selectedCustomer!.name[0].toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(_selectedCustomer!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(_selectedCustomer!.phone, style: const TextStyle(color: Colors.grey)),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.redAccent),
                        onPressed: _clearCustomerSelection,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),

          if (_selectedCustomer != null) const SizedBox(height: 16),

          // Promo Code Section - Only shown when customer is selected
          if (_selectedCustomer != null)
            Card(
              color: Colors.white,
              margin: EdgeInsets.zero,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_offer, color: Color(0xffFE691E), size: 20),
                        const SizedBox(width: 8),
                        const Text('PROMO CODE', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Promo Code Input - Show when no promo applied
                    if (_appliedPromo == null || !_appliedPromo!.isValid)
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xffFE691E).withOpacity(0.5)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: TextField(
                                controller: _promoCodeController,
                                textCapitalization: TextCapitalization.characters,
                                decoration: InputDecoration(
                                  hintText: 'Enter promo code',
                                  hintStyle: TextStyle(color: Colors.grey.shade400),
                                  prefixIcon: const Icon(Icons.discount, color: Color(0xffFE691E)),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xffFE691E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _isValidatingPromo ? null : _applyPromoCode,
                            child: _isValidatingPromo
                                ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                                : const Text('Apply'),
                          ),
                        ],
                      ),

                    // Applied Promo Display
                    if (_appliedPromo != null && _appliedPromo!.isValid)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xffFE691E).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xffFE691E), width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xffFE691E),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _promoCodeController.text.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_appliedPromo!.discountPercentage}% OFF Applied',
                                style: const TextStyle(
                                  color: Color(0xffFE691E),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Color(0xffFE691E), size: 20),
                              onPressed: _removePromoCode,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

          if (_selectedCustomer != null) const SizedBox(height: 16),

          const Text('ORDER SUMMARY', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _summaryRow('Subtotal', subtotal),
          if (_appliedPromo != null && _appliedPromo!.isValid)
            _summaryRow('Discount (${_appliedPromo!.discountPercentage}%)', -discount, color: const Color(0xffFE691E)),
          _summaryRow('Tax (8.5%)', tax),
          const Divider(),
          _summaryRow('Total Payable', total, bold: true),
          const SizedBox(height: 16),
          _paymentButtons(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ButtonStyle(
                shape: MaterialStateProperty.all(
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                backgroundColor: MaterialStateProperty.all(const Color(0xffFE691E)),
              ),
              onPressed: _processSale,
              child: Text('Charge \$${total.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: color))),
          Text(
            '\$${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : null,
              color: color,
            ),
          )
        ],
      ),
    );
  }

  Widget _paymentButtons() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        PaymentBtn(
          Icons.credit_card,
          'Card',
          isSelected: _selectedPaymentMethod == 'Card',
          onTap: () => _handlePaymentMethodSelected('Card'),
        ),
        PaymentBtn(
          Icons.money,
          'Cash',
          isSelected: _selectedPaymentMethod == 'Cash',
          onTap: () => _handlePaymentMethodSelected('Cash'),
        ),
        PaymentBtn(
          Icons.qr_code,
          'QR Pay',
          isSelected: _selectedPaymentMethod == 'QR Pay',
          onTap: () => _handlePaymentMethodSelected('QR Pay'),
        ),
        PaymentBtn(
          Icons.delivery_dining_outlined,
          'COD',
          isSelected: _selectedPaymentMethod == 'COD',
          onTap: () => _handlePaymentMethodSelected('COD'),
        ),
      ],
    );
  }
}

class PaymentBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const PaymentBtn(this.icon, this.label, {super.key, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ButtonStyle defaultStyle = OutlinedButton.styleFrom(
      foregroundColor: Colors.black,
      side: const BorderSide(color: Colors.grey, width: 1),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    );

    final ButtonStyle selectedStyle = OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: const Color(0xffFE691E),
      side: const BorderSide(color: Color(0xffFE691E), width: 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    );

    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label),
      ),
      style: isSelected ? selectedStyle : defaultStyle,
    );
  }
}