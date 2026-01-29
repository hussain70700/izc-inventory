// ============================================
// INVENTORY PAGE - With Image Support
// lib/screens/inventory_page.dart
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/product_model.dart';
import '../services/supabase_service.dart';
import '../services/session_service.dart';
import 'package:excel/excel.dart' hide Border;
import '../utils/file_download.dart';
import 'dart:typed_data';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  // Services
  final _supabaseService = SupabaseService();
  final _imagePicker = ImagePicker();

  // State variables
  List<Product> _allProducts = [];
  List<StockHistory> _stockHistory = [];
  bool _isLoading = true;
  bool _isAdmin = false;
  String? _currentUserRole;
  String? _currentUsername;
  String? _currentUserEmail;
  String _sortOrder = 'A-Z';
  String _activeFilter = 'All Products';
  int _currentPage = 1;
  final int _itemsPerPage = 4;
  final GlobalKey _filterButtonKey = GlobalKey();

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Stats
  double _totalValue = 0.0;
  int _lowStockCount = 0;
  int _outOfStockCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeData();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase().trim();
        _currentPage = 1;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    _loadUserSession();
    await _loadData();
    _setupRealtimeListeners();
  }

  void _loadUserSession() {
    setState(() {
      _currentUserRole = SessionService.getUserRole();
      _currentUsername = SessionService.getUsername();
      _currentUserEmail = SessionService.getEmail();
      _isAdmin = SessionService.isAdmin();
    });
  }

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
          print('Current User Role: $_currentUserRole');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Failed to load data: $e');
      }
    }
  }

  void _setupRealtimeListeners() {
    _supabaseService.watchProducts().listen((products) {
      if (mounted) {
        setState(() {
          _allProducts = products;
          _updateStats();
        });
      }
    });

    _supabaseService.watchStockHistory(limit: 10).listen((history) {
      if (mounted) {
        setState(() => _stockHistory = history);
      }
    });
  }

  void _updateStats() {
    _lowStockCount = _allProducts.where((p) => p.isLowStock).length;
    _outOfStockCount = _allProducts.where((p) => p.isOutOfStock).length;
    _totalValue = _allProducts.fold(0.0, (sum, p) => sum + (p.price * p.stock));
  }

  List<Product> _searchProducts(List<Product> products) {
    if (_searchQuery.isEmpty) return products;
    return products.where((product) {
      final nameLower = product.name.toLowerCase();
      final skuLower = product.sku.toLowerCase();
      return nameLower.contains(_searchQuery) || skuLower.contains(_searchQuery);
    }).toList();
  }


// Replace the filter-related code in _InventoryPageState



