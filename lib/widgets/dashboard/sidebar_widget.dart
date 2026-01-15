import 'package:flutter/material.dart';

class SidebarWidget extends StatelessWidget {
  final String selectedItem;
  final ValueChanged<String> onSelectItem;

  const SidebarWidget({
    super.key,
    required this.selectedItem,
    required this.onSelectItem,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < 200;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: Color(0xFFEEEEEE), width: 2)),
          ),
          child: Column(
            children: [
              // Logo section - fixed height
              SizedBox(
                height: isNarrow ? 60 : 75,
                width: double.infinity,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      right: isNarrow ? 0 : 65,
                      top: 0,
                      child: Center(
                        child: Image.asset(
                          "assets/images/Logo.png",
                          width: isNarrow ? 100 : 150,
                          height: isNarrow ? 50 : 70,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      top: isNarrow ? 50 : 70,
                      child: Divider(thickness: 1, color: Colors.grey[300]),
                    ),
                  ],
                ),
              ),

              // Scrollable menu items - takes available space
              Expanded(
                child: ListView(
                  padding: EdgeInsets.only(top: isNarrow ? 12 : 20),
                  children: [
                    _sidebarItem(Icons.dashboard, "Dashboard", isNarrow),
                    _sidebarItem(Icons.home_outlined, 'Sales', isNarrow),
                    _sidebarItem(Icons.analytics_outlined, "Reports", isNarrow),
                    _sidebarItem(Icons.location_on_outlined, "Tracking", isNarrow),
                    _sidebarItem(Icons.people_alt_outlined, "Staff", isNarrow),
                    _sidebarItem(Icons.inventory_outlined, "Inventory", isNarrow),
                    _sidebarItem(Icons.discount, "Promo Codes", isNarrow),
                  ],
                ),
              ),

              // Help section - fixed at bottom
              const Divider(height: 1),
              Container(
                margin: EdgeInsets.all(isNarrow ? 8 : 10),
                padding: EdgeInsets.all(isNarrow ? 12 : 10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey, width: 0.7),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Need Help?",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: isNarrow ? 14 : 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () { /* TODO: Implement Contact Support */ },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A237E),
                          padding: EdgeInsets.symmetric(vertical: isNarrow ? 8 : 12),
                        ),
                        child: Text(
                          "Contact Support",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isNarrow ? 12 : 14,
                          ),
                        ),
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

  Widget _sidebarItem(IconData icon, String label, bool isNarrow) {
    final isSelected = selectedItem == label;
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: isNarrow ? 4 : 12),
      decoration: BoxDecoration(
        color: isSelected ? Color(0xffFE691E).withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: isNarrow,
        leading: Icon(icon, color: isSelected ? Color(0xffFE691E) : Colors.grey, size: isNarrow ? 20 : 24),
        title: isNarrow
            ? null
            : Text(
          label,
          style: TextStyle(
            color: isSelected ? Color(0xffFE691E) : Colors.grey.shade600,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: isNarrow ? 12 : 14,
          ),
        ),
        onTap: () => onSelectItem(label),
        contentPadding: EdgeInsets.symmetric(horizontal: isNarrow ? 8 : 16, vertical: isNarrow ? 4 : 8),
      ),
    );
  }
}