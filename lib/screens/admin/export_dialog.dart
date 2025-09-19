import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/export_service.dart';
import '../../utils/error_handler.dart';

class ExportDialog extends StatefulWidget {
  final String? currentManufacturerFilter;
  final String? currentStatusFilter;
  final String? currentSearchQuery;

  const ExportDialog({
    super.key,
    this.currentManufacturerFilter,
    this.currentStatusFilter,
    this.currentSearchQuery,
  });

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  ExportFormat _selectedFormat = ExportFormat.csv;
  bool _includeCurrentFilters = true;
  bool _isExporting = false;
  final _prefixController = TextEditingController();

  @override
  void dispose() {
    _prefixController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF0072BC),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.download, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Export Chemicals',
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
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Format Selection
                    Text(
                      'Export Format',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0072BC),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFormatOptions(),
                    const SizedBox(height: 24),
                    
                    // Filter Options
                    Text(
                      'Export Options',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0072BC),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFilterOptions(),
                    const SizedBox(height: 24),
                    
                    // Custom Prefix
                    Text(
                      'File Prefix (Optional)',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0072BC),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _prefixController,
                      decoration: InputDecoration(
                        hintText: 'e.g., lab_inventory',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.label_outline),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Preview
                    _buildPreview(),
                  ],
                ),
              ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isExporting ? null : _exportData,
                      icon: _isExporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download),
                      label: Text(_isExporting ? 'Exporting...' : 'Export'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0072BC),
                        foregroundColor: Colors.white,
                      ),
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

  Widget _buildFormatOptions() {
    return Column(
      children: [
        _buildFormatTile(
          format: ExportFormat.csv,
          title: 'CSV (Comma Separated Values)',
          subtitle: 'Compatible with Excel, Google Sheets',
          icon: Icons.table_chart,
        ),
        const SizedBox(height: 8),
        _buildFormatTile(
          format: ExportFormat.json,
          title: 'JSON (JavaScript Object Notation)',
          subtitle: 'For developers and data processing',
          icon: Icons.code,
        ),
      ],
    );
  }

  Widget _buildFormatTile({
    required ExportFormat format,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedFormat == format;
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? const Color(0xFF0072BC) : Colors.grey.withOpacity(0.3),
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
        color: isSelected ? const Color(0xFF0072BC).withOpacity(0.05) : null,
      ),
      child: RadioListTile<ExportFormat>(
        value: format,
        groupValue: _selectedFormat,
        onChanged: (value) {
          setState(() {
            _selectedFormat = value!;
          });
        },
        title: Row(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF0072BC) : Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  color: isSelected ? const Color(0xFF0072BC) : null,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(fontSize: 12),
        ),
        activeColor: const Color(0xFF0072BC),
      ),
    );
  }

  Widget _buildFilterOptions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            value: _includeCurrentFilters,
            onChanged: (value) {
              setState(() {
                _includeCurrentFilters = value;
              });
            },
            title: Text(
              'Use Current Filters',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'Export only chemicals matching current search and filters',
              style: GoogleFonts.poppins(fontSize: 12),
            ),
            activeColor: const Color(0xFF0072BC),
          ),
          if (_includeCurrentFilters && _hasActiveFilters()) ...[
            const Divider(),
            Text(
              'Active Filters:',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            ..._buildActiveFilterChips(),
          ],
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final filename = ExportService.generateFilename(
      _selectedFormat.name,
      prefix: _prefixController.text.trim().isEmpty ? null : _prefixController.text.trim(),
    );
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.preview, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Preview',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Filename: $filename',
            style: GoogleFonts.poppins(fontSize: 12),
          ),
          Text(
            'Format: ${_selectedFormat.name.toUpperCase()}',
            style: GoogleFonts.poppins(fontSize: 12),
          ),
          Text(
            'Filters: ${_includeCurrentFilters && _hasActiveFilters() ? "Applied" : "None"}',
            style: GoogleFonts.poppins(fontSize: 12),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActiveFilterChips() {
    final chips = <Widget>[];
    
    if (widget.currentManufacturerFilter != null && widget.currentManufacturerFilter != 'All') {
      chips.add(_buildFilterChip('Manufacturer: ${widget.currentManufacturerFilter}'));
    }
    
    if (widget.currentStatusFilter != null && widget.currentStatusFilter != 'All') {
      chips.add(_buildFilterChip('Status: ${widget.currentStatusFilter}'));
    }
    
    if (widget.currentSearchQuery != null && widget.currentSearchQuery!.isNotEmpty) {
      chips.add(_buildFilterChip('Search: "${widget.currentSearchQuery}"'));
    }
    
    return chips;
  }

  Widget _buildFilterChip(String label) {
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0072BC).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0072BC).withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          color: const Color(0xFF0072BC),
        ),
      ),
    );
  }

  bool _hasActiveFilters() {
    return (widget.currentManufacturerFilter != null && widget.currentManufacturerFilter != 'All') ||
           (widget.currentStatusFilter != null && widget.currentStatusFilter != 'All') ||
           (widget.currentSearchQuery != null && widget.currentSearchQuery!.isNotEmpty);
  }

  Future<void> _exportData() async {
    setState(() {
      _isExporting = true;
    });

    try {
      final options = ExportOptions(
        format: _selectedFormat,
        manufacturerFilter: _includeCurrentFilters ? widget.currentManufacturerFilter : null,
        statusFilter: _includeCurrentFilters ? widget.currentStatusFilter : null,
        searchQuery: _includeCurrentFilters ? widget.currentSearchQuery : null,
        customPrefix: _prefixController.text.trim().isEmpty ? null : _prefixController.text.trim(),
      );

      String content;
      String mimeType;
      
      switch (_selectedFormat) {
        case ExportFormat.csv:
          content = await ExportService.exportToCSV(
            manufacturerFilter: options.manufacturerFilter,
            statusFilter: options.statusFilter,
            searchQuery: options.searchQuery,
          );
          mimeType = 'text/csv';
          break;
        case ExportFormat.json:
          content = await ExportService.exportToJSON(
            manufacturerFilter: options.manufacturerFilter,
            statusFilter: options.statusFilter,
            searchQuery: options.searchQuery,
          );
          mimeType = 'application/json';
          break;
      }

      final filename = ExportService.generateFilename(
        _selectedFormat.name,
        prefix: options.customPrefix,
      );

      await ExportService.saveAndShareExport(
        content: content,
        filename: filename,
        mimeType: mimeType,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Export completed successfully',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, 'Export failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }
}