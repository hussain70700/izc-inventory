import 'package:flutter/material.dart';
import 'package:izc_inventory/utils/dashboard_service.dart';
import 'package:izc_inventory/widgets/dashboard/dashboard_cards.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DashboardService _service = DashboardService();
  DashboardData? _currentData;
  bool _isLoading = true;
  final GlobalKey _periodButtonKey = GlobalKey();
  String _selectedPeriod = "Last 30 Days";

  @override
  void initState() {
    super.initState();
    // Fetch data specifically for this page
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.fetchDataFor("Dashboard");
      setState(() {
        _currentData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_currentData == null) {
      return const Center(child: Text("Failed to load dashboard data."));
    }

    // This is the scrollable content that was previously in Dashboard_main.dart
    return SingleChildScrollView(
      child: _buildScrollableMainContent(),
    );
  }

  // All the helper methods that build the UI for THIS page are now here.
  // ... (_buildScrollableMainContent, _buildPeriodSelectionButton, _buildFinancialSection, etc.)

  /// Builds the scrollable main content area of the dashboard (everything below the sticky header).
  Widget _buildScrollableMainContent() {
    const double kTabletBreakpoint = 768.0;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "Dashboard Overview",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "Track your shipments and performance metrics in real time.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                flex: 3,
                child: Wrap(
                  spacing: 12.0,
                  runSpacing: 12.0,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildPeriodSelectionButton(),
                    _buildExportButton(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 700) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      children: [
                        _buildSectionHeader(icon: Icons.monetization_on_outlined, title: "Sales Overview"),
                        _buildResponsiveSalesCards(),
                        const SizedBox(height: 32),
                        _buildFinancialSection(),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildPerformanceSection(),
                  ],
                );
              } else {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: Column(
                      children: [
                        _buildSectionHeader(icon: Icons.monetization_on_outlined, title: "Sales Overview"),
                        _buildResponsiveSalesCards(),
                        const SizedBox(height: 32,),
                        _buildFinancialSection(),
                      ],
                    )),
                    Expanded(flex: 1, child: _buildPerformanceSection()),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelectionButton() {
    return ElevatedButton.icon(
      key: _periodButtonKey,
      onPressed: () => _showPeriodPopupMenu(),
      icon: const Icon(Icons.calendar_month, color: Colors.white),
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
      }
    });
  }

  Widget _buildExportButton() {
    return ElevatedButton.icon(
      onPressed: () => print("Exporting report for $_selectedPeriod"),
      icon: const Icon(Icons.download, color: Color(0xffFE691E)),
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

  Widget _buildResponsiveSalesCards() {
    return Wrap(
      spacing: 12.0,
      runSpacing: 12.0,
      children: [
        FinancialCard(width: 258, title: "Total Sales", amount: _currentData!.totalSales, color: Colors.blue, status: "All Channels"),
        FinancialCard(width: 258, title: "Online Sales", amount: _currentData!.onlineSales, color: Colors.purple, status: "Website"),
        FinancialCard(width: 258, title: "In-Store", amount: _currentData!.offlineSales, color: Colors.teal, status: "In-Store & Phone"),
      ],
    );
  }

  Widget _buildFinancialSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(icon: Icons.account_balance_wallet_outlined, title: "Financial Overview"),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12.0,
          runSpacing: 12.0,
          children: [
            FinancialCard(width: 258, title: "Payment Processed", amount: _currentData!.paymentProcessed, color: Colors.green, status: "Verified & Cleared"),
            FinancialCard(width: 258, title: "Online Payment", amount: _currentData!.paymentTransferred, color: Colors.blue, status: "Sent to Bank"),
            FinancialCard(width: 258, title: "Cash Payment", amount: _currentData!.toBeTransferred, color: Colors.orange, status: "On the spot payments"),
          ],
        ),
        const SizedBox(height: 24),
        _buildRecentTransactionsTable(),
      ],
    );
  }

  Widget _buildPerformanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(icon: Icons.bar_chart, title: "Performance"),
        const SizedBox(height: 16),
        PerformanceCard(title: "Delivered Percentage", value: "${(_currentData!.deliveredPercentage * 100).toStringAsFixed(1)}%", subtitle: "Top 5% in your region", progress: _currentData!.deliveredPercentage, color: Colors.green),
        const SizedBox(height: 12),
        PerformanceCard(title: "Return Ratio", value: "${(_currentData!.returnRatio * 100).toStringAsFixed(1)}%", subtitle: "Within acceptable limits", progress: _currentData!.returnRatio, color: Colors.red),
        const SizedBox(height: 12),
        const PerformanceCard(title: "COD Amount Booked", value: "\$12.4k", subtitle: "65% of total bookings", progress: 0.65, color: Colors.deepOrange),
      ],
    );
  }

  Widget _buildRecentTransactionsTable() {
    final List<Map<String, String>> transactions = [
      {'billNo': 'BN001', 'type': 'online', 'id': '#12345', 'name': 'John Doe', 'date': '10/10/2023', 'amount': '\$500', 'status': 'Completed'},
      {'billNo': 'BN002', 'type': 'online', 'id': '#12346', 'name': 'Jane Smith', 'date': '10/09/2023', 'amount': '\$258', 'status': 'Completed'},
      {'billNo': 'BN003', 'type': 'cash', 'id': '', 'name': 'Bob Johnson', 'date': '10/08/2023', 'amount': '\$1200', 'status': 'Processing'},
      {'billNo': 'BN004', 'type': 'online', 'id': '#12348', 'name': 'Alice Brown', 'date': '10/07/2023', 'amount': '\$150', 'status': 'Refund'},
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Recent Transactions", style: TextStyle(fontWeight: FontWeight.bold)),
              TextButton(onPressed: () {}, child: const Text("View All", style: TextStyle(color: Color(0xffFE691E)))),
            ],
          ),
          const Divider(),
          SizedBox(
            width: double.infinity,
            child: DataTable(
              headingTextStyle: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11),
              columns: const [
                DataColumn(label: Text("BILL NO")),
                DataColumn(label: Text("TRANSACTION id")),
                DataColumn(label: Text("NAME")),
                DataColumn(label: Text("DATE")),
                DataColumn(label: Text("AMOUNT")),
                DataColumn(label: Text("STATUS")),
              ],
              rows: transactions.map((transaction) {
                return DataRow(cells: [
                  DataCell(Text(transaction['billNo']!, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
                  DataCell(Text(transaction['type'] == 'online' ? transaction['id']! : 'Cash Payment', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
                  DataCell(Text(transaction['name']!)),
                  DataCell(Text(transaction['date']!)),
                  DataCell(Text(transaction['amount']!, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
                  DataCell(_buildStatusPill(transaction['status']!)),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    Color backgroundColor;
    Color textColor;
    switch (status) {
      case 'Completed':
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        break;
      case 'Processing':
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        break;
      case 'Refund':
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        break;
      default:
        backgroundColor = Colors.grey.shade200;
        textColor = Colors.grey.shade800;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(12)),
      child: Text(status, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}
