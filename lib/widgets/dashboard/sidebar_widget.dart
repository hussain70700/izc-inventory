// Path: lib/widgets/dashboard/sidebar_widget.dart

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
    return Container(
      decoration:BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFEEEEEE), width: 2)),
      ),

      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Text("izzah's COLLECTION", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.deepOrange)),
          const SizedBox(height: 40),
          _sidebarItem(Icons.home_outlined, "Home"),
          _sidebarItem(Icons.dashboard, "Dashboard"),
          _sidebarItem(Icons.analytics_outlined, "Reports"),
          _sidebarItem(Icons.location_on_outlined, "Tracking"),
          _sidebarItem(Icons.people_alt_outlined, "Customers"),
          _sidebarItem(Icons.settings_outlined, "Settings"),
          const Spacer(),
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                const Text("Need Help?", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () { /* TODO: Implement Contact Support */ },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E)),
                  child: const Text("Contact Support", style: TextStyle(color: Colors.white)),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _sidebarItem(IconData icon, String label) {
    final isSelected = selectedItem == label;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      decoration: BoxDecoration(
        color: isSelected ? Colors.orange.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? Colors.orange : Colors.grey),
        title: Text(label, style: TextStyle(color: isSelected ? Colors.orange : Colors.grey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        onTap: () => onSelectItem(label),
      ),
    );
  }
}
