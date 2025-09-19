import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/user_export_service.dart';

class UserExportDialog extends StatefulWidget {
  final String? currentRoleFilter;
  final String? currentStatusFilter;
  final String? currentSearchQuery;

  const UserExportDialog({
    super.key,
    this.currentRoleFilter,
    this.currentStatusFilter,
    this.currentSearchQuery,
  });

  @override
  State<UserExportDialog> createState() => _UserExportDialogState();
}

class _UserExportDialogState extends State<UserExportDialog> {
  UserExportFormat _selectedFormat = UserExportFormat.csv;
  bool _isExporting = false;
  String _customPrefix = '';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0072BC),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.download, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Export Users',
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
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current Filters Info
                    if (widget.currentRoleFilter != null && widget.currentRoleFilter != 'All' ||
                        widget.currentStatusFilter != null && widget.currentStatusFilter != 'All' ||
                        widget.currentSearchQuery != null && widget.currentSearchQuery!.isNotEmpty)
                      _buildCurrentFiltersInfo(),
                    
                    const SizedBox(height: 24),
                    
                    // Format Selection
                    Text(
                      'Export Format',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    _buildFormatOption(
                      UserExportFormat.csv,
                      'CSV (Excel Compatible)',
                      'Comma-separated values file that can be opened in Excel, Google Sheets, etc.',
                      Icons.table_chart_outlined,
                    ),
                    const SizedBox(height: 8),
                    _buildFormatOption(
                      UserExportFormat.json,
                      'JSON (Developer Friendly)',
                      'JavaScript Object Notation format for developers and data processing.',
                      Icons.code_outlined,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Custom Filename Prefix
                    Text(
                      'Filename Prefix (Optional)',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      onChanged: (value) => _customPrefix = value,
                      decoration: InputDecoration(
                        hintText: 'e.g., company_users, team_export',
                        hintStyle: GoogleFonts.poppins(fontSize: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Preview
                    _buildPreviewSection(),
                  ],
                ),
              ),
            ),
            
            // Actions
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
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

  Widget _buildCurrentFiltersInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
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
              const Icon(Icons.info_outline, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Current Filters Applied',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.currentRoleFilter != null && widget.currentRoleFilter != 'All')
            Text('• Role: ${widget.currentRoleFilter}', style: GoogleFonts.poppins(fontSize: 12)),
          if (widget.currentStatusFilter != null && widget.currentStatusFilter != 'All')
            Text('• Status: ${widget.currentStatusFilter}', style: GoogleFonts.poppins(fontSize: 12)),
          if (widget.currentSearchQuery != null && widget.currentSearchQuery!.isNotEmpty)
            Text('• Search: "${widget.currentSearchQuery}"', style: GoogleFonts.poppins(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildFormatOption(UserExportFormat format, String title, String subtitle, IconData icon) {
    final isSelected = _selectedFormat == format;
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? const Color(0xFF0072BC) : Colors.grey.withOpacity(0.3),
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: RadioListTile<UserExportFormat>(
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
      ),
    );
  }

  Widget _buildPreviewSection() {
    return Column(
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
          _getPreviewText(),
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  String _getPreviewText() {
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final prefix = _customPrefix.isNotEmpty ? '${_customPrefix}_' : '';
    final extension = _selectedFormat == UserExportFormat.csv ? 'csv' : 'json';
    
    return 'Filename: ${prefix}users_export_$dateStr.$extension';
  }

  Future<void> _exportData() async {
    setState(() {
      _isExporting = true;
    });

    try {
      final now = DateTime.now();
      final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final prefix = _customPrefix.isNotEmpty ? '${_customPrefix}_' : '';
      
      String content;
      String filename;
      String mimeType;
      
      if (_selectedFormat == UserExportFormat.csv) {
        content = await UserExportService.exportToCSV(
          roleFilter: widget.currentRoleFilter,
          statusFilter: widget.currentStatusFilter,
          searchQuery: widget.currentSearchQuery,
        );
        filename = '${prefix}users_export_$dateStr.csv';
        mimeType = 'text/csv';
      } else {
        content = await UserExportService.exportToJSON(
          roleFilter: widget.currentRoleFilter,
          statusFilter: widget.currentStatusFilter,
          searchQuery: widget.currentSearchQuery,
        );
        filename = '${prefix}users_export_$dateStr.json';
        mimeType = 'application/json';
      }

      await UserExportService.shareExportedFile(content, filename, mimeType);
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Users exported successfully!',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Export failed: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
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