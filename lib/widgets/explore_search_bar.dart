// lib/widgets/explore_search_bar.dart
//
// Overlay architecture:
// ┌─────────────────────────────────────────────────────────────────────┐
// │  The dropdown is rendered via OverlayEntry so it floats ABOVE the  │
// │  page layout. The search bar uses a GlobalKey to measure its own   │
// │  position via RenderBox, then positions the OverlayEntry directly  │
// │  below it using Positioned with exact top/left/width values.       │
// │                                                                     │
// │  Lifecycle:                                                         │
// │  onChanged   → _search() → Firestore fetch → _showOverlay()        │
// │  item tap    → _selectItem() → _removeOverlay()                    │
// │  tap outside → TapRegion onTapOutside → _removeOverlay()           │
// │  clear btn   → _clearSearch() → _removeOverlay()                   │
// │  dispose     → _removeOverlay() (safety cleanup)                   │
// └─────────────────────────────────────────────────────────────────────┘

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/app_colors.dart';

class ExploreSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final void Function(String city) onCitySelected;
  final VoidCallback onFilterTap;
  final bool includeApartments;
  final void Function(String)? onApartmentSelected;

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
  // ── Overlay ───────────────────────────────────────────────────────────────
  OverlayEntry? _overlayEntry;

  // ── Key to measure the search bar's position on screen ───────────────────
  // Attached to the Row that contains the TextField + filter button.
  // We read its RenderBox in _showOverlay() to get exact top/left/width.
  final GlobalKey _barKey = GlobalKey();

  // ── State ─────────────────────────────────────────────────────────────────
  List<Map<String, String>> _suggestions = [];
  bool _loading = false;

  // ════════════════════════════════════════════════════════════════════════
  //  LIFECYCLE
  // ════════════════════════════════════════════════════════════════════════

  @override
  void dispose() {
    _removeOverlay(); // always clean up on widget removal
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════════
  //  OVERLAY MANAGEMENT
  // ════════════════════════════════════════════════════════════════════════

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
  }

  void _showOverlay() {
    _removeOverlay(); // remove any existing one first

    // Read the search bar's current screen position
    final renderBox =
        _barKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    // We need a BuildContext that belongs to the overlay's scope.
    // Using the widget's own context is correct here — Overlay.of()
    // walks up the tree from this context to find the nearest Overlay.
    final overlayState = Overlay.of(context);

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return Stack(
          children: [
            // ── Tap-outside barrier ──────────────────────────────────────
            // A transparent full-screen hit-test area that dismisses the
            // dropdown when the user taps anywhere outside it.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _removeOverlay,
                // Must be a transparent container so it absorbs taps
                child: const SizedBox.expand(),
              ),
            ),

            // ── The dropdown itself ──────────────────────────────────────
            Positioned(
              // Sit flush below the search bar with a small gap
              top: offset.dy + size.height + 6,
              left: offset.dx,
              width: size.width,
              child: Material(
                color: Colors.transparent,
                // TapRegion prevents taps inside the dropdown from being
                // caught by the barrier above
                child: TapRegion(
                  onTapOutside: (_) => _removeOverlay(),
                  child: _DropdownContent(
                    loading: _loading,
                    suggestions: _suggestions,
                    onSelect: _selectItem,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlayState.insert(_overlayEntry!);
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SEARCH
  // ════════════════════════════════════════════════════════════════════════

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      _removeOverlay();
      setState(() => _loading = false);
      return;
    }

    // Show a loading spinner in the overlay immediately
    setState(() => _loading = true);
    _showOverlay();

    final snapshot = await FirebaseFirestore.instance
        .collection('properties')
        .where('isActive', isEqualTo: true)
        .get();

    if (!mounted) return;

    final seen = <String>{};
    final results = <Map<String, String>>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final city = (data['city'] ?? '').toString();
      final name = (data['name'] ?? '').toString();

      if (city.toLowerCase().contains(query.toLowerCase())) {
        final key = 'city|$city';
        if (seen.add(key)) {
          results.add({'type': 'city', 'value': city});
        }
      }

      if (widget.includeApartments &&
          name.toLowerCase().contains(query.toLowerCase())) {
        final key = 'apartment|$name';
        if (seen.add(key)) {
          results.add({'type': 'apartment', 'value': name});
        }
      }
    }

    _suggestions = results.take(6).toList();

    setState(() => _loading = false);

    // Rebuild the overlay with real results now that loading is done
    _showOverlay();
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SELECTION & CLEAR
  // ════════════════════════════════════════════════════════════════════════

  void _selectItem(Map<String, String> item) {
    widget.controller.text = item['value']!;
    _removeOverlay();

    if (item['type'] == 'city') {
      widget.onCitySelected(item['value']!);
    } else {
      widget.onApartmentSelected?.call(item['value']!);
    }
  }

  void _clearSearch() {
    widget.controller.clear();
    _suggestions = [];
    _removeOverlay();
    setState(() {});
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // The widget itself is ONLY the search bar row.
    // The dropdown never lives here — it's in the Overlay.
    return Row(
      key: _barKey, // ← RenderBox anchor for overlay positioning
      children: [
        // ── Search field ─────────────────────────────────────────────────
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
              onChanged: (value) {
  setState(() {});
  _search(value);
},
              decoration: InputDecoration(
                hintText: 'Search city or apartment',
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
                        onPressed: _clearSearch,
                      )
                    : null,
              ),
            ),
          ),
        ),

        const SizedBox(width: 10),

        // ── Filter button ─────────────────────────────────────────────────
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DROPDOWN CONTENT
//
//  Extracted into its own StatelessWidget so OverlayEntry.builder can
//  rebuild it cleanly without needing a setState on the parent.
// ─────────────────────────────────────────────────────────────────────────────

class _DropdownContent extends StatelessWidget {
  final bool loading;
  final List<Map<String, String>> suggestions;
  final void Function(Map<String, String>) onSelect;

  const _DropdownContent({
    required this.loading,
    required this.suggestions,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // Max height: show up to ~4.5 items, then scroll
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: loading
            ? const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                ),
              )
            : suggestions.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      'No results found',
                      style: TextStyle(
                        color: AppColors.textMid,
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.separated(
                    // shrinkWrap works correctly here because the Container
                    // above provides a bounded maxHeight constraint
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    physics: const BouncingScrollPhysics(),
                    itemCount: suggestions.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      thickness: 0.8,
                      color: AppColors.border,
                    ),
                    itemBuilder: (_, index) {
                      final item = suggestions[index];
                      final isCity = item['type'] == 'city';

                      return InkWell(
                        onTap: () => onSelect(item),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              // Icon badge
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.orangeLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isCity
                                      ? Icons.location_on_rounded
                                      : Icons.apartment_rounded,
                                  size: 16,
                                  color: AppColors.primaryOrange,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Label + type subtitle
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['value']!,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.text(context),
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      isCity ? 'City' : 'Apartment',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Arrow hint
                              Icon(
                                Icons.north_west_rounded,
                                size: 14,
                                color: AppColors.textLight,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}