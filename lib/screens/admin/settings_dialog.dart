import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/notification_service.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  NotificationSettings? _settings;
  bool _isLoading = true;
  bool _isSaving = false;
  
  final _lowStockController = TextEditingController();
  final _expiryDaysController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _lowStockController.dispose();
    _expiryDaysController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await NotificationService.getSettings();
      setState(() {
        _settings = settings;
        _lowStockController.text = settings.lowStockThreshold.toString();
        _expiryDaysController.text = settings.expiryNotificationDays.toString();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
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
                  const Icon(Icons.settings, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Chemical Settings',
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
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildNotificationSettings(),
                          const SizedBox(height: 24),
                          _buildThresholdSettings(),
                          const SizedBox(height: 24),
                          _buildDisplaySettings(),
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
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveSettings,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isSaving ? 'Saving...' : 'Save'),
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

  Widget _buildNotificationSettings() {
    if (_settings == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notifications',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0072BC),
          ),
        ),
        const SizedBox(height: 12),
        _buildSettingTile(
          icon: Icons.inventory_2,
          title: 'Low Stock Alerts',
          subtitle: 'Get notified when chemical stock is running low',
          value: _settings!.lowStockEnabled,
          onChanged: (value) {
            setState(() {
              _settings = _settings!.copyWith(lowStockEnabled: value);
            });
          },
        ),
        const SizedBox(height: 8),
        _buildSettingTile(
          icon: Icons.event_busy,
          title: 'Expiry Notifications',
          subtitle: 'Alert before chemicals reach expiry date',
          value: _settings!.expiryEnabled,
          onChanged: (value) {
            setState(() {
              _settings = _settings!.copyWith(expiryEnabled: value);
            });
          },
        ),
      ],
    );
  }

  Widget _buildThresholdSettings() {
    if (_settings == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Alert Thresholds',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0072BC),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _lowStockController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Low Stock Threshold',
                  hintText: 'e.g., 10',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.inventory_2),
                  suffixText: 'units',
                ),
                enabled: _settings!.lowStockEnabled,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _expiryDaysController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Expiry Alert Days',
                  hintText: 'e.g., 30',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.schedule),
                  suffixText: 'days',
                ),
                enabled: _settings!.expiryEnabled,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Set how many days before expiry to show alerts',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildDisplaySettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Display Options',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0072BC),
          ),
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          icon: Icons.info_outline,
          title: 'Auto-refresh',
          description: 'Chemical data refreshes automatically every 30 seconds',
          color: Colors.blue,
        ),
        const SizedBox(height: 8),
        _buildInfoCard(
          icon: Icons.cloud_sync,
          title: 'Real-time Sync',
          description: 'Changes are synchronized across all devices instantly',
          color: Colors.green,
        ),
        const SizedBox(height: 8),
        _buildInfoCard(
          icon: Icons.security,
          title: 'Data Security',
          description: 'All data is encrypted and stored securely in the cloud',
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF0072BC).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF0072BC),
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF0072BC),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSettings() async {
    if (_settings == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Validate inputs
      final lowStockThreshold = double.tryParse(_lowStockController.text);
      final expiryDays = int.tryParse(_expiryDaysController.text);

      if (lowStockThreshold == null || lowStockThreshold < 0) {
        throw Exception('Invalid low stock threshold');
      }

      if (expiryDays == null || expiryDays < 1) {
        throw Exception('Invalid expiry notification days');
      }

      // Update settings
      final updatedSettings = _settings!.copyWith(
        lowStockThreshold: lowStockThreshold,
        expiryNotificationDays: expiryDays,
      );

      await NotificationService.saveSettings(updatedSettings);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Settings saved successfully',
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
              'Error saving settings: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}