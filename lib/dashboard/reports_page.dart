import 'dart:typed_data';
import 'dart:html' as html show Blob, Url, AnchorElement, document;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:izc_inventory/services/supabase_service.dart';
import 'package:izc_inventory/models/product_model.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:fl_chart/fl_chart.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final _supabaseService = SupabaseService();

  // Loading state
  bool _isLoading = true;

  // Data
  List<Map<String, dynamic>> _salesHistory = [];
  List<Map<String, dynamic>> _filteredSalesHistory = [];
  List<Map<String, dynamic>> _bestSellingProducts = [];
  List<_SalesData> _chartData = [];

  // Statistics
  double _onlineSales = 0.0;
  double _instoreSales = 0.0;
  double _totalSales = 0.0;
  int _ordersCount = 0;

  // Status counts
  Map<String, int> _statusCounts = {
    'Completed': 0,
    'Returned': 0,
  };

  // Filter
  String _selectedFilter = 'Today';
  final List<String> _filterOptions = ['Today', 'Last 7 Days', 'Monthly'];

  // Search
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterSales);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterSales() {
    final query = _searchController.text.toLowerCase();

    if (query.isEmpty) {
      setState(() {
        _filteredSalesHistory = _salesHistory;
      });
      return;
    }

    setState(() {
      _filteredSalesHistory = _salesHistory.where((sale) {
        final customer = sale['customers'];
        final customerName = customer['name']?.toString().toLowerCase() ?? '';
        final paymentMethod = sale['payment_method']?.toString().toLowerCase() ?? '';
        final total = sale['total']?.toString().toLowerCase() ?? '';
        final invoiceId = sale['id']?.toString().toLowerCase() ?? '';

        return customerName.contains(query) ||
            paymentMethod.contains(query) ||
            total.contains(query) ||
            invoiceId.contains(query);
      }).toList();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await _loadSalesData();
      _updateChartData();
    } catch (e) {
      _showError('Failed to load data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSalesData() async {
    try {
      final DateTime now = DateTime.now();
      DateTime startDate;

      switch (_selectedFilter) {
        case 'Today':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'Last 7 Days':
          startDate = now.subtract(const Duration(days: 7));
          break;
        case 'Monthly':
          startDate = DateTime(now.year, now.month, 1);
          break;
        default:
          startDate = DateTime(now.year, now.month, now.day);
      }

      // Fetch sales history with date filter
      final sales = await _supabaseService.getSalesHistoryByDateRange(
        startDate: startDate,
        endDate: now,
        limit: 100,
      );

      final bestSelling = await _supabaseService.getBestSellingProducts(limit: 10);

      // Calculate statistics
      double onlineSales = 0.0;
      double instoreSales = 0.0;
      double totalSales = 0.0;
      int ordersCount = sales.length;

      for (var sale in sales) {
        final amount = (sale['total'] as num).toDouble();
        final status = sale['status'] ?? 'Completed';

        // Count completed and delivered sales in totals (exclude returned)
        if (status == 'Completed' || status == 'Delivered') {
          totalSales += amount;
          if (sale['payment_method'] == 'COD') {
            onlineSales += amount;
          } else {
            instoreSales += amount;
          }
        }
      }

      setState(() {
        _salesHistory = sales;
        _filteredSalesHistory = sales;
        _bestSellingProducts = bestSelling;
        _onlineSales = onlineSales;
        _instoreSales = instoreSales;
        _totalSales = totalSales;
        _ordersCount = ordersCount;
      });
    } catch (e) {
      _showError('Failed to load sales data: $e');
    }
  }

  void _updateChartData() {
    final Map<String, double> salesByDate = {};

    for (var sale in _salesHistory) {
      final status = sale['status'] ?? 'Completed';
      // Include completed and delivered sales in chart
      if (status == 'Completed' || status == 'Delivered') {
        final date = DateTime.parse(sale['sale_date']);
        final dateKey = _selectedFilter == 'Today'
            ? DateFormat('HH:00').format(date)
            : DateFormat('MMM dd').format(date);

        salesByDate[dateKey] = (salesByDate[dateKey] ?? 0) + (sale['total'] as num).toDouble();
      }
    }

    final sortedEntries = salesByDate.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    setState(() {
      _chartData = sortedEntries
          .map((e) => _SalesData(e.key, e.value))
          .toList();
    });
  }

  void _onFilterChanged(String? value) {
    if (value != null) {
      setState(() => _selectedFilter = value);
      _loadData();
    }
  }

  double _getMaxY() {
    if (_chartData.isEmpty) return 100;
    final maxValue = _chartData.map((e) => e.amount).reduce((a, b) => a > b ? a : b);
    return (maxValue * 1.2).ceilToDouble();
  }

  double _getHorizontalInterval() {
    final maxY = _getMaxY();
    if (maxY <= 100) return 20;
    if (maxY <= 500) return 100;
    if (maxY <= 1000) return 200;
    return 500;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _getInvoiceDisplay(String? id) {
    if (id == null || id.isEmpty) return 'N/A';
    if (id.startsWith('IZC-')) {
      return id;
    }
    return '#${id.substring(0, 8).toUpperCase()}';
  }

  Future<pw.Font> _loadFont() async {
    return await PdfGoogleFonts.notoSansRegular();
  }

  Future<pw.Font> _loadBoldFont() async {
    return await PdfGoogleFonts.notoSansBold();
  }

  Future<void> _generateSalesPDF() async {
    try {
      final pdf = pw.Document();
      final font = await _loadFont();
      final boldFont = await _loadBoldFont();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          theme: pw.ThemeData.withFont(
            base: font,
            bold: boldFont,
          ),
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Sales Report - $_selectedFilter',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Generated on ${DateFormat('MMM dd, yyyy - hh:mm a').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                  ),
                  pw.Divider(thickness: 2),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildPdfStatCard('Online Sales', 'Rs. ${_onlineSales.toStringAsFixed(2)}', font, boldFont),
                _buildPdfStatCard('In-Store Sales', 'Rs. ${_instoreSales.toStringAsFixed(2)}', font, boldFont),
                _buildPdfStatCard('Total Sales', 'Rs. ${_totalSales.toStringAsFixed(2)}', font, boldFont),
                _buildPdfStatCard('Orders', _ordersCount.toString(), font, boldFont),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.SizedBox(height: 30),
            if (_bestSellingProducts.isNotEmpty) ...[
              pw.Text(
                'Best Selling Products',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellPadding: const pw.EdgeInsets.all(8),
                headers: ['Rank', 'Product', 'SKU', 'Qty Sold', 'Revenue'],
                data: _bestSellingProducts.asMap().entries.map((entry) {
                  final index = entry.key;
                  final product = entry.value;
                  return [
                    '${index + 1}',
                    product['product_name'],
                    product['product_sku'],
                    product['total_quantity'].toString(),
                    'Rs. ${product['total_revenue'].toStringAsFixed(2)}',
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 30),
            ],
            pw.Text(
              'Recent Sales',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellPadding: const pw.EdgeInsets.all(8),
              headers: ['Invoice', 'Date', 'Customer', 'Payment', 'Total', 'Status'],
              data: _salesHistory.take(30).map((sale) {
                final customer = sale['customers'];
                final date = DateTime.parse(sale['sale_date']);
                final status = sale['status'] ?? 'Completed';
                return [
                  _getInvoiceDisplay(sale['id']),
                  DateFormat('MMM dd, yyyy').format(date),
                  customer['name'],
                  sale['payment_method'],
                  'Rs. ${sale['total'].toStringAsFixed(2)}',
                  status == 'Returned' ? 'Returned' : '',
                ];
              }).toList(),
            ),
          ],
        ),
      );

      await _savePDF(pdf, 'sales_report_$_selectedFilter');
    } catch (e) {
      _showError('Failed to generate PDF: $e');
    }
  }

  pw.Widget _buildPdfStatCard(String title, String value, pw.Font font, pw.Font boldFont) {
    return pw.Container(
      width: 110,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              font: boldFont,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey700,
              font: font,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _savePDF(pw.Document pdf, String filename) async {
    try {
      final Uint8List pdfBytes = await pdf.save();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fullFilename = '${filename}_$timestamp.pdf';

      if (kIsWeb) {
        final blob = html.Blob([pdfBytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..style.display = 'none'
          ..download = fullFilename;
        html.document.body?.children.add(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fullFilename');
        await file.writeAsBytes(pdfBytes);

        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Sales Report - $_selectedFilter',
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF report generated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showError('Failed to save PDF: $e');
    }
  }

  Future<void> _exportSalesCSV() async {
    try {
      final csv = _supabaseService.generateSalesCSV(_salesHistory);
      await _saveAndShareCSV(csv, 'sales_report_$_selectedFilter');
    } catch (e) {
      _showError('Failed to export sales report: $e');
    }
  }

  Future<void> _saveAndShareCSV(String csv, String filename) async {
    try {
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fullFilename = '${filename}_$timestamp.csv';

      if (kIsWeb) {
        final bytes = Uint8List.fromList(csv.codeUnits);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..style.display = 'none'
          ..download = fullFilename;
        html.document.body?.children.add(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fullFilename');
        await file.writeAsString(csv);

        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Sales Report - $_selectedFilter',
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report exported successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showError('Failed to save report: $e');
    }
  }

  void _showExportOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Export Report'),
        content: const Text('Choose export format:'),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _exportSalesCSV();
            },
            icon: const Icon(Icons.table_chart),
            label: const Text('CSV'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _generateSalesPDF();
            },
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('PDF'),
          ),
        ],
      ),
    );
  }

  // ✅ NEW: Show All Sales Bottom Sheet
  void _showAllSalesBottomSheet() {
    // Create a separate controller for the bottom sheet search
    final bottomSheetSearchController = TextEditingController();
    List<Map<String, dynamic>> bottomSheetFilteredSales = List.from(_salesHistory);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setBottomSheetState) {
          void filterBottomSheetSales(String query) {
            if (query.isEmpty) {
              setBottomSheetState(() {
                bottomSheetFilteredSales = _salesHistory;
              });
              return;
            }

            setBottomSheetState(() {
              bottomSheetFilteredSales = _salesHistory.where((sale) {
                final customer = sale['customers'];
                final customerName = customer['name']?.toString().toLowerCase() ?? '';
                final paymentMethod = sale['payment_method']?.toString().toLowerCase() ?? '';
                final total = sale['total']?.toString().toLowerCase() ?? '';
                final invoiceId = sale['id']?.toString().toLowerCase() ?? '';

                return customerName.contains(query) ||
                    paymentMethod.contains(query) ||
                    total.contains(query) ||
                    invoiceId.contains(query);
              }).toList();
            });
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'All Sales',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: bottomSheetSearchController,
                      onChanged: filterBottomSheetSales,
                      decoration: InputDecoration(
                        hintText: 'Search by invoice, customer, payment method...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: bottomSheetSearchController.text.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            bottomSheetSearchController.clear();
                            filterBottomSheetSales('');
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
                          borderSide: const BorderSide(color: Color(0xFFE86B32), width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Results count
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          '${bottomSheetFilteredSales.length} ${bottomSheetFilteredSales.length == 1 ? 'sale' : 'sales'} found',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // Sales List
                  Expanded(
                    child: bottomSheetFilteredSales.isEmpty
                        ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No sales found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                        : ListView.separated(
                      controller: scrollController,
                      itemCount: bottomSheetFilteredSales.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final sale = bottomSheetFilteredSales[index];
                        final customer = sale['customers'];
                        final date = DateTime.parse(sale['sale_date']);
                        final status = sale['status'] ?? 'Completed';
                        final isReturned = status == 'Returned';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE86B32).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFE86B32).withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              _getInvoiceDisplay(sale['id']),
                              style: const TextStyle(
                                color: Color(0xFFE86B32),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  customer['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (isReturned)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.red.withOpacity(0.3),
                                    ),
                                  ),
                                  child: const Text(
                                    'Returned',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('MMM dd, yyyy - hh:mm a').format(date),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    Icons.payment,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    sale['payment_method'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Text(
                            'Rs. ${sale['total'].toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFFE86B32),
                            ),
                          ),
                          isThreeLine: true,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 0,
                      blurRadius: 6,
                      offset: const Offset(0, 8)
                  )
                ]
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sales Report',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        // Filter Dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedFilter,
                              items: _filterOptions.map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              onChanged: _onFilterChanged,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Export Button
                        ElevatedButton.icon(
                          onPressed: _showExportOptions,
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('Export'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE86B32),
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Refresh Button
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _loadData,
                          tooltip: 'Refresh Data',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Statistics Cards and Chart Side by Side
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // Show side by side on wider screens
                      if (constraints.maxWidth > 900) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Stats Grid (3x2)
                            SizedBox(
                              width: 500,
                              child: _buildStatsGrid(),
                            ),
                            const SizedBox(width: 16),
                            // Chart
                            Expanded(
                              child: _buildSalesChart(),
                            ),
                          ],
                        );
                      } else {
                        // Stack vertically on smaller screens
                        return Column(
                          children: [
                            _buildStatsGrid(),
                            const SizedBox(height: 16),
                            _buildSalesChart(),
                          ],
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // Best Selling Products
                  if (_bestSellingProducts.isNotEmpty) ...[
                    Card(
                      elevation: 5,
                      color: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Best Selling Products',
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
                            itemCount: _bestSellingProducts.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final product = _bestSellingProducts[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFFE86B32),
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(product['product_name']),
                                subtitle: Text('SKU: ${product['product_sku']}'),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${product['total_quantity']} sold',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      'Rs. ${product['total_revenue'].toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Recent Sales with Search
                  Card(
                    elevation: 5,
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Recent Sales',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              // ✅ NEW: Show All Button
                              TextButton.icon(
                                onPressed: _showAllSalesBottomSheet,
                                icon: const Icon(Icons.open_in_full, size: 16),
                                label: const Text('Show All'),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFE86B32),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        if (_filteredSalesHistory.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(40.0),
                            child: Center(
                              child: Text(
                                'No sales found',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _filteredSalesHistory.take(10).length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final sale = _filteredSalesHistory[index];
                              final customer = sale['customers'];
                              final date = DateTime.parse(sale['sale_date']);
                              final status = sale['status'] ?? 'Completed';
                              final isReturned = status == 'Returned';

                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE86B32).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: const Color(0xFFE86B32).withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    _getInvoiceDisplay(sale['id']),
                                    style: const TextStyle(
                                      color: Color(0xFFE86B32),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(child: Text(customer['name'])),
                                    if (isReturned)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                                        ),
                                        child: const Text(
                                          'Returned',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  '${DateFormat('MMM dd, yyyy - hh:mm a').format(date)}\n'
                                      'Payment: ${sale['payment_method']}',
                                ),
                                trailing: Text(
                                  'Rs. ${sale['total'].toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                isThreeLine: true,
                              );
                            },
                          ),
                      ],
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

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.9,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _StatCard(
          title: 'Online Sales',
          value: 'Rs. ${_onlineSales.toStringAsFixed(2)}',
          icon: Icons.shopping_cart,
          color: Colors.blue,
        ),
        _StatCard(
          title: 'In-Store Sales',
          value: 'Rs. ${_instoreSales.toStringAsFixed(2)}',
          icon: Icons.store,
          color: Colors.green,
        ),
        _StatCard(
          title: 'Total Sales',
          value: 'Rs. ${_totalSales.toStringAsFixed(2)}',
          icon: Icons.attach_money,
          color: const Color(0xFFE86B32),
        ),
        _StatCard(
          title: 'Orders',
          value: _ordersCount.toString(),
          icon: Icons.receipt_long,
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildSalesChart() {
    return Card(
      elevation: 5,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sales Trend - $_selectedFilter',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 190,
              child: _chartData.isEmpty
                  ? const Center(
                child: Text('No data available'),
              )
                  : Padding(
                padding: const EdgeInsets.only(right: 16, top: 20),
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: _getHorizontalInterval(),
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey.withOpacity(0.2),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= 0 &&
                                value.toInt() < _chartData.length) {
                              final index = value.toInt();
                              if (_chartData.length > 10 && index % 2 != 0) {
                                return const SizedBox();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  _chartData[index].period,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox();
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 45,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              'Rs. ${value.toInt()}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.withOpacity(0.2),
                          width: 1,
                        ),
                        left: BorderSide(
                          color: Colors.grey.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    minX: 0,
                    maxX: (_chartData.length - 1).toDouble(),
                    minY: 0,
                    maxY: _getMaxY(),
                    lineBarsData: [
                      LineChartBarData(
                        spots: _chartData.asMap().entries.map((entry) {
                          return FlSpot(
                            entry.key.toDouble(),
                            entry.value.amount,
                          );
                        }).toList(),
                        isCurved: true,
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFE86B32),
                            Color(0xFFFF8A50),
                          ],
                        ),
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 4,
                              color: Colors.white,
                              strokeWidth: 2,
                              strokeColor: const Color(0xFFE86B32),
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFE86B32).withOpacity(0.3),
                              const Color(0xFFE86B32).withOpacity(0.05),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
                        getTooltipItems: (List<LineBarSpot> touchedSpots) {
                          return touchedSpots.map((LineBarSpot touchedSpot) {
                            return LineTooltipItem(
                              '${_chartData[touchedSpot.x.toInt()].period}\nRs. ${touchedSpot.y.toStringAsFixed(2)}',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SalesData {
  final String period;
  final double amount;

  _SalesData(this.period, this.amount);
}