// C:/Users/DELL/StudioProjects/izc_inventory/lib/dashboard/Dashboard_main.dart
import 'package:flutter/material.dart';

import 'package:izc_inventory/utils/dashboard_service.dart';
import 'package:izc_inventory/widgets/dashboard/sidebar_widget.dart';
import 'package:izc_inventory/widgets/dashboard/dashboard_cards.dart';

// Assuming kTabletBreakpoint is defined somewhere, e.g.,
// const double kTabletBreakpoint = 768.0;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardService _service = DashboardService();
  String _selectedItem = "Dashboard";
  DashboardData? _currentData;
  bool _isLoading = true;
  final GlobalKey _periodButtonKey = GlobalKey();
  // State variable for the selected period in the toggler
  String _selectedPeriod = "Last 30 Days";

  @override
  void initState() {
    super.initState();
    _fetchDataFor(_selectedItem);
  }

  Future<void> _fetchDataFor(String itemName) async {
    setState(() {
      _isLoading = true;
      _selectedItem = itemName;
    });

    try {
      final data = await _service.fetchDataFor(itemName);
      setState(() {
        _currentData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    // kTabletBreakpoint needs to be defined or imported. Using a placeholder for context.
    // In your actual code, ensure 'kTabletBreakpoint' is defined.
    const double kTabletBreakpoint = 768.0; // Placeholder, adjust if different in your project

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= kTabletBreakpoint;
        return Scaffold(
          appBar: isWide
              ? null
              : AppBar(
            title: Text(_selectedItem, style: const TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFF1A237E),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          drawer: isWide ? null : Drawer(child: _buildSidebar()),
          body: Row(
            children: [
              if (isWide)
                Expanded(
                  flex: 2,
                  child: _buildSidebar(),
                ),
              Expanded(
                flex: 10,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _currentData == null
                    ? const Center(child: Text("Failed to load data."))
                    : SingleChildScrollView(
                  child: _buildMainContent(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Builds the sidebar by calling the external SidebarWidget.
  Widget _buildSidebar() {
    return SidebarWidget(
      selectedItem: _selectedItem,
      onSelectItem: (itemName) {
        _fetchDataFor(itemName);
        if (Scaffold.of(context).isDrawerOpen) {
          Navigator.of(context).pop();
        }
      },
    );
  }

  /// Builds the main content area of the dashboard.
  Widget _buildMainContent() {
    // kTabletBreakpoint needs to be defined or imported. Using a placeholder for context.
    const double kTabletBreakpoint = 768.0; // Placeholder

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row to hold Dashboard Overview title, toggler, and export button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    flex: 2, // Give more space to the title column
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
                  const SizedBox(width: 16), // Spacing between title and controls
                  Flexible(
                    flex: 3, // Give space to the controls, allowing them to wrap
                    child: Wrap(
                      spacing: 12.0, // Horizontal space between widgets
                      runSpacing: 12.0, // Vertical space if widgets wrap to a new line
                      alignment: WrapAlignment.end, // Align to the right if they wrap
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildPeriodSelectionButton(), // NEW: Replaced _buildPeriodToggler()
                        _buildExportButton(),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSectionHeader(icon: Icons.monetization_on_outlined, title: "Sales Overview"),
              const SizedBox(height: 16),
              _buildResponsiveSalesCards(),
              const SizedBox(height: 32),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 700) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildFinancialSection(),
                        const SizedBox(height: 24),
                        _buildPerformanceSection(),
                      ],
                    );
                  } else {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _buildFinancialSection()),
                        const SizedBox(width: 24),
                        Expanded(flex: 1, child: _buildPerformanceSection()),
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds the top header with user info.
  Widget _buildHeader() {
    // kTabletBreakpoint needs to be defined or imported. Using a placeholder for context.
    const double kTabletBreakpoint = 768.0; // Placeholder

    final bool isNarrow = MediaQuery.of(context).size.width < kTabletBreakpoint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
      ),
      child: Row(
        children: [
          if (!isNarrow) const Text("Welcome back, Mr.xyz", style: TextStyle(fontSize: 16)),
          const Spacer(),
          const Icon(Icons.notifications_none, color: Colors.grey),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("Mr.xyz", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("Logistic manager", style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(width: 8),
          const CircleAvatar(radius: 16, backgroundColor: Colors.grey),
        ],
      ),
    );
  }

  // NEW: Builds the period selection button with a dropdown menu.
  Widget _buildPeriodSelectionButton() {
    return ElevatedButton.icon(
      key: _periodButtonKey,
      onPressed: () {
        _showPeriodPopupMenu();
      },
      icon: const Icon(Icons.calendar_month, color: Colors.white), // Calendar icon
      label: Text(_selectedPeriod, style: const TextStyle(color: Colors.white, fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  // Helper to show the PopupMenu
  void _showPeriodPopupMenu() {
    final RenderBox button =
    _periodButtonKey.currentContext!.findRenderObject() as RenderBox;
    final RenderBox overlay =
    Overlay.of(context).context.findRenderObject() as RenderBox;

    final Offset buttonPosition =
    button.localToGlobal(Offset.zero, ancestor: overlay);
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
        setState(() {
          _selectedPeriod = value;
        });
      }
    });
  }


  /// Builds the "Export Report" button.
  Widget _buildExportButton() {
    return ElevatedButton.icon(
      onPressed: () {
        // TODO: Implement export logic
        print("Exporting report for $_selectedPeriod");
      },
      icon: const Icon(Icons.download, color: Colors.orange), // Changed icon color to orange
      label: const Text("Export Report", style: TextStyle(color: Colors.orange, fontSize: 13)), // Changed text color to orange
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white, // Changed background to white
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Builds the header for a content section.
  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.brown),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  /// Builds the row of 3 sales cards using the external FinancialCard widget.
  Widget _buildResponsiveSalesCards() {
    return Wrap(
      spacing: 12.0,
      runSpacing: 12.0,
      children: [
        // REMOVED SizedBox, passing width directly
        FinancialCard(
          width: 250, // NEW: Pass width directly
          title: "Total Sales",
          amount: _currentData!.totalSales,
          color: Colors.blue,
          status: "All Channels",
        ),
        FinancialCard(
          width: 250, // NEW: Pass width directly
          title: "Online Sales",
          amount: _currentData!.onlineSales,
          color: Colors.purple,
          status: "Website & App",
        ),
        FinancialCard(
          width: 250, // NEW: Pass width directly
          title: "Offline Sales",
          amount: _currentData!.offlineSales,
          color: Colors.teal,
          status: "In-Store & Phone",
        ),
      ],
    );
  }

  /// Builds the "Financial Overview" section.
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
            // REMOVED SizedBox, passing width directly
            FinancialCard(
              width: 250, // NEW: Pass width directly
              title: "Payment Processed",
              amount: _currentData!.paymentProcessed,
              color: Colors.green,
              status: "Verified & Cleared",
            ),
            FinancialCard(
              width: 250, // NEW: Pass width directly
              title: "Payment Transferred",
              amount: _currentData!.paymentTransferred,
              color: Colors.blue,
              status: "Sent to Bank",
            ),
            FinancialCard(
              width: 250, // NEW: Pass width directly
              title: "To be Transferred",
              amount: _currentData!.toBeTransferred,
              color: Colors.orange,
              status: "Pending clearance",
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildRecentTransactionsTable(),
      ],
    );
  }

  /// Builds the "Performance" section using the external PerformanceCard widget.
  Widget _buildPerformanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(icon: Icons.bar_chart, title: "Performance"),
        const SizedBox(height: 16),
        PerformanceCard(
          title: "Delivered Percentage",
          value: "${(_currentData!.deliveredPercentage * 100).toStringAsFixed(1)}%",
          subtitle: "Top 5% in your region",
          progress: _currentData!.deliveredPercentage,
          color: Colors.green,
        ),
        const SizedBox(height: 12),
        PerformanceCard(
          title: "Return Ratio",
          value: "${(_currentData!.returnRatio * 100).toStringAsFixed(1)}%",
          subtitle: "Within acceptable limits",
          progress: _currentData!.returnRatio,
          color: Colors.red,
        ),
        const SizedBox(height: 12),
        const PerformanceCard(
          title: "COD Amount Booked",
          value: "\$12.4k",
          subtitle: "65% of total bookings",
          progress: 0.65,
          color: Colors.deepOrange,
        ),
      ],
    );
  }

  /// Builds the recent transactions table.
  Widget _buildRecentTransactionsTable() {
    final List<Map<String, String>> transactions = [
      {'id': '#12345', 'date': '10/10/2023', 'amount': '\$500', 'status': 'Completed'},
      {'id': '#12346', 'date': '10/09/2023', 'amount': '\$250', 'status': 'Completed'},
      {'id': '#12347', 'date': '10/08/2023', 'amount': '\$1200', 'status': 'Processing'},
      {'id': '#12348', 'date': '10/07/2023', 'amount': '\$150', 'status': 'Failed'},
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
              TextButton(onPressed: () {}, child: const Text("View All", style: TextStyle(color: Colors.orange))),
            ],
          ),
          const Divider(),
          SizedBox(
            width: double.infinity,
            child: DataTable(
              headingTextStyle: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12),
              columns: const [
                DataColumn(label: Text("TRANSACTION ID")),
                DataColumn(label: Text("DATE")),
                DataColumn(label: Text("AMOUNT")),
                DataColumn(label: Text("STATUS")),
              ],
              rows: transactions.map((transaction) {
                return DataRow(cells: [
                  DataCell(Text(
                    transaction['id']!,
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  )),
                  DataCell(Text(transaction['date']!)),
                  DataCell(Text(
                    transaction['amount']!,
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  )),
                  DataCell(_buildStatusPill(transaction['status']!)),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// A helper method to create the styled status pill.
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
      default:
        backgroundColor = Colors.grey.shade200;
        textColor = Colors.grey.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}