import 'package:flutter/material.dart';

class InventoryDashboard extends StatelessWidget {
  const InventoryDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF6F7FB),
      body: Row(
        children: [
          // SIDEBAR
          Container(
            width: 220,
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Izzah's\nCollection",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),
                sidebarItem(Icons.dashboard, "Dashboard", false),
                sidebarItem(Icons.inventory, "Inventory", true),
                sidebarItem(Icons.shopping_cart, "Sales Orders", false),
                sidebarItem(Icons.people, "Suppliers", false),
                sidebarItem(Icons.bar_chart, "Reports", false),
                const Spacer(),
                sidebarItem(Icons.settings, "Settings", false),
              ],
            ),
          ),

          // MAIN CONTENT
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Inventory Management",
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(
                        width: 250,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: "Search products, SKU...",
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // STATS
                  Row(
                    children: [
                      statCard("Total Products", "2,453", Icons.inventory,
                          Colors.blue),
                      statCard("Total Value", "\$142,300", Icons.attach_money,
                          Colors.green),
                      statCard("Low Stock", "12", Icons.warning,
                          Colors.orange),
                      statCard("Out of Stock", "4", Icons.cancel,
                          Colors.red),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // TABLE
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "All Products",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          tableHeader(),
                          tableRow("Minimalist Watch", "WT-2024-001", "45",
                              "\$129.00", true),
                          tableRow("Wireless Headphones", "AU-2024-055", "5",
                              "\$249.99", true, lowStock: true),
                          tableRow("Urban Runners", "SH-2024-102", "128",
                              "\$89.50", true),
                          tableRow("Vintage Camera", "CM-2024-009", "0",
                              "\$599.00", false, outOfStock: true),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // HISTORY LOG
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text("Stock History Log",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(height: 12),
                        ListTile(
                          leading:
                          CircleAvatar(backgroundColor: Colors.green),
                          title: Text("Stock Added"),
                          subtitle:
                          Text("Added 50 units to Urban Runners"),
                          trailing: Text("2 mins ago"),
                        ),
                        ListTile(
                          leading:
                          CircleAvatar(backgroundColor: Colors.blue),
                          title: Text("Product Updated"),
                          subtitle: Text("Updated price for Minimalist Watch"),
                          trailing: Text("1 hour ago"),
                        ),
                        ListTile(
                          leading:
                          CircleAvatar(backgroundColor: Colors.red),
                          title: Text("Stock Adjustment"),
                          subtitle:
                          Text("Removed 2 units (Damaged)"),
                          trailing: Text("3 hours ago"),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- WIDGETS ----------

  Widget sidebarItem(IconData icon, String title, bool active) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: active ? Colors.blue : Colors.grey),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
                color: active ? Colors.blue : Colors.grey,
                fontWeight: active ? FontWeight.bold : FontWeight.normal),
          )
        ],
      ),
    );
  }

  Widget statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.grey)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget tableHeader() {
    return Row(
      children: const [
        Expanded(flex: 3, child: Text("PRODUCT")),
        Expanded(flex: 2, child: Text("SKU")),
        Expanded(child: Text("STOCK")),
        Expanded(child: Text("PRICE")),
        Expanded(child: Text("STATUS")),
      ],
    );
  }

  Widget tableRow(String name, String sku, String stock, String price,
      bool active,
      {bool lowStock = false, bool outOfStock = false}) {
    Color statusColor =
    outOfStock ? Colors.red : active ? Colors.green : Colors.grey;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(name)),
          Expanded(flex: 2, child: Text(sku)),
          Expanded(
              child: Text(stock,
                  style: TextStyle(
                      color: lowStock || outOfStock
                          ? Colors.red
                          : Colors.black))),
          Expanded(child: Text(price)),
          Expanded(
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                outOfStock ? "Out" : "Active",
                textAlign: TextAlign.center,
                style: TextStyle(color: statusColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}