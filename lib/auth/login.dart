import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
void _launchAdminURL() async {
  // --- THIS IS THE ONLY LINE YOU NEED TO CHANGE ---
  // Replace the 'mailto:' link with your desired website URL.
  final Uri url = Uri.parse('https://www.example.com/contact'); // Changed to a website

  if (!await launchUrl(url)) {
    // You could show a snackbar here to inform the user of the failure
    debugPrint("Could not launch $url");
  }
}
class Login extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5), // Light gray background
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 400, // Fixed width for the card
                padding: EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo Icon
                    Center(
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Color(0xFFFFE0D3),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.hexagon, color: Color(0xFFE86B32), size: 30),
                      ),
                    ),
                    SizedBox(height: 16),
                     Text("Welcome Back",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
                    ),
                    Text("Please enter your details to sign in",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14)
                    ),
                    SizedBox(height: 32),

                    // Username Field
                    Text("Username", style: TextStyle(fontWeight: FontWeight.w600)),
                    SizedBox(height: 8),
                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.person_outline, size: 20),
                        hintText: "Enter your username",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Password Field

                        Text("Password", style: TextStyle(fontWeight: FontWeight.w600)),


                    SizedBox(height: 8),
                    TextField(
                      obscureText: true,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.lock_outline, size: 20),
                        hintText: "••••••••",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    SizedBox(height: 32),

                    // Sign In Button
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFE86B32),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text("Sign in", style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                    SizedBox(height: 24),

                    // Sign Up Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Facing an issue? Contact "),
                        InkWell(
                          onTap: _launchAdminURL, // Call the function when tapped
                          child: Text(
                            "Admin", // Removed the extra space from here
                            style: TextStyle(
                              color: Color(0xFFE86B32),
                              fontWeight: FontWeight.bold, // Add underline to look like a link
                              decorationColor: Color(0xFFE86B32), // Match underline color
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              Text("© 2024 Company Name. All rights reserved.", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}