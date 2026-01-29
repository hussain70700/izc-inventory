// Path: C:/Users/DELL/StudioProjects/izc_inventory/lib/dashboard/dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:izc_inventory/utils/dashboard_service.dart';
import 'package:izc_inventory/widgets/dashboard/dashboard_cards.dart';
import 'package:excel/excel.dart';
import 'dart:typed_data';
import '../utils/file_download.dart';
import 'package:izc_inventory/services/supabase_service.dart';
import 'package:intl/intl.dart';

class DashboardPage extends StatefulWidget {
  final VoidCallback? onNavigateToReports;

  const DashboardPage({super.key, this.onNavigateToReports});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DashboardService _service = DashboardService();
  final SupabaseService _supabaseService = SupabaseService();
  DashboardData? _currentData;
  bool _isLoading = true;
  final GlobalKey _periodButtonKey = GlobalKey();
  String _selectedPeriod = "Last 30 Days";

  // Recent sales data
  List<Map<String, dynamic>> _recentSales = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    try {
      // Load real sales data first
      await _loadRecentSales();

      // If _currentData is still null after loading sales, use dummy data as fallback
      if (_currentData == null) {
        final data = await _service.fetchDataFor(_selectedPeriod);
        setState(() {
          _currentData = data;
        });
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print(e);
    }
  }

