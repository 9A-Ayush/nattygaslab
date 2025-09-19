import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/user_service.dart';
import 'user_form_dialog.dart';
import 'user_export_dialog.dart';
import 'dart:async';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedRole = 'All';
  String _selectedStatus = 'All';
  Timer? _debounceTimer;
  
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  
  final List<String> _roles = ['All', ...UserService.getAvailableRoles()];
  
  @override
  void initState() {
    super.initState();
    _setupRealtimeUpdates();
    
    // Debounced search
    _searchController.addListener(() {
      if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        if (_searchController.text != _searchQuery) {
          setState(() {
            _searchQuery = _searchController.text;
          });
          _filterUsers();
        }
      });
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }
  
  void _setupRealtimeUpdates() {
    UserService.getUsersStream().listen(
      (users) {
        if (mounted) {
          setState(() {
            _users = users;
            _isLoading = false;
            _hasError = false;
          });
          _filterUsers();
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = error.toString();
          });
        }
      },
    );
  }
  
  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    
    try {
      final users = await UserService.searchUsers('');
      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
        _filterUsers();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }
  
  void _filterUsers() {
    List<Map<String, dynamic>> filtered = List.from(_users);
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((user) {
        final name = (user['name'] as String? ?? '').toLowerCase();
        final email = (user['email'] as String? ?? '').toLowerCase();
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || email.contains(query);
      }).toList();
    }
    
    // Apply role filter
    if (_selectedRole != 'All') {
      filtered = filtered.where((user) => user['role'] == _selectedRole).toList();
    }
    
    // Apply status filter
    if (_selectedStatus != 'All') {
      final isActive = _selectedStatus == 'Active';
      filtered = filtered.where((user) => (user['active'] as bool? ?? true) == isActive).toList();
    }
    
    setState(() {
      _filteredUsers = filtered;
    });
  }

  void _showRoleFilter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter by Role',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _roles.map((role) {
                return FilterChip(
                  label: Text(
                    role == 'All' ? 'All Roles' : role.toUpperCase(),
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  selected: _selectedRole == role,
                  onSelected: (selected) {
                    setState(() {
                      _selectedRole = role;
                    });
                    _filterUsers();
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showStatusFilter(BuildContext context) {
    final statuses = ['All', 'Active', 'Inactive'];
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter by Status',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: statuses.map((status) {
                return FilterChip(
                  label: Text(
                    status,
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  selected: _selectedStatus == status,
                  onSelected: (selected) {
                    setState(() {
                      _selectedStatus = status;
                    });
                    _filterUsers();
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }


  
  void _showAddUserDialog() {
    showDialog(
      context: context,
      builder: (context) => UserFormDialog(
        onSaved: () {
          // No need to refresh - real-time updates handle this
        },
      ),
    );
  }


  
  
  Future<void> _exportUsers() async {
    await showDialog(
      context: context,
      builder: (context) => UserExportDialog(
        currentRoleFilter: _selectedRole,
        currentStatusFilter: _selectedStatus,
        currentSearchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      ),
    );
  }
  
  Future<void> _sendPasswordReset(String email) async {
    try {
      await UserService.sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset email sent to $email'),
            backgroundColor: Colors.green[600],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending password reset: $e'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }
  
  Future<void> _toggleUserStatus(Map<String, dynamic> user) async {
    final isActive = user['active'] as bool? ?? true;
    final action = isActive ? 'deactivate' : 'reactivate';
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${action.substring(0, 1).toUpperCase()}${action.substring(1)} User',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to $action "${user['name']}"?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive ? Colors.red[600] : Colors.green[600],
              foregroundColor: Colors.white,
            ),
            child: Text(
              action.substring(0, 1).toUpperCase() + action.substring(1),
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        if (isActive) {
          await UserService.deactivateUser(user['id']);
        } else {
          await UserService.reactivateUser(user['id']);
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User ${action}d successfully'),
              backgroundColor: Colors.green[600],
            ),
          );
          // No need to call _loadUsers() anymore - real-time updates handle this
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error ${action}ing user: $e'),
              backgroundColor: Colors.red[600],
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete User',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.red[600],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete "${user['name']}"?',
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red[600], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone!',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.red[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await UserService.deleteUser(user['id']);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User "${user['name']}" deleted successfully'),
              backgroundColor: Colors.green[600],
            ),
          );
          // No need to call _loadUsers() anymore - real-time updates handle this
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting user: $e'),
              backgroundColor: Colors.red[600],
            ),
          );
        }
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;
        final isDesktop = constraints.maxWidth > 1200;
        
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: _buildAppBar(context, isTablet),
          body: Column(
            children: [
              _buildSearchAndFilters(context, isTablet),
              Expanded(
                child: _buildBody(context, isTablet, isDesktop),
              ),
            ],
          ),
          floatingActionButton: _buildFAB(context),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isTablet) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return AppBar(
      backgroundColor: isDarkMode 
          ? Theme.of(context).colorScheme.surface
          : const Color(0xFF0072BC),
      foregroundColor: isDarkMode 
          ? Theme.of(context).colorScheme.onSurface
          : Colors.white,
      elevation: 0,
      title: Text(
        'Users Management',
        style: GoogleFonts.poppins(
          fontSize: isTablet ? 22 : 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        IconButton(
          onPressed: _showAddUserDialog,
          icon: const Icon(Icons.person_add_outlined),
          tooltip: 'Add User',
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'export':
                _exportUsers();
                break;
              case 'refresh':
                _loadUsers();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'test-email',
              child: Row(
                children: [
                  const Icon(Icons.email_outlined, size: 20),
                  const SizedBox(width: 8),
                  Text('Test Email Service', style: GoogleFonts.poppins()),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  const Icon(Icons.download_outlined, size: 20),
                  const SizedBox(width: 8),
                  Text('Export Users', style: GoogleFonts.poppins()),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  const Icon(Icons.refresh_outlined, size: 20),
                  const SizedBox(width: 8),
                  Text('Refresh', style: GoogleFonts.poppins()),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters(BuildContext context, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search Bar
          SearchBar(
            controller: _searchController,
            hintText: 'Search users by name or email...',
            hintStyle: MaterialStatePropertyAll(
              GoogleFonts.poppins(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            textStyle: MaterialStatePropertyAll(GoogleFonts.poppins()),
            leading: const Icon(Icons.search_outlined),
            trailing: _searchController.text.isNotEmpty
                ? [
                    IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                        _filterUsers();
                      },
                      icon: const Icon(Icons.clear),
                    ),
                  ]
                : null,
          ),
          const SizedBox(height: 16),
          // Filter Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Role Filter
              _buildFilterChip(
                context,
                'Role: $_selectedRole',
                _selectedRole != 'All',
                () => _showRoleFilter(context),
              ),
              // Status Filter
              _buildFilterChip(
                context,
                'Status: $_selectedStatus',
                _selectedStatus != 'All',
                () => _showStatusFilter(context),
              ),
              // Clear Filters
              if (_selectedRole != 'All' || _selectedStatus != 'All')
                ActionChip(
                  label: Text(
                    'Clear Filters',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedRole = 'All';
                      _selectedStatus = 'All';
                    });
                    _filterUsers();
                  },
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  labelStyle: GoogleFonts.poppins(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, bool isSelected, VoidCallback onTap) {
    return FilterChip(
      label: Text(
        label,
        style: GoogleFonts.poppins(fontSize: 12),
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      checkmarkColor: Theme.of(context).colorScheme.onPrimaryContainer,
      labelStyle: GoogleFonts.poppins(
        color: isSelected 
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: _showAddUserDialog,
      backgroundColor: const Color(0xFF0072BC),
      foregroundColor: Colors.white,
      icon: const Icon(Icons.person_add_outlined),
      label: Text(
        'Add User',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
    );
  }
  
  Widget _buildBody(BuildContext context, bool isTablet, bool isDesktop) {
    if (_isLoading) {
      return _buildLoadingSkeleton(context, isTablet);
    }
    
    if (_hasError) {
      return _buildErrorState(context);
    }
    
    if (_filteredUsers.isEmpty) {
      return _buildEmptyState(context);
    }
    
    if (isDesktop) {
      return _buildDataTable(context);
    } else if (isTablet) {
      return _buildGridView(context);
    } else {
      return _buildUserList(context);
    }
  }

  Widget _buildLoadingSkeleton(BuildContext context, bool isTablet) {
    return ListView.builder(
      padding: EdgeInsets.all(isTablet ? 24 : 16),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 200,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading users',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadUsers,
              icon: const Icon(Icons.refresh_outlined),
              label: Text('Retry', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty || _selectedRole != 'All' || _selectedStatus != 'All'
                  ? 'Try adjusting your search or filters'
                  : 'Add your first user to get started',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _showAddUserDialog,
              icon: const Icon(Icons.person_add_outlined),
              label: Text('Add User', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGridView(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        return _UserGridCard(
          user: _filteredUsers[index],
          onEdit: () => _showEditUserDialog(_filteredUsers[index]),
          onResetPassword: () => _sendPasswordReset(_filteredUsers[index]['email']),
          onToggleStatus: () => _toggleUserStatus(_filteredUsers[index]),
          onDelete: () => _deleteUser(_filteredUsers[index]),
        );
      },
    );
  }

  Widget _buildDataTable(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(
              Theme.of(context).colorScheme.surfaceVariant,
            ),
            columns: [
              DataColumn(
                label: Text(
                  'User',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
              DataColumn(
                label: Text(
                  'Email',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
              DataColumn(
                label: Text(
                  'Role',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
              DataColumn(
                label: Text(
                  'Status',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
              DataColumn(
                label: Text(
                  'Actions',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
            rows: _filteredUsers.map((user) {
              final isActive = user['active'] as bool? ?? true;
              
              return DataRow(
                cells: [
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          child: Text(
                            (user['name'] as String? ?? 'U').substring(0, 1).toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          user['name'] ?? 'Unknown',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(
                      user['email'] ?? '',
                      style: GoogleFonts.poppins(),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getRoleColor(user['role']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getRoleColor(user['role']).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        (user['role'] as String? ?? 'user').toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getRoleColor(user['role']),
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.green[100] : Colors.red[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isActive ? 'ACTIVE' : 'INACTIVE',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isActive ? Colors.green[800] : Colors.red[800],
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _showEditUserDialog(user),
                          icon: const Icon(Icons.edit, size: 18),
                          tooltip: 'Edit User',
                          color: const Color(0xFF0072BC),
                        ),
                        IconButton(
                          onPressed: () => _sendPasswordReset(user['email']),
                          icon: const Icon(Icons.lock_reset, size: 18),
                          tooltip: 'Reset Password',
                          color: Colors.orange[600],
                        ),
                        IconButton(
                          onPressed: () => _toggleUserStatus(user),
                          icon: Icon(
                            isActive ? Icons.person_off : Icons.person,
                            size: 18,
                          ),
                          tooltip: isActive ? 'Deactivate' : 'Reactivate',
                          color: isActive ? Colors.red[600] : Colors.green[600],
                        ),
                        IconButton(
                          onPressed: () => _deleteUser(user),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          tooltip: 'Delete User',
                          color: Colors.red[700],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
  
  Widget _buildUserList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        return _UserListCard(
          user: _filteredUsers[index],
          onEdit: () => _showEditUserDialog(_filteredUsers[index]),
          onResetPassword: () => _sendPasswordReset(_filteredUsers[index]['email']),
          onToggleStatus: () => _toggleUserStatus(_filteredUsers[index]),
          onDelete: () => _deleteUser(_filteredUsers[index]),
        );
      },
    );
  }
  
  Color _getRoleColor(String? role) {
    switch (role) {
      case 'admin':
      case 'supervisor':
        return Colors.purple;
      case 'clerk':
        return const Color(0xFF0072BC);
      case 'technician':
        return Colors.green;
      case 'assistant':
        return Colors.orange;
      case 'customer':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}

class _UserListCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onEdit;
  final VoidCallback onResetPassword;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;
  
  const _UserListCard({
    required this.user,
    required this.onEdit,
    required this.onResetPassword,
    required this.onToggleStatus,
    required this.onDelete,
  });
  
  @override
  Widget build(BuildContext context) {
    final isActive = user['active'] as bool? ?? true;
    final role = user['role'] as String? ?? 'user';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: _getRoleColor(role).withOpacity(0.1),
                    child: Text(
                      (user['name'] as String? ?? 'U').substring(0, 1).toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _getRoleColor(role),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['name'] ?? 'Unknown',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user['email'] ?? '',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getRoleColor(role).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          role.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _getRoleColor(role),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive 
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isActive ? Icons.check_circle : Icons.cancel,
                              size: 12,
                              color: isActive 
                                  ? Theme.of(context).colorScheme.onPrimaryContainer
                                  : Theme.of(context).colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isActive ? 'ACTIVE' : 'INACTIVE',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isActive 
                                    ? Theme.of(context).colorScheme.onPrimaryContainer
                                    : Theme.of(context).colorScheme.onErrorContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: Text(
                        'Edit',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onResetPassword,
                      icon: const Icon(Icons.lock_reset_outlined, size: 16),
                      label: Text(
                        'Reset',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.tertiary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    onPressed: onToggleStatus,
                    icon: Icon(
                      isActive ? Icons.person_off_outlined : Icons.person_outlined,
                      size: 18,
                    ),
                    style: IconButton.styleFrom(
                      foregroundColor: isActive 
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                    ),
                    tooltip: isActive ? 'Deactivate' : 'Activate',
                  ),
                  const SizedBox(width: 4),
                  IconButton.outlined(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    style: IconButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    tooltip: 'Delete User',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Color _getRoleColor(String? role) {
    switch (role) {
      case 'admin':
        return const Color(0xFF6A1B9A); // Purple
      case 'supervisor':
        return const Color(0xFF8E24AA); // Light Purple
      case 'clerk':
        return const Color(0xFF0072BC); // Primary Blue
      case 'technician':
        return const Color(0xFF66A23F); // Primary Green
      case 'assistant':
        return const Color(0xFFFF9800); // Orange
      case 'customer':
        return const Color(0xFF00BCD4); // Accent Cyan
      default:
        return const Color(0xFF757575); // Grey
    }
  }
}

class _UserGridCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onEdit;
  final VoidCallback onResetPassword;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;
  
  const _UserGridCard({
    required this.user,
    required this.onEdit,
    required this.onResetPassword,
    required this.onToggleStatus,
    required this.onDelete,
  });
  
  @override
  Widget build(BuildContext context) {
    final isActive = user['active'] as bool? ?? true;
    final role = user['role'] as String? ?? 'user';
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _getRoleColor(role).withOpacity(0.1),
                    child: Text(
                      (user['name'] as String? ?? 'U').substring(0, 1).toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _getRoleColor(role),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive 
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isActive ? Icons.check_circle : Icons.cancel,
                      size: 16,
                      color: isActive 
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                user['name'] ?? 'Unknown',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                user['email'] ?? '',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getRoleColor(role).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  role.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _getRoleColor(role),
                  ),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: IconButton.outlined(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      tooltip: 'Edit',
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: IconButton.outlined(
                      onPressed: onResetPassword,
                      icon: const Icon(Icons.lock_reset_outlined, size: 16),
                      tooltip: 'Reset Password',
                      style: IconButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.tertiary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: IconButton.outlined(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 16),
                      tooltip: 'Delete',
                      style: IconButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Color _getRoleColor(String? role) {
    switch (role) {
      case 'admin':
        return const Color(0xFF6A1B9A); // Purple
      case 'supervisor':
        return const Color(0xFF8E24AA); // Light Purple
      case 'clerk':
        return const Color(0xFF0072BC); // Primary Blue
      case 'technician':
        return const Color(0xFF66A23F); // Primary Green
      case 'assistant':
        return const Color(0xFFFF9800); // Orange
      case 'customer':
        return const Color(0xFF00BCD4); // Accent Cyan
      default:
        return const Color(0xFF757575); // Grey
    }
  }
}