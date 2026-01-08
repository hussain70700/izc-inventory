

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

      child: Column(
        children: [

          SizedBox(
            height: 75,
            width: double.infinity,
            child: Stack(

              children: [

                Positioned(
                  left: 0,
                  right: 65,

                  top: 0,
                  child: Center(
                    child: Image .asset(
                      "assets/images/Logo.png",
                      width: 150,
                      height: 70,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  top: 70,
                  child: Divider(thickness: 1, color: Colors.grey[300]),
                ),
              ],
            ),
          ),
SizedBox(height: 20),
          _sidebarItem(Icons.dashboard, "Dashboard"),
          _sidebarItem(Icons.home_outlined, 'Sales'),
          _sidebarItem(Icons.analytics_outlined, "Reports"),
          _sidebarItem(Icons.location_on_outlined, "Tracking"),
          _sidebarItem(Icons.people_alt_outlined, "Customers"),
          _sidebarItem(Icons.inventory_outlined, "Inventory"),
          const Spacer(),
          const Divider(),
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey,width: 0.7)
            ),
            child: Column(
              children: [
                const Text("Need Help?", style: TextStyle(fontWeight: FontWeight.w900,fontSize: 18)),
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
        color: isSelected ? Color(0xffFE691E).withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? Color(0xffFE691E) : Colors.grey),
        title: Text(label, style: TextStyle(color: isSelected ? Color(0xffFE691E) : Colors.grey.shade600, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        onTap: () => onSelectItem(label),
      ),
    );
  }
}