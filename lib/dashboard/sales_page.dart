import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:izc_inventory/dashboard/receipt_page.dart';
import '../models/cart_item_model.dart';
import '../models/customer_model.dart';
import '../models/product_model.dart';
import '../models/promo_code_model.dart';
import '../services/supabase_service.dart';
import '../services/promo_code_service.dart';
import 'package:url_launcher/url_launcher.dart';
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final _supabaseService = SupabaseService();
  final _promoCodeService = PromoCodeService();
  final List<CartItem> cart = [];
  final TextEditingController _searchController = TextEditingController();
  List<Product> _searchResults = [];
  bool _isSearching = false;
  bool _showSearchResults = false;
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  Customer? _selectedCustomer;
  bool _isLoadingCustomer = false;
  final TextEditingController _promoCodeController = TextEditingController();
  PromoCodeValidation? _appliedPromo;
  bool _isValidatingPromo = false;
  String? _selectedPaymentMethod;
  final TextEditingController _advancePaymentController = TextEditingController();
  double _advancePayment = 0.0;
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
  double get remainingAmount => total - _advancePayment;
  String? _originalSaleIdForExchange; // ✅ Track which invoice is being exchanged// ✅ You already have this
  bool _isReturnMode = false;        // ✅ ADD THIS
  bool _isExchangeMode = false;
  List<String> _originalReturnProductIds = [];
  @override
  void dispose() {
    _searchController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _promoCodeController.dispose();
    _advancePaymentController.dispose();
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
    // ✅ NEW: Check if in return mode and product wasn't in original sale
    if (_isReturnMode && _originalReturnProductIds.isNotEmpty) {
      if (!_originalReturnProductIds.contains(product.id)) {
        _showError('Cannot add "${product.name}" - it was not in the original sale');
        return;
      }
    }

    setState(() {
      final existingIndex = cart.indexWhere((item) => item.productId == product.id);

      if (existingIndex != -1) {
        if (_isReturnMode) {
          // In return mode, check against original quantity
          // You might want to store original quantities too for more precise validation
          cart[existingIndex].qty++;
        } else if (cart[existingIndex].qty < product.stock) {
          cart[existingIndex].qty++;
        } else {
          _showError('Cannot add more. Available stock: ${product.stock}');
        }
      } else {
        if (_isReturnMode) {
          // In return mode, this product should already be in cart from the original sale
          _showError('Cannot add "${product.name}" - it was not in the original sale');
          return;
        } else if (product.stock > 0) {
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
      _isReturnMode = false;
      _isExchangeMode = false;
      _originalReturnProductIds.clear();  // ✅ NEW: Clear validation list
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
    setState(() {
      _selectedPaymentMethod = methodLabel;
      // Clear advance payment when switching payment methods
      if (methodLabel != 'COD') {
        _advancePaymentController.clear();
        _advancePayment = 0.0;
      }
    });
  }

  void _updateAdvancePayment(String value) {
    setState(() {
      final inputAmount = double.tryParse(value) ?? 0.0;

      // Ensure advance payment doesn't exceed total
      if (inputAmount > total) {
        _advancePayment = total;
        _advancePaymentController.text = total.toStringAsFixed(2);
        _showError('Advance payment cannot exceed total amount of Rs ${total.toStringAsFixed(2)}');
      } else {
        _advancePayment = inputAmount;
      }
    });
  }

  Future<void> _sendWhatsAppMessage({
    required String phoneNumber,
    required String invoiceId,
    required double total,
    String? paymentMethod,
    double? codAmount,
    List<CartItem>? items,
    double? advancePayment,
    bool isReturn = false,        // ✅ NEW: Flag for return
    bool isExchange = false,      // ✅ NEW: Flag for exchange
  })
  async {
    try {
      // Clean phone number - remove all non-digits except leading +
      String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

      // If phone doesn't start with +, add country code
      if (!cleanPhone.startsWith('+')) {
        cleanPhone = cleanPhone.replaceFirst(RegExp(r'^0+'), '');
        cleanPhone = '+92$cleanPhone';
      }

      // Validate phone number
      if (cleanPhone.length < 10) {
        if (mounted) {
          _showError('Invalid phone number format');
        }
        return;
      }

      // Build items list
      String itemsList = '';
      if (items != null && items.isNotEmpty) {
        itemsList = '\n\nItems:\n';
        for (var item in items) {
          itemsList += '- ${item.name} \n ${item.qty} X Rs ${item.price.toStringAsFixed(2)} = Rs ${(item.price * item.qty).toStringAsFixed(2)}\n';
        }
      }

      // Build advance payment line (only if advance was made)
      String advanceLine = '';
      if (advancePayment != null && advancePayment > 0 && !isReturn) {
        advanceLine = '\n*Advance Paid:* Rs ${advancePayment.toStringAsFixed(2)}';
      }

      // Build COD line (only if there's a remaining COD amount)
      String codLine = '';
      if (codAmount != null && codAmount > 0 && !isReturn) {
        codLine = '\n*COD Amount:* Rs ${codAmount.toStringAsFixed(2)}';
      }

      // ✅ NEW: Format message based on type
      String message;

      if (isReturn) {
        // RETURN MESSAGE FORMAT
        message = '''*Izzahs collection*
 *RETURN / CREDIT NOTE*

*Invoice:* $invoiceId$itemsList
----------------------------------------------
*Refund Amount:* Rs ${total.abs().toStringAsFixed(2)}

Items returned and stock restored.
For any queries, please contact us.''';
      } else if (isExchange) {
        // EXCHANGE MESSAGE FORMAT
        message = '''*Izzahs collection*
 *EXCHANGE RECEIPT*

*Invoice:* $invoiceId$itemsList
----------------------------------------------
*New Total:* Rs ${total.toStringAsFixed(2)}
*Payment Method:* ${paymentMethod ?? 'N/A'}$advanceLine$codLine

Thank you for shopping with us!''';
      } else {
        // NORMAL SALE MESSAGE FORMAT
        message = '''*Izzahs collection*
*Sale Receipt*

*Invoice:* $invoiceId$itemsList
----------------------------------------------
*Subtotal:* Rs ${total.toStringAsFixed(2)}
*Payment Method:* ${paymentMethod ?? 'N/A'}$advanceLine$codLine

Thank you for your purchase!''';
      }

      // Create WhatsApp URL
      final encodedMessage = Uri.encodeComponent(message);
      final whatsappUrl = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMessage');

      print('📱 Attempting to open WhatsApp...');
      print('📱 Phone: $cleanPhone');
      print('📱 Type: ${isReturn ? "RETURN" : isExchange ? "EXCHANGE" : "SALE"}');
      print('📱 Message: $message');

      // Try to launch WhatsApp
      final canLaunch = await canLaunchUrl(whatsappUrl);

      if (canLaunch) {
        final launched = await launchUrl(
          whatsappUrl,
          mode: LaunchMode.externalApplication,
        );

        if (!launched && mounted) {
          _showError('Could not open WhatsApp');
        }
      } else {
        if (mounted) {
          _showError('WhatsApp is not installed or phone number is invalid');
        }
      }

    } catch (e) {
      print('❌ WhatsApp error: $e');
      if (mounted) {
        _showError('Failed to open WhatsApp: $e');
      }
    }
  }



  // Process sale
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

    // Validate advance payment for COD
    if (_selectedPaymentMethod == 'COD' && _advancePayment > total) {
      _showError('Advance payment (Rs ${_advancePayment.toStringAsFixed(2)}) cannot exceed total amount (Rs ${total.toStringAsFixed(2)})');
      return;
    }

    // Additional check to ensure remaining amount is not negative
    if (_selectedPaymentMethod == 'COD' && remainingAmount < 0) {
      _showError('Invalid advance payment amount');
      setState(() {
        _advancePayment = 0.0;
        _advancePaymentController.clear();
      });
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Confirm Sale'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${_selectedCustomer!.name}'),
            Text('Phone: ${_selectedCustomer!.phone}'),
            Text('Total Amount: Rs ${total.toStringAsFixed(2)}'),
            if (_selectedPaymentMethod == 'COD' && _advancePayment > 0)
              Text('Advance Payment: Rs ${_advancePayment.toStringAsFixed(2)}'),
            if (_selectedPaymentMethod == 'COD')
              Text(
                'COD Amount: Rs ${remainingAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xffFE691E),
                  fontWeight: FontWeight.bold,
                ),
              ),
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

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xffFE691E)),
      ),
    );

    try {
      // Determine status based on payment method
      String status;
      if (_selectedPaymentMethod == 'COD') {
        if (_advancePayment >= total) {
          status = 'Completed';
        } else {
          status = 'In Process';
        }
      } else {
        status = 'Completed';
      }

      final saleId = await _supabaseService.createSale(
        customerId: _selectedCustomer!.id!,
        items: cart,
        subtotal: subtotal,
        discount: discount,
        tax: tax,
        total: total,
        paymentMethod: _selectedPaymentMethod!,
        advancePayment: _selectedPaymentMethod == 'COD' ? _advancePayment : null,
        status: status,
      );



      // Close loading dialog
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      _showSuccess('Sale completed successfully!');
      final customerPhone = _selectedCustomer!.phone;
      final paymentMethod = _selectedPaymentMethod!;
      final saleTotal = total;  // ✅ Store total before clearing cart
      final codAmountToSend = _selectedPaymentMethod == 'COD' ? remainingAmount : null;
      final cartItemsCopy = List<CartItem>.from(cart);  // ✅ Copy cart items
      final advancePaymentAmount = _advancePayment > 0 ? _advancePayment : null;  // ✅ Only if > 0

      setState(() {
        cart.clear();
        _clearCustomerSelection();
        _selectedPaymentMethod = null;
        _advancePaymentController.clear();
        _advancePayment = 0.0;
      });

      if (saleId != null && mounted) {
        // Send WhatsApp message with stored values
        await _sendWhatsAppMessage(
          phoneNumber: customerPhone,
          invoiceId: saleId,
          total: saleTotal,
          paymentMethod: paymentMethod,
          codAmount: codAmountToSend,
          items: cartItemsCopy,  // ✅ Pass cart items
          advancePayment: advancePaymentAmount,  // ✅ Pass advance payment (only if > 0)
        );



        if (saleId != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReceiptScreen(saleId: saleId),
            ),
          );
        }
      }} catch (e) {
      // Close loading dialog
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showError('Failed to process sale: $e');
    }
  }

  // ✅ NEW: Process Return
  // ✅ UPDATED: Process Return - cleaner workflow
  // ✅ UPDATED: Process Return - adds items to cart for partial returns
  Future<void> _processReturn() async {
    // Check if cart is empty
    if (cart.isNotEmpty) {
      final clearCart = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Clear Cart?'),
          content: const Text('Your cart is not empty. Do you want to clear it before processing a return?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear Cart', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (clearCart != true) return;

      setState(() {
        cart.clear();
      });
    }

    final invoiceController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Process Return'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the invoice number of the sale to return:'),
            const SizedBox(height: 16),
            TextField(
              controller: invoiceController,
              decoration: const InputDecoration(
                labelText: 'Invoice Number',
                hintText: 'IZC-0126-00001',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (invoiceController.text.trim().isEmpty) {
                Navigator.pop(context);
                return;
              }
              Navigator.pop(context, {'invoiceId': invoiceController.text.trim()});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (result == null) return;

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xffFE691E)),
        ),
      );

      // Get the sale
      final sale = await _supabaseService.getSaleById(result['invoiceId']);
      setState(() {
        _originalSaleIdForExchange = result['invoiceId'];
      });
      final items = await _supabaseService.getDetailedSaleItems(result['invoiceId']);

      Navigator.pop(context); // Close loading

      if (items.isEmpty) {
        _showError('No items found for this invoice');
        return;
      }

      // Show return information
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Return Items'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invoice: ${result['invoiceId']}'),
                Text('Customer: ${items.first.customerName ?? "N/A"}'),
                Text('Original Total: Rs ${sale.total.toStringAsFixed(2)}'),
                const SizedBox(height: 16),
                const Text('Items in sale:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('• ${item.productName} x${item.quantity} - Rs ${item.total.toStringAsFixed(2)}'),
                )),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: const Text(
                    'ℹ️ Items will be added to cart. Adjust quantities for partial return, then click "Process Return" button below. You cannot add items that were not in the original sale.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add to Cart'),
            ),
          ],
        ),
      );

      if (proceed != true) return;

      final actualCustomer = await _supabaseService.getCustomerById(sale.customerId);

      setState(() {
        _selectedCustomer = Customer(
          id: sale.customerId,
          name: actualCustomer?.name ?? items.first.customerName ?? "Unknown",
          phone: actualCustomer?.phone ?? "0000000000",
        );
        _isReturnMode = true;
        _isExchangeMode = false;

        // ✅ NEW: Store original product IDs for validation
        _originalReturnProductIds = items.map((item) => item.productId).toList();
      });

      // Add items to cart
      for (var item in items) {
        // Get fresh product data
        final products = await _supabaseService.searchProducts(item.sku);
        if (products.isNotEmpty) {
          final product = products.first;

          // Check if item already in cart
          final existingIndex = cart.indexWhere((cartItem) => cartItem.productId == product.id);

          if (existingIndex != -1) {
            // Update quantity if already in cart
            setState(() {
              cart[existingIndex].qty += item.quantity;
            });
          } else {
            // Add new item to cart (for return, we don't check stock)
            setState(() {
              cart.add(CartItem(
                productId: product.id,
                name: product.name,
                sku: product.sku,
                price: product.price,
                qty: item.quantity,
                availableStock: product.stock,
              ));
            });
          }
        }
      }

      _showSuccess(
        'Return mode activated! Items added to cart. Reduce quantities for partial return, then click "Process Return" button. You cannot add new items.',
      );

    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showError('Failed to load return: $e');
    }
  }

  // ✅ NEW: Process Exchange
  // ✅ UPDATED: Process Exchange - adds items to cart
  Future<void> _processExchange() async {
    // Check if cart is empty
    if (cart.isNotEmpty) {
      final clearCart = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Clear Cart?'),
          content: const Text('Your cart is not empty. Do you want to clear it before processing an exchange?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear Cart', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (clearCart != true) return;

      setState(() {
        cart.clear();
      });
    }

    final invoiceController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Process Exchange'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the invoice number for the exchange:'),
            const SizedBox(height: 16),
            TextField(
              controller: invoiceController,
              decoration: const InputDecoration(
                labelText: 'Invoice Number',
                hintText: 'IZC-0126-00001',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (invoiceController.text.trim().isEmpty) {
                Navigator.pop(context);
                return;
              }
              Navigator.pop(context, {'invoiceId': invoiceController.text.trim()});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (result == null) return;

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xffFE691E)),
        ),
      );

      // ✅ STORE THE ORIGINAL SALE ID FIRST - BEFORE ANY OTHER OPERATIONS
      final originalSaleId = result['invoiceId'];

      // Get the sale
      final sale = await _supabaseService.getSaleById(originalSaleId);
      final items = await _supabaseService.getDetailedSaleItems(originalSaleId);

      Navigator.pop(context); // Close loading

      if (items.isEmpty) {
        _showError('No items found for this invoice');
        return;
      }

      // Show exchange information
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Exchange Items'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Original Invoice: $originalSaleId'),
                Text('Customer: ${items.first.customerName ?? "N/A"}'),
                Text('Original Total: Rs ${sale.total.toStringAsFixed(2)}'),
                const SizedBox(height: 16),
                const Text('Original items:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('• ${item.productName} x${item.quantity}'),
                )),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Text(
                    'ℹ️ These items will be added to your cart. Modify quantities or add new items, then complete the sale.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add to Cart'),
            ),
          ],
        ),
      );

      if (proceed != true) return;

      final actualCustomer = await _supabaseService.getCustomerById(sale.customerId);

      setState(() {
        // ✅ SET THE ORIGINAL SALE ID HERE - THIS WAS MISSING!
        _originalSaleIdForExchange = originalSaleId;

        _selectedCustomer = Customer(
          id: sale.customerId,
          name: actualCustomer?.name ?? items.first.customerName ?? "Unknown",
          phone: actualCustomer?.phone ?? "0000000000",
        );
        _isReturnMode = false;
        _isExchangeMode = true;
      });

      // ✅ FIXED: Add items to cart with better error handling
      for (var item in items) {
        try {
          // Try to get fresh product data by searching first
          List<Product> products = await _supabaseService.searchProducts(item.sku);

          // If not found by SKU search, try to get product by ID directly
          if (products.isEmpty) {
            final directProduct = await _supabaseService.getProductById(item.productId);
            if (directProduct != null) {
              products = [directProduct];
            }
          }

          if (products.isEmpty) {
            // Product not found at all - still add it to cart but with warning
            _showError('Warning: ${item.productName} not found in inventory. Adding with original price.');

            setState(() {
              cart.add(CartItem(
                productId: item.productId,
                name: item.productName,
                sku: item.sku,
                price: item.price,
                qty: item.quantity,
                availableStock: 0, // No stock info available
              ));
            });
            continue;
          }

          final product = products.first;

          // Check if item already in cart
          final existingIndex = cart.indexWhere((cartItem) => cartItem.productId == product.id);

          if (existingIndex != -1) {
            // Update quantity if already in cart
            final newQty = cart[existingIndex].qty + item.quantity;
            if (newQty <= product.stock || !product.isActive) {
              setState(() {
                cart[existingIndex].qty = newQty;
              });
            } else {
              _showError('${product.name}: Cannot add ${item.quantity} more. Available stock: ${product.stock}');
              // Still add what we can
              setState(() {
                cart[existingIndex].qty = product.stock;
              });
            }
          } else {
            // Add new item to cart
            if (item.quantity <= product.stock || !product.isActive) {
              setState(() {
                cart.add(CartItem(
                  productId: product.id,
                  name: product.name,
                  sku: product.sku,
                  price: product.price,
                  qty: item.quantity,
                  availableStock: product.stock,
                ));
              });
            } else {
              _showError('${product.name}: Requested ${item.quantity} but only ${product.stock} in stock');
              // Add what's available
              if (product.stock > 0) {
                setState(() {
                  cart.add(CartItem(
                    productId: product.id,
                    name: product.name,
                    sku: product.sku,
                    price: product.price,
                    qty: product.stock,
                    availableStock: product.stock,
                  ));
                });
              }
            }
          }
        } catch (e) {
          _showError('Error loading ${item.productName}: $e');
        }
      }

      // ✅ DON'T CALL processExchange() HERE - it should only be called when completing the exchange
      // Remove this line:
      // await _supabaseService.processExchange(result['invoiceId']);

      _showSuccess(
        'Exchange mode activated! Original items added to cart. Adjust quantities or add new items, then complete the sale.',
      );

    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showError('Failed to process exchange: $e');
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
// Complete the return process with items in cart
  // Complete the return - generates NEGATIVE invoice
  Future<void> _completeReturn() async {
    if (cart.isEmpty) {
      _showError('Cart is empty');
      return;
    }

    // Calculate return total
    final returnSubtotal = cart.fold<double>(0, (sum, item) => sum + item.price * item.qty);
    final returnTax = returnSubtotal * 0.085;
    final returnTotal = returnSubtotal + returnTax;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Confirm Return'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${_selectedCustomer!.name}'),
            const SizedBox(height: 8),
            const Text('Items to return:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...cart.map((item) => Text('• ${item.name} x${item.qty}')),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '⚠️ Stock will be restored for these items.',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Refund Amount: Rs ${returnTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Process Return'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xffFE691E)),
        ),
      );

      // ✅ FIX: Create return record with POSITIVE quantities but NEGATIVE totals
      final returnSaleId = await _supabaseService.createReturnRecord(
        customerId: _selectedCustomer!.id!,
        items: cart,
        subtotal: -returnSubtotal,  // Negative
        discount: 0.0,
        tax: -returnTax,  // Negative
        total: -returnTotal,  // Negative
        notes: 'RETURN - Credit Note${_originalSaleIdForExchange != null ? " (Original: $_originalSaleIdForExchange)" : ""}',
      );

      // Close loading
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      _showSuccess('Return processed! Credit note generated and stock restored.');

      // Store values before clearing cart
      final customerPhone = _selectedCustomer!.phone;
      final cartItemsCopy = List<CartItem>.from(cart);

      setState(() {
        cart.clear();
        _clearCustomerSelection();
        _originalSaleIdForExchange = null;
        _isReturnMode = false;
        _originalReturnProductIds.clear();  // ✅ NEW: Clear validation list
      });

      // Send WhatsApp message for return
      if (returnSaleId != null && mounted) {
        await _sendWhatsAppMessage(
          phoneNumber: customerPhone,
          invoiceId: returnSaleId,
          total: returnTotal,
          items: cartItemsCopy,
          isReturn: true,
        );

        // Navigate to receipt for the return/credit note
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReceiptScreen(saleId: returnSaleId),
          ),
        );
      }

    } catch (e) {
      // Close loading if still open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showError('Failed to process return: $e');
    }
  }

