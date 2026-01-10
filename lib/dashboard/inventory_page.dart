import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// A simple data model for our product. This makes managing data easier.
class Product {
  final String name;
  final String sku;
  final int stock;
  final String price;
  final bool isActive;
  // A new property to manage the visibility of the action menu
  bool isMenuOpen;

  Product({
    required this.name,
    required this.sku,
    required this.stock,
    required this.price,
    required this.isActive,
    this.isMenuOpen = false,
  });

  bool get isLowStock => stock > 0 && stock <= 10;
  bool get isOutOfStock => stock == 0;
}


// Converted to a StatefulWidget to manage state for filters, pagination, and menus.
class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  // --- STATE VARIABLES ---

  // Simulating a database of products
  final List<Product> _allProducts = [
    Product(name: "Minimalist Watch", sku: "WT-2024-001", stock: 45, price: "\$129.00", isActive: true),
    Product(name: "Wireless Headphones", sku: "AU-2024-055", stock: 5, price: "\$249.99", isActive: true),
    Product(name: "Urban Runners", sku: "SH-2024-102", stock: 128, price: "\$89.50", isActive: true),
    Product(name: "Vintage Camera", sku: "CM-2024-009", stock: 0, price: "\$599.00", isActive: false),
    Product(name: "Leather Wallet", sku: "AC-2024-030", stock: 200, price: "\$49.00", isActive: true),
    Product(name: "Smart Speaker", sku: "EL-2024-015", stock: 30, price: "\$99.00", isActive: true),
    Product(name: "Yoga Mat", sku: "SP-2024-080", stock: 8, price: "\$29.99", isActive: true),
    Product(name: "Glass Water Bottle", sku: "KT-2024-019", stock: 50, price: "\$19.99", isActive: true),
    Product(name: "LED Desk Lamp", sku: "OF-2024-003", stock: 0, price: "\$79.00", isActive: false),
    Product(name: "Bluetooth Keyboard", sku: "PC-2024-088", stock: 2, price: "\$59.50", isActive: true),
    Product(name: "Cotton T-Shirt", sku: "AP-2024-301", stock: 150, price: "\$25.00", isActive: true),
    Product(name: "Scented Candle", sku: "HM-2024-042", stock: 60, price: "\$15.00", isActive: true),
  ];

  // State for the active filter button
  String _activeFilter = 'Active products';
  // State for pagination
  int _currentPage = 1;
  final int _itemsPerPage = 4;
  // Key for the Filter button to get its position
  final GlobalKey _filterButtonKey = GlobalKey();

  // --- DERIVED STATE & LOGIC ---

  // Filter products based on the active filter
  List<Product> get _filteredProducts {
    switch (_activeFilter) {
      case 'Out of stock':
        return _allProducts.where((p) => p.isOutOfStock).toList();
      case 'Active products':
        return _allProducts.where((p) => p.isActive).toList();
      case 'Inactive products':
        return _allProducts.where((p) => !p.isActive).toList();
      default:
        // Fallback to showing all products if an unknown filter is set.
        return _allProducts;
    }
  }

  // Calculate total pages for pagination
  int get _totalPages {
    if (_filteredProducts.isEmpty) return 1;
    return (_filteredProducts.length / _itemsPerPage).ceil();
  }

  // Get products for the current page
  List<Product> get _paginatedProducts {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    // Ensure the end index does not exceed the list's length
    final endIndex = (startIndex + _itemsPerPage > _filteredProducts.length)
        ? _filteredProducts.length
        : startIndex + _itemsPerPage;
    return _filteredProducts.sublist(startIndex, endIndex);
  }

  // Method to close all open menus
  void _closeAllMenus() {
    setState(() {
      for (var product in _allProducts) {
        product.isMenuOpen = false;
      }
    });
  }


  // ... inside _InventoryPageState ...

  // ... inside _InventoryPageState ...

  // ... inside _InventoryPageState ...

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < 800;
        final bool isMobile = constraints.maxWidth < 600;
        final double horizontalPadding = isMobile ? 12.0 : (isNarrow ? 16.0 : 24.0);

        return Scaffold(
          backgroundColor: const Color(0xffF6F7FB),
          body: SingleChildScrollView(
            child: GestureDetector(
              onTap: _closeAllMenus,
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
                            tableHeader(isMobile),
                            const Divider(height: 1),
                            Expanded(
                              child: isMobile
                                  ? _buildMobileProductList()
                                  : ListView.separated(
                                      itemCount: _paginatedProducts.length,
                                      itemBuilder: (context, index) {
                                        final product = _paginatedProducts[index];
                                        return tableRow(product, isMobile);
                                      },
                                      separatorBuilder: (context, index) => const Divider(height: 1),
                                    ),
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

// ... rest of your code remains the same ...

// ... rest of your code remains the same ...

// ... rest of your code remains the same ...

  // ---------- WIDGETS (Refactored for clarity) ----------
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
            offset: const Offset(0, 4), // changes position of shadow
          ),
        ],

      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Stock History Log",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              OutlinedButton(
                onPressed: () { /* TODO: Implement View All History */ },
                child: const Text("View All"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Log Entries
          _historyLogRow("Minimalist Watch updated from 50 to 45.", "Sale #12345", "1h ago", false),
          _historyLogRow("Wireless Headphones restocked from 0 to 10.", "Manual Restock", "4h ago", true),
          _historyLogRow("Urban Runners updated from 130 to 128.", "Sale #12344", "Yesterday", false),
        ],
      ),
    );
  }

  // Helper widget for a single row in the history log
  Widget _historyLogRow(String description, String reason, String time, bool isRestock) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isRestock ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
            child: Icon(
              isRestock ? Icons.arrow_upward : Icons.arrow_downward,
              color: isRestock ? Colors.green : Colors.orange,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text("Reason: $reason", style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return isMobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Inventory Management",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
              const Text(
                "Inventory Management",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
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
          );
  }

  Widget _buildStatsRow(bool isMobile) {
    return isMobile
        ? Column(
            children: [
              Row(
                children: [
                  Expanded(child: statCard("Total Products", _allProducts.length.toString(), Icons.inventory, Colors.blue)),
                  const SizedBox(width: 8),
                  Expanded(child: statCard("Total Value", "\$142,300", Icons.attach_money, Colors.green)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: statCard("Low Stock", _allProducts.where((p) => p.isLowStock).length.toString(), Icons.warning, Colors.orange)),
                  const SizedBox(width: 8),
                  Expanded(child: statCard("Out of Stock", _allProducts.where((p) => p.isOutOfStock).length.toString(), Icons.cancel, Colors.red)),
                ],
              ),
            ],
          )
        : Row(
            children: [
              Expanded(child: statCard("Total Products", _allProducts.length.toString(), Icons.inventory, Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: statCard("Total Value", "\$142,300", Icons.attach_money, Colors.green)),
              const SizedBox(width: 12),
              Expanded(child: statCard("Low Stock", _allProducts.where((p) => p.isLowStock).length.toString(), Icons.warning, Colors.orange)),
              const SizedBox(width: 12),
              Expanded(child: statCard("Out of Stock", _allProducts.where((p) => p.isOutOfStock).length.toString(), Icons.cancel, Colors.red)),
            ],
          );
  }

  // NEW: Menu bar with filter and action buttons
  Widget _buildMenuBar(bool isMobile) {
    return isMobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: _filterButton("Active products")),
                  const SizedBox(width: 8),
                  Expanded(child: _filterButton("Out of stock")),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  _actionButtonWithKey(
                    Icons.filter_alt_outlined,
                    "Filter",
                    key: _filterButtonKey,
                    onPressed: _showFilterMenu,
                  ),
                  _actionButton(
                    Icons.file_upload_outlined,
                    "Export",
                    onPressed: _exportInventoryToCsv,
                  ),
                  ElevatedButton.icon(
                    onPressed: _showAddProductDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text("Add Product"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xffFE691E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left side: Filter buttons
              Row(
                children: [
                  _filterButton("Active products"),
                  const SizedBox(width: 8),
                  _filterButton("Out of stock"),
                ],
              ),
              // Right side: Action buttons
              Row(
                children: [
                  _actionButtonWithKey(
                    Icons.filter_alt_outlined,
                    "Filter",
                    key: _filterButtonKey,
                    onPressed: _showFilterMenu,
                  ),
                  const SizedBox(width: 8),
                  _actionButton(
                    Icons.file_upload_outlined,
                    "Export",
                    onPressed: _exportInventoryToCsv,
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _showAddProductDialog,
                    icon: const Icon(Icons.add),
                    label: const Text("Add Product"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xffFE691E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          );
  }

  // Helper for filter buttons
  Widget _filterButton(String title) {
    bool isSelected = _activeFilter == title;
    return TextButton(
      onPressed: () {
        setState(() {
          _activeFilter = title;
          _currentPage = 1; // Reset to first page on filter change
        });
      },
      style: TextButton.styleFrom(
        backgroundColor: isSelected ? Color(0xffFE691E).withOpacity(0.1) : Colors.transparent,
        foregroundColor: isSelected ? Color(0xffFE691E) : Colors.grey.shade600,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  // Helper for action buttons (Filter, Export)
  Widget _actionButton(IconData icon, String label, {VoidCallback? onPressed}) {
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

  // Helper for action button with key (for Filter button)
  Widget _actionButtonWithKey(IconData icon, String label, {Key? key, VoidCallback? onPressed}) {
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

  /// Export current inventory data to a CSV string and copy it to the clipboard.
  /// This CSV can be pasted directly into Excel or Google Sheets.
  void _exportInventoryToCsv() async {
    final buffer = StringBuffer();
    buffer.writeln('Product,SKU,Stock,Price,Status');

    for (final product in _allProducts) {
      final status = product.isOutOfStock
          ? 'Out of Stock'
          : (product.isActive ? 'Active' : 'Inactive');
      // Wrap text fields in quotes to be safe for commas.
      buffer.writeln(
          '"${product.name}","${product.sku}",${product.stock},"${product.price}","$status"');
    }

    final csvText = buffer.toString();
    await Clipboard.setData(ClipboardData(text: csvText));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Inventory data copied to clipboard. Paste into Excel to view.',
          ),
        ),
      );
    }
  }

  // Popup menu to choose filter options when tapping the Filter button
  void _showFilterMenu() {
    final RenderBox? button = _filterButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (button == null) return;

    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final Offset buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);
    final Size buttonSize = button.size;

    final RelativeRect position = RelativeRect.fromLTRB(
      buttonPosition.dx,
      buttonPosition.dy + buttonSize.height + 8,
      overlay.size.width - (buttonPosition.dx + buttonSize.width),
      overlay.size.height - (buttonPosition.dy + buttonSize.height + 8),
    );

    final filterOptions = <String>[
      'Active products',
      'Inactive products',
      'Out of stock',
    ];

    showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
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
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
          _currentPage = 1; // Reset to first page on filter change
        });
      }
    });
  }

  /// Dialog to add a new product to the inventory.
  void _showAddProductDialog() {
    final nameController = TextEditingController();
    final skuController = TextEditingController();
    final stockController = TextEditingController();
    final priceController = TextEditingController();
    bool isActive = true;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
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
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
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
                      onChanged: (val) {
                        setStateDialog(() {
                          isActive = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final sku = skuController.text.trim();
                    final stockText = stockController.text.trim();
                    final priceText = priceController.text.trim();

                    if (name.isEmpty ||
                        sku.isEmpty ||
                        stockText.isEmpty ||
                        priceText.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please fill in all product details.'),
                        ),
                      );
                      return;
                    }

                    final stock = int.tryParse(stockText);
                    final priceValue = double.tryParse(priceText);
                    if (stock == null || priceValue == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Please enter valid numeric stock and price.'),
                        ),
                      );
                      return;
                    }

                    setState(() {
                      _allProducts.insert(
                        0,
                        Product(
                          name: name,
                          sku: sku,
                          stock: stock,
                          price: '\$${priceValue.toStringAsFixed(2)}',
                          isActive: isActive,
                        ),
                      );
                      // Reset to first page so the new item is visible.
                      _currentPage = 1;
                    });

                    Navigator.of(dialogContext).pop();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Product "$name" added.')),
                    );
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // NEW: Pagination controls
  Widget _buildPaginationControls() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Previous Button
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 1 ? () {
              setState(() {
                _currentPage--;
              });
            } : null, // Disable if on the first page
          ),
          // Page Number Buttons
          ...List.generate(_totalPages, (index) {
            final pageNum = index + 1;
            return TextButton(
              onPressed: () {
                setState(() {
                  _currentPage = pageNum;
                });
              },
              style: TextButton.styleFrom(
                backgroundColor: _currentPage == pageNum ? Color(0xffFE691E) : Colors.transparent,
                foregroundColor: _currentPage == pageNum ? Colors.white : Colors.black,
                shape: const CircleBorder(),
                minimumSize: const Size(40, 40),
              ),
              child: Text('$pageNum'),
            );
          }),
          // Next Button
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < _totalPages ? () {
              setState(() {
                _currentPage++;
              });
            } : null, // Disable if on the last page
          ),
        ],
      ),
    );
  }

  Widget statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 4), // changes position of shadow
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.grey)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget tableHeader(bool isMobile) {
    if (isMobile) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Text("PRODUCTS", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      child: Row(
        children: [
          const Expanded(flex: 3, child: Text("PRODUCT", style: TextStyle(color: Colors.grey, fontSize: 12))),
          const Expanded(flex: 2, child: Text("SKU", style: TextStyle(color: Colors.grey, fontSize: 12))),
          const Expanded(child: Text("STOCK", style: TextStyle(color: Colors.grey, fontSize: 12))),
          const Expanded(flex: 2, child: Text("PRICE", style: TextStyle(color: Colors.grey, fontSize: 12))),
          const Expanded(flex: 2, child: Text("STATUS", style: TextStyle(color: Colors.grey, fontSize: 12))),
          const Expanded(flex: 2, child: Text("ACTIONS", style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  // Mobile product list view
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
    Color statusColor = product.isOutOfStock ? Colors.red : (product.isActive ? Colors.green : Colors.grey);
    String statusText = product.isOutOfStock ? "Out of Stock" : (product.isActive ? "Active" : "Disabled");

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
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
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
                  const Text("Stock", style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text(
                    product.stock.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: product.isLowStock || product.isOutOfStock ? Colors.red : Colors.black,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("Price", style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text(
                    product.price,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
                _restockButton()
              else
                _optionsMenu(product),
            ],
          ),
        ],
      ),
    );
  }

  // MODIFIED: tableRow now accepts a Product object and isMobile flag
  Widget tableRow(Product product, bool isMobile) {
    Color statusColor = product.isOutOfStock ? Colors.red : (product.isActive ? Colors.green : Colors.grey);
    String statusText = product.isOutOfStock ? "Out of Stock" : (product.isActive ? "Active" : "Disabled");

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
          Expanded(flex: 2, child: Text(product.price)),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 4), // changes position of shadow
                  ),
                ],

              ),
              child: Text(
                statusText,
                textAlign: TextAlign.center,
                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
          // NEW: Actions column with conditional Restock button or Options button
          Expanded(
            flex: 2,
            child: Center(
              child: product.isOutOfStock
                  ? _restockButton()
                  : _optionsMenu(product),
            ),
          ),
        ],
      ),
    );
  }

  // NEW: Widget for the "Restock" button
  Widget _restockButton() {
    return ElevatedButton(
      onPressed: () { /* TODO: Implement Restock logic */ },
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xffFE691E),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text("Restock", style: TextStyle(fontSize: 12)),
    );
  }

  // NEW: Widget for the "Edit/Delete" options menu
  Widget _optionsMenu(Product product) {
    // Using a LayoutBuilder to get the position for the PopupMenu
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (details) async {
            // Close any other open menus first
            _closeAllMenus();
            // Then show the new menu
            final position = details.globalPosition;
            final result = await showMenu<String>(
              context: context,
              // Position the menu relative to the button
              position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
              items: [
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(children: [Icon(Icons.edit, size: 18, color: Color(0xffFE691E)), SizedBox(width: 8), Text("Edit")]),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text("Delete")]),
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
      },
    );
  }

  /// Dialog to edit an existing product.
  void _showEditProductDialog(Product product) {
    final nameController = TextEditingController(text: product.name);
    final skuController = TextEditingController(text: product.sku);
    final stockController = TextEditingController(text: product.stock.toString());
    // Remove $ sign and parse price
    final priceText = product.price.replaceAll('\$', '');
    final priceController = TextEditingController(text: priceText);
    bool isActive = product.isActive;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
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
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
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
                      onChanged: (val) {
                        setStateDialog(() {
                          isActive = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final sku = skuController.text.trim();
                    final stockText = stockController.text.trim();
                    final priceText = priceController.text.trim();

                    if (name.isEmpty ||
                        sku.isEmpty ||
                        stockText.isEmpty ||
                        priceText.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please fill in all product details.'),
                        ),
                      );
                      return;
                    }

                    final stock = int.tryParse(stockText);
                    final priceValue = double.tryParse(priceText);
                    if (stock == null || priceValue == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Please enter valid numeric stock and price.'),
                        ),
                      );
                      return;
                    }

                    setState(() {
                      // Find the product index and update it
                      final index = _allProducts.indexOf(product);
                      if (index != -1) {
                        _allProducts[index] = Product(
                          name: name,
                          sku: sku,
                          stock: stock,
                          price: '\$${priceValue.toStringAsFixed(2)}',
                          isActive: isActive,
                        );
                      }
                      // Reset to first page to show updated item
                      _currentPage = 1;
                    });

                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Product "$name" updated successfully.')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffFE691E),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Dialog to confirm deletion of a product.
  void _showDeleteProductDialog(Product product) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Product'),
          content: Text('Are you sure you want to delete "${product.name}"?\n\nThis action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _allProducts.remove(product);
                  // Adjust current page if needed
                  if (_currentPage > _totalPages && _totalPages > 0) {
                    _currentPage = _totalPages;
                  }
                });
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Product "${product.name}" deleted successfully.')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
