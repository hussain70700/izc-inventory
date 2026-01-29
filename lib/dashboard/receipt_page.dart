import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:izc_inventory/services/session_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/detail_sale_item.dart';
import '../models/sales_model.dart';
import '../services/supabase_service.dart';
import 'dart:typed_data';
class ReceiptScreen extends StatefulWidget {
  final String saleId;

  const ReceiptScreen({
    super.key,
    required this.saleId,
  });

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final _supabaseService = SupabaseService();
  Sale? _sale;
  List<DetailedSaleItem> _items = [];
  bool _isLoading = true;
  String? _error;
  String _cashierName = 'Admin User';

  // ✅ FIXED: Updated isReturn getter to check status as well
  bool get isReturn =>
      _sale?.paymentMethod == 'Return' ||
          (_sale?.notes?.contains('RETURN') ?? false);

  @override
  void initState() {
    super.initState();
    _loadReceiptData();
  }

  Future<void> _loadReceiptData() async {
    try {
      print('📱 Starting to load receipt data for sale ID: ${widget.saleId}');

      // ✅ GET CURRENT USER
      final userEmail = SessionService.getEmail() ?? 'Unknown';
      final userName = SessionService.getFullName() ?? userEmail.split('@').first;

      print('📱 Fetching sale...');
      final sale = await _supabaseService.getSaleById(widget.saleId);
      print('✅ Sale fetched successfully: ${sale?.id}');

      print('📱 Fetching sale items...');
      final items = await _supabaseService.getDetailedSaleItems(widget.saleId);
      print('✅ Items fetched successfully: ${items.length} items');

      if (items.isNotEmpty) {
        final firstItem = items.first;
        print('📦 First item details:');
        print('  - Product: ${firstItem.productName}');
        print('  - Customer: ${firstItem.customerName ?? "NULL"}');
        print('  - Customer ID: ${firstItem.customerId ?? "NULL"}');
      }

      setState(() {
        _sale = sale;
        _items = items;
        _cashierName = userName;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('❌ ERROR loading receipt data:');
      print('Error: $e');
      print('StackTrace: $stackTrace');

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<pw.Document> _generatePdf() async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd MMM yyyy hh:mm a');
    final customerName = _items.isNotEmpty ? (_items.first.customerName ?? 'Guest') : 'N/A';
    final ByteData bytes = await rootBundle.load('images/Logo.png');
    final Uint8List logoBytes = bytes.buffer.asUint8List();
    final pw.MemoryImage logoImage = pw.MemoryImage(logoBytes);

    // Calculate remaining payment
    final advancePayment = _sale?.advancePayment ?? 0.0;
    final totalAmount = _sale?.total ?? 0.0;
    final remainingPayment = totalAmount - advancePayment;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                child: pw.Column(
                  children: [
                    pw.Image(logoImage, width: 100, height: 100),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Faisalabad, Pakistan\nTel: +92 315747 8727\nEmail: info@izzahs.com',
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(
                        color: PdfColors.black,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // ✅ NEW: Return banner for PDF
              if (isReturn)
                pw.Container(
                  margin: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.red50,
                    border: pw.Border.all(color: PdfColors.red, width: 2),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      '⚠️ RETURN / CREDIT NOTE',
                      style: pw.TextStyle(
                        color: PdfColors.red,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),

              // Invoice Info
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16),
                child: pw.Column(
                  children: [
                    _pdfRow('INVOICE NO:', '#${_sale!.id?.substring(0, 14).toUpperCase() ?? 'N/A'}'),
                    _pdfRow('DATE:', dateFormat.format(_sale!.saleDate)),
                    _pdfRow('CASHIER:', _cashierName),
                    _pdfRow('CUSTOMER:', customerName),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Divider(),

              // Items
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      isReturn ? 'ITEMS RETURNED' : 'ITEMS PURCHASED',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    ..._items.map((item) => pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Expanded(
                              child: pw.Text(
                                item.productName,
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            pw.Text(
                              'Rs ${item.total.abs().toStringAsFixed(2)}', // ✅ Use abs()
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        pw.Text(
                          'SKU: ${item.sku}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.Text(
                          '${item.quantity} x Rs ${item.price.abs().toStringAsFixed(2)}', // ✅ Use abs()
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.SizedBox(height: 8),
                      ],
                    )),
                  ],
                ),
              ),
              pw.Divider(),

              // Totals
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16),
                child: pw.Column(
                  children: [
                    // ✅ FIXED: Use proper labels and abs() for returns
                    _pdfRow(
                      isReturn ? 'RETURN SUBTOTAL:' : 'SUBTOTAL:',
                      'Rs ${_sale!.subtotal.abs().toStringAsFixed(2)}',
                    ),
                    if (_sale!.discount > 0)
                      _pdfRow('DISCOUNT:', '-Rs ${_sale!.discount.toStringAsFixed(2)}'),
                    _pdfRow(
                      isReturn ? 'RETURN TAX (8.5%):' : 'TAX (8.5%):',
                      'Rs ${_sale!.tax.abs().toStringAsFixed(2)}',
                    ),
                    pw.SizedBox(height: 8),
                    pw.Divider(thickness: 1),
                    pw.SizedBox(height: 8),
                    _pdfRow(
                      isReturn ? 'TOTAL REFUND:' : 'TOTAL PAYABLE:',
                      'Rs ${totalAmount.abs().toStringAsFixed(2)}',
                      bold: true,
                    ),

                    // ✅ ADVANCE PAYMENT SECTION (only for non-returns)
                    if (!isReturn && advancePayment > 0) ...[
                      pw.SizedBox(height: 8),
                      _pdfRow('ADVANCE PAYMENT:', '-Rs ${advancePayment.toStringAsFixed(2)}'),
                      pw.Divider(thickness: 1),
                      _pdfRow(
                        'COD AMOUNT:',
                        'Rs ${remainingPayment.toStringAsFixed(2)}',
                        bold: true,
                      ),
                    ],

                    pw.SizedBox(height: 12),
                    _pdfRow('PAYMENT METHOD:', _sale!.paymentMethod.toUpperCase()),

                    if (_sale!.notes != null && _sale!.notes!.isNotEmpty) ...[
                      pw.SizedBox(height: 8),
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey400),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'NOTES:',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              _sale!.notes!,
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Divider(),

              // Footer
              pw.Padding(
                padding: const pw.EdgeInsets.all(16),
                child: pw.Column(
                  children: [
                    pw.Text(
                      isReturn ? 'ITEMS RETURNED - STOCK RESTORED' : 'THANK YOU FOR SHOPPING!',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.RichText(
                      textAlign: pw.TextAlign.center,
                      text: pw.TextSpan(
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.black),
                        children: [
                          const pw.TextSpan(text: 'For online shopping\nWebsite: ',),
                          pw.TextSpan(
                            text: 'www.izzahs.com',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                          ),
                          const pw.TextSpan(text: '\nInstagram: '),
                          pw.TextSpan(
                            text: 'izzah.s_collection',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                          ),
                          const pw.TextSpan(
                              text: '\n\nNo refunds without receipt\nExchange within 15 days\n\nPowered by IZZAHS COLLECTION'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  pw.Widget _pdfRow(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _printReceipt() async {
    try {
      final pdf = await _generatePdf();
      final bytes = await pdf.save();

      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
        name: 'receipt_${_sale!.id?.substring(0, 8) ?? 'unknown'}.pdf',
      );
    } catch (e) {
      if (mounted) {
        print('❌ Print error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade300,
      appBar: AppBar(
        title: Text(isReturn ? 'Return Receipt' : 'Receipt'), // ✅ Updated title
        backgroundColor: isReturn ? Colors.red : const Color(0xffFE691E), // ✅ Red for returns
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _isLoading ? null : _printReceipt,
            tooltip: 'Print Receipt',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Error Loading Receipt',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      )
          : Center(
        child: Container(
          width: 360,
          color: Colors.white,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _header(),
                // ✅ NEW: Return banner
                if (isReturn) _returnBanner(),
                _infoSection(),
                _itemsSection(),
                _totalSection(),
                _footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Image.asset('images/Logo.png', width: 100, height: 100,),
          const SizedBox(height: 6),
          const Text(
            'Faisalabad, Pakistan\n'
                'Tel: +92 315 747 8727\n'
                'Email: info@izzahs.com',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ✅ NEW: Return banner widget
  Widget _returnBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.keyboard_return, color: Colors.red, size: 24),
          SizedBox(width: 8),
          Text(
            'RETURN / CREDIT NOTE',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoSection() {
    if (_sale == null || _items.isEmpty) return const SizedBox.shrink();

    final dateFormat = DateFormat('dd MMM yyyy hh:mm a');
    final customerName = _items.first.customerName ?? 'Guest';

    return _section(
      Column(
        children: [
          _row('INVOICE NO:', '#${_sale!.id?.substring(0, 14).toUpperCase() ?? 'N/A'}'),
          _row('DATE:', dateFormat.format(_sale!.saleDate)),
          _row('CASHIER:', _cashierName),
          _row('CUSTOMER:', customerName),
        ],
      ),
    );
  }

  Widget _itemsSection() {
    if (_items.isEmpty) return const SizedBox.shrink();

    return _section(
      Column(
        children: [
          Text(
            isReturn ? 'ITEMS RETURNED' : 'ITEMS PURCHASED', // ✅ Updated label
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 10),
          ..._items.map((item) => _item(
            item.productName,
            'SKU: ${item.sku}',
            '${item.quantity} x Rs ${item.price.abs().toStringAsFixed(2)}', // ✅ Use abs()
            'Rs ${item.total.abs().toStringAsFixed(2)}', // ✅ Use abs()
          )),
        ],
      ),
    );
  }

  Widget _totalSection() {
    if (_sale == null) return const SizedBox.shrink();

    // Calculate remaining payment
    final advancePayment = _sale!.advancePayment ?? 0.0;
    final totalAmount = _sale!.total;
    final remainingPayment = totalAmount - advancePayment;

    return _section(
      Column(
        children: [
          // ✅ FIXED: Use proper labels and abs() for returns
          _row(
            isReturn ? 'RETURN SUBTOTAL:' : 'SUBTOTAL:',
            'Rs ${_sale!.subtotal.abs().toStringAsFixed(2)}',
          ),
          if (_sale!.discount > 0)
            _row(
              'DISCOUNT:',
              '-Rs ${_sale!.discount.toStringAsFixed(2)}',
              valueColor: const Color(0xffFE691E),
            ),
          _row(
            isReturn ? 'RETURN TAX (8.5%):' : 'TAX (8.5%):',
            'Rs ${_sale!.tax.abs().toStringAsFixed(2)}',
          ),
          const SizedBox(height: 8),
          Container(
            height: 1,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          _row(
            isReturn ? 'TOTAL REFUND:' : 'TOTAL PAYABLE:',
            'Rs ${totalAmount.abs().toStringAsFixed(2)}',
            bold: true,
            valueColor: isReturn ? Colors.red : Colors.black,
            fontSize: 16,
          ),

          // ✅ ADVANCE PAYMENT SECTION (only for non-returns with COD)
          if (!isReturn && advancePayment > 0) ...[
            const SizedBox(height: 8),
            _row(
              'ADVANCE PAYMENT:',
              '-Rs ${advancePayment.toStringAsFixed(2)}',
              valueColor: Colors.green.shade700,
              fontSize: 14,
            ),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.grey.shade400,
            ),
            _row(
              'COD AMOUNT:',
              'Rs ${remainingPayment.toStringAsFixed(2)}',
              bold: true,
              valueColor: const Color(0xffFE691E),
              fontSize: 16,
            ),
          ],

          const SizedBox(height: 12),
          _row('PAYMENT METHOD:', _sale!.paymentMethod.toUpperCase()),

          if (_sale!.notes != null && _sale!.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isReturn ? Colors.red.shade50 : Colors.grey.shade100, // ✅ Red background for returns
                  borderRadius: BorderRadius.circular(4),
                  border: isReturn ? Border.all(color: Colors.red.shade200) : null, // ✅ Red border for returns
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NOTES:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _sale!.notes!,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            isReturn ? 'ITEMS RETURNED - STOCK RESTORED' : 'THANK YOU FOR SHOPPING!', // ✅ Updated message
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              children: <TextSpan>[
                const TextSpan(text: 'For online shopping\nWebsite: '),
                TextSpan(
                  text: 'www.izzahs.com',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade900),
                ),
                const TextSpan(text: '\nInstagram: '),
                TextSpan(
                  text: 'izzah.s_collection',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade900),
                ),
                const TextSpan(text: '\n\nNo refunds without receipt\nExchange within 15 days\n\nPowered by IZZAHS COLLECTION'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(Widget child) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          child,
          const SizedBox(height: 10),
          _dashedDivider(),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color valueColor = Colors.black, double fontSize = 12,}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(String name, String sku, String qty, String price) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                price,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            sku,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
          Text(
            qty,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _dashedDivider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 5.0;
        const dashSpace = 5.0;
        final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: 0.8,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.grey.shade400),
              ),
            );
          }),
        );
      },
    );
  }
}