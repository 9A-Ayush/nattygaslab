import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/chemical_service.dart';
import '../../utils/error_handler.dart';

class ChemicalFormDialog extends StatefulWidget {
  final Chemical? chemical;

  const ChemicalFormDialog({super.key, this.chemical});

  @override
  State<ChemicalFormDialog> createState() => _ChemicalFormDialogState();
}

class _ChemicalFormDialogState extends State<ChemicalFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _manufacturerController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitController = TextEditingController();
  final _batchNoController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  DateTime? _mfgDate;
  DateTime? _expiryDate;
  bool _isLoading = false;

  final List<String> _commonUnits = [
    'kg', 'g', 'mg', 'L', 'mL', 'pcs', 'bottles', 'boxes'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.chemical != null) {
      _populateFields();
    }
  }

  void _populateFields() {
    final chemical = widget.chemical!;
    _nameController.text = chemical.name;
    _manufacturerController.text = chemical.manufacturer;
    _quantityController.text = chemical.quantity.toString();
    _unitController.text = chemical.unit;
    _batchNoController.text = chemical.batchNo ?? '';
    _descriptionController.text = chemical.description ?? '';
    _mfgDate = chemical.mfgDate?.toDate();
    _expiryDate = chemical.expiryDate?.toDate();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _manufacturerController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _batchNoController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isMfgDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isMfgDate 
          ? (_mfgDate ?? DateTime.now()) 
          : (_expiryDate ?? DateTime.now().add(const Duration(days: 365))),
      firstDate: DateTime(2000),
      lastDate: DateTime(2030),
    );
    
    if (picked != null) {
      setState(() {
        if (isMfgDate) {
          _mfgDate = picked;
        } else {
          _expiryDate = picked;
        }
      });
    }
  }

  Future<void> _saveChemical() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final chemicalData = {
        'name': _nameController.text.trim(),
        'manufacturer': _manufacturerController.text.trim(),
        'quantity': double.parse(_quantityController.text.trim()),
        'unit': _unitController.text.trim(),
        'batchNo': _batchNoController.text.trim().isEmpty 
            ? null 
            : _batchNoController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        'mfgDate': _mfgDate != null ? Timestamp.fromDate(_mfgDate!) : null,
        'expiryDate': _expiryDate != null ? Timestamp.fromDate(_expiryDate!) : null,
      };

      if (widget.chemical == null) {
        // Add new chemical
        await ChemicalService.addChemical(chemicalData);
      } else {
        // Update existing chemical
        await ChemicalService.updateChemical(widget.chemical!.id, chemicalData);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, 'Failed to save chemical: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
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
                  Icon(
                    widget.chemical == null ? Icons.add : Icons.edit,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.chemical == null ? 'Add Chemical' : 'Edit Chemical',
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
                      // Chemical Name
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Chemical Name *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter chemical name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Manufacturer
                      TextFormField(
                        controller: _manufacturerController,
                        decoration: InputDecoration(
                          labelText: 'Manufacturer *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter manufacturer';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Quantity and Unit Row
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _quantityController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Quantity *',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter quantity';
                                }
                                if (double.tryParse(value.trim()) == null) {
                                  return 'Please enter valid number';
                                }
                                if (double.parse(value.trim()) < 0) {
                                  return 'Quantity cannot be negative';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: DropdownButtonFormField<String>(
                              value: _commonUnits.contains(_unitController.text) 
                                  ? _unitController.text 
                                  : null,
                              decoration: InputDecoration(
                                labelText: 'Unit *',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                              ),
                              isExpanded: true,
                              items: _commonUnits.map((unit) =>
                                DropdownMenuItem(
                                  value: unit,
                                  child: Text(
                                    unit,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  _unitController.text = value;
                                }
                              },
                              validator: (value) {
                                if (_unitController.text.trim().isEmpty) {
                                  return 'Please select unit';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Batch Number
                      TextFormField(
                        controller: _batchNoController,
                        decoration: InputDecoration(
                          labelText: 'Batch Number',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Manufacturing Date
                      InkWell(
                        onTap: () => _selectDate(context, true),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Manufacturing Date',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            suffixIcon: const Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            _mfgDate != null 
                                ? '${_mfgDate!.day}/${_mfgDate!.month}/${_mfgDate!.year}'
                                : 'Select date',
                            style: TextStyle(
                              color: _mfgDate != null 
                                  ? Theme.of(context).textTheme.bodyLarge?.color
                                  : Theme.of(context).hintColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Expiry Date
                      InkWell(
                        onTap: () => _selectDate(context, false),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Expiry Date',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            suffixIcon: const Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            _expiryDate != null 
                                ? '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}'
                                : 'Select date',
                            style: TextStyle(
                              color: _expiryDate != null 
                                  ? Theme.of(context).textTheme.bodyLarge?.color
                                  : Theme.of(context).hintColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveChemical,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0072BC),
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(widget.chemical == null ? 'Add Chemical' : 'Update Chemical'),
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