import 'package:flutter/material.dart';
import 'package:izc_inventory/dashboard/dashboard_page.dart';
import 'package:izc_inventory/dashboard/inventory_page.dart';
import 'package:izc_inventory/dashboard/promo_code_page.dart';
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
  int _selectedIndex = 0;

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
    "Staff": 3,
    "Settings": 0,
    "Promo Codes": 4,
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

  // Handle logout
  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
    const double kTabletBreakpoint = 768.0;
    final bool isWide = MediaQuery.of(context).size.width >= kTabletBreakpoint;

    return Scaffold(
      backgroundColor: const Color(0xfff5f6f8),
      // The AppBar is now part of the shell, so it's consistent.
      appBar: isWide
          ? null
          : AppBar(
        title: Text(_selectedItemName),
        backgroundColor: const Color(0xFF1A237E),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              // Handle notifications
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: _showUserMenu,
          ),
        ],
      ),
      // The drawer for mobile view.
      drawer: isWide
          ? null
          : Builder(
            builder: (drawerContext) {
              return Drawer(
                      child: Column(
              children: [
                // User profile header in drawer
                SafeArea(
                  bottom: false,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFE86B32),
                          const Color(0xFFE86B32).withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                        const SizedBox(height: 12),
                        Text(
                          _userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          SessionService.getEmail() ?? '',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _userRole.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
                  // User profile in sidebar
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFFFFE0D3),
                          backgroundImage: _userImageUrl != null && _userImageUrl!.isNotEmpty
                              ? NetworkImage(_userImageUrl!)
                              : null,
                          child: _userImageUrl == null || _userImageUrl!.isEmpty
                              ? Text(
                            _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              color: Color(0xFFE86B32),
                              fontWeight: FontWeight.bold,
                            ),
                          )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _userName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _userRole,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
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
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: isNarrow ? 12 : 24),
                  child: Text(
                    "Welcome back, $_userName",
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
                    IconButton(
                      icon: Icon(
                        Icons.notifications_none,
                        color: Colors.grey,
                        size: isNarrow ? 20 : 24,
                      ),
                      onPressed: () {
                        // Handle notifications
                      },
                      tooltip: 'Notifications',
                    ),
                    if (!isNarrow)
                      const VerticalDivider(
                        thickness: 1,
                        color: Colors.grey,
                        indent: 8,
                        endIndent: 8,
                        width: 32,
                      )
                    else
                      const SizedBox(width: 12),
                    if (!isVeryNarrow) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _userName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isNarrow ? 12 : 14,
                            ),
                          ),
                          if (!isNarrow)
                            Text(
                              _userRole,
                              style: TextStyle(
                                fontSize: isNarrow ? 9 : 12,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(width: isNarrow ? 4 : 8),
                    ],
                    IconButton(
                      onPressed: _showUserMenu,
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: Colors.grey,
                        size: isNarrow ? 20 : 24,
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