  Future<void> _loadRecentSales() async {
    try {
      final DateTime now = DateTime.now();
      DateTime startDate;

      switch (_selectedPeriod) {
        case 'Last 30 Days':
          startDate = now.subtract(const Duration(days: 30));
          break;
        case 'Last 120 Days':
          startDate = now.subtract(const Duration(days: 120));
          break;
        case 'Past Year':
          startDate = now.subtract(const Duration(days: 365));
          break;
        default:
          startDate = now.subtract(const Duration(days: 30));
      }

      // Fetch all sales within the date range
      final sales = await _supabaseService.getSalesHistoryByDateRange(
        startDate: startDate,
        endDate: now,
        limit: 1000, // Get all sales for calculation
      );

      // Calculate status counts and amounts
      int completedCount = 0;
      int returnedCount = 0;
      int totalBookedCount = 0;
      int shipperAdviceCount = 0;
      int inProcessCount = 0;
      int handedOverCount = 0;

      double totalSalesAmount = 0.0;
      double onlineSalesAmount = 0.0;
      double instoreSalesAmount = 0.0;

      double paymentProcessed = 0.0;
      double paymentTransferred = 0.0;
      double cashPayment = 0.0;

      // ✅ NEW: Track COD amounts
      double codAmountBooked = 0.0;
      int codOrdersCount = 0;

      for (var sale in sales) {
        final status = sale['status'] ?? 'Completed';
        final amount = (sale['total'] as num).toDouble();
        final paymentMethod = sale['payment_method'] ?? '';
        final advancePayment = (sale['advance_payment'] as num?)?.toDouble() ?? 0.0;

        switch (status) {
          case 'Completed':
          case 'Delivered':
            completedCount++;
            totalSalesAmount += amount;
            paymentProcessed += amount;

            // ✅ NEW: Calculate based on actual payment method
            if (paymentMethod == 'Cash') {
              cashPayment += amount;           // Only Cash goes here
              instoreSalesAmount += amount;     // Cash is in-store
            } else {
              // All other methods (Card, QR Pay, COD) are online
              paymentTransferred += amount;     // Card, QR, COD go here
              onlineSalesAmount += amount;      // Online payments
            }
            // ❌ COD NOT counted here - order is delivered
            break;

          case 'Returned':
            returnedCount++;
            totalSalesAmount += amount; // Adds negative = subtraction
            paymentProcessed += amount;
            instoreSalesAmount += amount;
            cashPayment += amount;
            // ❌ COD NOT counted here - order is returned
            break;

          case 'Total Booked':
          case 'Booked':
            totalBookedCount++;
            // ✅ Count COD for pending orders (not delivered yet)
            if (paymentMethod == 'COD') {
              codOrdersCount++;
              final remainingCOD = amount - advancePayment;
              codAmountBooked += remainingCOD > 0 ? remainingCOD : 0;
            }
            break;

          case 'Shipper Advice':
            shipperAdviceCount++;
            // ✅ Count COD for pending orders (not delivered yet)
            if (paymentMethod == 'COD') {
              codOrdersCount++;
              final remainingCOD = amount - advancePayment;
              codAmountBooked += remainingCOD > 0 ? remainingCOD : 0;
            }
            break;

          case 'In Process':
            inProcessCount++;
            // ✅ Count COD for pending orders (not delivered yet)
            if (paymentMethod == 'COD') {
              codOrdersCount++;
              final remainingCOD = amount - advancePayment;
              codAmountBooked += remainingCOD > 0 ? remainingCOD : 0;
            }
            break;

          case 'Handed Over':
            handedOverCount++;
            totalSalesAmount += amount;
            paymentProcessed += amount;

            // ✅ NEW: Calculate based on actual payment method
            if (paymentMethod == 'Cash') {
              cashPayment += amount;           // Only Cash goes here
              instoreSalesAmount += amount;     // Cash is in-store
            } else {
              // All other methods (Card, QR Pay, COD) are online
              paymentTransferred += amount;     // Card, QR, COD go here
              onlineSalesAmount += amount;      // Online payments
            }

            // ✅ Count COD even for Handed Over (not delivered to customer yet)
            if (paymentMethod == 'COD') {
              codOrdersCount++;
              final remainingCOD = amount - advancePayment;
              codAmountBooked += remainingCOD > 0 ? remainingCOD : 0;
            }
            break;

          default:
          // ✅ For any other status, if COD, count it as pending
            if (paymentMethod == 'COD') {
              codOrdersCount++;
              final remainingCOD = amount - advancePayment;
              codAmountBooked += remainingCOD > 0 ? remainingCOD : 0;
            }
            break;
        }
      }

      // Calculate return ratio based on ORDER COUNT
      final totalOrders = sales.length;
      final returnRatio = totalOrders > 0 ? returnedCount / totalOrders : 0.0;

      // Calculate delivered percentage (completed + handed over)
      final deliveredCount = completedCount + handedOverCount;
      final deliveredPercentage = totalOrders > 0 ? deliveredCount / totalOrders : 0.0;

      // ✅ Calculate COD percentage
      final codPercentage = totalSalesAmount > 0 ? codAmountBooked / totalSalesAmount : 0.0;

      setState(() {
        _recentSales = sales.take(4).toList(); // Keep only 4 for display

        // Create or update the dashboard data with actual values from database
        _currentData = DashboardData(
          totalSales: 'Rs ${totalSalesAmount.toStringAsFixed(2)}',
          onlineSales: 'Rs ${onlineSalesAmount.toStringAsFixed(2)}',
          offlineSales: 'Rs ${instoreSalesAmount.toStringAsFixed(2)}',
          paymentProcessed: 'Rs ${paymentProcessed.toStringAsFixed(2)}',
          paymentTransferred: 'Rs ${paymentTransferred.toStringAsFixed(2)}',
          toBeTransferred: 'Rs ${cashPayment.toStringAsFixed(2)}',
          deliveredPercentage: deliveredPercentage,
          returnRatio: returnRatio,
          totalBooked: totalBookedCount.toString(),
          shipperAdvice: shipperAdviceCount.toString(),
          returned: returnedCount.toString(),
          inProcess: inProcessCount.toString(),
          handedOver: handedOverCount.toString(),
          delivered: completedCount.toString(),
          codAmountBooked: codAmountBooked, // ✅ Add COD amount
          codOrdersCount: codOrdersCount, // ✅ Add COD orders count
          codPercentage: codPercentage, // ✅ Add COD percentage
        );
      });
    } catch (e) {
      print('Failed to load recent sales: $e');
    }
  }

