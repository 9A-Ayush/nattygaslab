import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/user_service.dart';

class UserFormDialog extends StatefulWidget {
  final Map<String, dynamic>? user;
  final VoidCallback onSaved;
  
  const UserFormDialog({
    super.key,
    this.user,
    required this.onSaved,
  });
  
  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  String _selectedRole = 'clerk';
  bool _isActive = true;
  bool _sendWelcomeEmail = true;
  bool _autoGeneratePassword = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  
  final List<String> _roles = UserService.getAvailableRoles();
  
  @override
  void initState() {
    super.initState();
    
    if (widget.user != null) {
      _nameController.text = widget.user!['name'] ?? '';
      _emailController.text = widget.user!['email'] ?? '';
      _selectedRole = widget.user!['role'] ?? 'clerk';
      _isActive = widget.user!['active'] ?? true;
      _sendWelcomeEmail = false; // Don't send welcome email for existing users
      _autoGeneratePassword = false; // Don't show password field for existing users
    } else {
      _generatePassword();
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  void _generatePassword() {
    if (_autoGeneratePassword) {
      setState(() {
        _passwordController.text = UserService.generateRandomPassword(length: 12);
      });
    }
  }
  
  PasswordStrength _getPasswordStrength() {
    return UserService.checkPasswordStrength(_passwordController.text);
  }
  
  Color _getStrengthColor(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.veryWeak:
        return Colors.red[700]!;
      case PasswordStrength.weak:
        return Colors.orange[700]!;
      case PasswordStrength.medium:
        return Colors.yellow[700]!;
      case PasswordStrength.strong:
        return Colors.lightGreen[700]!;
      case PasswordStrength.veryStrong:
        return Colors.green[700]!;
    }
  }
  
  String _getStrengthText(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.veryWeak:
        return 'Very Weak';
      case PasswordStrength.weak:
        return 'Weak';
      case PasswordStrength.medium:
        return 'Medium';
      case PasswordStrength.strong:
        return 'Strong';
      case PasswordStrength.veryStrong:
        return 'Very Strong';
    }
  }
  