// Replace the _filteredProducts getter
  List<Product> get _filteredProducts {
    List<Product> filtered;
    switch (_activeFilter) {
      case 'Active products':
        filtered = _allProducts.where((p) => p.isActive).toList();
        break;
      case 'Out of Stock':
        filtered = _allProducts.where((p) => p.isOutOfStock).toList();
        break;
      case 'Low Stock':
        filtered = _allProducts.where((p) => p.isLowStock && !p.isOutOfStock).toList();
        break;
      case 'Inactive products':
        filtered = _allProducts.where((p) => !p.isActive).toList();
        break;
      case 'All Products':
      default:
        filtered = _allProducts;
    }

    // Apply search filter
    filtered = _searchProducts(filtered);

    // Apply sorting
    switch (_sortOrder) {
      case 'A-Z':
        filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case 'Z-A':
        filtered.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case 'Price: Low to High':
        filtered.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'Price: High to Low':
        filtered.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'Stock: Low to High':
        filtered.sort((a, b) => a.stock.compareTo(b.stock));
        break;
      case 'Stock: High to Low':
        filtered.sort((a, b) => b.stock.compareTo(a.stock));
        break;
    }

    return filtered;
  }

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

    final filterOptions = ['Active products', 'Low Stock', 'Inactive products'];

    showMenu<String>(
      color: Colors.white,
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
          _currentPage = 1;
        });
      }
    });
  }

  void _showSortMenu() {
    final sortOptions = [
      'A-Z',
      'Z-A',
      'Price: Low to High',
      'Price: High to Low',
      'Stock: Low to High',
      'Stock: High to Low',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Sort Products'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: sortOptions.map((option) {
            final isSelected = _sortOrder == option;
            return ListTile(
              title: Text(
                option,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? const Color(0xffFE691E) : Colors.black,
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check, color: Color(0xffFE691E))
                  : null,
              onTap: () {
                setState(() {
                  _sortOrder = option;
                  _currentPage = 1;
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  // Pick image from gallery
  Future<Uint8List?> _pickImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        return await pickedFile.readAsBytes();
      }
      return null;
    } catch (e) {
      _showError('Failed to pick image: $e');
      return null;
    }
  }

  // Add Product Dialog with Image
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
    Uint8List? selectedImage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text('Add Product'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Image Picker
                    GestureDetector(
                      onTap: isSubmitting ? null : () async {
                        final image = await _pickImage();
                        if (image != null) {
                          setDialogState(() => selectedImage = image);
                        }
                      },
                      child: Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: selectedImage != null
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            selectedImage!,
                            fit: BoxFit.cover,
                          ),
                        )
                            : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate,
                                size: 48, color: Colors.grey.shade600),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to add product image',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : () async {
                    final name = nameController.text.trim();
                    final sku = skuController.text.trim();
                    final stockText = stockController.text.trim();
                    final priceText = priceController.text.trim();

                    if (name.isEmpty || sku.isEmpty || stockText.isEmpty || priceText.isEmpty) {
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
                        imageFile: selectedImage,
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

  // Edit Product Dialog with Image
  void _showEditProductDialog(Product product) {
    if (!_isAdmin) {
      _showError('Only admins can edit products');
      return;
    }

    final nameController = TextEditingController(text: product.name);
    final skuController = TextEditingController(text: product.sku);
    final stockController = TextEditingController(text: product.stock.toString());
    final priceController = TextEditingController(text: product.price.toStringAsFixed(2));
    bool isActive = product.isActive;
    bool isSubmitting = false;
    Uint8List? newImage;
    bool hasExistingImage = product.imageUrl != null && product.imageUrl!.isNotEmpty;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text('Edit Product'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Image Picker
                    GestureDetector(
                      onTap: isSubmitting ? null : () async {
                        final image = await _pickImage();
                        if (image != null) {
                          setDialogState(() {
                            newImage = image;
                            hasExistingImage = false;
                          });
                        }
                      },
                      child: Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: newImage != null
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            newImage!,
                            fit: BoxFit.cover,
                          ),
                        )
                            : hasExistingImage
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            product.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image,
                                      size: 48, color: Colors.grey.shade600),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Failed to load image',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                ],
                              );
                            },
                          ),
                        )
                            : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate,
                                size: 48, color: Colors.grey.shade600),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to add product image',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (hasExistingImage || newImage != null)
                      TextButton.icon(
                        onPressed: isSubmitting ? null : () {
                          setDialogState(() {
                            newImage = null;
                            hasExistingImage = false;
                          });
                        },
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('Remove Image'),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                      ),
                    const SizedBox(height: 16),
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
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : () async {
                    final name = nameController.text.trim();
                    final sku = skuController.text.trim();
                    final stockText = stockController.text.trim();
                    final priceText = priceController.text.trim();

                    if (name.isEmpty || sku.isEmpty || stockText.isEmpty || priceText.isEmpty) {
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
                          imageUrl: hasExistingImage ? product.imageUrl : null,
                        ),
                        newImageBytes: newImage,
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

  Future<void> _exportInventoryToExcel() async {
    try {
      // Debug: Log what we're trying to export
      print('🔍 Export Debug Info:');
      print('   Total products: ${_allProducts.length}');
      print('   Filtered products: ${_filteredProducts.length}');
      print('   Active filter: $_activeFilter');
      print('   Search query: "$_searchQuery"');
      print('   Sort order: $_sortOrder');

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xffFE691E)),
        ),
      );

      var excel = Excel.createExcel();

      // Delete default sheet
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      // Create new sheet
      excel.copy('Sheet1', 'Inventory');
      Sheet sheetObject = excel['Inventory'];

      var headers = ['Product Name', 'SKU', 'Stock', 'Price', 'Status', 'Total Value'];
      for (var i = 0; i < headers.length; i++) {
        var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#FE691E'),
          fontColorHex: ExcelColor.white,
        );
      }

      // Use _filteredProducts to respect current view
      final productsToExport = _filteredProducts;

      print('📦 Products to export: ${productsToExport.length}');

      if (productsToExport.isEmpty) {
        if (mounted) Navigator.pop(context);
        _showError('No products to export with current filter');
        return;
      }

      // Add each product
      for (var i = 0; i < productsToExport.length; i++) {
        final product = productsToExport[i];
        final rowIndex = i + 1;

        print('   Adding product ${i + 1}: ${product.name}');

        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
            .value = TextCellValue(product.name);
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
            .value = TextCellValue(product.sku);
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
            .value = IntCellValue(product.stock);
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
            .value = DoubleCellValue(product.price);

        String status = product.isOutOfStock
            ? "Out of Stock"
            : (product.isActive ? "Active" : "Inactive");
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
            .value = TextCellValue(status);

        double totalValue = product.price * product.stock;
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex))
            .value = DoubleCellValue(totalValue);
      }

      // Set column widths
      for (var i = 0; i < headers.length; i++) {
        sheetObject.setColumnWidth(i, 20);
      }

      // Encode to bytes
      var fileBytes = excel.encode();

      print('📄 Excel encoded, bytes: ${fileBytes?.length ?? 0}');

      if (mounted) Navigator.pop(context);

      if (fileBytes == null || fileBytes.isEmpty) {
        _showError('Failed to generate Excel file - encoding returned null/empty');
        return;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'inventory_export_$timestamp.xlsx';
      final bytes = Uint8List.fromList(fileBytes);

      print('💾 Downloading file: $fileName (${bytes.length} bytes)');

      await downloadFile(bytes, fileName);

      if (mounted) {
        _showSuccess('Exported ${productsToExport.length} products successfully: $fileName');
      }

      print('✅ Export completed successfully');
    } catch (e, stackTrace) {
      print('❌ Export error: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        Navigator.pop(context);
        _showError('Failed to export: $e');
      }
    }
  }

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
              backgroundColor: Colors.white,
              title: const Text('Delete Product'),
              content: Text('Are you sure you want to delete "${product.name}"?\n\nThis action cannot be undone.'),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isDeleting ? null : () async {
                    setDialogState(() => isDeleting = true);
                    try {
                      await _supabaseService.deleteProduct(product.id);
                      Navigator.pop(dialogContext);
                      _showSuccess('Product "${product.name}" deleted successfully');
                      await _loadData();
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
              backgroundColor: Colors.white,
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
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
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

  void _showAllHistoryDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Complete Stock History",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Expanded(
                  child: FutureBuilder<List<StockHistory>>(
                    future: _supabaseService.fetchStockHistory(limit: 100),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: Color(0xffFE691E)),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error loading history: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }
                      final allHistory = snapshot.data ?? [];
                      if (allHistory.isEmpty) {
                        return const Center(
                          child: Text(
                            'No stock history available',
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }
                      return ListView.separated(
                        itemCount: allHistory.length,
                        itemBuilder: (context, index) {
                          final history = allHistory[index];
                          return _buildHistoryLogRow(history);
                        },
                        separatorBuilder: (context, index) => const Divider(height: 1),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
          child: CircularProgressIndicator(color: Color(0xffFE691E)),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < 800;
        final bool isMobile = constraints.maxWidth < 600;
        final double horizontalPadding = isMobile ? 12.0 : (isNarrow ? 16.0 : 24.0);
        final double contentVerticalPadding = isMobile ? 16.0 : 24.0;

        return Scaffold(
          backgroundColor: const Color(0xffF6F7FB),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: isMobile ? 16 : 24,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 0,
                      blurRadius: 6,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: _buildHeader(isMobile),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: contentVerticalPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatsRow(isMobile),
                          SizedBox(height: isMobile ? 16 : 24),
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
                                        _searchQuery.isNotEmpty
                                            ? 'No products found matching "$_searchQuery"'
                                            : 'No products found',
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
                          _buildStockHistoryCard(isMobile),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
          controller: _searchController,
          decoration: InputDecoration(
            hintText: "Search products, SKU...",
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => _searchController.clear(),
            )
                : null,
            filled: true,
            fillColor: Colors.grey.shade200,
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

          ],
        ),
        Row(
          children: [
            SizedBox(
              width: 250,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Search products, SKU...",
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _searchController.clear(),
                  )
                      : null,
                  filled: true,
                  fillColor: Colors.grey.shade200,
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
            Expanded(
                child: _buildStatCard("Total Products",
                    _allProducts.length.toString(), Icons.inventory, Colors.blue)),
            const SizedBox(width: 8),
            Expanded(
                child: _buildStatCard("Total Value",
                    "Rs ${_totalValue.toStringAsFixed(2)}", Icons.attach_money, Colors.green)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
                child: _buildStatCard(
                    "Low Stock", _lowStockCount.toString(), Icons.warning, Colors.orange)),
            const SizedBox(width: 8),
            Expanded(
                child: _buildStatCard("Out of Stock", _outOfStockCount.toString(),
                    Icons.cancel, Colors.red)),
          ],
        ),
      ],
    )
        : Row(
      children: [
        Expanded(
            child: _buildStatCard("Total Products", _allProducts.length.toString(),
                Icons.inventory, Colors.blue)),
        const SizedBox(width: 12),
        Expanded(
            child: _buildStatCard("Total Value", 'Rs ${_totalValue.toStringAsFixed(2)}',
                Icons.attach_money, Colors.green)),
        const SizedBox(width: 12),
        Expanded(
            child: _buildStatCard(
                "Low Stock", _lowStockCount.toString(), Icons.warning, Colors.orange)),
        const SizedBox(width: 12),
        Expanded(
            child: _buildStatCard(
                "Out of Stock", _outOfStockCount.toString(), Icons.cancel, Colors.red)),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
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
                Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Text(value,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
            Expanded(child: _buildFilterButton("All Products")),
            const SizedBox(width: 8),
            Expanded(child: _buildFilterButton("Out of Stock")),
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
              Icons.sort,
              "Sort",
              onPressed: _showSortMenu,
            ),
            _buildActionButton(
              Icons.file_upload_outlined,
              "Export",
              onPressed: _exportInventoryToExcel,
            ),
            ElevatedButton.icon(
              onPressed: _isAdmin
                  ? _showAddProductDialog
                  : () => _showError('Only admins can add products'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text("Add Product"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isAdmin ? const Color(0xffFE691E) : Colors.grey,
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
        Row(
          children: [
            _buildFilterButton("All Products"),
            const SizedBox(width: 8),
            _buildFilterButton("Out of Stock"),
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
              Icons.sort,
              "Sort",
              onPressed: _showSortMenu,
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              Icons.file_upload_outlined,
              "Export",
              onPressed: _exportInventoryToExcel,
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _isAdmin
                  ? _showAddProductDialog
                  : () => _showError('Only admins can add products'),
              icon: const Icon(Icons.add),
              label: const Text("Add Product"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isAdmin ? const Color(0xffFE691E) : Colors.grey,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        backgroundColor:
        isSelected ? const Color(0xffFE691E).withOpacity(0.1) : Colors.transparent,
        foregroundColor: isSelected ? const Color(0xffFE691E) : Colors.grey.shade600,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildActionButton(IconData icon, String label, {VoidCallback? onPressed}) {
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
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("PRODUCTS",
                style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
            if (_searchQuery.isNotEmpty || _activeFilter != 'Active products')
              Text(
                '${_filteredProducts.length} result${_filteredProducts.length != 1 ? 's' : ''}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
      child: Row(
        children: [
          // IMAGE - Center aligned
          Expanded(
            flex: 1,
            child: Center(
              child: const Text("IMAGE",
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
          ),
          const SizedBox(width: 20),

          // PRODUCT - Left aligned (default)
          const Expanded(
            flex: 3,
            child: Text("PRODUCT",
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),

          // SKU - Left aligned (default)
          const Expanded(
            flex: 2,
            child: Text("SKU",
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),

          // STOCK - Center aligned
          Expanded(
            flex: 1,
            child: Center(
              child: const Text("STOCK",
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
          ),
          const SizedBox(width: 20),

          // PRICE - Left aligned (default)
          const Expanded(
            flex: 2,
            child: Text("PRICE",
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),

          // STATUS - Center aligned
          Expanded(
            flex: 2,
            child: Center(
              child: const Text("STATUS",
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
          ),

          // ACTIONS - Center aligned
          Expanded(
            flex: 2,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("ACTIONS",
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  if (_searchQuery.isNotEmpty || _activeFilter != 'Active products')
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        '(${_filteredProducts.length})',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
          ),
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
    Color statusColor =
    product.isOutOfStock ? Colors.red : (product.isActive ? Colors.green : Colors.grey);
    String statusText =
    product.isOutOfStock ? "Out of Stock" : (product.isActive ? "Active" : "Disabled");

    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image
          Container(
            width: 60,
            height: 60,
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
                  return Icon(Icons.broken_image, color: Colors.grey.shade400);
                },
              ),
            )
                : Icon(Icons.inventory_2, color: Colors.grey.shade400, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
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
                        style: TextStyle(
                            color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
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
                            color: product.isLowStock || product.isOutOfStock
                                ? Colors.red
                                : Colors.black,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text("Price", style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text(
                          product.priceFormatted,
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
                      _buildRestockButton(product)
                    else
                      _buildOptionsMenu(product),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(Product product, bool isMobile) {
    Color statusColor =
    product.isOutOfStock ? Colors.red : (product.isActive ? Colors.green : Colors.grey);
    String statusText =
    product.isOutOfStock ? "Out of Stock" : (product.isActive ? "Active" : "Disabled");

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        children: [
          // Product Image - Center aligned
          Expanded(
            flex: 1,
            child: Center(
              child: Container(
                width: 48,           // slightly smaller looks better in table
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,           // ← important
                  color: Colors.grey.shade200,
                  // Optional: border
                  // border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: ClipOval(                    // ← clips content to circle
                  child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                      ? Image.network(
                    product.imageUrl!,
                    fit: BoxFit.cover,
                    width: 48,
                    height: 48,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.broken_image,
                        color: Colors.grey.shade400,
                        size: 24,
                      );
                    },
                  )
                      : Icon(
                    Icons.inventory_2,
                    color: Colors.grey.shade400,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),

          // Product Name - Left aligned (default)
          Expanded(
            flex: 3,
            child: Text(product.name),
          ),

          // SKU - Left aligned (default)
          Expanded(
            flex: 2,
            child: Text(product.sku),
          ),

          // Stock - Center aligned
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                product.stock.toString(),
                style: TextStyle(
                  color: product.isLowStock || product.isOutOfStock
                      ? Colors.red
                      : Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),

          // Price - Left aligned (default)
          Expanded(
            flex: 2,
            child: Text(product.priceFormatted),
          ),

          // Status - Center aligned
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),

          // Actions - Center aligned
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
          position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
        Text(
        'Showing ${_paginatedProducts.isEmpty ? 0 : ((_currentPage - 1) * _itemsPerPage) + 1}-${((_currentPage - 1) * _itemsPerPage) + _paginatedProducts.length} of ${_filteredProducts.length}',
    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
    ),
    Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
    IconButton(
    icon: const Icon(Icons.chevron_left),
    onPressed: _currentPage > 1
    ? () {
    setState(() => _currentPage--);
    }
        : null,
    ),
    ...List.generate(_totalPages, (index) {
    final pageNum = index + 1;
    return TextButton(
      onPressed: () {
        setState(() => _currentPage = pageNum);
      },
      style: TextButton.styleFrom(
        backgroundColor: _currentPage == pageNum
            ? const Color(0xffFE691E)
            : Colors.transparent,
        foregroundColor:
        _currentPage == pageNum ? Colors.white : Colors.black,
        shape: const CircleBorder(),
        minimumSize: const Size(40, 40),
      ),
      child: Text('$pageNum'),
    );
    }),
      IconButton(
        icon: const Icon(Icons.chevron_right),
        onPressed: _currentPage < _totalPages
            ? () {
          setState(() => _currentPage++);
        }
            : null,
      ),
    ],
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
                onPressed: _showAllHistoryDialog,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
            ..._stockHistory.take(3).map((history) => _buildHistoryLogRow(history)),
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
                  '${history.productName} updated from ${history.oldStock ?? "N/A"} to ${history.newStock}',
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