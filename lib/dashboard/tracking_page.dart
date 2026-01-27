import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TrackingPage extends StatefulWidget {
  const TrackingPage({super.key});

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> transactions = [];
  List<Map<String, dynamic>> filteredTransactions = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  final List<String> statusOptions = [
    'Processing',
    'In Transit',
    'Shipped',
    'Delivered',
  ];

  final List<String> courierOptions = [
    'TCS',
    'Postex',
    'M&P',
  ];

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
    _searchController.addListener(_filterTransactions);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterTransactions() {
    final query = _searchController.text.toLowerCase();

    if (query.isEmpty) {
      setState(() {
        filteredTransactions = transactions;
      });
      return;
    }

    setState(() {
      filteredTransactions = transactions.where((transaction) {
        final invoiceNumber = transaction['id']?.toString().toLowerCase() ?? '';
        final orderNumber = transaction['order_id']?.toString().toLowerCase() ?? '';
        final customerName = transaction['customer_name']?.toString().toLowerCase() ?? '';
        final status = transaction['status']?.toString().toLowerCase() ?? '';
        final courier = transaction['courier_service']?.toString().toLowerCase() ?? '';

        return invoiceNumber.contains(query) ||
            orderNumber.contains(query) ||
            customerName.contains(query) ||
            status.contains(query) ||
            courier.contains(query);
      }).toList();
    });
  }

  Future<void> _fetchTransactions() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // ✅ Fetch sales with advance_payment field
      final salesResponse = await _supabase
          .from('sales')
          .select('id, status, order_id, courier_service, shipping_address, advance_payment')
          .eq('payment_method', 'COD');

      final statusMap = <String, String>{};
      final orderIdMap = <String, String>{};
      final courierMap = <String, String>{};
      final addressMap = <String, String>{};
      final advancePaymentMap = <String, double>{};

      for (var sale in salesResponse) {
        final saleId = sale['id'].toString();
        statusMap[saleId] = sale['status']?.toString() ?? 'Processing';
        orderIdMap[saleId] = sale['order_id']?.toString() ?? '';
        courierMap[saleId] = sale['courier_service']?.toString() ?? '';
        addressMap[saleId] = sale['shipping_address']?.toString() ?? '';
        advancePaymentMap[saleId] = (sale['advance_payment'] as num?)?.toDouble() ?? 0.0;
      }

      final response = await _supabase
          .from('sales_with_customers')
          .select('''
            *, 
            detailed_sale_items (
              id,
              product_id,
              quantity,
              price,
              product_name
            )
          ''')
          .eq('payment_method', 'COD')
          .order('sale_date', ascending: false);

      if (!mounted) return;

      final salesWithItems = response.map((sale) {
        final saleId = sale['id'].toString();
        return {
          ...sale,
          'status': statusMap[saleId] ?? 'Processing',
          'order_id': orderIdMap[saleId] ?? '',
          'courier_service': courierMap[saleId] ?? '',
          'shipping_address': addressMap[saleId] ?? '',
          'advance_payment': advancePaymentMap[saleId] ?? 0.0,
          'items': (sale['detailed_sale_items'] as List?)?.map((item) {
            return {
              ...item,
              'product_name': item['product_name'] ?? 'Unknown Product',
            };
          }).toList() ?? [],
        };
      }).toList();

      setState(() {
        transactions = List<Map<String, dynamic>>.from(salesWithItems);
        filteredTransactions = transactions;
        _isLoading = false;
      });

      if (transactions.isNotEmpty) {
        print('Loaded ${transactions.length} sales from "sales_with_customers" view');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Failed to load transactions: $e';
        _isLoading = false;
      });
      print('Error fetching transactions: $e');
    }
  }

  Future<void> _updateStatus(int index, String newStatus) async {
    final transaction = transactions[index];
    final id = transaction['id'];

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xffFE691E)),
        ),
      );

      await _supabase
          .from('sales')
          .update({'status': newStatus})
          .eq('id', id);

      if (mounted) {
        setState(() {
          final updatedTransaction = Map<String, dynamic>.from(transactions[index]);
          updatedTransaction['status'] = newStatus;
          transactions[index] = updatedTransaction;
        });
      }

      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to $newStatus for Invoice #$id'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      print('Error updating status: $e');
    }
  }

  Future<void> _updateCourier(int index, String newCourier) async {
    final transaction = transactions[index];
    final id = transaction['id'];

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xffFE691E)),
        ),
      );

      await _supabase
          .from('sales')
          .update({'courier_service': newCourier})
          .eq('id', id);

      if (mounted) {
        setState(() {
          final updatedTransaction = Map<String, dynamic>.from(transactions[index]);
          updatedTransaction['courier_service'] = newCourier;
          transactions[index] = updatedTransaction;
        });
      }

      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Courier updated to $newCourier for Invoice #$id'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update courier: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      print('Error updating courier: $e');
    }
  }

  Future<void> _updateOrderNumber(int index, String newOrderNumber) async {
    final transaction = transactions[index];
    final id = transaction['id'];

    try {
      await _supabase
          .from('sales')
          .update({'order_id': newOrderNumber})
          .eq('id', id);

      if (mounted) {
        setState(() {
          final updatedTransaction = Map<String, dynamic>.from(transactions[index]);
          updatedTransaction['order_id'] = newOrderNumber;
          transactions[index] = updatedTransaction;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order number updated successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update order number: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      print('Error updating order number: $e');
    }
  }

  Future<void> _updateAddress(int index, String newAddress) async {
    final transaction = transactions[index];
    final id = transaction['id'];

    try {
      await _supabase
          .from('sales')
          .update({'shipping_address': newAddress})
          .eq('id', id);

      if (mounted) {
        setState(() {
          final updatedTransaction = Map<String, dynamic>.from(transactions[index]);
          updatedTransaction['shipping_address'] = newAddress;
          transactions[index] = updatedTransaction;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Address updated successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update address: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      print('Error updating address: $e');
    }
  }

  // ✅ DELETE SALE FUNCTION
  Future<void> _deleteSale(int index) async {
    final transaction = transactions[index];
    final id = transaction['id'];
    final invoiceNumber = _getShortInvoiceNumber(id);

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete Sale'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this sale?'),
            const SizedBox(height: 12),
            Text(
              'Invoice: #$invoiceNumber',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Customer: ${transaction['customer_name'] ?? 'N/A'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Text(
                '⚠️ Warning: This action cannot be undone. The stock will NOT be restored.',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xffFE691E)),
        ),
      );

      // Delete sale items first (foreign key constraint)
      await _supabase
          .from('sale_items')
          .delete()
          .eq('sale_id', id);

      // Then delete the sale
      await _supabase
          .from('sales')
          .delete()
          .eq('id', id);

      if (mounted) {
        setState(() {
          transactions.removeAt(index);
          filteredTransactions = transactions;
        });
      }

      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sale #$invoiceNumber deleted successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete sale: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      print('Error deleting sale: $e');
    }
  }

  void _showEditOrderNumberDialog(int index, String currentOrderNumber) {
    final TextEditingController controller = TextEditingController(text: currentOrderNumber);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Edit Tracking Number'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Tracking Number',
            hintText: 'Enter tracking number',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xffFE691E),
            ),
            onPressed: () {
              Navigator.pop(context);
              _updateOrderNumber(index, controller.text.trim());
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditAddressDialog(int index, String currentAddress) {
    final TextEditingController controller = TextEditingController(text: currentAddress);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Edit Shipping Address'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Shipping Address',
            hintText: 'Enter complete shipping address',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xffFE691E),
            ),
            onPressed: () {
              Navigator.pop(context);
              _updateAddress(index, controller.text.trim());
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(Map<String, dynamic> transaction) {
    // ✅ Calculate advance and remaining
    final total = (transaction['total'] as num?)?.toDouble() ?? 0.0;
    final advancePayment = (transaction['advance_payment'] as num?)?.toDouble() ?? 0.0;
    final remaining = total - advancePayment;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xffFE691E),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Invoice #${_getShortInvoiceNumber(transaction['id'])}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Container(
                  color: Colors.white,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Invoice Number', '#${_getShortInvoiceNumber(transaction['id'])}'),
                        _buildDetailRow('Order Number', transaction['order_id']?.toString().isEmpty ?? true ? 'Not Set' : transaction['order_id']?.toString() ?? 'Not Set'),
                        _buildDetailRow('Customer', transaction['customer_name']?.toString() ?? 'N/A'),
                        _buildDetailRow('Phone', transaction['customer_phone']?.toString() ?? 'N/A'),
                        _buildDetailRow('Shipping Address', transaction['shipping_address']?.toString().isEmpty ?? true ? 'Not Set' : transaction['shipping_address']?.toString() ?? 'Not Set'),
                        _buildDetailRow('Date', _formatDate(transaction['sale_date'])),
                        _buildDetailRow('Payment Method', transaction['payment_method']?.toString() ?? 'Cash'),
                        _buildDetailRow('Status', transaction['status']?.toString() ?? 'Processing'),
                        _buildDetailRow('Courier Service', transaction['courier_service']?.toString().isEmpty ?? true ? 'Not Assigned' : transaction['courier_service']?.toString() ?? 'Not Assigned'),

                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 10),

                        const Text(
                          'Products',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),

                        if (transaction['items'] != null && (transaction['items'] as List).isNotEmpty)
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: (transaction['items'] as List).length,
                            itemBuilder: (context, index) {
                              final item = (transaction['items'] as List)[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['product_name']?.toString() ?? 'Unknown Product',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Qty: ${item['quantity']?.toString() ?? '0'}',
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '\$${item['price']?.toString() ?? '0'}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Color(0xffFE691E),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Center(
                              child: Text(
                                'No items found',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),

                        const SizedBox(height: 20),
                        const Divider(),

                        // ✅ Updated payment breakdown
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Amount',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '\$${total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        if (advancePayment > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Advance Payment',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                '-\$${advancePayment.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'COD Amount',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '\$${remaining.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xffFE691E),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < 700;
        final double horizontalPadding = isNarrow ? 16.0 : 24.0;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 24.0,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 0,
                      blurRadius: 6,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Order Tracking",
                          style: TextStyle(
                            fontSize: isNarrow ? 20 : 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Track and manage order status in real-time",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Color(0xffFE691E)),
                      onPressed: _fetchTransactions,
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Search Bar
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by invoice, order number, customer, status, or courier...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xffFE691E)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xffFE691E), width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: _buildContent(isNarrow),
              ),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(bool isNarrow) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(color: Color(0xffFE691E)),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchTransactions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffFE691E),
                ),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    if (transactions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: Text(
            'No transactions found',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    if (filteredTransactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            children: [
              const Icon(Icons.search_off, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'No results found',
                style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Try adjusting your search',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return _buildTransactionsTable(isNarrow);
  }

  Widget _buildTransactionsTable(bool isNarrow) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.4),
            spreadRadius: 4,
            blurRadius: 8,
            offset: const Offset(0, 5),
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
                "All Transactions",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                '${filteredTransactions.length} of ${transactions.length} orders',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
          const Divider(),
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: constraints.maxWidth,
                  ),
                  child: DataTable(
                    headingTextStyle: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                    columnSpacing: 20,
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 64,
                    columns: const [
                      DataColumn(label: Text("INVOICE #")),
                      DataColumn(label: Text("Tracking #")),
                      DataColumn(label: Text("CUSTOMER")),
                      DataColumn(label: Text("DATE")),
                      DataColumn(label: Text("AMOUNT")),
                      DataColumn(label: Text("ADVANCE")),
                      DataColumn(label: Text("REMAINING")),
                      DataColumn(label: Text("STATUS")),
                      DataColumn(label: Text("COURIER")),
                      DataColumn(label: Text("ACTIONS")),
                    ],
                    rows: filteredTransactions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final transaction = entry.value;
                      final originalIndex = transactions.indexWhere((t) => t['id'] == transaction['id']);
                      final orderNumber = transaction['order_id']?.toString() ?? '';
                      final address = transaction['shipping_address']?.toString() ?? '';

                      // ✅ Calculate advance and remaining
                      final total = (transaction['total'] as num?)?.toDouble() ?? 0.0;
                      final advancePayment = (transaction['advance_payment'] as num?)?.toDouble() ?? 0.0;
                      final remaining = total - advancePayment;

                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              '#${_getShortInvoiceNumber(transaction['id'])}',
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DataCell(
                            InkWell(
                              onTap: () => _showEditOrderNumberDialog(originalIndex, orderNumber),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: orderNumber.isEmpty ? Colors.grey.shade100 : const Color(0xffFE691E),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: orderNumber.isEmpty ? Colors.grey.shade300 : Colors.white,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      orderNumber.isEmpty ? 'Add' : orderNumber,
                                      style: TextStyle(
                                        color: orderNumber.isEmpty ? Colors.grey : Colors.white,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.edit,
                                      size: 14,
                                      color: orderNumber.isEmpty ? Colors.grey : Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(transaction['customer_name']?.toString() ?? 'N/A'),
                          ),
                          DataCell(
                            Text(_formatDate(transaction['sale_date'])),
                          ),
                          DataCell(
                            Text(
                              '\$${total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // ✅ ADVANCE PAYMENT COLUMN
                          DataCell(
                            Text(
                              advancePayment > 0 ? '\$${advancePayment.toStringAsFixed(2)}' : '-',
                              style: TextStyle(
                                color: advancePayment > 0 ? Colors.green.shade700 : Colors.grey,
                                fontWeight: advancePayment > 0 ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          // ✅ REMAINING COLUMN
                          DataCell(
                            Text(
                              '\$${remaining.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Color(0xffFE691E),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataCell(
                            _buildStatusDropdown(
                              originalIndex,
                              transaction['status']?.toString() ?? 'Processing',
                            ),
                          ),
                          DataCell(
                            _buildCourierDropdown(
                              originalIndex,
                              transaction['courier_service']?.toString() ?? '',
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.location_on_outlined, color: Color(0xffFE691E)),
                                  onPressed: () => _showEditAddressDialog(originalIndex, address),
                                  tooltip: 'Edit Address',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.inventory_outlined, color: Color(0xffFE691E)),
                                  onPressed: () => _showOrderDetails(transaction),
                                  tooltip: 'View Details',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _deleteSale(originalIndex),
                                  tooltip: 'Delete Sale',
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDropdown(int index, String currentStatus) {
    if (!statusOptions.contains(currentStatus)) {
      currentStatus = 'Processing';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(currentStatus).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getStatusColor(currentStatus).withOpacity(0.3),
        ),
      ),
      child: DropdownButton<String>(
        value: currentStatus,
        underline: const SizedBox(),
        isDense: true,
        style: TextStyle(
          color: _getStatusColor(currentStatus),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        dropdownColor: Colors.white,
        icon: Icon(
          Icons.arrow_drop_down,
          color: _getStatusColor(currentStatus),
          size: 18,
        ),
        items: statusOptions.map((String status) {
          return DropdownMenuItem<String>(
            value: status,
            child: Text(
              status,
              style: TextStyle(
                color: _getStatusColor(status),
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }).toList(),
        onChanged: (String? newStatus) {
          if (newStatus != null && newStatus != currentStatus) {
            _updateStatus(index, newStatus);
          }
        },
      ),
    );
  }

  Widget _buildCourierDropdown(int index, String currentCourier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xfffe691e),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white,
        ),
      ),
      child: DropdownButton<String>(
        value: currentCourier.isEmpty ? null : currentCourier,
        hint: const Text(
          'Select',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
        underline: const SizedBox(),
        isDense: true,
        style: const TextStyle(
          color: Color(0xffFE691E),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        dropdownColor: const Color(0xffFE691E),
        icon: const Icon(
          Icons.arrow_drop_down,
          color: Colors.white,
          size: 18,
        ),
        items: courierOptions.map((String courier) {
          return DropdownMenuItem<String>(
            value: courier,
            child: Text(
              courier,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }).toList(),
        onChanged: (String? newCourier) {
          if (newCourier != null && newCourier != currentCourier) {
            _updateCourier(index, newCourier);
          }
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Delivered':
        return Colors.green;
      case 'Shipped':
        return Colors.blue;
      case 'In Transit':
        return Colors.orange;
      case 'Processing':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getShortInvoiceNumber(dynamic id) {
    if (id == null) return 'N/A';
    final fullId = id.toString();
    if (fullId.length <= 100) return fullId;
    return fullId.substring(0, 100);
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'N/A';

    try {
      final date = DateTime.parse(dateValue.toString());
      return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateValue.toString();
    }
  }
}