  double _getStrengthProgress(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.veryWeak:
        return 0.2;
      case PasswordStrength.weak:
        return 0.4;
      case PasswordStrength.medium:
        return 0.6;
      case PasswordStrength.strong:
        return 0.8;
      case PasswordStrength.veryStrong:
        return 1.0;
    }
  }
  
  Widget _buildPasswordLengthButton(int length, String label) {
    return Expanded(
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            _passwordController.text = UserService.generateRandomPassword(length: length);
          });
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8),
          side: BorderSide(color: Colors.blue.withOpacity(0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$length',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.blue[700],
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.blue[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      if (widget.user != null) {
        // Update existing user
        await UserService.updateUser(
          widget.user!['id'],
          {
            'name': _nameController.text.trim(),
            'role': _selectedRole,
            'active': _isActive,
          },
        );
        
        if (mounted) {
          Navigator.of(context).pop();
          widget.onSaved();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User "${_nameController.text}" updated successfully'),
              backgroundColor: Colors.green[600],
            ),
          );
        }
      } else {
        // Create new user
        // PRODUCTION NOTE: This should be handled by a Cloud Function for security
        await UserService.createUser(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          role: _selectedRole,
          password: _passwordController.text,
          sendWelcomeEmail: _sendWelcomeEmail,
        );
        
        if (mounted) {
          Navigator.of(context).pop();
          widget.onSaved();
          
          String message = 'User "${_nameController.text}" created successfully';
          if (_sendWelcomeEmail) {
            message += '\n📧 Welcome email sent to ${_emailController.text}';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.green[600],
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving user: $e'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final isEditing = widget.user != null;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isTablet ? 500 : screenSize.width * 0.9,
          maxHeight: screenSize.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF0072BC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit : Icons.person_add,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEditing ? 'Edit User' : 'Add New User',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic Information Section
                      Text(
                        'Basic Information',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Full Name
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Full Name *',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter full name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Email
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !isEditing, // Don't allow email changes for existing users
                        decoration: InputDecoration(
                          labelText: 'Email Address *',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          helperText: isEditing ? 'Email cannot be changed' : null,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter email address';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Role
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        decoration: InputDecoration(
                          labelText: 'Role *',
                          prefixIcon: const Icon(Icons.admin_panel_settings_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: _roles.map((role) {
                          return DropdownMenuItem(
                            value: role,
                            child: Text(
                              role.toUpperCase(),
                              style: GoogleFonts.poppins(),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedRole = value!;
                          });
                        },
                      ),
                      
                      // Status (for editing only)
                      if (isEditing) ...[
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: Text(
                            'Active Status',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            _isActive ? 'User is active' : 'User is inactive',
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                          value: _isActive,
                          onChanged: (value) {
                            setState(() {
                              _isActive = value;
                            });
                          },
                          activeColor: const Color(0xFF0072BC),
                        ),
                      ],
                      
                      // Password Section (for new users only)
                      if (!isEditing) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Password Settings',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Auto-generate password toggle
                        SwitchListTile(
                          title: Text(
                            'Auto-generate Password',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            'Generate a secure random password with mixed characters',
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                          value: _autoGeneratePassword,
                          onChanged: (value) {
                            setState(() {
                              _autoGeneratePassword = value;
                              if (value) {
                                _generatePassword();
                              } else {
                                _passwordController.clear();
                              }
                            });
                          },
                          activeColor: const Color(0xFF0072BC),
                        ),
                        
                        // Password generation options
                        if (_autoGeneratePassword) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Password Length Options:',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.blue[700],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _buildPasswordLengthButton(8, 'Basic'),
                                    const SizedBox(width: 8),
                                    _buildPasswordLengthButton(12, 'Strong'),
                                    const SizedBox(width: 8),
                                    _buildPasswordLengthButton(16, 'Ultra'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        
                        // Password field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password *',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_autoGeneratePassword)
                                  IconButton(
                                    icon: const Icon(Icons.refresh),
                                    onPressed: _generatePassword,
                                    tooltip: 'Generate new password',
                                  ),
                                IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ],
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a password';
                            }
                            if (value.length < 8) {
                              return 'Password must be at least 8 characters';
                            }
                            
                            final strength = UserService.checkPasswordStrength(value);
                            if (strength == PasswordStrength.veryWeak) {
                              return 'Password is too weak. Please use a stronger password.';
                            }
                            
                            return null;
                          },
                          onChanged: (value) {
                            setState(() {}); // Trigger rebuild to update strength indicator
                          },
                        ),
                        
                        // Password strength indicator
                        if (_passwordController.text.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final strength = _getPasswordStrength();
                              final strengthColor = _getStrengthColor(strength);
                              final strengthText = _getStrengthText(strength);
                              final progress = _getStrengthProgress(strength);
                              
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Password Strength: ',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        strengthText,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: strengthColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: Colors.grey[300],
                                    valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                        
                        const SizedBox(height: 16),
                        
                        // Send welcome email toggle
                        SwitchListTile(
                          title: Text(
                            'Send Welcome Email',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            'Send login credentials and welcome message to user\'s email address',
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                          value: _sendWelcomeEmail,
                          onChanged: (value) {
                            setState(() {
                              _sendWelcomeEmail = value;
                            });
                          },
                          activeColor: const Color(0xFF0072BC),
                        ),
                        
                        // Email info note
                        if (_sendWelcomeEmail) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.email_outlined, 
                                         color: Colors.blue[700], size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Welcome Email Contents:',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '• Login credentials (email & password)\n• Welcome message and getting started guide\n• Role information and system access details',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning_outlined, 
                                     color: Colors.orange[700], size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'User will need to be manually informed of their login credentials.',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.orange[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                      
                      // Production Note
                      if (!isEditing) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber[50],
                            border: Border.all(color: Colors.amber[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.amber[800], size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Production Note: User creation should be handled by a Cloud Function for enhanced security.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.amber[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // Action Buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0072BC),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            isEditing ? 'Update User' : 'Create User',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}