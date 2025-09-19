import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/chemical_service.dart';
import '../../services/notification_service.dart';
import '../../utils/error_handler.dart';
import 'chemical_form_dialog.dart';
import 'chemical_details_dialog.dart';
import 'notifications_dialog.dart';
import 'export_dialog.dart';

import 'settings_dialog.dart';
import 'dart:async';

class ChemicalsScreen extends StatefulWidget {
  const ChemicalsScreen({super.key});

  @override
  State<ChemicalsScreen> createState() => _ChemicalsScreenState();
}

class _ChemicalsScreenState extends State<ChemicalsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  String _searchQuery = '';
  String _selectedManufacturer = 'All';
  String _selectedStatus = 'All';
  List<String> _manufacturers = [];
  Timer? _debounceTimer;
  
  // Pagination
  DocumentSnapshot? _lastDocument;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  bool _isInitialLoading = true;
  
  // Notifications
  int _notificationCount = 0;
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    _loadManufacturers();
    _setupScrollListener();
    _setupSearchListener();
    _loadNotificationCount();
    _setupNotificationTimer();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    _notificationTimer?.cancel();
    super.dispose();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent - 200) {
        _loadMoreChemicals();
      }
    });
  }

  void _setupSearchListener() {
    _searchController.addListener(() {
      if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        if (_searchController.text != _searchQuery) {
          setState(() {
            _searchQuery = _searchController.text;
            _lastDocument = null;
            _hasMoreData = true;
          });
        }
      });
    });
  }

  Future<void> _loadManufacturers() async {
    try {
      final manufacturers = await ChemicalService.getManufacturers();
      setState(() {
        _manufacturers = manufacturers;
        _isInitialLoading = false;
      });
    } catch (e) {
      setState(() {
        _isInitialLoading = false;
      });
      if (mounted) {
        ErrorHandler.showError(context, 'Failed to load manufacturers: $e');
      }
    }
  }

  Future<void> _loadMoreChemicals() async {
    if (_isLoadingMore || !_hasMoreData) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    // This would be implemented with the stream builder
    // Just updating the loading state for now
    await Future.delayed(const Duration(milliseconds: 500));
    
    setState(() {
      _isLoadingMore = false;
    });
  }

  void _onSearchChanged(String query) {
    // This is handled by the listener in _setupSearchListener
  }

  Future<void> _showAddChemicalDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const ChemicalFormDialog(),
    );
    
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Chemical added successfully',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  Future<void> _showEditChemicalDialog(Chemical chemical) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ChemicalFormDialog(chemical: chemical),
    );
    
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Chemical updated successfully',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  Future<void> _showChemicalDetailsDialog(Chemical chemical) async {
    await showDialog(
      context: context,
      builder: (context) => ChemicalDetailsDialog(
        chemical: chemical,
        onEdit: () {
          // Refresh will happen automatically via StreamBuilder
        },
      ),
    );
  }

  void _setupNotificationTimer() {
    _notificationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadNotificationCount();
    });
  }

  Future<void> _loadNotificationCount() async {
    try {
      final count = await NotificationService.getNotificationCount();
      if (mounted) {
        setState(() {
          _notificationCount = count;
        });
      }
    } catch (e) {
      // Silently handle notification count errors
    }
  }

  Future<void> _showNotificationsDialog() async {
    await showDialog(
      context: context,
      builder: (context) => const NotificationsDialog(),
    );
    // Refresh notification count after viewing
    _loadNotificationCount();
  }

  Future<void> _deleteChemical(Chemical chemical) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Chemical',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete "${chemical.name}"? This action cannot be undone.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text('Delete', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ChemicalService.deleteChemical(chemical.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Chemical deleted successfully',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ErrorHandler.showError(context, 'Failed to delete chemical: $e');
        }
      }
    }
  }

  void _showManufacturerFilter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter by Manufacturer',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['All', ..._manufacturers].map((manufacturer) {
                return FilterChip(
                  label: Text(
                    manufacturer == 'All' ? 'All Manufacturers' : manufacturer,
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  selected: _selectedManufacturer == manufacturer,
                  onSelected: (selected) {
                    setState(() {
                      _selectedManufacturer = manufacturer;
                      _lastDocument = null;
                      _hasMoreData = true;
                    });
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
    final statuses = ['All', 'Good', 'Expired', 'Near Expiry', 'Low Stock'];
    
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
                      _lastDocument = null;
                      _hasMoreData = true;
                    });
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

  Future<void> _exportChemicals() async {
    await showDialog(
      context: context,
      builder: (context) => ExportDialog(
        currentManufacturerFilter: _selectedManufacturer,
        currentStatusFilter: _selectedStatus,
        currentSearchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      ),
    );
  }



  void _showImageDialog(Chemical chemical) {
    if (chemical.imageUrl == null) return;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(
                chemical.name,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Flexible(
              child: Image.network(
                chemical.imageUrl!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Failed to load image',
                            style: GoogleFonts.poppins(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }



  Future<void> _showSettingsDialog() async {
    await showDialog(
      context: context,
      builder: (context) => const SettingsDialog(),
    );
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
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back_outlined),
        tooltip: 'Back to Dashboard',
      ),
      title: Text(
        'Chemicals Management',
        style: GoogleFonts.poppins(
          fontSize: isTablet ? 22 : 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        // Notification Button
        Stack(
          children: [
            IconButton(
              onPressed: _showNotificationsDialog,
              icon: Icon(
                Icons.notifications_outlined,
                color: isDarkMode ? Colors.white : Colors.white,
              ),
              tooltip: 'Notifications',
            ),
            if (_notificationCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: NotificationService.buildNotificationBadge(_notificationCount),
              ),
          ],
        ),
        IconButton(
          onPressed: _showAddChemicalDialog,
          icon: const Icon(Icons.add_outlined),
          tooltip: 'Add Chemical',
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'export':
                _exportChemicals();
                break;
              case 'settings':
                _showSettingsDialog();
                break;
              case 'refresh':
                _loadManufacturers();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  const Icon(Icons.download_outlined, size: 20),
                  const SizedBox(width: 8),
                  Text('Export Data', style: GoogleFonts.poppins()),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  const Icon(Icons.settings_outlined, size: 20),
                  const SizedBox(width: 8),
                  Text('Settings', style: GoogleFonts.poppins()),
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
            hintText: 'Search chemicals by name or manufacturer...',
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
                        _onSearchChanged('');
                      },
                      icon: const Icon(Icons.clear),
                    ),
                  ]
                : null,
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 16),
          // Filter Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Manufacturer Filter
              _buildFilterChip(
                context,
                'Manufacturer: $_selectedManufacturer',
                _selectedManufacturer != 'All',
                () => _showManufacturerFilter(context),
              ),
              // Status Filter
              _buildFilterChip(
                context,
                'Status: $_selectedStatus',
                _selectedStatus != 'All',
                () => _showStatusFilter(context),
              ),
              // Clear Filters
              if (_selectedManufacturer != 'All' || _selectedStatus != 'All')
                ActionChip(
                  label: Text(
                    'Clear Filters',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedManufacturer = 'All';
                      _selectedStatus = 'All';
                    });
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
      onPressed: _showAddChemicalDialog,
      backgroundColor: const Color(0xFF0072BC),
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add_outlined),
      label: Text(
        'Add Chemical',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool isTablet, bool isDesktop) {
    // Use different streams based on filter to avoid complex index requirements
    final Stream<QuerySnapshot> stream = _selectedStatus == 'Expired'
        ? ChemicalService.getExpiredChemicalsStream()
        : ChemicalService.getChemicals(
            searchQuery: _searchController.text.trim().isEmpty 
                ? null 
                : _searchController.text.trim(),
            manufacturerFilter: _selectedManufacturer == 'All' ? null : _selectedManufacturer,
          );
    
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(context);
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingSkeleton(context, isTablet);
        }

        final docs = snapshot.data?.docs ?? [];
        
        // Apply low stock filter if needed
        final filteredDocs = _selectedStatus == 'Low Stock' 
            ? docs.where((doc) {
                final chemical = Chemical.fromFirestore(doc);
                return chemical.isLowStock(10.0);
              }).toList()
            : docs;
        
        if (filteredDocs.isEmpty) {
          return _buildEmptyState(context);
        }

        if (isDesktop) {
          return _buildDataTable(context, filteredDocs);
        } else if (isTablet) {
          return _buildGridView(context, filteredDocs);
        } else {
          return _buildChemicalsList(context, filteredDocs);
        }
      },
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context, bool isTablet) {
    return GridView.builder(
      padding: EdgeInsets.all(isTablet ? 24 : 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isTablet ? 2 : 1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: isTablet ? 1.2 : 2.5,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 12),
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
                            width: 120,
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
              'Error loading chemicals',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your connection and try again',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => setState(() {}),
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
              Icons.science_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No chemicals found',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isNotEmpty || _selectedManufacturer != 'All' || _selectedStatus != 'All'
                  ? 'Try adjusting your search or filters'
                  : 'Add your first chemical to get started',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _showAddChemicalDialog,
              icon: const Icon(Icons.add_outlined),
              label: Text('Add Chemical', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChemicalsList(BuildContext context, List<QueryDocumentSnapshot> docs) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: docs.length,
      physics: const AlwaysScrollableScrollPhysics(),
      cacheExtent: 200, // Improve scrolling performance
      itemBuilder: (context, index) {
        final chemical = Chemical.fromFirestore(docs[index]);
        return ChemicalListCard(
          key: ValueKey(chemical.id), // Add key for better performance
          chemical: chemical,
          onTap: () => _showChemicalDetailsDialog(chemical),
          onEdit: () => _showEditChemicalDialog(chemical),
          onDelete: () => _deleteChemical(chemical),
          onImageTap: () => _showImageDialog(chemical),
        );
      },
    );
  }

  Widget _buildGridView(BuildContext context, List<QueryDocumentSnapshot> docs) {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      cacheExtent: 200, // Improve scrolling performance
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final chemical = Chemical.fromFirestore(docs[index]);
        return ChemicalGridCard(
          key: ValueKey(chemical.id), // Add key for better performance
          chemical: chemical,
          onTap: () => _showChemicalDetailsDialog(chemical),
          onEdit: () => _showEditChemicalDialog(chemical),
          onDelete: () => _deleteChemical(chemical),
          onImageTap: () => _showImageDialog(chemical),
        );
      },
    );
  }

  Widget _buildDataTable(BuildContext context, List<QueryDocumentSnapshot> docs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
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
                  'Chemical',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
              DataColumn(
                label: Text(
                  'Manufacturer',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
              DataColumn(
                label: Text(
                  'Quantity',
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
                  'Expiry',
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
            rows: docs.map((doc) {
              final chemical = Chemical.fromFirestore(doc);
              final expiryStatus = chemical.expiryStatus;
              final isLowStock = chemical.isLowStock(10.0);
              
              return DataRow(
                cells: [
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Theme.of(context).colorScheme.primaryContainer,
                          ),
                          child: chemical.imageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    chemical.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        Icons.science_outlined,
                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                      );
                                    },
                                  ),
                                )
                              : Icon(
                                  Icons.science_outlined,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          chemical.name,
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(
                      chemical.manufacturer,
                      style: GoogleFonts.poppins(),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isLowStock 
                            ? Theme.of(context).colorScheme.errorContainer
                            : Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${chemical.quantity} ${chemical.unit}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isLowStock 
                              ? Theme.of(context).colorScheme.onErrorContainer
                              : Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(expiryStatus, isLowStock, context).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getStatusText(expiryStatus, isLowStock),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(expiryStatus, isLowStock, context),
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      chemical.expiryDate != null 
                          ? _formatDate(chemical.expiryDate!.toDate())
                          : 'N/A',
                      style: GoogleFonts.poppins(),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _showEditChemicalDialog(chemical),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          onPressed: () => _deleteChemical(chemical),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          tooltip: 'Delete',
                          style: IconButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.error,
                          ),
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

  Color _getStatusColor(ExpiryStatus expiryStatus, bool isLowStock, BuildContext context) {
    if (isLowStock) return Theme.of(context).colorScheme.error;
    
    switch (expiryStatus) {
      case ExpiryStatus.expired:
        return Theme.of(context).colorScheme.error;
      case ExpiryStatus.nearExpiry:
        return Theme.of(context).colorScheme.tertiary;
      case ExpiryStatus.good:
        return const Color(0xFF66A23F); // Primary Green
      default:
        return Theme.of(context).colorScheme.outline;
    }
  }

  String _getStatusText(ExpiryStatus expiryStatus, bool isLowStock) {
    if (isLowStock) return 'Low Stock';
    
    switch (expiryStatus) {
      case ExpiryStatus.expired:
        return 'Expired';
      case ExpiryStatus.nearExpiry:
        return 'Expires Soon';
      case ExpiryStatus.good:
        return 'Good';
      default:
        return 'Unknown';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// Chemical List Card for Mobile View
class ChemicalListCard extends StatelessWidget {
  final Chemical chemical;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onImageTap;

  const ChemicalListCard({
    super.key,
    required this.chemical,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    final expiryStatus = chemical.expiryStatus;
    final isLowStock = chemical.isLowStock(10.0);
    final statusColor = _getStatusColor(expiryStatus, isLowStock);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Row
                Row(
                  children: [
                    // Chemical Icon
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0072BC).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.science,
                        color: Color(0xFF0072BC),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Chemical Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            chemical.name,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            chemical.manufacturer,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Icon(
                        _getStatusIcon(expiryStatus, isLowStock),
                        size: 14,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Info Row
                Row(
                  children: [
                    Expanded(
                      child: _buildCompactInfo(
                        'Quantity',
                        '${chemical.quantity} ${chemical.unit}',
                        Icons.inventory_2_outlined,
                        isLowStock ? Colors.orange : const Color(0xFF0072BC),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (chemical.expiryDate != null)
                      Expanded(
                        child: _buildCompactInfo(
                          'Expiry',
                          _formatDate(chemical.expiryDate!.toDate()),
                          Icons.event_busy,
                          statusColor,
                        ),
                      ),
                    if (chemical.batchNo != null && chemical.batchNo!.isNotEmpty)
                      Expanded(
                        child: _buildCompactInfo(
                          'Batch',
                          chemical.batchNo!,
                          Icons.qr_code,
                          Colors.green,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Action Row
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit, size: 16),
                        label: Text(
                          'Edit',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          side: const BorderSide(color: Color(0xFF0072BC)),
                          foregroundColor: const Color(0xFF0072BC),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline, size: 16),
                        color: Colors.red,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactInfo(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ExpiryStatus expiryStatus, bool isLowStock) {
    if (isLowStock) return Colors.orange;
    
    switch (expiryStatus) {
      case ExpiryStatus.expired:
        return Colors.red;
      case ExpiryStatus.nearExpiry:
        return Colors.orange;
      case ExpiryStatus.good:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(ExpiryStatus expiryStatus, bool isLowStock) {
    if (isLowStock) return Icons.warning;
    
    switch (expiryStatus) {
      case ExpiryStatus.expired:
        return Icons.error;
      case ExpiryStatus.nearExpiry:
        return Icons.schedule;
      case ExpiryStatus.good:
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// Chemical Grid Card for Tablet View - Optimized
class ChemicalGridCard extends StatelessWidget {
  final Chemical chemical;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onImageTap;

  const ChemicalGridCard({
    super.key,
    required this.chemical,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    final expiryStatus = chemical.expiryStatus;
    final isLowStock = chemical.isLowStock(10.0);
    final statusColor = _getStatusColor(expiryStatus, isLowStock);
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Chemical Icon with Status
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0072BC).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.science,
                        color: Color(0xFF0072BC),
                        size: 36,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getStatusIcon(expiryStatus, isLowStock),
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Chemical Name
                Text(
                  chemical.name,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Manufacturer
                Text(
                  chemical.manufacturer,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // Quantity Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLowStock ? Colors.orange.withOpacity(0.1) : const Color(0xFF0072BC).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isLowStock ? Colors.orange.withOpacity(0.3) : const Color(0xFF0072BC).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    '${chemical.quantity} ${chemical.unit}',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isLowStock ? Colors.orange : const Color(0xFF0072BC),
                    ),
                  ),
                ),
                const Spacer(),
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onEdit,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          side: const BorderSide(color: Color(0xFF0072BC)),
                          foregroundColor: const Color(0xFF0072BC),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Icon(Icons.edit, size: 14),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: IconButton(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline, size: 14),
                        color: Colors.red,
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(ExpiryStatus expiryStatus, bool isLowStock) {
    if (isLowStock) return Colors.orange;
    
    switch (expiryStatus) {
      case ExpiryStatus.expired:
        return Colors.red;
      case ExpiryStatus.nearExpiry:
        return Colors.orange;
      case ExpiryStatus.good:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(ExpiryStatus expiryStatus, bool isLowStock) {
    if (isLowStock) return Icons.warning;
    
    switch (expiryStatus) {
      case ExpiryStatus.expired:
        return Icons.error;
      case ExpiryStatus.nearExpiry:
        return Icons.schedule;
      case ExpiryStatus.good:
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }
}