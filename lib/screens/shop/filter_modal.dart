import 'package:flutter/material.dart';
import '../../data/dummy_data.dart';

class FilterModal extends StatefulWidget {
  final List<String> selectedCategories;
  final double minPrice;
  final double maxPrice;
  final List<String> selectedMaterials;
  final List<String> selectedColors;
  final Function(List<String>, double, double, List<String>, List<String>)
      onApply;

  const FilterModal({
    super.key,
    required this.selectedCategories,
    required this.minPrice,
    required this.maxPrice,
    required this.selectedMaterials,
    required this.selectedColors,
    required this.onApply,
  });

  @override
  State<FilterModal> createState() => _FilterModalState();
}

class _FilterModalState extends State<FilterModal> {
  late List<String> _selectedCategories;
  late double _minPrice;
  late double _maxPrice;
  late List<String> _selectedMaterials;
  late List<String> _selectedColors;

  @override
  void initState() {
    super.initState();
    _selectedCategories = List.from(widget.selectedCategories);
    _minPrice = widget.minPrice;
    _maxPrice = widget.maxPrice;
    _selectedMaterials = List.from(widget.selectedMaterials);
    _selectedColors = List.from(widget.selectedColors);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Filter',
          style: TextStyle(
            color: Color(0xFF1E3A8A),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: Container(),
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Color(0xFF1E3A8A)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Categories
              _buildSectionTitle('Categories'),
              _buildCategoryChips(),
              const SizedBox(height: 32),

              // Price
              _buildSectionTitle('Price'),
              _buildPriceDisplay(),
              _buildPriceSlider(),
              const SizedBox(height: 32),

              // Materials
              _buildSectionTitle('Materials'),
              _buildMaterialChips(),
              const SizedBox(height: 32),

              // Colors
              _buildSectionTitle('Color'),
              _buildColorChips(),
              const SizedBox(height: 40),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _selectedCategories.clear();
                          _minPrice = 0;
                          _maxPrice = 500;
                          _selectedMaterials.clear();
                          _selectedColors.clear();
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(
                          color: Color(0xFF1E3A8A),
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                          color: Color(0xFF1E3A8A),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onApply(
                          _selectedCategories,
                          _minPrice,
                          _maxPrice,
                          _selectedMaterials,
                          _selectedColors,
                        );
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFDB022),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Apply',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF1E3A8A),
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: categories.map((category) {
        bool isSelected = _selectedCategories.contains(category);
        return FilterChip(
          label: Text(category),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedCategories.add(category);
              } else {
                _selectedCategories.remove(category);
              }
            });
          },
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF1E3A8A),
            fontWeight: FontWeight.w600,
          ),
          backgroundColor: Colors.grey[200],
          selectedColor: const Color(0xFFFDB022),
          showCheckmark: false,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide.none,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPriceDisplay() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        '₱${_minPrice.toStringAsFixed(0)}-₱${_maxPrice.toStringAsFixed(0)}',
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPriceSlider() {
    return RangeSlider(
      values: RangeValues(_minPrice, _maxPrice),
      min: 0,
      max: 500,
      activeColor: const Color(0xFFFDB022),
      inactiveColor: Colors.grey[300],
      onChanged: (RangeValues values) {
        setState(() {
          _minPrice = values.start;
          _maxPrice = values.end;
        });
      },
    );
  }

  Widget _buildMaterialChips() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: materials.map((material) {
        bool isSelected = _selectedMaterials.contains(material);
        return FilterChip(
          label: Text(material),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedMaterials.add(material);
              } else {
                _selectedMaterials.remove(material);
              }
            });
          },
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF1E3A8A),
            fontWeight: FontWeight.w600,
          ),
          backgroundColor: Colors.grey[200],
          selectedColor: const Color(0xFFFDB022),
          showCheckmark: false,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide.none,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColorChips() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: colors.map((color) {
        bool isSelected = _selectedColors.contains(color);
        return FilterChip(
          label: Text(color),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedColors.add(color);
              } else {
                _selectedColors.remove(color);
              }
            });
          },
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF1E3A8A),
            fontWeight: FontWeight.w600,
          ),
          backgroundColor: Colors.grey[200],
          selectedColor: const Color(0xFFFDB022),
          showCheckmark: false,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide.none,
          ),
        );
      }).toList(),
    );
  }
}
