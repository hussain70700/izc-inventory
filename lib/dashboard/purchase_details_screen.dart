// ============================================
// PURCHASE DETAILS SCREEN - FIXED
// lib/screens/purchase_details_screen.dart
// ============================================

import 'package:flutter/material.dart';
import 'package:izc_inventory/dashboard/receipt_page.dart';
import '../models/detail_sale_item.dart';
import '../models/sales_model.dart';
import '../services/supabase_service.dart';

class PurchaseDetailsScreen extends StatefulWidget {
  final String saleId;

  const PurchaseDetailsScreen({super.key, required this.saleId});

  @override
  State<PurchaseDetailsScreen> createState() => _PurchaseDetailsScreenState();
}

class _PurchaseDetailsScreenState extends State<PurchaseDetailsScreen> {
  final _supabaseService = SupabaseService();

  Sale? _sale;
  List<DetailedSaleItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPurchaseDetails();
  }

  Future<void> _loadPurchaseDetails() async {
    setState(() => _isLoading = true);

    try {
      final sale = await _supabaseService.getSaleById(widget.saleId);
      final items = await _supabaseService.getDetailedSaleItems(widget.saleId);

      if (mounted) {
        setState(() {
          _sale = sale;
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Failed to load purchase details: $e');
      }
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 600;
        final double horizontalPadding = isMobile ? 12.0 : 24.0;

        return Scaffold(
          backgroundColor: const Color(0xffF6F7FB),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 2,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Purchase Details',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
          body: _isLoading
              ? const Center(
            child: CircularProgressIndicator(color: Color(0xffFE691E)),
          )
              : _sale == null
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Purchase not found',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          )
              : RefreshIndicator(
            onRefresh: _loadPurchaseDetails,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sale Info Card
                  _buildSaleInfoCard(isMobile),
                  SizedBox(height: isMobile ? 16 : 24),

                  // Items List
                  _buildItemsList(isMobile),
                  SizedBox(height: isMobile ? 16 : 24),

                  // Summary Card
                  _buildSummaryCard(isMobile),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSaleInfoCard(bool isMobile) {
    // FIX: saleDate is already a DateTime, no need to parse it
    final saleDate = _sale!.saleDate;

    return Container(
      padding: const EdgeInsets.all(20),
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
                'Order Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xffFE691E).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _sale!.paymentMethod,
                  style: const TextStyle(
                    color: Color(0xffFE691E),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildInfoRow(Icons.tag, 'Order ID', _sale!.id!.substring(0, 8).toUpperCase()),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.calendar_today, 'Date', _formatDateTime(saleDate)),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.shopping_bag, 'Items', '${_items.length} item${_items.length != 1 ? 's' : ''}'),
          if (_sale!.notes != null && _sale!.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(Icons.note, 'Notes', _sale!.notes!),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemsList(bool isMobile) {
    return Container(
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
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
              'Items Purchased',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = _items[index];
              return _buildItemTile(item, isMobile);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(DetailedSaleItem item, bool isMobile) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
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
            child: item.productImageUrl != null && item.productImageUrl!.isNotEmpty
                ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item.productImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.inventory_2,
                    color: Colors.grey.shade400,
                    size: 30,
                  );
                },
              ),
            )
                : Icon(
              Icons.inventory_2,
              color: Colors.grey.shade400,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          // Product Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'SKU: ${item.sku}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '\$${item.price.toStringAsFixed(2)} × ${item.quantity}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '\$${item.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xffFE691E),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          const Text(
            'Payment Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('Subtotal', _sale!.subtotal),
          if (_sale!.discount > 0) ...[
            const SizedBox(height: 8),
            _buildSummaryRow('Discount', -_sale!.discount, color: const Color(0xffFE691E)),
          ],
          const SizedBox(height: 8),
          _buildSummaryRow('Tax', _sale!.tax),
          const Divider(height: 24),
          _buildSummaryRow('Total', _sale!.total, bold: true, large: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value,
      {bool bold = false, bool large = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: large ? 18 : 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
        Text(
          '\$${value.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: large ? 20 : 16,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: color ?? (bold ? const Color(0xffFE691E) : Colors.black),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');

    return '${months[date.month - 1]} ${date.day}, ${date.year} at $hour:$minute $period';
  }
}