// Complete the exchange (just process as normal sale)
  // Complete exchange - UPDATE the same invoice
  Future<void> _completeExchange() async {
    if (cart.isEmpty) {
      _showError('Cart is empty');
      return;
    }

    if (_selectedPaymentMethod == null) {
      _showError('Please select a payment method');
      return;
    }

    if (_originalSaleIdForExchange == null) {
      _showError('Original sale ID not found');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Confirm Exchange'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Original Invoice: $_originalSaleIdForExchange'),
            Text('Customer: ${_selectedCustomer!.name}'),
            Text('New Total: Rs ${total.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            const Text('New Items:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...cart.map((item) => Text('• ${item.name} x${item.qty}')),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Text(
                'ℹ️ Original invoice will be updated with new items.',
                style: TextStyle(fontSize: 12),
              ),
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
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Exchange'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // 1. Get original sale items to restore their stock
      final originalItems = await _supabaseService.getDetailedSaleItems(_originalSaleIdForExchange!);

      // 2. Restore stock for original items
      for (var item in originalItems) {
        final product = await _supabaseService.searchProducts(item.sku);
        if (product.isNotEmpty) {
          final currentProduct = product.first;
          final newStock = currentProduct.stock + item.quantity;

          await _supabaseService.updateProductStock(
            currentProduct.id,
            newStock,
            'Exchange - Returning original items',
          );
        }
      }

      // 3. Delete old sale_items
      await _supabaseService.deleteSaleItems(_originalSaleIdForExchange!);

      // 4. Update the sale with new totals
      await _supabaseService.updateSale(
        saleId: _originalSaleIdForExchange!,
        subtotal: subtotal,
        discount: discount,
        tax: tax,
        total: total,
        paymentMethod: _selectedPaymentMethod!,
        advancePayment: _selectedPaymentMethod == 'COD' ? _advancePayment : null,
        status: 'Exchanged',
      );

      // 5. Add new sale_items
      for (var item in cart) {
        await _supabaseService.addSaleItem(
          saleId: _originalSaleIdForExchange!,
          productId: item.productId,
          quantity: item.qty,
          price: item.price,
        );

        // Deduct stock for new items
        final product = await _supabaseService.searchProducts(item.sku);
        if (product.isNotEmpty) {
          final currentProduct = product.first;
          final newStock = currentProduct.stock - item.qty;

          await _supabaseService.updateProductStock(
            currentProduct.id,
            newStock,
            'Exchange - New items',
          );
        }
      }

      _showSuccess('Exchange completed! Invoice $_originalSaleIdForExchange updated.');

      // ✅ NEW: Store values before clearing cart
      final customerPhone = _selectedCustomer!.phone;
      final paymentMethod = _selectedPaymentMethod!;
      final exchangeTotal = total;
      final codAmountToSend = _selectedPaymentMethod == 'COD' ? remainingAmount : null;
      final cartItemsCopy = List<CartItem>.from(cart);
      final advancePaymentAmount = _advancePayment > 0 ? _advancePayment : null;
      final exchangeInvoiceId = _originalSaleIdForExchange!;

      setState(() {
        cart.clear();
        _clearCustomerSelection();
        _selectedPaymentMethod = null;
        _advancePaymentController.clear();
        _advancePayment = 0.0;
        _originalSaleIdForExchange = null;
        _isExchangeMode = false;
      });

      // ✅ NEW: Send WhatsApp message for exchange
      if (mounted) {
        await _sendWhatsAppMessage(
          phoneNumber: customerPhone,
          invoiceId: exchangeInvoiceId,
          total: exchangeTotal,
          paymentMethod: paymentMethod,
          codAmount: codAmountToSend,
          items: cartItemsCopy,
          advancePayment: advancePaymentAmount,
          isExchange: true, // ✅ Flag as exchange
        );

        // Navigate to updated receipt
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReceiptScreen(saleId: exchangeInvoiceId),
          ),
        );
      }

    } catch (e) {
      _showError('Failed to process exchange: $e');
    }
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
              Flexible(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 12,
                        color: Colors.black12,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          child: _summaryPanel(),
                        ),
                      ),
                    ],
                  ),
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
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  product.name[0].toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.blue.shade900,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      )
                          : Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            product.name[0].toUpperCase(),
                            style: TextStyle(
                              color: Colors.blue.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
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
              Expanded(child: Text('Rs ${item.price.toStringAsFixed(2)}')),
              Expanded(
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.grey),
                      onPressed: () {
                        setState(() {
                          if (item.qty > 1) {
                            item.qty--;
                          } else {
                            // If quantity is 1 and user tries to decrease, remove the item
                            cart.removeAt(
                                i); // Remove from the cart list using its index
                          }
                        });
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
                  'Rs ${(item.price * item.qty).toStringAsFixed(2)}',
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
        // Show Process Return button when in return mode
        if (_isReturnMode)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextButton.icon(
                style: ButtonStyle(
                  splashFactory: NoSplash.splashFactory,
                  overlayColor: MaterialStateProperty.all(Colors.transparent),
                  foregroundColor: MaterialStateProperty.all(Colors.white),
                ),
                onPressed: cart.isEmpty ? null : _completeReturn,
                icon: const Icon(Icons.check_circle, size: 18),
                label: const Text('Process Return', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),

        // Show Process Exchange button when in exchange mode
        if (_isExchangeMode)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextButton.icon(
                style: ButtonStyle(
                  splashFactory: NoSplash.splashFactory,
                  overlayColor: MaterialStateProperty.all(Colors.transparent),
                  foregroundColor: MaterialStateProperty.all(Colors.white),
                ),
                onPressed: cart.isEmpty ? null : _completeExchange,
                icon: const Icon(Icons.check_circle, size: 18),
                label: const Text('Complete Exchange', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),

        // Normal buttons when not in return/exchange mode
        if (!_isReturnMode && !_isExchangeMode) ...[
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade300, width: 1),
            ),
            child: TextButton.icon(
              style: ButtonStyle(
                splashFactory: NoSplash.splashFactory,
                overlayColor: MaterialStateProperty.all(Colors.transparent),
                foregroundColor: MaterialStateProperty.all(Colors.red),
              ),
              onPressed: _processReturn,
              icon: const Icon(Icons.keyboard_return, size: 18),
              label: const Text('Return'),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade300, width: 1),
            ),
            child: TextButton.icon(
              style: ButtonStyle(
                splashFactory: NoSplash.splashFactory,
                overlayColor: MaterialStateProperty.all(Colors.transparent),
                foregroundColor: MaterialStateProperty.all(Colors.orange),
              ),
              onPressed: _processExchange,
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: const Text('Exchange'),
            ),
          ),
        ],

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
            onPressed: () {
              setState(() {
                cart.clear();
                _clearCustomerSelection();
              });
            },
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

          // Promo Code Section
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

          // Show advance payment and remaining amount if COD is selected
          if (_selectedPaymentMethod == 'COD' && _advancePayment > 0) ...[
            const SizedBox(height: 8),
            _summaryRow('Advance Payment', -_advancePayment, color: Colors.green),
            const Divider(),
            _summaryRow('COD Amount', remainingAmount, bold: true, color: const Color(0xffFE691E)),
          ],

          const SizedBox(height: 16),
          _paymentButtons(),

          // COD Advance Payment Field
          if (_selectedPaymentMethod == 'COD') ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.white,
              margin: EdgeInsets.zero,
              elevation: 5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.payment, color: Color(0xffFE691E), size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'ADVANCE PAYMENT (Optional)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _advancePaymentController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      onChanged: _updateAdvancePayment,
                      decoration: InputDecoration(
                        labelText: 'Enter advance amount',
                        prefixText: 'Rs  ',
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: _advancePayment > total ? Colors.red : Colors.grey,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: _advancePayment > total ? Colors.red : Colors.grey.shade400,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: _advancePayment > total ? Colors.red : const Color(0xffFE691E),
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        isDense: true,
                        helperText: 'Max: Rs ${total.toStringAsFixed(2)}',
                        helperStyle: TextStyle(
                          fontSize: 11,
                          color: _advancePayment > total ? Colors.red : Colors.grey.shade600,
                        ),
                        errorText: _advancePayment > total ? 'Exceeds total amount' : null,
                      ),
                    ),
                    if (_advancePayment > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xffFE691E).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xffFE691E).withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'To be collected on delivery:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              'Rs ${remainingAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xffFE691E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ButtonStyle(
                shape: MaterialStateProperty.all(
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                backgroundColor: MaterialStateProperty.all(
                    (_selectedPaymentMethod == 'COD' && _advancePayment > total)
                        ? Colors.grey // Disabled state
                        : const Color(0xffFE691E)
                ),
              ),
              onPressed: (_selectedPaymentMethod == 'COD' && _advancePayment > total)
                  ? null // Disable button if advance exceeds total
                  : _processSale,
              child: Text(
                _selectedPaymentMethod == 'COD' && _advancePayment > 0
                    ? 'Charge Rs ${_advancePayment.toStringAsFixed(2)} (COD: Rs ${remainingAmount.toStringAsFixed(2)})'
                    : 'Charge Rs ${total.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white),
              ),
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
            'Rs ${value.toStringAsFixed(2)}',
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