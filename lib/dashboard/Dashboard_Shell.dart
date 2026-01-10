import 'package:flutter/material.dart';
import 'package:izc_inventory/dashboard/dashboard_page.dart';
import 'package:izc_inventory/dashboard/inventory_page.dart';
import 'package:izc_inventory/dashboard/sales_page.dart';
import 'package:izc_inventory/dashboard/user_page.dart';
import 'package:izc_inventory/widgets/dashboard/sidebar_widget.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  // A simple way to manage the selected index, just like a BottomNavigationBar.
  int _selectedIndex = 3;

  // List of all the pages that can be displayed in the main content area.
  static const List<Widget> _mainPages = <Widget>[
    DashboardPage(),
    SalesScreen(),
    InventoryPage(),
UsersPage()
    // Add other main pages here as you create them
    // e.g. TrackingPage(), CustomersPage(), etc.
  ];

  // A map to link the sidebar string to the correct index.
  // This makes the code readable and easy to maintain.
  final Map<String, int> _pageIndexMap = {
    "Dashboard": 0,
    "Sales": 1,
    "Inventory": 2,
    "Reports": 0,
    "Tracking": 0, // Placeholder
    "Customers": 3, // Placeholder
    "Settings": 0, // Placeholder
  };

  // This is used for the header title and sidebar selection.
  String get _selectedItemName => _pageIndexMap.keys.firstWhere(
        (key) => _pageIndexMap[key] == _selectedIndex,
    orElse: () => "Dashboard", // Fallback
  );

  void _onSelectItem(String itemName) {
    setState(() {
      // Update the index based on the string from the sidebar.
      _selectedIndex = _pageIndexMap[itemName] ?? 0;
    });
    // Close the drawer if it's open (for mobile view).
    if (Scaffold.of(context).isDrawerOpen) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    const double kTabletBreakpoint = 768.0;
    final bool isWide = MediaQuery.of(context).size.width >= kTabletBreakpoint;

    return Scaffold(
      backgroundColor: Color(0xfff5f6f8),
      // The AppBar is now part of the shell, so it's consistent.
      appBar: isWide ? null : AppBar(
        title: Text(_selectedItemName),
        backgroundColor: const Color(0xFF1A237E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // The drawer for mobile view.
      drawer: isWide ? null : Drawer(
        child: SidebarWidget(
          selectedItem: _selectedItemName,
          onSelectItem: _onSelectItem,
        ),
      ),
      body: Row(
        children: [
          // Show sidebar permanently on wide screens.
          if (isWide)
            Expanded(
              flex: 2,
              child: SidebarWidget(
                selectedItem: _selectedItemName,
                onSelectItem: _onSelectItem,
              ),
            ),
          // Main Content Area.
          Expanded(
            flex: 10,
            child: Column(
              children: [
                // The sticky header that is present on all pages.
                _buildHeader(),
                // The selected page will be displayed here.
                Expanded(
                  child: _mainPages.elementAt(_selectedIndex),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the persistent top header with user info.
  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < 600;
        final bool isVeryNarrow = constraints.maxWidth < 380;

        return Container(
          padding: EdgeInsets.symmetric(
            vertical: isNarrow ? 12 : 17.5,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: EdgeInsets.only(left: isNarrow ? 12 : 24),
                child: Flexible(
                  child: Text(
                    "Welcome back, Mr.xyz",
                    style: TextStyle(
                      fontSize: isNarrow ? 14 : 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(right: isNarrow ? 12 : 24),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none, color: Colors.grey, size: isNarrow ? 20 : 24),
                    if (!isNarrow)
                      const VerticalDivider(thickness: 1, color: Colors.grey, indent: 8, endIndent: 8, width: 32)
                    else
                      const SizedBox(width: 12),
                    if (!isVeryNarrow) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Mr.xyz", style: TextStyle(fontWeight: FontWeight.bold, fontSize: isNarrow ? 12 : 14)),
                          if (!isNarrow)
                            Text("Logistic manager", style: TextStyle(fontSize: isNarrow ? 9 : 12, color: Colors.grey)),
                        ],
                      ),
                      SizedBox(width: isNarrow ? 4 : 8),
                    ],
                    IconButton(
                      onPressed: () {},
                      icon: Icon(Icons.arrow_drop_down, color: Colors.grey, size: isNarrow ? 20 : 24),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
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
}