  // NEW: Export Dashboard Report to Excel
  Future<void> _exportDashboardReport() async {
    if (_currentData == null) return;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xffFE691E)),
        ),
      );

      // Create Excel
      var excel = Excel.createExcel();

      // Delete default sheet and create new one
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }
      excel.copy('Sheet1', 'Dashboard Report');
      Sheet sheetObject = excel['Dashboard Report'];

      // Title Row
      var titleCell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
      titleCell.value = TextCellValue('Dashboard Report - $_selectedPeriod');
      titleCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 16,
        backgroundColorHex: ExcelColor.fromHexString('#FE691E'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );

      // Merge title across columns
      sheetObject.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
        CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0),
      );

      // Sales Overview Section
      int currentRow = 2;
      var salesHeaderCell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
      salesHeaderCell.value = TextCellValue('SALES OVERVIEW');
      salesHeaderCell.cellStyle = CellStyle(bold: true, fontSize: 14);

      currentRow++;
      _addDataRow(sheetObject, currentRow++, 'Total Sales', _currentData!.totalSales);
      _addDataRow(sheetObject, currentRow++, 'Online Sales', _currentData!.onlineSales);
      _addDataRow(sheetObject, currentRow++, 'In-Store Sales', _currentData!.offlineSales);

      // Financial Overview Section
      currentRow++;
      var financialHeaderCell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
      financialHeaderCell.value = TextCellValue('FINANCIAL OVERVIEW');
      financialHeaderCell.cellStyle = CellStyle(bold: true, fontSize: 14);

      currentRow++;
      _addDataRow(sheetObject, currentRow++, 'Payment Processed', _currentData!.paymentProcessed);
      _addDataRow(sheetObject, currentRow++, 'Online Payment', _currentData!.paymentTransferred);
      _addDataRow(sheetObject, currentRow++, 'Cash Payment', _currentData!.toBeTransferred);

      // Performance Section
      currentRow++;
      var performanceHeaderCell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
      performanceHeaderCell.value = TextCellValue('PERFORMANCE METRICS');
      performanceHeaderCell.cellStyle = CellStyle(bold: true, fontSize: 14);

      currentRow++;
      _addDataRow(sheetObject, currentRow++, 'Delivered Percentage', '${(_currentData!.deliveredPercentage * 100).toStringAsFixed(1)}%');
      _addDataRow(sheetObject, currentRow++, 'Return Ratio', '${(_currentData!.returnRatio * 100).toStringAsFixed(1)}%');

      // Recent Transactions Section
      currentRow++;
      var transactionsHeaderCell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
      transactionsHeaderCell.value = TextCellValue('RECENT TRANSACTIONS');
      transactionsHeaderCell.cellStyle = CellStyle(bold: true, fontSize: 14);

      currentRow++;
      // Transaction headers
      final transactionHeaders = ['DATE', 'CUSTOMER', 'PAYMENT METHOD', 'AMOUNT', 'STATUS'];
      for (var i = 0; i < transactionHeaders.length; i++) {
        var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow));
        cell.value = TextCellValue(transactionHeaders[i]);
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#E0E0E0'),
        );
      }

      currentRow++;
      // Add recent sales from database
      for (var sale in _recentSales) {
        final customer = sale['customers'];
        final date = DateTime.parse(sale['sale_date']);

        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value =
            TextCellValue(DateFormat('MM/dd/yyyy').format(date));
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value =
            TextCellValue(customer['name'] ?? 'N/A');
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow)).value =
            TextCellValue(sale['payment_method'] ?? 'N/A');
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow)).value =
            TextCellValue('Rs ${sale['total'].toStringAsFixed(2)}');
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow)).value =
            TextCellValue(sale['status'] ?? 'Completed');
        currentRow++;
      }

      // Auto-fit columns
      for (var i = 0; i < 6; i++) {
        sheetObject.setColumnWidth(i, 20);
      }

      // Encode
      List<int>? excelBytes = excel.encode();

      if (mounted) Navigator.pop(context);

      if (excelBytes == null || excelBytes.isEmpty) {
        if (mounted) {
          _showError('Failed to generate Excel file');
        }
        return;
      }

      final bytes = Uint8List.fromList(excelBytes);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'dashboard_report_$timestamp.xlsx';

      await downloadFile(bytes, fileName);

      if (mounted) {

        _showSuccess('Dashboard report exported: $fileName');
      }
    } catch (e, stackTrace) {
      print('Export error: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        Navigator.pop(context);
        _showError('Export failed: $e');
      }
    }
  }

  // Helper to add data rows
  void _addDataRow(Sheet sheet, int rowIndex, String label, dynamic value) {
    var labelCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
    labelCell.value = TextCellValue(label);
    labelCell.cellStyle = CellStyle(bold: true);

    var valueCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
    valueCell.value = TextCellValue(value.toString());
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_currentData == null) {
      return const Center(child: Text("Failed to load dashboard data."));
    }

    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        child: _buildScrollableMainContent(constraints),
      );
    });
  }

  Widget _buildScrollableMainContent(BoxConstraints constraints) {
    final bool isNarrow = constraints.maxWidth < 700;
    final double horizontalPadding = isNarrow ? 16.0 : 24.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 24.0),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 0,
                blurRadius: 6,
                offset: Offset(0, 4),
              )
            ],
          ),
          child: _buildResponsiveHeader(isNarrow),
        ),
        SizedBox(height: 24.0),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: _buildResponsiveBody(isNarrow),
        ),
      ],
    );
  }

  Widget _buildResponsiveHeader(bool isNarrow) {
    return isNarrow
        ? Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildOverviewText(isNarrow),
        const SizedBox(height: 16),
        _buildActionButtons(),
      ],
    )
        : Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(flex: 2, child: _buildOverviewText(isNarrow)),
        const SizedBox(width: 16),
        Expanded(flex: 3, child: _buildActionButtons()),
      ],
    );
  }

  Widget _buildResponsiveBody(bool isNarrow) {
    if (isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(icon: Icons.monetization_on_outlined, title: "Sales Overview"),
          const SizedBox(height: 16),
          _buildResponsiveSalesCards(isNarrow),
          const SizedBox(height: 32),
          _buildFinancialSection(isNarrow),
          const SizedBox(height: 24),
          _buildPerformanceSection(isNarrow),
        ],
      );
    } else {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              flex: 2,
              child: Column(
                children: [
                  _buildSectionHeader(icon: Icons.monetization_on_outlined, title: "Sales Overview"),
                  const SizedBox(height: 16),
                  _buildResponsiveSalesCards(isNarrow),
                  const SizedBox(height: 32),
                  _buildFinancialSection(isNarrow),
                ],
              )),
          const SizedBox(width: 24),
          Expanded(flex: 1, child: _buildPerformanceSection(isNarrow)),
        ],
      );
    }
  }

  Widget _buildOverviewText(bool isNarrow) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Dashboard Overview",
          style: TextStyle(fontSize: isNarrow ? 20 : 24, fontWeight: FontWeight.bold),
        ),
        if (!isNarrow)
          const Padding(
            padding: EdgeInsets.only(top: 4.0),
            child: Text(
              "Track your shipments and performance metrics in real time.",
              style: TextStyle(color: Colors.grey),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Wrap(
      spacing: 12.0,
      runSpacing: 12.0,
      alignment: WrapAlignment.end,
      children: [
        _buildPeriodSelectionButton(),
        _buildExportButton(),
      ],
    );
  }

  Widget _buildPeriodSelectionButton() {
    return ElevatedButton.icon(
      key: _periodButtonKey,
      onPressed: () => _showPeriodPopupMenu(),
      icon: const Icon(Icons.calendar_month, color: Colors.white, size: 18),
      label: Text(_selectedPeriod, style: const TextStyle(color: Colors.white, fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xffFE691E),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showPeriodPopupMenu() {
    final RenderBox button = _periodButtonKey.currentContext!.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final Offset buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);
    final Size buttonSize = button.size;
    final RelativeRect position = RelativeRect.fromLTRB(
      buttonPosition.dx,
      buttonPosition.dy + buttonSize.height + 8,
      overlay.size.width - (buttonPosition.dx + buttonSize.width),
      0,
    );

    showMenu<String>(
      color: Colors.white,
      context: context,
      position: position,
      items: const [
        PopupMenuItem(value: 'Last 30 Days', child: Text('Last 30 Days')),
        PopupMenuItem(value: 'Last 120 Days', child: Text('Last 120 Days')),
        PopupMenuItem(value: 'Past Year', child: Text('Past Year')),
      ],
    ).then((value) {
      if (value != null && value != _selectedPeriod) {
        setState(() => _selectedPeriod = value);
        _fetchDashboardData(); // Refresh data when period changes
      }
    });
  }

  Widget _buildExportButton() {
    return ElevatedButton.icon(
      onPressed: _exportDashboardReport,
      icon: const Icon(Icons.download, color: Color(0xffFE691E), size: 18),
      label: const Text("Export Report", style: TextStyle(color: Color(0xffFE691E), fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.brown),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildResponsiveSalesCards(bool isNarrow) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: FinancialCard(
              title: "Total Sales",
              amount: _currentData!.totalSales,
              color: Colors.blue,
              status: "All Channels"),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: FinancialCard(
              title: "Online Sales",
              amount: _currentData!.onlineSales,
              color: Colors.purple,
              status: "Website"),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: FinancialCard(
              title: "In-Store",
              amount: _currentData!.offlineSales,
              color: Colors.teal,
              status: "In-Store & Phone"),
        ),
      ],
    );
  }

  Widget _buildFinancialSection(bool isNarrow) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
            icon: Icons.account_balance_wallet_outlined,
            title: "Financial Overview"),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: FinancialCard(
                  title: "Payment Processed",
                  amount: _currentData!.paymentProcessed,
                  color: Colors.green,
                  status: "Verified & Cleared"),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: FinancialCard(
                  title: "Online Payment",
                  amount: _currentData!.paymentTransferred,
                  color: Colors.blue,
                  status: "Sent to Bank"),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: FinancialCard(
                  title: "Cash Payment",
                  amount: _currentData!.toBeTransferred,
                  color: Colors.orange,
                  status: "On the spot payments"),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildRecentTransactionsTable(),
      ],
    );
  }

  Widget _buildPerformanceSection(bool isNarrow) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(icon: Icons.bar_chart, title: "Performance"),
        const SizedBox(height: 16),
        PerformanceCard(
            title: "Delivered Percentage",
            value: "${(_currentData!.deliveredPercentage * 100).toStringAsFixed(1)}%",
            subtitle: "${_currentData!.delivered} orders delivered",
            progress: _currentData!.deliveredPercentage,
            color: Colors.green
        ),
        const SizedBox(height: 12),
        PerformanceCard(
            title: "Return Ratio",
            value: "${(_currentData!.returnRatio * 100).toStringAsFixed(1)}%",
            subtitle: "${_currentData!.returned} items returned",
            progress: _currentData!.returnRatio,
            color: Colors.red
        ),
        const SizedBox(height: 12),
        PerformanceCard(
            title: "COD Amount Booked",
            value: "Rs ${_currentData!.codAmountBooked.toStringAsFixed(1)}", // ✅ Format as needed
            subtitle: "${_currentData!.codOrdersCount} pending COD orders",
            progress: _currentData!.codPercentage,
            color: Colors.deepOrange
        ),
      ],
    );
  }

  Widget _buildRecentTransactionsTable() {
    if (_recentSales.isEmpty) {
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
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
              'No recent transactions',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Recent Transactions", style: TextStyle(fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: widget.onNavigateToReports,
                child: const Text("View All", style: TextStyle(color: Color(0xffFE691E))),
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
                    columnSpacing: 38,
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 64,
                    columns: const [
                      DataColumn(label: Text("DATE")),
                      DataColumn(label: Text("CUSTOMER")),
                      DataColumn(label: Text("PAYMENT METHOD")),
                      DataColumn(label: Text("AMOUNT")),
                    ],
                    rows: _recentSales.map((sale) {
                      final customer = sale['customers'];
                      final date = DateTime.parse(sale['sale_date']);


                      return DataRow(cells: [
                        DataCell(
                          Text(
                            DateFormat('MM/dd/yyyy').format(date),
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            customer['name'] ?? 'N/A',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        DataCell(
                          Text(
                            sale['payment_method'] ?? 'N/A',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            'Rs ${sale['total'].toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                      ]);
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


}