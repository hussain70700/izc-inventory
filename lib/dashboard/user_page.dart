import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/session_service.dart';


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
  final Uint8List? imageBytes;

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

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      role: json['role'],
      isActive: json['is_active'] ?? true,
      lastLogin: json['last_login'] != null
          ? DateTime.parse(json['last_login'])
          : DateTime.now(),
      fullName: json['full_name'],
      idCardNumber: json['id_card_number'],
      imageUrl: json['image_url'],
    );
  }

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
  final SupabaseClient _supabase = Supabase.instance.client;

  String _selectedRoleFilter = "all";
  List<User> _users = [];
  List<User> _filteredUsers = [];
  bool _isLoading = true;
  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserRole();
    _loadUsers();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserRole() async {
    try {

          // Get role directly from Hive
          setState(() {
            _currentUserRole = SessionService.getUserRole();
          });


    } catch (e) {
      print('Error loading user role: $e');
    }
  }

// Replace your _loadUsers method with this simple version
  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('Fetching users from database...');

      // Query ONLY the users table - no joins, no profiles
      final response = await _supabase
          .from('users')
          .select('*')
          .order('created_at', ascending: false);

      print('Raw response: $response');
      print('Response type: ${response.runtimeType}');
      print('Number of records: ${(response as List).length}');

      if ((response as List).isEmpty) {
        print('⚠️ WARNING: No users found in the users table!');
        print('This could mean:');
        print('1. The table is actually empty');
        print('2. RLS (Row Level Security) is blocking access');
        print('3. The table name is different');

        setState(() {
          _users = [];
          _filteredUsers = [];
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No users found. Check RLS policies or add users first.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      setState(() {
        _users = (response as List).map((json) {
          print('Processing user record: $json');

          // Create User object from users table data only
          // Use dummy/default values for email, full_name, and role
          final userJson = {
            'id': json['id'],
            'username': json['username'] ?? 'unknown',
            'id_card_number': json['id_card_number'] ?? '',
            'is_active': json['is_active'] ?? true,
            'last_login': json['last_login'] ?? DateTime.now().toIso8601String(),
            'image_url': json['image_url'],
            // These fields don't exist in users table, so we use defaults
            'email': '${json['username']}@example.com', // Generate email from username
            'full_name': json['username'] ?? 'Unknown User',
            'role':  json['role'] ?? 'user', // Default role
          };

          print('Created user: ${userJson['username']}');
          return User.fromJson(userJson);
        }).toList();

        _filteredUsers = List.from(_users);
        _isLoading = false;

        print('✅ Successfully loaded ${_users.length} users');
      });
    } catch (e, stackTrace) {
      print('❌ Error loading users: $e');
      print('Stack trace: $stackTrace');

      setState(() {
        _isLoading = false;
        _users = [];
        _filteredUsers = [];
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading users: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

// IMPORTANT: Also update your User model to handle the case where
// email, full_name, and role might come from the users table
//
// If your users table actually HAS email, full_name, and role columns,
// then use this instead:
  Future<void> _loadUsersIfColumnsExist() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('Fetching users from database...');

      // Query users table with all the columns it actually has
      final response = await _supabase
          .from('users')
          .select('id, username, email, full_name, role, id_card_number, is_active, last_login, image_url, created_at')
          .order('created_at', ascending: false);

      print('Raw response: $response');
      print('Number of records: ${(response as List).length}');

      if ((response as List).isEmpty) {
        print('⚠️ No users found in the users table');
        setState(() {
          _users = [];
          _filteredUsers = [];
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _users = (response as List).map((json) {
          print('Processing: ${json['username']}');
          return User.fromJson(json);
        }).toList();

        _filteredUsers = List.from(_users);
        _isLoading = false;

        print('✅ Successfully loaded ${_users.length} users');
      });
    } catch (e, stackTrace) {
      print('❌ Error: $e');
      print('Stack trace: $stackTrace');

      setState(() {
        _isLoading = false;
        _users = [];
        _filteredUsers = [];
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading users: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  void _filterUsers() {
    setState(() {
      _filteredUsers = _users.where((user) {
        final matchesSearch = user.username.toLowerCase().contains(
            _searchController.text.toLowerCase()) ||
            user.email.toLowerCase().contains(
                _searchController.text.toLowerCase()) ||
            user.fullName.toLowerCase().contains(
                _searchController.text.toLowerCase());
        final matchesRole = _selectedRoleFilter == 'all' ||
            user.role.toLowerCase() == _selectedRoleFilter.toLowerCase();
        return matchesSearch && matchesRole;
      }).toList();
    });
  }

  bool _isAdmin() {
    return _currentUserRole == 'admin';
  }

  void _showAddUserDialog() {
    if (!_isAdmin()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only admins can add users'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final usernameController = TextEditingController();
    final emailController = TextEditingController();
    final fullNameController = TextEditingController();
    final idCardController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'user';
    XFile? selectedImage;
    Uint8List? imageBytes;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text('Add New User'),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                          "User Image", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                                  final bytes = await image.readAsBytes();
                                  setDialogState(() {
                                    selectedImage = image;
                                    imageBytes = bytes;
                                  });
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error picking image: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
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
                          helperText: 'Minimum 6 characters',
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

                          DropdownMenuItem(value: 'manager', child: Text('Manager')),
                          DropdownMenuItem(value: 'user', child: Text('User')),
                        ],
                        onChanged: (value) {
                          print('Role changed to: $value');
                          if (value != null) {
                            setDialogState(() {
                              selectedRole = value;

                            });
                            print('Selected role updated: $selectedRole');
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (usernameController.text.isEmpty ||
                        emailController.text.isEmpty ||
                        fullNameController.text.isEmpty ||
                        idCardController.text.isEmpty ||
                        passwordController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Colors.red,
                          content: Text('Please fill all required fields.'),
                        ),
                      );
                      return;
                    }

                    if (passwordController.text.length < 6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Colors.red,
                          content: Text('Password must be at least 6 characters'),
                        ),
                      );
                      return;
                    }
                    print('Creating user with role: $selectedRole');
                    // Close the add user dialog
                    Navigator.of(dialogContext).pop();

                    // Perform the async operation
                    _performUserCreation(
                      username: usernameController.text,
                      email: emailController.text,
                      fullName: fullNameController.text,
                      idCardNumber: idCardController.text,
                      password: passwordController.text,
                      role: selectedRole,
                      imageBytes: imageBytes,
                      imageName: selectedImage?.name,
                    );
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

  Future<void> _performUserCreation({
    required String username,
    required String email,
    required String fullName,
    required String idCardNumber,
    required String password,
    required String role,
    required Uint8List? imageBytes,
    required String? imageName,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      String? imageUrl;

      // Upload image if provided
      if (imageBytes != null && imageName != null) {
        print('Starting image upload...');
        final String fileExt = imageName.split('.').last;
        final String fileName = '${username}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

        await _supabase.storage
            .from('user-images')
            .uploadBinary(
          fileName,
          imageBytes,
          fileOptions: FileOptions(
            contentType: 'image/$fileExt',
            upsert: true,
          ),
        );

        imageUrl = _supabase.storage
            .from('user-images')
            .getPublicUrl(fileName);

        print('Image uploaded successfully: $imageUrl');
      }

      print('Calling create_user_with_password RPC...');

      // Create user using database function
      // The RPC function already creates BOTH the user AND the profile
      final result = await _supabase.rpc('create_user_with_password', params: {
        'p_username': username,
        'p_full_name': fullName,
        'p_email': email,
        'p_password': password,
        'p_id_card_number': idCardNumber,
        'p_role': role,
        'p_image_url': imageUrl,
      }).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timed out after 30 seconds');
        },
      );

      print('User and profile created successfully');
      print('RPC result: $result');

      // REMOVE ALL THE CODE THAT TRIES TO CREATE PROFILE MANUALLY
      // The RPC function already did it!

      await _loadUsers();

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Error adding user: $e');
      print('Stack trace: $stackTrace');

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        String errorMessage = 'Error adding user';
        if (e.toString().contains('duplicate key') && e.toString().contains('username')) {
          errorMessage = 'Username already exists. Please choose a different username.';
        } else if (e.toString().contains('duplicate key') && e.toString().contains('email')) {
          errorMessage = 'Email already exists. Please use a different email.';
        } else if (e.toString().contains('duplicate key') && e.toString().contains('id_card')) {
          errorMessage = 'ID card number already exists. Please check the ID card number.';
        } else if (e.toString().contains('Bucket not found')) {
          errorMessage = 'Storage bucket not found. Please contact administrator.';
        } else if (e.toString().contains('timeout')) {
          errorMessage = 'Request timed out. Please try again.';
        } else {
          errorMessage = 'Error adding user: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
  void _showEditUserDialog(User user) {
    if (!_isAdmin()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only admins can edit users'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final usernameController = TextEditingController(text: user.username);
    final emailController = TextEditingController(text: user.email);
    final idCardController = TextEditingController(text: user.idCardNumber);
    final fullNameController = TextEditingController(text: user.fullName);
    String selectedRole = user.role;
    bool isActive = user.isActive;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text('Edit User'),
              content: isLoading
                  ? const SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
                  : SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: fullNameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
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
                          DropdownMenuItem(value: 'admin', child: Text('Admin')),
                          DropdownMenuItem(value: 'manager', child: Text('Manager')),
                          DropdownMenuItem(value: 'user', child: Text('User')),
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
              actions: isLoading
                  ? []
                  : [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all<Color>(Color(0xffFE691E)),
                  ),
                  onPressed: () async {
                    if (usernameController.text.isEmpty ||
                        emailController.text.isEmpty ||
                        fullNameController.text.isEmpty ||
                        idCardController.text.isEmpty) {
                      ScaffoldMessenger.of(builderContext).showSnackBar(
                        const SnackBar(
                          backgroundColor: Colors.red,
                          content: Text('Please fill all required fields.'),
                        ),
                      );
                      return;
                    }

                    // Show loading in same dialog
                    setDialogState(() {
                      isLoading = true;
                    });

                    try {
                      // Update users table
                      await _supabase.from('users').update({
                        'username': usernameController.text,
                        'email': emailController.text,
                        'full_name': fullNameController.text,
                        'role': selectedRole,
                        'id_card_number': idCardController.text,
                        'is_active': isActive,
                      }).eq('id', user.id);

                      // Update profiles table (only role, email, full_name)
                      await _supabase.from('profiles').update({
                        'email': emailController.text,
                        'full_name': fullNameController.text,
                        'role': selectedRole,
                      }).eq('id', user.id);

                      await _loadUsers();

                      // Close dialog
                      if (Navigator.canPop(dialogContext)) {
                        Navigator.of(dialogContext).pop();
                      }

                      // Show success message
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('User updated successfully')),
                        );
                      }
                    } catch (e) {
                      // Hide loading
                      if (mounted) {
                        setDialogState(() {
                          isLoading = false;
                        });
                      }

                      // Show error message
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error updating user: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Update',style: TextStyle(color: Colors.white),),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showResetPasswordDialog(User user) {
    if (!_isAdmin()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only admins can reset passwords'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text('Change Password'),
              content: isLoading
                  ? const SizedBox(
                height: 100,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
                  : SizedBox(
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
                            obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
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
              actions: isLoading
                  ? []
                  : [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(

                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all<Color>(Color(0xffFE691E)),
                  ),
                  onPressed: () async {
                    // Validation
                    if (newPasswordController.text.isEmpty) {
                      ScaffoldMessenger.of(builderContext).showSnackBar(
                        const SnackBar(
                          backgroundColor: Colors.red,
                          content: Text('Please enter a new password'),
                        ),
                      );
                      return;
                    }

                    if (newPasswordController.text != confirmPasswordController.text) {
                      ScaffoldMessenger.of(builderContext).showSnackBar(
                        const SnackBar(
                          backgroundColor: Colors.red,
                          content: Text('Passwords do not match'),
                        ),
                      );
                      return;
                    }

                    if (newPasswordController.text.length < 6) {
                      ScaffoldMessenger.of(builderContext).showSnackBar(
                        const SnackBar(
                          backgroundColor: Colors.red,
                          content: Text('Password must be at least 6 characters'),
                        ),
                      );
                      return;
                    }

                    // Show loading in the same dialog
                    setDialogState(() {
                      isLoading = true;
                    });

                    try {
                      print('Calling change_user_password RPC...');
                      print('User ID: ${user.id}');

                      // Call database function to update password
                      await _supabase.rpc('change_user_password', params: {
                        'p_user_id': user.id,
                        'p_new_password': newPasswordController.text,
                      });

                      print('Password updated successfully');

                      // Close the dialog - use dialogContext which is guaranteed to be valid
                      if (Navigator.canPop(dialogContext)) {
                        Navigator.of(dialogContext).pop();
                      }

                      // Show success message using the page context
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Password changed successfully for ${user.username}'),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    } catch (e, stackTrace) {
                      print('Error changing password: $e');
                      print('Stack trace: $stackTrace');

                      // Hide loading
                      if (mounted) {
                        setDialogState(() {
                          isLoading = false;
                        });
                      }

                      // Show error message
                      if (mounted) {
                        String errorMessage = 'Error changing password';
                        if (e.toString().contains('not found')) {
                          errorMessage = 'User not found';
                        } else if (e.toString().contains('function') &&
                            e.toString().contains('does not exist')) {
                          errorMessage = 'Password reset function not available. Please contact administrator.';
                        } else {
                          errorMessage = 'Error changing password: ${e.toString()}';
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(errorMessage),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Change Password',style: TextStyle(color: Colors.white),),
                ),
              ],
            );
          },
        );
      },
    );
  }
    void _deleteUser(User user) {
    if (!_isAdmin()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only admins can delete users'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user.username}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              // Close confirmation dialog
              Navigator.of(dialogContext).pop();

              // Show loading dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              try {
                await _supabase.from('users').delete().eq('id', user.id);
                await _loadUsers();

                if (mounted) {
                  Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('User deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting user: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete',style: TextStyle(color: Colors.white),),
          ),
        ],
      ),
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
        automaticallyImplyLeading: false,
        elevation: 0,
        surfaceTintColor: WidgetStateColor.transparent,
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
          if (_isAdmin())
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ElevatedButton.icon(
                onPressed: _showAddUserDialog,
                icon: const Icon(Icons.person_add, color: Colors.white),
                label: const Text(
                    "Add New Member", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffFE691E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0), // Height for the shadow container
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white, // Ensure white background continues under shadow
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2), // Shadow color and opacity
                  spreadRadius: 4, // No spread for a clean bottom shadow
                  blurRadius: 6,   // Softness of the shadow
                  offset: Offset(0, 4), // Shifts shadow 4 pixels downwards
                ),
              ],
            ),
            height: 2.0, // A small height for the container, just enough for shadow to render clearly
          ),
        ),
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          color: Colors.white,
          elevation: 4,
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
                          DropdownMenuItem(value: "all", child: Text(
                              "All Roles")),
                           DropdownMenuItem(value: "manager", child: Text(
                              "Manager")),
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
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
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
                      Icon(Icons.people_outline, size: 64,
                          color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No users found',
                        style: TextStyle(fontSize: 16, color: Colors.grey
                            .shade600),
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
          Expanded(flex: 2, child: Align( // Adjusted flex from 2 to 2 (was correct)
              alignment: Alignment.centerLeft, // Center align text in header
              child: Text("ID CARD NUMBER", style: textStyle))),
          Expanded(flex: 2, child: Align( // Adjusted flex from 2 to 2 (was correct)
              alignment: Alignment(0.1, 0),
              child: Text("ROLE", style: textStyle))),
          Expanded(flex: 1, child: Align( // Adjusted flex from 1 to 1 (was correct)
              alignment: Alignment(0.1, 0),
              child: Text("STATUS", style: textStyle))),
          Expanded(flex: 2, child: Align( // Adjusted flex from 1 to 2
              alignment: Alignment.centerRight,
              child: Text("LAST LOGIN", style: textStyle))),
          Expanded(flex: 3, child: Align( // Adjusted flex from 2 to 3 to give more space for buttons
              alignment: Alignment(0.1, 0),
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
      child: Row( // This is the Row at line 1402
        children: [
          Expanded(flex: 2, child: Text(user.username, style: textStyle)),
          Expanded(flex: 2, child: Text(user.idCardNumber, style: textStyle)), // Adjusted flex from 3 to 2
          Expanded(
            flex: 2, // Adjusted flex from 2 to 2 (was correct)
            child: Padding(
              padding: const EdgeInsets.only(left: 0),
              child: Chip(
                label: Text(user.role),
                labelStyle: TextStyle(fontSize: 12,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.bold),
                backgroundColor: Colors.grey.shade200,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          Expanded(
            flex: 1, // Adjusted flex from 2 to 1
            child: Padding(
              padding: const EdgeInsets.only(left: 0),
              child: Chip(
                label: Text(user.isActive ? "Active" : "Inactive"),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: user.isActive ? Colors.green.shade800 : Colors.red
                      .shade800,
                ),
                backgroundColor: user.isActive ? Colors.green.shade100 : Colors
                    .red.shade100,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          Expanded(flex: 2, // Adjusted flex from 2 to 2 (was correct)
              child: Align(
                  alignment: Alignment(1, 0),
                  child: Text(_formatLastLogin(user.lastLogin), style: textStyle))),
          Expanded(
            flex: 3, // Adjusted flex from 2 to 3 to give more space for buttons
            child: Row(
              mainAxisAlignment: MainAxisAlignment.values[2],
              children: [
                if (_isAdmin()) ...[
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
              ],
            ),
          ),
        ],
      ),
    );
  }}