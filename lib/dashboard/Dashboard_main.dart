// C:/Users/DELL/StudioProjects/izc_inventory/lib/dashboard/Dashboard_main.dart
import 'package:flutter/material.dart';

import 'package:izc_inventory/utils/dashboard_service.dart';
import 'package:izc_inventory/widgets/dashboard/sidebar_widget.dart';
import 'package:izc_inventory/widgets/dashboard/dashboard_cards.dart';
import 'sales_page.dart'; // <--- NEW IMPORT

// Assuming kTabletBreakpoint is defined somewhere, e.g.,
// const double kTabletBreakpoint = 768.0;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardService _service = DashboardService();
  String _selectedItem = "Sales";
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

    // Only fetch dashboard data if it's not the Sales page
    if (itemName == "Dashboard") { // <--- Added condition
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
    } else {
      // For other pages like 'Sales', we just update the selected item
      // and stop loading, as the page itself might handle its own data.
      setState(() {
        _isLoading = false;
        _currentData = null; // Clear dashboard data when not on dashboard
      });
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
          backgroundColor: Color(0xfff5f6f8),
          appBar: isWide ? null
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
                child: _selectedItem == "Sales" // <--- NEW: Conditional rendering for SalesPage
                    ? const SalesScreen() // <--- Display SalesPage if "Sales" is selected
                    : _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _currentData == null && _selectedItem == "Dashboard"
                    ? const Center(child: Text("Failed to load data."))
                    : Column( // Column to hold sticky header and scrollable content
                  children: [
                    _buildHeader(), // STICKY HEADER
                    Expanded( // Expanded to make SingleChildScrollView take remaining space
                      child: SingleChildScrollView(
                        child: _buildScrollableMainContent(), // Renamed method for clarity
                      ),
                    ),
                  ],
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

  /// Builds the scrollable main content area of the dashboard (everything below the sticky header).
  Widget _buildScrollableMainContent() { // <<--- Renamed this method
    // kTabletBreakpoint needs to be defined or imported. Using a placeholder for context.
    const double kTabletBreakpoint = 768.0; // Placeholder

    return Padding( // The main content area's padding starts here
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
          // REMOVED these two lines from here:
          // _buildSectionHeader(icon: Icons.monetization_on_outlined, title: "Sales Overview"),
          // const SizedBox(height: 16),

          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 700) {
                // Stacked layout for narrow screens (Financial Overview, then Performance)
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column( // Group Sales Overview and Financial for narrow
                      children: [
                        _buildSectionHeader(icon: Icons.monetization_on_outlined, title: "Sales Overview"),
                        // REMOVED: const SizedBox(height: 16), // <--- REMOVED THIS LINE
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
                // Side-by-side layout for wide screens
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: Column( // This column holds Sales Overview and Financial Overview
                      children: [
                        _buildSectionHeader(icon: Icons.monetization_on_outlined, title: "Sales Overview"),
                        // REMOVED: const SizedBox(height: 16), // <--- REMOVED THIS LINE
                        _buildResponsiveSalesCards(),
                        const SizedBox(height: 32,), // Space between sales cards and financial section
                        _buildFinancialSection(),
                      ],
                    )),

                    Expanded(flex: 1, child: _buildPerformanceSection()), // Performance section
                  ],
                );
              }
            },
          ),

        ],
      ),
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
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 2)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            if (!isNarrow) Row(
              children: [
                const Text("Welcome back", style: TextStyle(fontSize: 16)),
                const Text(", Mr.xyz", style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.notifications_none, color: Colors.grey),
            const VerticalDivider( // Changed from Divider to VerticalDivider
              thickness: 1,
              color: Colors.grey,
              indent: 0, // Space from the top edge of the Row's content
              endIndent: 0, // Space from the bottom edge of the Row's content
              width: 32, // This adds 32 logical pixels of width, 1 of which is the divider itself
            ),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("Mr.xyz", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("Logistic manager", style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(width: 8),
            IconButton(onPressed: (){}, icon: Icon(Icons.arrow_drop_down, color: Colors.grey))
          ],
        ),
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
        backgroundColor: Color(0xffFE691E),
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
      icon: const Icon(Icons.download, color: Color(0xffFE691E)), // Changed icon color to orange
      label: const Text("Export Report", style: TextStyle(color: Color(0xffFE691E), fontSize: 13)), // Changed text color to orange
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
          width: 258, // NEW: Pass width directly
          title: "Total Sales",
          amount: _currentData!.totalSales,
          color: Colors.blue,
          status: "All Channels",
        ),
        FinancialCard(
          width: 258, // NEW: Pass width directly
          title: "Online Sales",
          amount: _currentData!.onlineSales,
          color: Colors.purple,
          status: "Website",
        ),
        FinancialCard(
          width: 258, // NEW: Pass width directly
          title: "In-Store",
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
              width: 258, // NEW: Pass width directly
              title: "Payment Processed",
              amount: _currentData!.paymentProcessed,
              color: Colors.green,
              status: "Verified & Cleared",
            ),
            FinancialCard(
              width: 258, // NEW: Pass width directly
              title: "Online Payment",
              amount: _currentData!.paymentTransferred,
              color: Colors.blue,
              status: "Sent to Bank",
            ),
            FinancialCard(
              width: 258, // NEW: Pass width directly
              title: "Cash Payment",
              amount: _currentData!.toBeTransferred,
              color: Colors.orange,
              status: "On the spot payments",
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
        // Moved this header inside the LayoutBuilder's else block
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
    // UPDATED: Added 'billNo', 'type', and 'name' fields to the transaction data.
    final List<Map<String, String>> transactions = [
      {'billNo': 'BN001', 'type': 'online', 'id': '#12345', 'name': 'John Doe', 'date': '10/10/2023', 'amount': '\$500', 'status': 'Completed'},
      {'billNo': 'BN002', 'type': 'online', 'id': '#12346', 'name': 'Jane Smith', 'date': '10/09/2023', 'amount': '\$258', 'status': 'Completed'},
      {'billNo': 'BN003', 'type': 'cash',   'id': '',        'name': 'Bob Johnson', 'date': '10/08/2023', 'amount': '\$1200', 'status': 'Processing'},
      {'billNo': 'BN004', 'type': 'online', 'id': '#12348', 'name': 'Alice Brown', 'date': '10/07/2023', 'amount': '\$150', 'status': 'Refund'}, // Changed 'Failed' to 'Refund' here
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      width: 800,
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
                // NEW: Add 'BILL NO' column
                DataColumn(label: Text("BILL NO")),
                // MODIFIED: Rename 'TRANSACTION ID' for clarity if it's conditional
                DataColumn(label: Text("TRANSACTION id")),
                // NEW: Add 'NAME' column
                DataColumn(label: Text("NAME")),
                DataColumn(label: Text("DATE")),
                DataColumn(label: Text("AMOUNT")),
                DataColumn(label: Text("STATUS")),
              ],
              rows: transactions.map((transaction) {
                return DataRow(cells: [
                  // NEW: Display Bill No
                  DataCell(Text(
                    transaction['billNo']!,
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  )),
                  // MODIFIED: Conditional display for Transaction ID / Cash Payment
                  DataCell(Text(
                    transaction['type'] == 'online'
                        ? transaction['id']! // Show transaction ID for online
                        : 'Cash Payment',    // Show "Cash Payment" for cash
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  )),
                  // NEW: Display Name
                  DataCell(Text(transaction['name']!)),
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
    // UPDATED: Handle 'Refund' status
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