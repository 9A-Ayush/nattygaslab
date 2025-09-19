import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'admin/users_screen.dart';
import 'admin/chemicals_screen.dart';
import '../services/sample_service.dart';
import '../services/cylinder_service.dart';
import '../services/report_service.dart';
import '../services/invoice_service.dart';
import '../utils/error_handler.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  final List<NavigationItem> _navigationItems = [
    NavigationItem(
      icon: Icons.dashboard,
      label: 'Dashboard',
      route: '/admin-dashboard',
    ),
    NavigationItem(
      icon: Icons.people,
      label: 'Users',
      route: '/users',
    ),
    NavigationItem(
      icon: Icons.science_outlined,
      label: 'Samples',
      route: '/samples',
    ),
    NavigationItem(
      icon: Icons.propane_tank_outlined,
      label: 'Cylinders',
      route: '/cylinders',
    ),
    NavigationItem(
      icon: Icons.science,
      label: 'Chemicals',
      route: '/chemicals',
    ),
    NavigationItem(
      icon: Icons.description,
      label: 'Reports',
      route: '/reports',
    ),
    NavigationItem(
      icon: Icons.receipt,
      label: 'Invoices',
      route: '/invoices',
    ),
    NavigationItem(
      icon: Icons.settings,
      label: 'Settings',
      route: '/settings',
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reset to dashboard when returning from other screens
    _selectedIndex = 0;
  }

  void _onNavigationTap(int index) {
    if (index == 0) {
      // Already on dashboard, just update selection
      setState(() {
        _selectedIndex = 0;
      });
      return;
    }
    
    // Navigate to other screens and reset selection when returning
    final route = _navigationItems[index].route;
    
    // Use proper navigation instead of named routes
    Widget? screen;
    switch (route) {
      case '/users':
        screen = const UsersScreen();
        break;
      case '/chemicals':
        screen = const ChemicalsScreen();
        break;
      default:
        // For placeholder screens, use named routes temporarily
        Navigator.of(context).pushNamed(route).then((_) {
          if (mounted) {
            setState(() {
              _selectedIndex = 0;
            });
          }
        });
        return;
    }
    
    if (screen != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => screen!),
      ).then((_) {
        // Reset to dashboard when returning
        if (mounted) {
          setState(() {
            _selectedIndex = 0;
          });
        }
      });
    }
  }

  Future<void> _handleLogout() async {
    try {
      await AuthService.signOut();
      // AuthWrapper will handle navigation automatically
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: ${e.toString()}'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Logout',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _handleLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Logout',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final user = FirebaseAuth.instance.currentUser;

    if (isTablet) {
      return _buildTabletLayout(user);
    } else {
      return _buildMobileLayout(user);
    }
  }

  Widget _buildMobileLayout(User? user) {
    return Scaffold(
      appBar: _buildAppBar(user, false),
      body: const DashboardBody(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.2),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: 60,
              maxHeight: MediaQuery.of(context).size.height * 0.1,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Main navigation items (first 4)
                  ..._navigationItems.take(4).map((item) {
                    final index = _navigationItems.indexOf(item);
                    final isSelected = index == _selectedIndex;
                    
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => _onNavigationTap(index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? const Color(0xFF0072BC).withOpacity(0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  item.icon,
                                  color: isSelected 
                                      ? const Color(0xFF0072BC)
                                      : Theme.of(context).iconTheme.color?.withOpacity(0.7),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Flexible(
                                child: Text(
                                  item.label,
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                    color: isSelected 
                                        ? const Color(0xFF0072BC)
                                        : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  // More menu for remaining items
                  Expanded(
                    child: PopupMenuButton<int>(
                      onSelected: (index) => _onNavigationTap(index),
                      itemBuilder: (context) => _navigationItems.skip(4).map((item) {
                        final index = _navigationItems.indexOf(item);
                        return PopupMenuItem<int>(
                          value: index,
                          child: Row(
                            children: [
                              Icon(
                                item.icon, 
                                size: 20,
                                color: Theme.of(context).iconTheme.color,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                item.label,
                                style: GoogleFonts.poppins(
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.more_horiz,
                                color: Theme.of(context).iconTheme.color?.withOpacity(0.7),
                                size: 20,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Flexible(
                              child: Text(
                                'More',
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w400,
                                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Navigate to Add Sample screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add Sample - Coming Soon')),
          );
        },
        backgroundColor: const Color(0xFF0072BC),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTabletLayout(User? user) {
    return Scaffold(
      appBar: _buildAppBar(user, true),
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 250,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    itemCount: _navigationItems.length,
                    itemBuilder: (context, index) {
                      final item = _navigationItems[index];
                      final isSelected = index == _selectedIndex;
                      
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          leading: Icon(
                            item.icon,
                            color: isSelected 
                                ? const Color(0xFF0072BC) 
                                : Theme.of(context).iconTheme.color,
                          ),
                          title: Text(
                            item.label,
                            style: GoogleFonts.poppins(
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected 
                                  ? const Color(0xFF0072BC) 
                                  : Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                          ),
                          selected: isSelected,
                          selectedTileColor: const Color(0xFF0072BC).withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onTap: () => _onNavigationTap(index),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: Column(
              children: [
                const Expanded(child: DashboardBody()),
                // Action Buttons Row
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Generate Invoice functionality
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Generate Invoice - Coming Soon')),
                          );
                        },
                        icon: const Icon(Icons.receipt_long),
                        label: Text(
                          'Generate Invoice',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF66A23F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 16),
                      FloatingActionButton.extended(
                        onPressed: () {
                          // TODO: Navigate to Add Sample screen
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Add Sample - Coming Soon')),
                          );
                        },
                        backgroundColor: const Color(0xFF0072BC),
                        foregroundColor: Colors.white,
                        icon: const Icon(Icons.add),
                        label: Text(
                          'Add Sample',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(User? user, bool isTablet) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: isDarkMode 
          ? Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).colorScheme.surface
          : const Color(0xFF0072BC),
      elevation: 0,
      systemOverlayStyle: isDarkMode ? null : const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF0072BC),
        statusBarIconBrightness: Brightness.light,
      ),
      title: Row(
        children: [
          // Logo
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/logo.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.science,
                      size: 20,
                      color: isDarkMode 
                          ? Theme.of(context).colorScheme.onSurface
                          : Colors.white,
                    ),
                  );
                },
              ),
            ),
          ),
          // Title
          Text(
            'Admin Dashboard',
            style: GoogleFonts.poppins(
              fontSize: isTablet ? 22 : 20,
              fontWeight: FontWeight.w600,
              color: isDarkMode 
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.white,
            ),
          ),
        ],
      ),
      actions: [
        // Profile Avatar
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: isDarkMode 
                ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                : Colors.white.withOpacity(0.2),
            child: Text(
              user?.email?.substring(0, 1).toUpperCase() ?? 'A',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: isDarkMode 
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.white,
              ),
            ),
          ),
        ),
        // Logout Button
        IconButton(
          onPressed: _showLogoutDialog,
          icon: Icon(
            Icons.logout,
            color: isDarkMode 
                ? Theme.of(context).colorScheme.onSurface
                : Colors.white,
          ),
          tooltip: 'Logout',
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class DashboardBody extends StatefulWidget {
  const DashboardBody({super.key});

  @override
  State<DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<DashboardBody> {
  Map<String, int> _sampleCounts = {};
  Map<String, int> _cylinderCounts = {};
  Map<String, int> _reportCounts = {};
  Map<String, int> _invoiceCounts = {};
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void dispose() {
    // Clear any pending operations
    _sampleCounts.clear();
    _cylinderCounts.clear();
    _reportCounts.clear();
    _invoiceCounts.clear();
    super.dispose();
  }
  
  Future<void> _loadDashboardData() async {
    try {
      final results = await Future.wait([
        SampleService.getSampleStatusCounts(),
        CylinderService.getCylinderStatusCounts(),
        ReportService.getReportStatusCounts(),
        InvoiceService.getInvoiceStatusCounts(),
      ]);
      
      if (mounted) {
        setState(() {
          _sampleCounts = results[0];
          _cylinderCounts = results[1];
          _reportCounts = results[2];
          _invoiceCounts = results[3];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ErrorHandler.showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    // Calculate metrics from real data
    final totalSamples = _sampleCounts.values.fold(0, (sum, count) => sum + count);
    final activeCylinders = (_cylinderCounts['in_use'] ?? 0) + (_cylinderCounts['checked_out'] ?? 0);
    final pendingReports = _reportCounts['pending_review'] ?? 0;
    final thisMonthInvoices = _invoiceCounts['sent'] ?? 0;
    
    final List<DashboardMetric> metrics = [
      DashboardMetric(
        title: 'Total Samples',
        count: totalSamples,
        icon: Icons.science_outlined,
        color: const Color(0xFF0072BC), // Primary Blue
        route: '/samples',
      ),
      DashboardMetric(
        title: 'Active Cylinders',
        count: activeCylinders,
        icon: Icons.propane_tank_outlined,
        color: const Color(0xFF66A23F), // Primary Green
        route: '/cylinders',
      ),
      DashboardMetric(
        title: 'Pending Reports',
        count: pendingReports,
        icon: Icons.pending_actions,
        color: const Color(0xFF00BCD4), // Accent Cyan
        route: '/reports',
      ),
      DashboardMetric(
        title: 'Recent Invoices',
        count: thisMonthInvoices,
        icon: Icons.receipt_long_outlined,
        color: const Color(0xFF0072BC), // Primary Blue
        route: '/invoices',
      ),
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.all(isTablet ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section
          Text(
            'Welcome to NattyGas Lab',
            style: GoogleFonts.poppins(
              fontSize: isTablet ? 28 : 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.headlineLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Laboratory Information Management System',
            style: GoogleFonts.poppins(
              fontSize: isTablet ? 16 : 14,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 32),
          
          // Metrics Grid
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount;
              if (constraints.maxWidth > 1200) {
                crossAxisCount = 4;
              } else if (constraints.maxWidth > 800) {
                crossAxisCount = 3;
              } else if (constraints.maxWidth > 600) {
                crossAxisCount = 2;
              } else {
                crossAxisCount = 1;
              }
              
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: isTablet ? 1.5 : 1.3,
                ),
                itemCount: metrics.length,
                itemBuilder: (context, index) {
                  return DashboardCard(metric: metrics[index]);
                },
              );
            },
          ),
          
          const SizedBox(height: 32),
          
          // Recent Activity Section (placeholder)
          Text(
            'Recent Activity',
            style: GoogleFonts.poppins(
              fontSize: isTablet ? 20 : 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.headlineSmall?.color,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.timeline,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Activity Timeline',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Recent samples, reports, and system activities will appear here.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardCard extends StatelessWidget {
  final DashboardMetric metric;

  const DashboardCard({super.key, required this.metric});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to detailed screen
          Navigator.of(context).pushNamed(metric.route);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: metric.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      metric.icon,
                      color: metric.color,
                      size: 24,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Theme.of(context).iconTheme.color?.withOpacity(0.5),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                metric.count.toString(),
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: metric.color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                metric.title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final String label;
  final String route;

  NavigationItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}

class DashboardMetric {
  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final String route;

  DashboardMetric({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.route,
  });
}