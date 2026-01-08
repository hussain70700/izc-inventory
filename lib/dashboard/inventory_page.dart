import 'package:flutter/material.dart';

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
  String _activeFilter = 'All products';
  // State for pagination
  int _currentPage = 1;
  final int _itemsPerPage = 4;

  // --- DERIVED STATE & LOGIC ---

  // Filter products based on the active filter
  List<Product> get _filteredProducts {
    if (_activeFilter == 'Low stock') {
      return _allProducts.where((p) => p.isLowStock).toList();
    }
    // "All products" and other potential filters will show everything for now
    return _allProducts;
  }

  // Calculate total pages for pagination
  int get _totalPages {
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
    return Scaffold(
      backgroundColor: const Color(0xffF6F7FB),
      body: SingleChildScrollView(
        child: GestureDetector( // To close menus when tapping outside
          onTap: _closeAllMenus,
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  // This is the main Column that lays out everything vertically.
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HEADER
                      _buildHeader(),
                      const SizedBox(height: 24),

                      // STATS
                      _buildStatsRow(),
                      const SizedBox(height: 24),

                      // <<<<< START OF CHANGE >>>>>
                      // NEW: SEPARATE CARD FOR THE MENU BAR
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _buildMenuBar(),
                      ),
                      const SizedBox(height: 24),
                      // <<<<< END OF CHANGE >>>>>

                      // TABLE AREA
                      SizedBox(
                        height: 440, // Adjusted height as the menu is no longer inside
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // REMOVED: _buildMenuBar() from here
                              // const SizedBox(height: 20),
                              tableHeader(),
                              const Divider(height: 1),
                              // The list of products
                              Expanded( // This Expanded is now contained and works correctly
                                child: ListView.separated(
                                  itemCount: _paginatedProducts.length,
                                  itemBuilder: (context, index) {
                                    final product = _paginatedProducts[index];
                                    return tableRow(product);
                                  },
                                  separatorBuilder: (context, index) => const Divider(height: 1),
                                ),
                              ),
                              const Divider(height: 1),
                              // Pagination Controls
                              _buildPaginationControls(),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24), // Space between the two cards
                      // The Stock History Card now sits comfortably below the fixed-height table
                      _buildStockHistoryCard(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// ... rest of your code remains the same ...

// ... rest of your code remains the same ...

// ... rest of your code remains the same ...

  // ---------- WIDGETS (Refactored for clarity) ----------
  Widget _buildStockHistoryCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          "Inventory Management",
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold),
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

  Widget _buildStatsRow() {
    return Row(
      children: [
        statCard("Total Products", _allProducts.length.toString(), Icons.inventory, Colors.blue),
        statCard("Total Value", "\$142,300", Icons.attach_money, Colors.green),
        statCard("Low Stock", _allProducts.where((p) => p.isLowStock).length.toString(), Icons.warning, Colors.orange),
        statCard("Out of Stock", _allProducts.where((p) => p.isOutOfStock).length.toString(), Icons.cancel, Colors.red),
      ],
    );
  }

  // NEW: Menu bar with filter and action buttons
  Widget _buildMenuBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left side: Filter buttons
        Row(
          children: [
            _filterButton("All products"),
            const SizedBox(width: 8),
            _filterButton("Low stock"),
          ],
        ),
        // Right side: Action buttons
        Row(
          children: [
            _actionButton(Icons.filter_alt_outlined, "Filter"),
            const SizedBox(width: 8),
            _actionButton(Icons.file_upload_outlined, "Export"),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () { /* TODO: Add Product Logic */ },
              icon: const Icon(Icons.add),
              label: const Text("Add Product"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xffFE691E),
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
  Widget _actionButton(IconData icon, String label) {
    return OutlinedButton.icon(
      onPressed: () { /* TODO: Implement action */ },
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.grey.shade700,
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
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

  Widget tableHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      child: Row(
        children: [
          const Expanded(flex: 3, child: Text("PRODUCT", style: TextStyle(color: Colors.grey, fontSize: 12))),
          const Expanded(flex: 2, child: Text("SKU", style: TextStyle(color: Colors.grey, fontSize: 12))),
          const Expanded(child: Text("STOCK", style: TextStyle(color: Colors.grey, fontSize: 12))),
          const Expanded(flex: 2, child: Text("PRICE", style: TextStyle(color: Colors.grey, fontSize: 12))),
          const Expanded(flex: 2, child: Text("STATUS", style: TextStyle(color: Colors.grey, fontSize: 12))),
          // Expanded widget for the actions column to align the header
          const Expanded(flex: 2, child: Text("ACTIONS", style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center,)),
        ],
      ),
    );
  }

  // MODIFIED: tableRow now accepts a Product object
  Widget tableRow(Product product) {
    Color statusColor = product.isOutOfStock ? Colors.orange : (product.isActive ? Colors.green : Colors.grey);
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
            await showMenu(
              context: context,
              // Position the menu relative to the button
              position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
              items: [
                const PopupMenuItem(
                  child: Row(children: [Icon(Icons.edit, size: 18, color: Color(0xffFE691E)), SizedBox(width: 8), Text("Edit")]),
                ),
                const PopupMenuItem(
                  child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text("Delete")]),
                ),
              ],
            );
          },
          child: const Icon(Icons.more_horiz, color: Colors.grey),
        );
      },
    );
  }
}
