// lib/widgets/explore_search_bar.dart
//
// Reusable search bar used by ExploreScreen, HomeScreen and SearchResultsScreen.
// Supports autocomplete for BOTH city and apartment names.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_colors.dart';

class ExploreSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final void Function(String city) onCitySelected;
  final VoidCallback onFilterTap;

  // Optional apartment search
  final bool includeApartments;
  final Function(String)? onApartmentSelected;

  const ExploreSearchBar({
    super.key,
    required this.controller,
    required this.onCitySelected,
    required this.onFilterTap,
    this.includeApartments = false,
    this.onApartmentSelected,
  });

  @override
  State<ExploreSearchBar> createState() => _ExploreSearchBarState();
}

class _ExploreSearchBarState extends State<ExploreSearchBar> {
  List<Map<String, String>> _suggestions = [];
  bool _showDropdown = false;
  bool _loading = false;

  // ─────────────────────────────────────────────
  // SEARCH SUGGESTIONS
  // ─────────────────────────────────────────────
  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _showDropdown = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _showDropdown = true;
    });

    final snapshot = await FirebaseFirestore.instance
        .collection('properties')
        .where('isActive', isEqualTo: true)
        .get();

    final results = <Map<String, String>>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final city = (data['city'] ?? '').toString();
      final name = (data['name'] ?? '').toString();

      if (city.toLowerCase().contains(query.toLowerCase())) {
        results.add({
          'type': 'city',
          'value': city,
        });
      }

      if (widget.includeApartments &&
          name.toLowerCase().contains(query.toLowerCase())) {
        results.add({
          'type': 'apartment',
          'value': name,
        });
      }
    }

    setState(() {
      _suggestions = results.take(6).toList();
      _loading = false;
    });
  }

  // ─────────────────────────────────────────────
  // HANDLE SELECTION
  // ─────────────────────────────────────────────
  void _selectItem(Map<String, String> item) {
    widget.controller.text = item['value']!;

    setState(() {
      _showDropdown = false;
    });

    if (item['type'] == 'city') {
      widget.onCitySelected(item['value']!);
    } else if (item['type'] == 'apartment') {
      widget.onApartmentSelected?.call(item['value']!);
    }
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [

        Row(
          children: [

            // ── SEARCH FIELD ───────────────────────────────
            Expanded(
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: widget.controller,
                  onChanged: _search,
                  decoration: InputDecoration(
                    hintText: "Search city or apartment",
                    hintStyle: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textLight,
                    ),
                    border: InputBorder.none,
                    prefixIcon: const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.textLight,
                    ),
                    suffixIcon: widget.controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              widget.controller.clear();
                              setState(() {
                                _suggestions = [];
                                _showDropdown = false;
                              });
                            },
                          )
                        : null,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 10),

            // ── FILTER BUTTON ──────────────────────────────
            GestureDetector(
              onTap: widget.onFilterTap,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryOrange.withOpacity(0.32),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),

        // ── DROPDOWN SUGGESTIONS ──────────────────────────
        if (_showDropdown)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryOrange,
                      ),
                    ),
                  )
                : Column(
                    children: _suggestions.map((item) {
                      final isCity = item['type'] == 'city';

                      return ListTile(
                        leading: Icon(
                          isCity
                              ? Icons.location_on_outlined
                              : Icons.home_outlined,
                          color: AppColors.primaryOrange,
                        ),
                        title: Text(
                          item['value']!,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.text(context),
                          ),
                        ),
                        onTap: () => _selectItem(item),
                      );
                    }).toList(),
                  ),
          ),
      ],
    );
  }
}