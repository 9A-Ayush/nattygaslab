import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/chemical_service.dart';
import 'chemical_form_dialog.dart';

class ChemicalDetailsDialog extends StatelessWidget {
  final Chemical chemical;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ChemicalDetailsDialog({
    super.key,
    required this.chemical,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final expiryStatus = chemical.expiryStatus;
    final isLowStock = chemical.isLowStock(10.0);
    
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          children: [
            // Header with chemical icon and name
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0072BC),
                    const Color(0xFF0072BC).withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Chemical Icon
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white.withOpacity(0.2),
                        ),
                        child: const Icon(
                          Icons.science,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chemical.name,
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              chemical.manufacturer,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Status indicators
                  Row(
                    children: [
                      if (isLowStock) ...[
                        _buildStatusChip(
                          'Low Stock',
                          Colors.orange,
                          Icons.warning,
                        ),
                        const SizedBox(width: 8),
                      ],
                      _buildStatusChip(
                        _getExpiryStatusText(expiryStatus),
                        _getExpiryStatusColor(expiryStatus),
                        _getExpiryStatusIcon(expiryStatus),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Details content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quantity and Unit
                    _buildDetailSection(
                      'Inventory Information',
                      [
                        _buildDetailRow(
                          'Quantity',
                          '${chemical.quantity} ${chemical.unit}',
                          Icons.inventory,
                          isLowStock ? Colors.orange : Colors.green,
                        ),
                        if (chemical.batchNo != null && chemical.batchNo!.isNotEmpty)
                          _buildDetailRow(
                            'Batch Number',
                            chemical.batchNo!,
                            Icons.qr_code,
                            Colors.blue,
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Dates
                    _buildDetailSection(
                      'Date Information',
                      [
                        if (chemical.mfgDate != null)
                          _buildDetailRow(
                            'Manufacturing Date',
                            _formatDate(chemical.mfgDate!),
                            Icons.calendar_today,
                            Colors.blue,
                          ),
                        if (chemical.expiryDate != null)
                          _buildDetailRow(
                            'Expiry Date',
                            _formatDate(chemical.expiryDate!),
                            Icons.event_busy,
                            _getExpiryStatusColor(expiryStatus),
                          ),
                      ],
                    ),
                    
                    if (chemical.description != null && chemical.description!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildDetailSection(
                        'Description',
                        [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              chemical.description!,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                height: 1.5,
                                color: Theme.of(context).textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    // Audit information
                    _buildDetailSection(
                      'Record Information',
                      [
                        if (chemical.createdAt != null)
                          _buildDetailRow(
                            'Added On',
                            _formatDateTime(chemical.createdAt!),
                            Icons.add_circle,
                            Colors.green,
                          ),
                        if (chemical.updatedAt != null)
                          _buildDetailRow(
                            'Last Updated',
                            _formatDateTime(chemical.updatedAt!),
                            Icons.update,
                            Colors.blue,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Action buttons
            Container(
              padding: const EdgeInsets.all(24),
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
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        final result = await showDialog<bool>(
                          context: context,
                          builder: (context) => ChemicalFormDialog(chemical: chemical),
                        );
                        if (result == true && onEdit != null) {
                          onEdit!();
                        }
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: const Color(0xFF0072BC)),
                        foregroundColor: const Color(0xFF0072BC),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      label: const Text('Close'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0072BC),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
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

  Widget _buildStatusChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0072BC),
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getExpiryStatusText(ExpiryStatus status) {
    switch (status) {
      case ExpiryStatus.good:
        return 'Good';
      case ExpiryStatus.nearExpiry:
        return 'Near Expiry';
      case ExpiryStatus.expired:
        return 'Expired';
      case ExpiryStatus.unknown:
        return 'Unknown';
    }
  }

  Color _getExpiryStatusColor(ExpiryStatus status) {
    switch (status) {
      case ExpiryStatus.good:
        return Colors.green;
      case ExpiryStatus.nearExpiry:
        return Colors.orange;
      case ExpiryStatus.expired:
        return Colors.red;
      case ExpiryStatus.unknown:
        return Colors.grey;
    }
  }

  IconData _getExpiryStatusIcon(ExpiryStatus status) {
    switch (status) {
      case ExpiryStatus.good:
        return Icons.check_circle;
      case ExpiryStatus.nearExpiry:
        return Icons.warning;
      case ExpiryStatus.expired:
        return Icons.error;
      case ExpiryStatus.unknown:
        return Icons.help;
    }
  }
}