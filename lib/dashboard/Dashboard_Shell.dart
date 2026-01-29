import 'dart:async';

import 'package:flutter/material.dart';
import 'package:izc_inventory/dashboard/customers_screen.dart';
import 'package:izc_inventory/dashboard/dashboard_page.dart';
import 'package:izc_inventory/dashboard/inventory_page.dart';
import 'package:izc_inventory/dashboard/promo_code_page.dart';
import 'package:izc_inventory/dashboard/reports_page.dart';
import 'package:izc_inventory/dashboard/sales_page.dart';
import 'package:izc_inventory/dashboard/tracking_page.dart';
import 'package:izc_inventory/dashboard/user_page.dart';
import 'package:izc_inventory/widgets/dashboard/sidebar_widget.dart';
import 'package:izc_inventory/services/session_service.dart';
import '../services/notification_service.dart';
import '../models/notification_model.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  // A simple way to manage the selected index, just like a BottomNavigationBar.
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Stream controllers for notifications
  final StreamController<int> _notificationCountController = StreamController<int>.broadcast();
  final StreamController<List<NotificationModel>> _notificationsController = StreamController<List<NotificationModel>>.broadcast();

  Timer? _notificationTimer;

  // Get user info from session
  String get _userName => SessionService.getFullName() ?? 'User';
  String get _userRole => SessionService.getUserRole() ?? 'user';
  String? get _userImageUrl => SessionService.getImageUrl();

  // Check if user is admin
  bool get _isAdmin => _userRole.toLowerCase() == 'admin';

  // A map to link the sidebar string to the correct index.
  // This makes the code readable and easy to maintain.
  final Map<String, int> _pageIndexMap = {
    "Dashboard": 0,
    "Sales": 1,
    "Inventory": 2,
    "Reports": 3,
    "Staff": 4,
    "Promo Codes": 5,
    "Customers": 6,
    "Tracking": 7,
  };

  @override
  void initState() {
    super.initState();
    _selectedIndex = 1;
    _loadNotificationData();

    // Poll every 5 seconds for real-time updates
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 5),
          (_) => _loadNotificationData(),
    );
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _notificationCountController.close();
    _notificationsController.close();
    super.dispose();
  }

  // Load notification data and update streams
  Future<void> _loadNotificationData() async {
    try {
      // Load count
      final count = await NotificationService.getNotificationCount();
      if (!_notificationCountController.isClosed) {
        _notificationCountController.add(count);
      }

      // Load notifications list
      final notifications = await NotificationService.getNotifications();
      if (!_notificationsController.isClosed) {
        _notificationsController.add(notifications);
      }
    } catch (e) {
      // Handle error silently or log it
      debugPrint('Error loading notifications: $e');
    }
  }

  // This is used for the header title and sidebar selection.
  String get _selectedItemName => _pageIndexMap.keys.firstWhere(
        (key) => _pageIndexMap[key] == _selectedIndex,
    orElse: () => "Sales", // Fallback
  );

  // Check if user has access to a specific page based on their role
  bool _hasAccessToPage(String pageName) {
    final role = _userRole.toLowerCase();

    switch (role) {
      case 'admin':
        return true; // Admin has access to all pages

      case 'manager':
        return ['Sales', 'Customers', 'Inventory'].contains(pageName);

      case 'user':
      default:
        return pageName == 'Sales';
    }
  }

  // Handle page selection with role-based access control
  void _onSelectItem(String itemName) {
    // Check if user has access to this page
    if (!_hasAccessToPage(itemName)) {
      // Show a message that they don't have access
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to access this page'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _selectedIndex = _pageIndexMap[itemName] ?? 0;
    });

    // Close drawer if open
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  // Navigate to Reports page - used by Dashboard
  void _navigateToReports() {
    // Check if user has access to Reports
    if (!_hasAccessToPage('Reports')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to access Reports'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _selectedIndex = 3; // Index of Reports page
    });

    // Close drawer if open
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  // Get the appropriate page widget based on selected index
  Widget _getSelectedPage() {
    switch (_selectedIndex) {
      case 0:
        return DashboardPage(onNavigateToReports: _navigateToReports);
      case 1:
        return const SalesScreen();
      case 2:
        return const InventoryPage();
      case 3:
        return const ReportsPage();
      case 4:
        return const UsersPage();
      case 5:
        return const PromoCodePage();
      case 6:
        return const CustomersScreen();
      case 7:
        return const TrackingPage();
      default:
        return DashboardPage(onNavigateToReports: _navigateToReports);
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

  // Show notifications dropdown
  void _showNotificationsDropdown(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu(
      color: Colors.white,
      context: context,
      position: position,
      constraints: const BoxConstraints(
        maxWidth: 400,
        maxHeight: 500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      items: [
        PopupMenuItem(
          enabled: false,
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  if (_isAdmin)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showCreateNotificationDialog();
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Create'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFE86B32),
                      ),
                    ),
                ],
              ),
              const Divider(),
              // Notifications list using StreamBuilder
              StreamBuilder<List<NotificationModel>>(
                stream: _notificationsController.stream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(
                        child: Text(
                          'No notifications',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  }

                  final notifications = snapshot.data!;
                  return SizedBox(
                    width: 400,
                    height: 400,
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: notifications.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final notification = notifications[index];
                        return _buildNotificationItem(notification);
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Build notification item
  Widget _buildNotificationItem(NotificationModel notification) {
    final timeAgo = _getTimeAgo(notification.createdAt);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE86B32).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.notifications,
              color: Color(0xFFE86B32),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    if (_isAdmin)
                      IconButton(
                        icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _deleteNotification(notification.id),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  timeAgo,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Get time ago string
  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // Show create notification dialog (Admin only)
  void _showCreateNotificationDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Create Notification'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'Enter notification title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter notification description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.description),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final success = await NotificationService.createNotification(
                  title: titleController.text.trim(),
                  description: descriptionController.text.trim(),
                  createdBy: _userName,
                );

                if (context.mounted) {
                  Navigator.pop(context);

                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notification created successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    // Immediately refresh notifications
                    _loadNotificationData();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to create notification'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE86B32),
              foregroundColor: Colors.white,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  // Delete notification (Admin only)
  Future<void> _deleteNotification(String notificationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete Notification'),
        content: const Text('Are you sure you want to delete this notification?'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await NotificationService.deleteNotification(notificationId);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Immediately refresh notifications
          _loadNotificationData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete notification'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const double kTabletBreakpoint = 900.0;
    final bool isWide = MediaQuery.of(context).size.width >= kTabletBreakpoint;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xfff5f6f8),
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
                      userRole: _userRole, // Pass user role
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
          }),
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
                      userRole: _userRole, // Pass user role
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
                  child: _getSelectedPage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
            vertical: isMobile ? 8 : (isInternalNarrow ? 12 : 17.5),
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Hamburger icon for mobile view
              if (isMobile)
                IconButton(
                  icon: const Icon(Icons.menu, color: Colors.grey),
                  onPressed: () {
                    _scaffoldKey.currentState?.openDrawer();
                  },
                  tooltip: 'Open menu',
                ),

              Expanded(
                child: Padding(
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
                    // Notification icon with badge - using StreamBuilder
                    Builder(
                      builder: (notificationContext) {
                        return StreamBuilder<int>(
                          stream: _notificationCountController.stream,
                          initialData: 0,
                          builder: (context, snapshot) {
                            final notificationCount = snapshot.data ?? 0;

                            return Stack(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.notifications_none,
                                    color: Colors.grey,
                                    size: isInternalNarrow ? 20 : 24,
                                  ),
                                  onPressed: () {
                                    _showNotificationsDropdown(notificationContext);
                                  },
                                  tooltip: 'Notifications',
                                ),
                                if (notificationCount > 0)
                                  Positioned(
                                    right: 8,
                                    top: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 16,
                                        minHeight: 16,
                                      ),
                                      child: Text(
                                        notificationCount > 9 ? '9+' : '$notificationCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    // User Profile Image
                    if (!isInternalVeryNarrow)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _userImageUrl != null && _userImageUrl!.isNotEmpty
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            _userImageUrl!,
                            width: isInternalNarrow ? 32 : 40,
                            height: isInternalNarrow ? 32 : 40,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return CircleAvatar(
                                radius: isInternalNarrow ? 16 : 20,
                                backgroundColor: const Color(0xFFE86B32).withOpacity(0.1),
                                child: Text(
                                  _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                                  style: TextStyle(
                                    color: const Color(0xFFE86B32),
                                    fontWeight: FontWeight.bold,
                                    fontSize: isInternalNarrow ? 14 : 16,
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                            : CircleAvatar(
                          radius: isInternalNarrow ? 16 : 20,
                          backgroundColor: const Color(0xFFE86B32).withOpacity(0.1),
                          child: Text(
                            _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                            style: TextStyle(
                              color: const Color(0xFFE86B32),
                              fontWeight: FontWeight.bold,
                              fontSize: isInternalNarrow ? 14 : 16,
                            ),
                          ),
                        ),
                      ),
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