import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data'; // Import the package

class User {
  final String id;
  final String username;
  final String email;
  final String role;
  final bool isActive;
  final DateTime lastLogin;
  final String fullName;
  final String idCardNumber;
  final String? imageUrl;
  final Uint8List? imageBytes; // For web

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    required this.isActive,
    required this.lastLogin,
    required this.fullName,
    required this.idCardNumber,
    this.imageUrl,
    this.imageBytes,
  });

  User copyWith({
    String? username,
    String? email,
    String? role,
    bool? isActive,
    DateTime? lastLogin,
    String? fullName,
    String? idCardNumber,
    String? imageUrl,
    Uint8List? imageBytes,
  }) {
    return User(
      id: id,
      username: username ?? this.username,
      email: email ?? this.email,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      lastLogin: lastLogin ?? this.lastLogin,
      fullName: fullName ?? this.fullName,
      idCardNumber: idCardNumber ?? this.idCardNumber,
      imageUrl: imageUrl ?? this.imageUrl,
      imageBytes: imageBytes ?? this.imageBytes,
    );
  }
}

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedRoleFilter = "all";
  List<User> _users = [];
  List<User> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    _initializeUsers();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _initializeUsers() {
    _users = [
      User(
        id: '1',
        username: 'john.doe',
        email: 'john.doe@company.com',
        role: 'Admin',
        isActive: true,
        lastLogin: DateTime.now().subtract(const Duration(hours: 2)),
        fullName: 'Johnathan Doe',
        idCardNumber: '123456789',
      ),
      User(
        id: '2',
        username: 'sarah.miller',
        email: 'sarah.miller@company.com',
        role: 'Manager',
        isActive: true,
        lastLogin: DateTime.now().subtract(const Duration(hours: 5)),
        fullName: 'Sarah Miller',
        idCardNumber: '987654321',
      ),
      User(
        id: '3',
        username: 'mike.chen',
        email: 'mike.chen@gmail.com',
        role: 'User',
        isActive: false,
        lastLogin: DateTime.now().subtract(const Duration(days: 3)),
        fullName: 'Michael Chen',
        idCardNumber: '112233445',
      ),
      User(
        id: '4',
        username: 'emily.white',
        email: 'emily.white@outlook.com',
        role: 'User',
        isActive: true,
        lastLogin: DateTime.now().subtract(const Duration(days: 1)),
        fullName: 'Emily White',
        idCardNumber: '556677889',
      ),
    ];
    _filteredUsers = List.from(_users);
  }

  void _filterUsers() {
    setState(() {
      _filteredUsers = _users.where((user) {
        final matchesSearch = user.username.toLowerCase().contains(_searchController.text.toLowerCase()) ||
            user.email.toLowerCase().contains(_searchController.text.toLowerCase());
        final matchesRole = _selectedRoleFilter == 'all' || user.role.toLowerCase() == _selectedRoleFilter.toLowerCase();
        return matchesSearch && matchesRole;
      }).toList();
    });
  }


  void _showAddUserDialog() {
    final usernameController = TextEditingController();
    final emailController = TextEditingController();
    final fullNameController = TextEditingController();
    final idCardController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'User';
    XFile? selectedImage;
    Uint8List? imageBytes;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add New User'),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User Image Picker
                      const Text("User Image", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                final ImagePicker picker = ImagePicker();
                                final XFile? image = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 800,
                                  maxHeight: 800,
                                  imageQuality: 85,
                                );

                                if (image != null) {
                                  // Read image bytes for web
                                  final bytes = await image.readAsBytes();
                                  setDialogState(() {
                                    selectedImage = image;
                                    imageBytes = bytes;
                                  });
                                  print("Image selected: ${image.name}, Size: ${bytes.length} bytes");
                                } else {
                                  print("No image selected");
                                }
                              } catch (e) {
                                print("Error picking image: $e");
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error picking image: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.upload_file),
                            label: const Text("Choose Image"),
                          ),
                          const SizedBox(width: 16),
                          if (selectedImage != null)
                            Expanded(
                              child: Row(
                                children: [
                                  if (imageBytes != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.memory(
                                        imageBytes!,
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      selectedImage!.name,
                                      style: const TextStyle(color: Colors.black54),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () {
                                      setDialogState(() {
                                        selectedImage = null;
                                        imageBytes = null;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const Divider(height: 24),

                      TextField(
                        controller: fullNameController,
                        decoration: const InputDecoration(
                          labelText: 'User Full Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: idCardController,
                        decoration: const InputDecoration(
                          labelText: 'User ID Card Number',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Manager', child: Text('Manager')),
                          DropdownMenuItem(value: 'User', child: Text('User')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              selectedRole = value;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (usernameController.text.isNotEmpty &&
                        emailController.text.isNotEmpty &&
                        fullNameController.text.isNotEmpty &&
                        idCardController.text.isNotEmpty &&
                        passwordController.text.isNotEmpty) {

                      // TODO: Upload image to your server here
                      if (selectedImage != null && imageBytes != null) {
                        print("Ready to upload image: ${selectedImage!.name}");
                        print("Image size: ${imageBytes!.length} bytes");
                        // You can now send imageBytes to your backend via HTTP
                      }

                      setState(() {
                        _users.add(User(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          username: usernameController.text,
                          email: emailController.text,
                          role: selectedRole,
                          isActive: true,
                          lastLogin: DateTime.now(),
                          fullName: fullNameController.text,
                          idCardNumber: idCardController.text,
                          imageUrl: selectedImage?.name,
                          imageBytes: imageBytes,
                        ));
                        _filterUsers();
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('User added successfully')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Colors.red,
                          content: Text('Please fill all required fields.'),
                        ),
                      );
                    }
                  },
                  child: const Text('Add User'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  void _showEditUserDialog(User user) {
    final usernameController = TextEditingController(text: user.username);
    final emailController = TextEditingController(text: user.email);
    final idCardController = TextEditingController(text: user.idCardNumber);
    String selectedRole = user.role;
    bool isActive = user.isActive;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit User'),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: idCardController,
                        decoration: const InputDecoration(
                          labelText: 'ID Card Number',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                          DropdownMenuItem(value: 'Manager', child: Text('Manager')),
                          DropdownMenuItem(value: 'User', child: Text('User')),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            selectedRole = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Account Status',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isActive ? Colors.green : Colors.red,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Switch(
                                  value: isActive,
                                  activeColor: Colors.green,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      isActive = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (usernameController.text.isNotEmpty &&
                        emailController.text.isNotEmpty &&
                        idCardController.text.isNotEmpty) {
                      setState(() {
                        final index = _users.indexWhere((u) => u.id == user.id);
                        if (index != -1) {
                          _users[index] = user.copyWith(
                            username: usernameController.text,
                            email: emailController.text,
                            idCardNumber: idCardController.text,
                            role: selectedRole,
                            isActive: isActive,
                          );
                          _filterUsers();
                        }
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('User updated successfully')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Colors.red,
                          content: Text('Please fill all required fields.'),
                        ),
                      );
                    }
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }


  void _showResetPasswordDialog(User user) {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Change password for ${user.username}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: newPasswordController,
                      obscureText: obscureNewPassword,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscureNewPassword = !obscureNewPassword;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscureConfirmPassword = !obscureConfirmPassword;
                            });
                          },
                        ),
                      ),
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
                  onPressed: () {
                    if (newPasswordController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Colors.red,
                          content: Text('Please enter a new password'),
                        ),
                      );
                      return;
                    }

                    if (newPasswordController.text != confirmPasswordController.text) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Colors.red,
                          content: Text('Passwords do not match'),
                        ),
                      );
                      return;
                    }

                    if (newPasswordController.text.length < 6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Colors.red,
                          content: Text('Password must be at least 6 characters'),
                        ),
                      );
                      return;
                    }

                    // TODO: Implement your password change logic here
                    print('Password changed for user: ${user.username}');
                    print('New password: ${newPasswordController.text}');

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Password changed successfully for ${user.username}')),
                    );
                  },
                  child: const Text('Change Password'),
                ),
              ],
            );
          },
        );
      },
    );
  }


  void _deleteUser(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user.username}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                _users.removeWhere((u) => u.id == user.id);
                _filterUsers();
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User deleted successfully')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _toggleUserStatus(User user) {
    setState(() {
      final index = _users.indexWhere((u) => u.id == user.id);
      if (index != -1) {
        _users[index] = user.copyWith(isActive: !user.isActive);
        _filterUsers();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('User ${user.isActive ? 'deactivated' : 'activated'}')),
    );
  }

  String _formatLastLogin(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inHours < 1) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F6FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "User Management",
              style: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 2),
            Text(
              "Manage user accounts, roles and permissions.",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: _showAddUserDialog,
              icon: const Icon(Icons.person_add,color: Colors.white,),
              label: const Text("Add New Member",style: TextStyle(color: Colors.white),),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xffFE691E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Search + Filter Row
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
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: "Search users...",
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<String>(
                        value: _selectedRoleFilter,
                        items: const [
                          DropdownMenuItem(value: "all", child: Text("All Roles")),
                          DropdownMenuItem(value: "admin", child: Text("Admin")),
                          DropdownMenuItem(value: "manager", child: Text("Manager")),
                          DropdownMenuItem(value: "user", child: Text("User")),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedRoleFilter = value!;
                            _filterUsers();
                          });
                        },
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Table Header
              _buildTableHeader(),

              // Table Body
              Expanded(
                child: _filteredUsers.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No users found',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  itemCount: _filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = _filteredUsers[index];
                    return _buildTableRow(user);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    const textStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.bold,
      color: Colors.grey,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: const [
          Expanded(flex: 2, child: Text("USERNAME", style: textStyle)),
          Expanded(flex: 2, child: Align(
              alignment: Alignment(-1.8, 10),
              child: Text("Id card number", style: textStyle))),
          Expanded(flex: 2, child: Align(
              alignment: Alignment(-0.5, 10),
              child: Text("ROLE", style: textStyle))),
          Expanded(flex: 1, child: Align(
              alignment: Alignment(-1, 10),
              child: Text("STATUS", style: textStyle))),
          Expanded(flex: 1, child: Align(
              alignment: Alignment(-1.2, 10),
              child: Text("LAST LOGIN", style: textStyle))),
          Expanded(flex: 2, child: Align(
              alignment: Alignment(0, 10),
              child: Text("ACTIONS", style: textStyle))),
        ],
      ),
    );
  }

  Widget _buildTableRow(User user) {
    const textStyle = TextStyle(fontSize: 13, color: Colors.black87);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(user.username, style: textStyle)),
          Expanded(flex: 3, child: Text(user.idCardNumber, style: textStyle)),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(left: 0),
              child: Chip(
                label: Text(user.role),
                labelStyle: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.bold),
                backgroundColor: Colors.grey.shade200,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(left: 0),
              child: InkWell(
                onTap: () => _toggleUserStatus(user),
                child: Chip(
                  label: Text(user.isActive ? "Active" : "Inactive"),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: user.isActive ? Colors.green.shade800 : Colors.red.shade800,
                  ),
                  backgroundColor: user.isActive ? Colors.green.shade100 : Colors.red.shade100,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ),
          Expanded(flex: 2, child: Text(_formatLastLogin(user.lastLogin), style: textStyle)),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => _showEditUserDialog(user),
                  icon: const Icon(Icons.edit, size: 18),
                  splashRadius: 18,
                  tooltip: 'Edit',
                ),
                IconButton(
                  onPressed: () => _showResetPasswordDialog(user),
                  icon: const Icon(Icons.vpn_key, size: 18),
                  splashRadius: 18,
                  tooltip: 'Reset Password',
                ),
                IconButton(
                  onPressed: () => _deleteUser(user),
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  splashRadius: 18,
                  tooltip: 'Delete',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}