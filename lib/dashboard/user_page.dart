import 'package:flutter/material.dart';

class User {
  final String id;
  final String username;
  final String email;
  final String role;
  final bool isActive;
  final DateTime lastLogin;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    required this.isActive,
    required this.lastLogin,
  });

  User copyWith({
    String? username,
    String? email,
    String? role,
    bool? isActive,
    DateTime? lastLogin,
  }) {
    return User(
      id: id,
      username: username ?? this.username,
      email: email ?? this.email,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      lastLogin: lastLogin ?? this.lastLogin,
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
      ),
      User(
        id: '2',
        username: 'sarah.miller',
        email: 'sarah.miller@company.com',
        role: 'Manager',
        isActive: true,
        lastLogin: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      User(
        id: '3',
        username: 'mike.chen',
        email: 'mike.chen@gmail.com',
        role: 'User',
        isActive: false,
        lastLogin: DateTime.now().subtract(const Duration(days: 3)),
      ),
      User(
        id: '4',
        username: 'emily.white',
        email: 'emily.white@outlook.com',
        role: 'User',
        isActive: true,
        lastLogin: DateTime.now().subtract(const Duration(days: 1)),
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
    String selectedRole = 'User';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New User'),
        content: SizedBox(
          width: 400,
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
              StatefulBuilder(
                builder: (context, setDialogState) => DropdownButtonFormField<String>(
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
              if (usernameController.text.isNotEmpty && emailController.text.isNotEmpty) {
                setState(() {
                  _users.add(User(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    username: usernameController.text,
                    email: emailController.text,
                    role: selectedRole,
                    isActive: true,
                    lastLogin: DateTime.now(),
                  ));
                  _filterUsers();
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User added successfully')),
                );
              }
            },
            child: const Text('Add User'),
          ),
        ],
      ),
    );
  }

  void _showEditUserDialog(User user) {
    final usernameController = TextEditingController(text: user.username);
    final emailController = TextEditingController(text: user.email);
    String selectedRole = user.role;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit User'),
        content: SizedBox(
          width: 400,
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
              StatefulBuilder(
                builder: (context, setDialogState) => DropdownButtonFormField<String>(
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
              setState(() {
                final index = _users.indexWhere((u) => u.id == user.id);
                if (index != -1) {
                  _users[index] = user.copyWith(
                    username: usernameController.text,
                    email: emailController.text,
                    role: selectedRole,
                  );
                  _filterUsers();
                }
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User updated successfully')),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showResetPasswordDialog(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Text('Send password reset email to ${user.email}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Password reset email sent to ${user.email}')),
              );
            },
            child: const Text('Send'),
          ),
        ],
      ),
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
              label: const Text("Add New User",style: TextStyle(color: Colors.white),),
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
          Expanded(flex: 1, child: Align(
              alignment: Alignment.centerLeft,
              child: Text("EMAIL", style: textStyle))),
          Expanded(flex: 2, child: Align(
              alignment: Alignment(0, 10),
              child: Text("ROLE", style: textStyle))),
          Expanded(flex: 1, child: Align(
              alignment: Alignment(0, 10),
              child: Text("STATUS", style: textStyle))),
          Expanded(flex: 1, child: Align(
              alignment: Alignment(0, 10),
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
          Expanded(flex: 3, child: Text(user.email, style: textStyle)),
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