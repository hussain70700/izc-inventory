import 'package:flutter/material.dart';
import 'package:izc_inventory/dashboard/dashboard_page.dart';
import 'package:izc_inventory/dashboard/inventory_page.dart';
import 'package:izc_inventory/dashboard/promo_code_page.dart';
import 'package:izc_inventory/dashboard/reports_page.dart';
import 'package:izc_inventory/dashboard/sales_page.dart';
import 'package:izc_inventory/dashboard/user_page.dart';
import 'package:izc_inventory/widgets/dashboard/sidebar_widget.dart';
import 'package:izc_inventory/services/session_service.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  // A simple way to manage the selected index, just like a BottomNavigationBar.
  int _selectedIndex = 5;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Get user info from session
  String get _userName => SessionService.getFullName() ?? 'User';
  String get _userRole => SessionService.getUserRole() ?? 'user';
  String? get _userImageUrl => SessionService.getImageUrl();

  // List of all the pages that can be displayed in the main content area.
  static const List<Widget> _mainPages = <Widget>[
    DashboardPage(),
    SalesScreen(),
    InventoryPage(),
    UsersPage(),
    PromoCodePage(),
    ReportsPage(),
    // Add other main pages here as you create them
    // e.g. TrackingPage(), CustomersPage(), etc.
  ];

  // A map to link the sidebar string to the correct index.
  // This makes the code readable and easy to maintain.
  final Map<String, int> _pageIndexMap = {
    "Dashboard": 0,
    "Sales": 1,
    "Inventory": 2,
    "Reports": 5,
    "Tracking": 0, // Placeholder
    "Staff": 3,
    "Settings": 0,
    "Promo Codes": 4,
  };

  // This is used for the header title and sidebar selection.
  String get _selectedItemName => _pageIndexMap.keys.firstWhere(
        (key) => _pageIndexMap[key] == _selectedIndex,
    orElse: () => "Dashboard", // Fallback
  );

  // In the _onSelectItem method

  void _onSelectItem(String itemName) {
    setState(() {
      _selectedIndex = _pageIndexMap[itemName] ?? 0;
    });
    // Use the key to safely access the Scaffold's state
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }


  // Handle logout
  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Clear session
      await SessionService.clearSession();

      // Navigate to login page
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/login',
              (route) => false,
        );
      }
    }
  }

  // Show user menu
  void _showUserMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // User info header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFE86B32),
                    const Color(0xFFE86B32).withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    backgroundImage: _userImageUrl != null && _userImageUrl!.isNotEmpty
                        ? NetworkImage(_userImageUrl!)
                        : null,
                    child: _userImageUrl == null || _userImageUrl!.isEmpty
                        ? Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: Color(0xFFE86B32),
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          SessionService.getEmail() ?? '',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _userRole.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Menu options
            ListTile(
              leading: const Icon(Icons.person, color: Color(0xFFE86B32)),
              title: const Text('My Profile'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to profile page
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Color(0xFFE86B32)),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to settings page
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Logout',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _handleLogout();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double kTabletBreakpoint = 900.0;
    final bool isWide = MediaQuery.of(context).size.width >= kTabletBreakpoint;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xfff5f6f8),
      // The AppBar is now part of the shell, so it's consistent.
      appBar: null,
      // The drawer for mobile view.
      drawer: isWide
          ? null
          : Builder(
            builder: (drawerContext) {
              return Drawer(
                      child: Column(
              children: [

                // Sidebar widget
                Expanded(
                  child: SidebarWidget(
                    selectedItem: _selectedItemName,
                    onSelectItem: _onSelectItem,
                  ),
                ),
                // Logout at bottom
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: _handleLogout,
                ),
              ],
                      ),
                    );
            }
          ),
      body: Row(
        children: [
          // Show sidebar permanently on wide screens.
          if (isWide)
            SizedBox(
              width: 250,
              child: Column(
                children: [

                  // Sidebar menu
                  Expanded(
                    child: SidebarWidget(
                      selectedItem: _selectedItemName,
                      onSelectItem: _onSelectItem,
                    ),
                  ),
                ],
              ),
            ),
          // Main Content Area.
          Expanded(
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
  /// Builds the persistent top header with user info, adding a hamburger menu on narrow screens.
  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use the same breakpoint as in the main build method to determine mobile vs wide
        const double kTabletBreakpoint = 900.0;
        final bool isMobile = constraints.maxWidth < kTabletBreakpoint;

        final bool isInternalNarrow = constraints.maxWidth < 600;
        final bool isInternalVeryNarrow = constraints.maxWidth < 380;

        return Container(
          padding: EdgeInsets.symmetric(
            vertical: isMobile ? 8 : (isInternalNarrow ? 12 : 17.5), // Slightly less vertical padding for mobile
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 2)),
          ),
          child: Row(
            // Change mainAxisAlignment to start, Expanded widgets will handle spacing
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // --- HAMBURGER ICON ADDED HERE FOR MOBILE VIEW ---
              if (isMobile)
                IconButton(
                  icon: const Icon(Icons.menu, color: Colors.grey), // Match existing icon color
                  onPressed: () {
                    _scaffoldKey.currentState?.openDrawer(); // Opens the drawer
                  },
                  tooltip: 'Open menu',
                ),
              // --- END HAMBURGER ICON ---

              Expanded(
                child: Padding(
                  // Adjust left padding: less if hamburger is present, otherwise existing padding
                  padding: EdgeInsets.only(left: isMobile ? 8 : (isInternalNarrow ? 12 : 24)),
                  child: Text(
                    "Welcome back, $_userName",
                    style: TextStyle(
                      fontSize: isInternalNarrow ? 14 : 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(right: isInternalNarrow ? 12 : 24),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.notifications_none,
                        color: Colors.grey,
                        size: isInternalNarrow ? 20 : 24,
                      ),
                      onPressed: () {
                        // Handle notifications
                      },
                      tooltip: 'Notifications',
                    ),
                    if (!isInternalNarrow)
                      const VerticalDivider(
                        thickness: 1,
                        color: Colors.grey,
                        indent: 8,
                        endIndent: 8,
                        width: 32,
                      )
                    else
                      const SizedBox(width: 12),
                    if (!isInternalVeryNarrow) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _userName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isInternalNarrow ? 12 : 14,
                            ),
                          ),
                          if (!isInternalNarrow)
                            Text(
                              _userRole,
                              style: TextStyle(
                                fontSize: isInternalNarrow ? 9 : 12,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(width: isInternalNarrow ? 4 : 8),
                    ],
                    IconButton(
                      onPressed: _showUserMenu,
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: Colors.grey,
                        size: isInternalNarrow ? 20 : 24,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'User menu',
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