import 'package:flutter/material.dart';


// Define a simple Customer data model
class Customer {
  final String name;
  final String number; // Assuming customer number can contain non-numeric characters, so String is safer
  // You might want to add more fields like id, address, etc.

  Customer(this.name, this.number);

  // Helper for checking equality based on name and number
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Customer &&
              runtimeType == other.runtimeType &&
              name == other.name &&
              number == other.number;

  @override
  int get hashCode => name.hashCode ^ number.hashCode;
}


class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  // Existing cart items
  final List<CartItem> cart = [
    CartItem('Nike Air Max 270', '883210-001', 129, 1),
    CartItem('Minimalist Watch', 'MW-2023-BL', 85.5, 2),
    CartItem('Sony WH-1000XM4', 'SONY-XM4-BLK', 348, 1),
    CartItem('Hydro Flask 32oz', 'HF-32-TEAL', 45, 1),
  ];

  double get subtotal =>
      cart.fold(0, (sum, item) => sum + item.price * item.qty);

  // NEW: TextEditingControllers for customer input
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerNumberController = TextEditingController();

  // NEW: List to simulate a customer database
  final List<Customer> _allCustomers = [
    Customer('John Doe', '123-456-7890'),
    Customer('Jane Smith', '098-765-4321'),
    Customer('Alice Brown', '555-111-2222'),
  ];

  // NEW: Variable to hold the currently selected/added customer
  Customer? _selectedCustomer;

  // NEW: State variable to track the selected payment method
  String? _selectedPaymentMethod; // Holds the label of the selected payment button

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerNumberController.dispose();
    super.dispose();
  }

  // NEW: Method to search for or add a customer
  void _searchAndAddCustomer() {
    final name = _customerNameController.text.trim();
    final number = _customerNumberController.text.trim();

    if (name.isEmpty || number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both customer name and number.')),
      );
      return;
    }

    // Check if customer already exists (case-insensitive for name)
    final existingCustomer = _allCustomers.firstWhere(
          (c) => c.name.toLowerCase() == name.toLowerCase() && c.number == number,
      orElse: () => Customer('', ''), // Sentinel value for "not found"
    );

    setState(() {
      if (existingCustomer.name.isNotEmpty) { // Customer found
        _selectedCustomer = existingCustomer;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Customer "${existingCustomer.name}" found!')),
        );
      } else { // Customer does not exist, add new
        final newCustomer = Customer(name, number);
        _allCustomers.add(newCustomer);
        _selectedCustomer = newCustomer;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('New customer "${newCustomer.name}" added!')),
        );
      }
    });
  }

  // NEW: Method to clear the selected customer and input fields
  void _clearCustomerSelection() {
    setState(() {
      _selectedCustomer = null;
      _customerNameController.clear();
      _customerNumberController.clear();
    });
  }

  // NEW: Method to handle a payment button being selected
  void _handlePaymentMethodSelected(String methodLabel) {
    setState(() {
      _selectedPaymentMethod = methodLabel;
      // Optionally, show a snackbar or update UI based on selected method

    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f6f8),
      body: Row(
        children: [
          /// LEFT - CART SECTION (Now composed of a separate search card and the main cart card)
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column( // <--- Column to stack the two cards
                children: [
                  // --- NEW: SEPARATE SEARCH BAR CARD ---
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    color: Colors.white,
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: _searchBar(), // The search bar widget itself
                  ),

                  const SizedBox(height: 16), // Space between the search card and the main cart card

                  // --- MAIN CART CARD (Existing structure, but without the search bar) ---
                  Expanded( // Expanded to allow this card to take remaining vertical space
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          // --- GREY HEADER SECTION (for cart header only) ---
                          Container(
                            color: Colors.grey.shade200,
                            // Adjusted padding to control space ABOVE and BELOW _cartHeader content,
                            // allowing the Divider to be the visual bottom of the grey.
                            padding: const EdgeInsets.fromLTRB(0, 16, 0, 8), // Top 16, Bottom 8 (for content)
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20.0,vertical: 10),
                                  child: _cartHeader(),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, thickness: 1,),

                          // --- WHITE LIST & ACTIONS SECTION ---
                          Expanded(
                            child: Container(
                              color: Colors.white,
                              child: Column(
                                children: [
                                  Expanded(child: _cartList()), // Cart list takes available space
                                  // _cartActions moved here, directly after the list, still within white background
                                ],
                              ),
                            ),
                          ),
                          Container(
                            color: Colors.grey.shade200, // Background for the actions
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0,vertical: 10), // Padding for actions
                              child: _cartActions(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          /// RIGHT - SUMMARY
          Container(
            width: 400,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  blurRadius: 8,
                  color: Colors.black12,
                )
              ],
            ),
            child: _summaryPanel(),
          )
        ],
      ),
    );
  }

  Widget _searchBar() {
    // This widget now represents the content *inside* the new search bar Card.
    // Its own container/decoration is removed as the parent Card handles it.
    return Padding(
      padding: const EdgeInsets.all(16.0), // Padding for the content within the search card
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100, // Textfield background
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Scan barcode or search product',
                  prefixIcon: const Icon(Icons.qr_code_scanner),
                  focusColor: Colors.transparent,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10), // Adjust padding within TextField
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Reverted buttons to TextButton.icon with custom style from your provided snippet
          Container(
            decoration: BoxDecoration(
                border: Border.all(color: Colors.black,width: 1),
                borderRadius: BorderRadius.all(Radius.circular(8))
            ),
            child: TextButton.icon(
              style: ButtonStyle(
                splashFactory: NoSplash.splashFactory,
                overlayColor: MaterialStateProperty.all(Colors.transparent),
                foregroundColor: MaterialStateProperty.all(Colors.black), // Ensure text/icon color
                padding: MaterialStateProperty.all(const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
              ),
              onPressed: () {},
              icon: const Icon(Icons.search),
              label: const Text('Search'),
            ),
          ),

        ],
      ),
    );
  }

  Widget _cartHeader() {
    return const Row(
      children: [
        Expanded(flex: 4, child: Text('PRODUCT')),
        Expanded(child: Text('PRICE')),
        Expanded(child: Text('        QTY')), // Added spaces for alignment
        Expanded(child: Text('TOTAL')),
      ],
    );
  }

  Widget _cartList() {
    return ListView.separated(
      itemCount: cart.length,
      separatorBuilder: (_, __) => const Divider(indent: 16, endIndent: 16), // Indent divider for aesthetic
      itemBuilder: (_, i) {
        final item = cart[i];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Padding for each list item
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('SKU: ${item.sku}',
                        style:
                        const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Expanded(child: Text('\$${item.price.toStringAsFixed(2)}')),
              Expanded(
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline,color: Colors.grey,),
                      onPressed: () {
                        if (item.qty > 1) {
                          setState(() => item.qty--);
                        }
                      },
                    ),
                    Text(item.qty.toString(),style: TextStyle(fontWeight: FontWeight.bold),),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline,color: Colors.grey,),
                      onPressed: () => setState(() => item.qty++),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Text(
                  '\$${(item.price * item.qty).toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },

    );
  }

  Widget _cartActions() {
    // These actions are now placed at the bottom of the white list container
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade400,width: 1)
          ),
          child: TextButton(
              style: ButtonStyle(
                splashFactory: NoSplash.splashFactory,
                overlayColor: MaterialStateProperty.all(Colors.transparent),
                foregroundColor: MaterialStateProperty.all(Colors.black), // Ensure text/icon color
              ),
              onPressed: () {}, child: const Text('Add Note',style: TextStyle(color: Colors.black),)),
        ),
        const SizedBox(width: 8),
        Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade400,width: 1)
            ),
            child: TextButton(
                style: ButtonStyle(
                  splashFactory: NoSplash.splashFactory,
                  overlayColor: MaterialStateProperty.all(Colors.transparent),
                  foregroundColor: MaterialStateProperty.all(Colors.black), // Ensure text/icon color
                ),
                onPressed: () {}, child: const Text('Discount Item',style: TextStyle(color: Colors.black),))),
        const Spacer(),
        Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade400,width: 1)
          ),
          child: TextButton(
            style: ButtonStyle(
              splashFactory: NoSplash.splashFactory,
              overlayColor: MaterialStateProperty.all(Colors.transparent),
              foregroundColor: MaterialStateProperty.all(Colors.black), // Ensure text/icon color
            ),
            onPressed: () => setState(cart.clear),
            child: const Text('Clear Cart', style: TextStyle(color: Colors.red)),
          ),
        ),
      ],
    );
  }

  Widget _summaryPanel() {
    final discount = subtotal * 0.05;
    final tax = (subtotal - discount) * 0.085;
    final total = subtotal - discount + tax;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, color: Colors.grey.shade600),
              Text('Customer Details',style: TextStyle(fontWeight: FontWeight.bold,fontSize: 15),),
            ],
          ),
          SizedBox(height: 20,),
          // --- Card 1: Customer Input and Submit (Conditional Visibility) ---
          if (_selectedCustomer == null) // <<--- Only show this card if no customer is selected
            Card(
              color: Colors.white,
              margin: EdgeInsets.zero, // Remove default Card margin
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CUSTOMER INFO',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _customerNameController,
                      decoration: const InputDecoration(
                        labelText: 'Customer Name',
                        border: OutlineInputBorder(),
                        isDense: true, // Makes the field slightly smaller vertically
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _customerNumberController,
                      keyboardType: TextInputType.phone, // Suggests numeric keyboard for phone numbers
                      decoration: const InputDecoration(
                        labelText: 'Customer Number',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center, // Center the single button
                      children: [
                        Expanded( // Make the submit button fill available space
                          child: ElevatedButton(
                            style: ButtonStyle(
                              backgroundColor: MaterialStateProperty.all(Color(0xffFE691E)),
                            ),
                            onPressed: _searchAndAddCustomer,
                            child: const Text('Submit',style: TextStyle(color: Colors.white),),
                          ),
                        ),
                        // The "Clear" button is now only on the selected customer card or within this card logic
                        // if you wanted to clear the inputs without selecting.
                        // Currently, it's effectively handled by showing the input card again.
                      ],
                    ),
                  ],
                ),
              ),
            ),
          // Add a SizedBox only if the customer input card is visible
          if (_selectedCustomer == null)
            const SizedBox(height: 16), // Space between customer input card and next section


          // --- Card 2: Selected Customer Details (Conditional) ---
          if (_selectedCustomer != null) // Only show this card if a customer has been selected/added
            Card(
              color: Colors.white,
              margin: EdgeInsets.zero,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SELECTED CUSTOMER',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    // Reusing the ListTile structure for selected customer
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100, // Light blue background
                        foregroundColor: Colors.blue.shade800, // Dark blue text
                        child: Text(
                          _selectedCustomer!.name.isNotEmpty
                              ? _selectedCustomer!.name[0].toUpperCase()
                              : '?', // Display first letter of name
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(_selectedCustomer!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(_selectedCustomer!.number, style: const TextStyle(color: Colors.grey)),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.redAccent),
                        onPressed: _clearCustomerSelection, // Button to clear the selected customer
                      ),
                      contentPadding: EdgeInsets.zero, // Remove default ListTile padding to fit within Card better
                    ),
                  ],
                ),
              ),
            ),

          if (_selectedCustomer != null) // Add a SizedBox only if the customer details card is visible
            const SizedBox(height: 16),

          // --- Existing Order Summary ---
          const Text('ORDER SUMMARY',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _summaryRow('Subtotal', subtotal),
          _summaryRow('Discount (5%)', -discount),
          _summaryRow('Tax (8.5%)', tax),
          const Divider(),
          _summaryRow('Total Payable', total, bold: true),
          const SizedBox(height: 16),
          _paymentButtons(), // This widget will now manage the selection state
          SizedBox(height: 24,),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ButtonStyle(
                shape:MaterialStateProperty.all(
      RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10), // Adjust the radius as needed

      ),), backgroundColor: MaterialStateProperty.all(Color(0xffFE691E)),
              ),
              onPressed: () {},
              child: Text('Charge \$${total.toStringAsFixed(2)}',style: TextStyle(color: Colors.white),),
            ),
          )
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double value, {bool bold = false}) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              '\$${value.toStringAsFixed(2)}',
              style: TextStyle(fontWeight: bold ? FontWeight.bold : null),
            )
          ],
        ));
    }

  Widget _paymentButtons() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        PaymentBtn(
          Icons.credit_card,
          'Card',
          isSelected: _selectedPaymentMethod == 'Card', // Check if this button is selected
          onTap: () => _handlePaymentMethodSelected('Card'), // Call the state handler
        ),
        PaymentBtn(
          Icons.money,
          'Cash',
          isSelected: _selectedPaymentMethod == 'Cash',
          onTap: () => _handlePaymentMethodSelected('Cash'),
        ),
        PaymentBtn(
          Icons.qr_code,
          'QR Pay',
          isSelected: _selectedPaymentMethod == 'QR Pay',
          onTap: () => _handlePaymentMethodSelected('QR Pay'),
        ),
        PaymentBtn(
          Icons.delivery_dining_outlined,
          'COD',
          isSelected: _selectedPaymentMethod == 'Other',
          onTap: () => _handlePaymentMethodSelected('Other'),
        ),
      ],
    );
  }
}

