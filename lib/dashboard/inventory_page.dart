// ============================================
// INVENTORY PAGE - Updated with Session Service
// lib/screens/inventory_page.dart
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/product_model.dart';
import '../services/supabase_service.dart';
import '../services/session_service.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  // Services
  final _supabaseService = SupabaseService();

  // State variables
  List<Product> _allProducts = [];
  List<StockHistory> _stockHistory = [];
  bool _isLoading = true;
  bool _isAdmin = false;
  String? _currentUserRole;
  String? _currentUsername;
  String? _currentUserEmail;

  String _activeFilter = 'Active products';
  int _currentPage = 1;
  final int _itemsPerPage = 4;
  final GlobalKey _filterButtonKey = GlobalKey();

  // Stats
  double _totalValue = 0.0;
  int _lowStockCount = 0;
  int _outOfStockCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  // Initialize all data
  Future<void> _initializeData() async {
    _loadUserSession();
    await _loadData();
    _setupRealtimeListeners();
  }

  // Load user session from Hive
  void _loadUserSession() {
    setState(() {
      _currentUserRole = SessionService.getUserRole();
      _currentUsername = SessionService.getUsername();
      _currentUserEmail = SessionService.getEmail();
      _isAdmin = SessionService.isAdmin();
    });

    print('User session loaded:');
    print('Role: $_currentUserRole');
    print('Username: $_currentUsername');
    print('Is Admin: $_isAdmin');
  }

  // Load all data from Supabase
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final products = await _supabaseService.fetchProducts();
      final history = await _supabaseService.fetchStockHistory(limit: 10);
      final totalValue = await _supabaseService.calculateTotalInventoryValue();
      final lowStock = await _supabaseService.getLowStockCount();
      final outOfStock = await _supabaseService.getOutOfStockCount();

      if (mounted) {
        setState(() {
          _allProducts = products;
          _stockHistory = history;
          _totalValue = totalValue;
          _lowStockCount = lowStock;
          _outOfStockCount = outOfStock;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Failed to load data: $e');
      }
    }
  }

  // Setup real-time listeners for live updates
  void _setupRealtimeListeners() {
    // Listen to product changes
    _supabaseService.watchProducts().listen((products) {
      if (mounted) {
        setState(() {
          _allProducts = products;
          _updateStats();
        });
      }
    });

    // Listen to stock history changes
    _supabaseService.watchStockHistory(limit: 10).listen((history) {
      if (mounted) {
        setState(() => _stockHistory = history);
      }
    });
  }

  // Update statistics
  void _updateStats() {
    _lowStockCount = _allProducts
        .where((p) => p.isLowStock)
        .length;
    _outOfStockCount = _allProducts
        .where((p) => p.isOutOfStock)
        .length;
    _totalValue = _allProducts.fold(0.0, (sum, p) => sum + (p.price * p.stock));
    print('total values $_totalValue');

  }

  // Filtered products based on active filter
  List<Product> get _filteredProducts {
    switch (_activeFilter) {
      case 'Out of stock':
        return _allProducts.where((p) => p.isOutOfStock).toList();
      case 'Active products':
        return _allProducts.where((p) => p.isActive).toList();
      case 'Inactive products':
        return _allProducts.where((p) => !p.isActive).toList();
      default:
        return _allProducts;
    }
  }

  // Pagination calculations
  int get _totalPages {
    if (_filteredProducts.isEmpty) return 1;
    return (_filteredProducts.length / _itemsPerPage).ceil();
  }

  List<Product> get _paginatedProducts {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage > _filteredProducts.length)
        ? _filteredProducts.length
        : startIndex + _itemsPerPage;
    return _filteredProducts.sublist(startIndex, endIndex);
  }

  // UI Helper methods
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

  // Export to CSV
  void _exportInventoryToCsv() async {
    final csvText = _supabaseService.generateProductsCSV(_allProducts);
    await Clipboard.setData(ClipboardData(text: csvText));

    if (mounted) {
      _showSuccess('Inventory data copied to clipboard');
    }
  }

  // Show filter menu
  void _showFilterMenu() {
    final RenderBox? button = _filterButtonKey.currentContext
        ?.findRenderObject() as RenderBox?;
    if (button == null) return;

    final RenderBox overlay = Overlay
        .of(context)
        .context
        .findRenderObject() as RenderBox;
    final Offset buttonPosition = button.localToGlobal(
        Offset.zero, ancestor: overlay);
    final Size buttonSize = button.size;

    final RelativeRect position = RelativeRect.fromLTRB(
      buttonPosition.dx,
      buttonPosition.dy + buttonSize.height + 8,
      overlay.size.width - (buttonPosition.dx + buttonSize.width),
      overlay.size.height - (buttonPosition.dy + buttonSize.height + 8),
    );

    final filterOptions = [
      'Active products',
      'Inactive products',
      'Out of stock'
    ];

    showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: filterOptions.map((option) {
        final isSelected = _activeFilter == option;
        return PopupMenuItem<String>(
          value: option,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  option,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight
                        .normal,
                    color: isSelected ? const Color(0xffFE691E) : Colors.black,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check, color: Color(0xffFE691E), size: 18),
            ],
          ),
        );
      }).toList(),
    ).then((value) {
      if (value != null && value != _activeFilter) {
        setState(() {
          _activeFilter = value;
          _currentPage = 1;
        });
      }
    });
  }

  // Add Product Dialog
  void _showAddProductDialog() {
    if (!_isAdmin) {
      _showError('Only admins can add products');
      return;
    }

    final nameController = TextEditingController();
    final skuController = TextEditingController();
    final stockController = TextEditingController();
    final priceController = TextEditingController();
    bool isActive = true;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Product'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: skuController,
                      decoration: const InputDecoration(
                        labelText: 'SKU',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Stock quantity',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Price (e.g. 129.00)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active'),
                      value: isActive,
                      onChanged: isSubmitting ? null : (val) {
                        setDialogState(() => isActive = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () =>
                      Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : () async {
                    final name = nameController.text.trim();
                    final sku = skuController.text.trim();
                    final stockText = stockController.text.trim();
                    final priceText = priceController.text.trim();

                    if (name.isEmpty || sku.isEmpty || stockText.isEmpty ||
                        priceText.isEmpty) {
                      _showError('Please fill in all fields');
                      return;
                    }

                    final stock = int.tryParse(stockText);
                    final price = double.tryParse(priceText);

                    if (stock == null || price == null) {
                      _showError('Invalid stock or price');
                      return;
                    }

                    setDialogState(() => isSubmitting = true);

                    try {
                      await _supabaseService.addProduct(
                        Product(
                          id: '',
                          name: name,
                          sku: sku,
                          stock: stock,
                          price: price,
                          isActive: isActive,
                        ),
                      );

                      Navigator.pop(dialogContext);
                      _showSuccess('Product "$name" added successfully');
                      setState(() => _currentPage = 1);
                      await _loadData();
                    } catch (e) {
                      setDialogState(() => isSubmitting = false);
                      _showError(e.toString().replaceAll('Exception: ', ''));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffFE691E),
                    foregroundColor: Colors.white,
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                      : const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Edit Product Dialog
  void _showEditProductDialog(Product product) {
    if (!_isAdmin) {
      _showError('Only admins can edit products');
      return;
    }

    final nameController = TextEditingController(text: product.name);
    final skuController = TextEditingController(text: product.sku);
    final stockController = TextEditingController(
        text: product.stock.toString());
    final priceController = TextEditingController(
        text: product.price.toStringAsFixed(2));
    bool isActive = product.isActive;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Product'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: skuController,
                      decoration: const InputDecoration(
                        labelText: 'SKU',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Stock quantity',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Price (e.g. 129.00)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active'),
                      value: isActive,
                      onChanged: isSubmitting ? null : (val) {
                        setDialogState(() => isActive = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () =>
                      Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : () async {
                    final name = nameController.text.trim();
                    final sku = skuController.text.trim();
                    final stockText = stockController.text.trim();
                    final priceText = priceController.text.trim();

                    if (name.isEmpty || sku.isEmpty || stockText.isEmpty ||
                        priceText.isEmpty) {
                      _showError('Please fill in all fields');
                      return;
                    }

                    final stock = int.tryParse(stockText);
                    final price = double.tryParse(priceText);

                    if (stock == null || price == null) {
                      _showError('Invalid stock or price');
                      return;
                    }

                    setDialogState(() => isSubmitting = true);

                    try {
                      await _supabaseService.updateProduct(
                        product.id,
                        Product(
                          id: product.id,
                          name: name,
                          sku: sku,
                          stock: stock,
                          price: price,
                          isActive: isActive,
                        ),
                      );

                      Navigator.pop(dialogContext);
                      _showSuccess('Product "$name" updated successfully');
                      await _loadData();
                    } catch (e) {
                      setDialogState(() => isSubmitting = false);
                      _showError(e.toString().replaceAll('Exception: ', ''));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffFE691E),
                    foregroundColor: Colors.white,
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Delete Product Dialog
  void _showDeleteProductDialog(Product product) {
    if (!_isAdmin) {
      _showError('Only admins can delete products');
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Delete Product'),
              content: Text('Are you sure you want to delete "${product
                  .name}"?\n\nThis action cannot be undone.'),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () =>
                      Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isDeleting ? null : () async {
                    setDialogState(() => isDeleting = true);

                    try {
                      await _supabaseService.deleteProduct(product.id);
                      Navigator.pop(dialogContext);
                      _showSuccess(
                          'Product "${product.name}" deleted successfully');
                      await _loadData();

                      // Adjust current page if needed
                      if (_currentPage > _totalPages && _totalPages > 0) {
                        setState(() => _currentPage = _totalPages);
                      }
                    } catch (e) {
                      setDialogState(() => isDeleting = false);
                      _showError(e.toString().replaceAll('Exception: ', ''));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: isDeleting
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                      : const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Restock functionality
  void _showRestockDialog(Product product) {
    if (!_isAdmin) {
      _showError('Only admins can restock products');
      return;
    }

    final stockController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Restock ${product.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current Stock: ${product.stock}'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: stockController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'New Stock Quantity',
                      border: OutlineInputBorder(),
                      hintText: 'Enter new stock amount',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () =>
                      Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : () async {
                    final stockText = stockController.text.trim();

                    if (stockText.isEmpty) {
                      _showError('Please enter stock quantity');
                      return;
                    }

                    final newStock = int.tryParse(stockText);

                    if (newStock == null || newStock < 0) {
                      _showError('Please enter a valid stock quantity');
                      return;
                    }

                    setDialogState(() => isSubmitting = true);

                    try {
                      await _supabaseService.updateProductStock(
                        product.id,
                        newStock,
                        'Manual Restock',
                      );

                      Navigator.pop(dialogContext);
                      _showSuccess('Product restocked successfully');
                      await _loadData();
                    } catch (e) {
                      setDialogState(() => isSubmitting = false);
                      _showError(e.toString().replaceAll('Exception: ', ''));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffFE691E),
                    foregroundColor: Colors.white,
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                      : const Text('Restock'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xffF6F7FB),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xffFE691E),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < 800;
        final bool isMobile = constraints.maxWidth < 600;
        final double horizontalPadding = isMobile ? 12.0 : (isNarrow
            ? 16.0
            : 24.0);

        return Scaffold(
          backgroundColor: const Color(0xffF6F7FB),
          body: RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.all(horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HEADER
                    _buildHeader(isMobile),
                    SizedBox(height: isMobile ? 16 : 24),

                    // STATS
                    _buildStatsRow(isMobile),
                    SizedBox(height: isMobile ? 16 : 24),

                    // MENU BAR
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 24,
                        vertical: isMobile ? 12 : 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 2,
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _buildMenuBar(isMobile),
                    ),
                    SizedBox(height: isMobile ? 16 : 24),

                    // TABLE AREA
                    SizedBox(
                      height: isMobile ? 350 : (isNarrow ? 400 : 440),
                      child: Container(
                        padding: EdgeInsets.all(isMobile ? 12 : 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 2,
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTableHeader(isMobile),
                            const Divider(height: 1),
                            Expanded(
                              child: _filteredProducts.isEmpty
                                  ? Center(
                                child: Text(
                                  'No products found',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 16,
                                  ),
                                ),
                              )
                                  : (isMobile
                                  ? _buildMobileProductList()
                                  : ListView.separated(
                                itemCount: _paginatedProducts.length,
                                itemBuilder: (context, index) {
                                  final product = _paginatedProducts[index];
                                  return _buildTableRow(product, isMobile);
                                },
                                separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                              )),
                            ),
                            const Divider(height: 1),
                            _buildPaginationControls(),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: isMobile ? 16 : 24),
                    // Stock History Card
                    _buildStockHistoryCard(isMobile),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

// ============================================
// WIDGET BUILDERS FOR INVENTORY PAGE
// ============================================

  Widget _buildHeader(bool isMobile) {
    return isMobile
        ? Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Inventory Management",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (_currentUserRole != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isAdmin ? Colors.orange.shade100 : Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _currentUserRole!.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _isAdmin ? Colors.orange.shade900 : Colors.blue.shade900,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: InputDecoration(
            hintText: "Search products, SKU...",
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
          ),
        ),
      ],
    )
        : Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Inventory Management",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            if (_currentUserEmail != null)
              Text(
                'Logged in as $_currentUserEmail',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
          ],
        ),
        Row(
          children: [
            if (_currentUserRole != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isAdmin ? Colors.orange.shade100 : Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _currentUserRole!.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _isAdmin ? Colors.orange.shade900 : Colors.blue.shade900,
                  ),
                ),
              ),
            const SizedBox(width: 16),
            SizedBox(
              width: 250,
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Search products, SKU...",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow(bool isMobile) {
    return isMobile
        ? Column(
      children: [


        Row(
          children: [
            Expanded(child: _buildStatCard(
                "Total Products", _allProducts.length.toString(),
                Icons.inventory, Colors.blue)),
            const SizedBox(width: 8),
            Expanded(child: _buildStatCard(
                "Total Value", "\$${_totalValue.toStringAsFixed(2)}",
                Icons.attach_money, Colors.green)),

          ],

        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildStatCard(
                "Low Stock", _lowStockCount.toString(), Icons.warning,
                Colors.orange)),
            const SizedBox(width: 8),
            Expanded(child: _buildStatCard(
                "Out of Stock", _outOfStockCount.toString(), Icons.cancel,
                Colors.red)),
          ],
        ),
      ],
    )
        : Row(
      children: [
        Expanded(child: _buildStatCard(
            "Total Products", _allProducts.length.toString(), Icons.inventory,
            Colors.blue)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard(
            "Total Value", '\$${_totalValue.toStringAsFixed(2)}',
            Icons.attach_money, Colors.green)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard(
            "Low Stock", _lowStockCount.toString(), Icons.warning,
            Colors.orange)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard(
            "Out of Stock", _outOfStockCount.toString(), Icons.cancel,
            Colors.red)),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon,
      Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMenuBar(bool isMobile) {
    return isMobile
        ? Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _buildFilterButton("Active products")),
            const SizedBox(width: 8),
            Expanded(child: _buildFilterButton("Out of stock")),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            _buildActionButtonWithKey(
              Icons.filter_alt_outlined,
              "Filter",
              key: _filterButtonKey,
              onPressed: _showFilterMenu,
            ),
            _buildActionButton(
              Icons.file_upload_outlined,
              "Export",
              onPressed: _exportInventoryToCsv,
            ),
            ElevatedButton.icon(
              onPressed: _isAdmin ? _showAddProductDialog : () {
                _showError('Only admins can add products');
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text("Add Product"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isAdmin ? const Color(0xffFE691E) : Colors
                    .grey,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
      ],
    )
        : Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            _buildFilterButton("Active products"),
            const SizedBox(width: 8),
            _buildFilterButton("Out of stock"),
          ],
        ),
        Row(
          children: [
            _buildActionButtonWithKey(
              Icons.filter_alt_outlined,
              "Filter",
              key: _filterButtonKey,
              onPressed: _showFilterMenu,
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              Icons.file_upload_outlined,
              "Export",
              onPressed: _exportInventoryToCsv,
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _isAdmin ? _showAddProductDialog : () {
                _showError('Only admins can add products');
              },
              icon: const Icon(Icons.add),
              label: const Text("Add Product"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isAdmin ? const Color(0xffFE691E) : Colors
                    .grey,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterButton(String title) {
    bool isSelected = _activeFilter == title;
    return TextButton(
      onPressed: () {
        setState(() {
          _activeFilter = title;
          _currentPage = 1;
        });
      },
      style: TextButton.styleFrom(
        backgroundColor: isSelected
            ? const Color(0xffFE691E).withOpacity(0.1)
            : Colors.transparent,
        foregroundColor: isSelected ? const Color(0xffFE691E) : Colors.grey
            .shade600,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildActionButton(IconData icon, String label,
      {VoidCallback? onPressed}) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.grey.shade700,
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildActionButtonWithKey(IconData icon, String label,
      {Key? key, VoidCallback? onPressed}) {
    return OutlinedButton.icon(
      key: key,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.grey.shade700,
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildTableHeader(bool isMobile) {
    if (isMobile) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Text("PRODUCTS", style: TextStyle(
            color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      child: Row(
        children: const [
          Expanded(flex: 3,
              child: Text("PRODUCT",
                  style: TextStyle(color: Colors.grey, fontSize: 12))),
          Expanded(flex: 2,
              child: Text(
                  "SKU", style: TextStyle(color: Colors.grey, fontSize: 12))),
          Expanded(child: Text(
              "STOCK", style: TextStyle(color: Colors.grey, fontSize: 12))),
          Expanded(flex: 2,
              child: Text(
                  "PRICE", style: TextStyle(color: Colors.grey, fontSize: 12))),
          Expanded(flex: 2,
              child: Text("STATUS",
                  style: TextStyle(color: Colors.grey, fontSize: 12))),
          Expanded(flex: 2,
              child: Text(
                  "ACTIONS", style: TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildMobileProductList() {
    return ListView.separated(
      itemCount: _paginatedProducts.length,
      itemBuilder: (context, index) {
        final product = _paginatedProducts[index];
        return _buildMobileProductCard(product);
      },
      separatorBuilder: (context, index) => const Divider(height: 1),
    );
  }

  Widget _buildMobileProductCard(Product product) {
    Color statusColor = product.isOutOfStock ? Colors.red : (product.isActive
        ? Colors.green
        : Colors.grey);
    String statusText = product.isOutOfStock ? "Out of Stock" : (product
        .isActive ? "Active" : "Disabled");

    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SKU: ${product.sku}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Stock",
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text(
                    product.stock.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: product.isLowStock || product.isOutOfStock ? Colors
                          .red : Colors.black,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("Price",
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text(
                    product.priceFormatted,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (product.isOutOfStock)
                _buildRestockButton(product)
              else
                _buildOptionsMenu(product),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(Product product, bool isMobile) {
    Color statusColor = product.isOutOfStock ? Colors.red : (product.isActive
        ? Colors.green
        : Colors.grey);
    String statusText = product.isOutOfStock ? "Out of Stock" : (product
        .isActive ? "Active" : "Disabled");

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(product.name)),
          Expanded(flex: 2, child: Text(product.sku)),
          Expanded(
              child: Text(product.stock.toString(),
                  style: TextStyle(
                      color: product.isLowStock || product.isOutOfStock
                          ? Colors.red
                          : Colors.black))),
          Expanded(flex: 2, child: Text(product.priceFormatted)),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusText,
                textAlign: TextAlign.center,
                style: TextStyle(color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: product.isOutOfStock
                  ? _buildRestockButton(product)
                  : _buildOptionsMenu(product),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestockButton(Product product) {
    return ElevatedButton(
      onPressed: () => _showRestockDialog(product),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xffFE691E),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text("Restock", style: TextStyle(fontSize: 12)),
    );
  }

  Widget _buildOptionsMenu(Product product) {
    return GestureDetector(
      onTapDown: (details) async {
        final position = details.globalPosition;
        final result = await showMenu<String>(
          context: context,
          position: RelativeRect.fromLTRB(
              position.dx, position.dy, position.dx, position.dy),
          items: [
            const PopupMenuItem<String>(
              value: 'edit',
              child: Row(children: [
                Icon(Icons.edit, size: 18, color: Color(0xffFE691E)),
                SizedBox(width: 8),
                Text("Edit")
              ]),
            ),
            const PopupMenuItem<String>(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete, size: 18, color: Colors.red),
                SizedBox(width: 8),
                Text("Delete")
              ]),
            ),
          ],
        );

        if (result == 'edit') {
          _showEditProductDialog(product);
        } else if (result == 'delete') {
          _showDeleteProductDialog(product);
        }
      },
      child: const Icon(Icons.more_horiz, color: Colors.grey),
    );
  }

  Widget _buildPaginationControls() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 1 ? () {
              setState(() => _currentPage--);
            } : null,
          ),
          ...List.generate(_totalPages, (index) {
            final pageNum = index + 1;
            return TextButton(
              onPressed: () {
                setState(() => _currentPage = pageNum);
              },
              style: TextButton.styleFrom(
                backgroundColor: _currentPage == pageNum ? const Color(
                    0xffFE691E) : Colors.transparent,
                foregroundColor: _currentPage == pageNum ? Colors.white : Colors
                    .black,
                shape: const CircleBorder(),
                minimumSize: const Size(40, 40),
              ),
              child: Text('$pageNum'),
            );
          }),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < _totalPages ? () {
              setState(() => _currentPage++);
            } : null,
          ),
        ],
      ),
    );
  }

  Widget _buildStockHistoryCard(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Stock History Log",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              OutlinedButton(
                onPressed: () {
                  /* TODO: Implement View All History */
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text("View All"),
              ),
            ],
          ),
          const Divider(height: 24),
          if (_stockHistory.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No stock history available',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ..._stockHistory.take(3).map((history) =>
                _buildHistoryLogRow(history)),
        ],
      ),
    );
  }

  Widget _buildHistoryLogRow(StockHistory history) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: history.isRestock
                ? Colors.green.withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
            child: Icon(
              history.isRestock ? Icons.arrow_upward : Icons.arrow_downward,
              color: history.isRestock ? Colors.green : Colors.orange,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${history.productName} updated from ${history.oldStock ??
                      "N/A"} to ${history.newStock}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Reason: ${history.reason}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            history.timeAgo,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}