// MODIFIED PaymentBtn to accept isSelected and onTap
// ... inside sales_page.dart

// MODIFIED PaymentBtn to be flexible
class PaymentBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const PaymentBtn(this.icon, this.label,
      {super.key, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Define the base style for the outlined button
    final ButtonStyle defaultStyle = OutlinedButton.styleFrom(
      foregroundColor: Colors.black, // Default text/icon color
      side: const BorderSide(color: Colors.grey, width: 1), // Default border
      backgroundColor: Colors.white, // Default background
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), // Allow padding to adjust
    );

    // Define the selected style, overriding parts of the default
    final ButtonStyle selectedStyle = OutlinedButton.styleFrom(
      foregroundColor: Colors.white, // White text/icon when selected
      backgroundColor: const Color(0xffFE691E), // Orange background
      side: const BorderSide(color: Color(0xffFE691E), width: 1), // Orange border
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    );

    // REMOVED the SizedBox with a fixed width. The button's size is now controlled by its parent.
    return OutlinedButton.icon(
      onPressed: onTap, // Use the provided onTap callback
      icon: Icon(icon, size: 20), // Slightly smaller icon
      label: FittedBox( // Use FittedBox to shrink the label text if needed
        fit: BoxFit.scaleDown,
        child: Text(label),
      ),
      style: isSelected ? selectedStyle : defaultStyle,
    );
  }
}

// ... CartItem class remains the same ...

class CartItem {
  final String name;
  final String sku;
  final double price;
  int qty;

  CartItem(this.name, this.sku, this.price, this.qty);
}