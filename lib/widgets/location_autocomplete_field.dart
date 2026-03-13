// ════════════════════════════════════════════════════════════════════════════
//  FILE: lib/widgets/location_autocomplete_field.dart
//
//  Reusable location autocomplete widget backed by AppCities.list.
//
//  ┌─ HOW IT WORKS ───────────────────────────────────────────────────────┐
//  │  • Filters AppCities.list client-side as the user types              │
//  │  • Renders a floating OverlayEntry dropdown below the field          │
//  │  • Tapping a suggestion → fills the field, closes dropdown,         │
//  │    fires onSelected(city)                                            │
//  │  • Tapping outside → closes dropdown, preserves typed text          │
//  │  • Works inside ScrollViews — overlay is positioned via LayerLink    │
//  │  • Fully dark-mode aware via AppColors                               │
//  └──────────────────────────────────────────────────────────────────────┘
//
//  USAGE:
//    LocationAutocompleteField(
//      controller: locationCtrl,
//      onSelected: (city) {
//        setState(() => _filters['location'] = city);
//      },
//    )
//
//  OPTIONAL PARAMS:
//    hint        → placeholder text  (default: 'Search city or location')
//    prefixIcon  → leading icon      (default: Icons.location_on_rounded)
//    enabled     → editable toggle   (default: true)
//    onChanged   → keystroke callback before filtering
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_cities.dart';

// ────────────────────────────────────────────────────────────────────────────
//  PUBLIC WIDGET
// ────────────────────────────────────────────────────────────────────────────

class LocationAutocompleteField extends StatefulWidget {
  final TextEditingController      controller;
  final void Function(String city) onSelected;
  final String                     hint;
  final IconData                   prefixIcon;
  final bool                       enabled;
  final void Function(String)?     onChanged;

  const LocationAutocompleteField({
    super.key,
    required this.controller,
    required this.onSelected,
    this.hint       = 'Search city or location',
    this.prefixIcon = Icons.location_on_rounded,
    this.enabled    = true,
    this.onChanged,
  });

  @override
  State<LocationAutocompleteField> createState() =>
      _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState
    extends State<LocationAutocompleteField>
    with SingleTickerProviderStateMixin {

  // ── Overlay ───────────────────────────────────────────────────────────────
  OverlayEntry?    _overlayEntry;
  final _layerLink = LayerLink();
  final _focusNode = FocusNode();

  // ── State ─────────────────────────────────────────────────────────────────
  List<String> _suggestions  = [];
  bool         _dropdownOpen = false;

  // ── Animation ─────────────────────────────────────────────────────────────
  late final AnimationController _animCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  // ════════════════════════════════════════════════════════════════════════
  //  LIFECYCLE
  // ════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.04),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    _focusNode.addListener(_onFocusChanged);
    widget.controller.addListener(_onTextChanged);
  }

@override
void dispose() {
  _removeOverlay();

  if (_animCtrl.isAnimating) {
    _animCtrl.stop();
  }

  _animCtrl.dispose();
  _focusNode.removeListener(_onFocusChanged);
  _focusNode.dispose();
  widget.controller.removeListener(_onTextChanged);
  super.dispose();
}

  // ════════════════════════════════════════════════════════════════════════
  //  TEXT / FOCUS LISTENERS
  // ════════════════════════════════════════════════════════════════════════

  void _onTextChanged() {
    widget.onChanged?.call(widget.controller.text);

    final query = widget.controller.text.trim();

    if (query.isEmpty) {
      _close();
      return;
    }

    final filtered = AppCities.list
        .where((c) => c.toLowerCase().contains(query.toLowerCase()))
        .take(8)
        .toList();

    if (filtered.isEmpty) {
      _close();
      return;
    }

    setState(() {
      _suggestions  = filtered;
      _dropdownOpen = true;
    });

    if (_overlayEntry == null) {
      _insertOverlay();
    } else {
      // Already showing — just refresh items & re-animate
      _overlayEntry!.markNeedsBuild();
      _animCtrl.forward(from: 0);
    }
  }

void _onFocusChanged() {
  if (!_focusNode.hasFocus) {
    Future.delayed(const Duration(milliseconds: 160), () {
      if (!mounted) return;
      _close();
    });
  }
}
  // ════════════════════════════════════════════════════════════════════════
  //  OVERLAY MANAGEMENT
  // ════════════════════════════════════════════════════════════════════════

  void _insertOverlay() {
    _overlayEntry = _buildOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _animCtrl.forward(from: 0);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

void _close() {
  if (!_dropdownOpen) return;
  if (!_animCtrl.isAnimating && _animCtrl.value == 0) {
    _removeOverlay();
    return;
  }

  _animCtrl.reverse().whenComplete(() {
    if (!mounted) return;
    setState(() => _dropdownOpen = false);
    _removeOverlay();
  });
}

  // ════════════════════════════════════════════════════════════════════════
  //  SELECTION
  // ════════════════════════════════════════════════════════════════════════

  void _selectCity(String city) {
    // Temporarily remove the listener so writing to the controller
    // does not re-trigger filtering.
    widget.controller.removeListener(_onTextChanged);
    widget.controller.value = TextEditingValue(
      text:      city,
      selection: TextSelection.collapsed(offset: city.length),
    );
    widget.controller.addListener(_onTextChanged);

    _close();
    _focusNode.unfocus();
    widget.onSelected(city);
  }

  // ════════════════════════════════════════════════════════════════════════
  //  OVERLAY ENTRY
  // ════════════════════════════════════════════════════════════════════════

  OverlayEntry _buildOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final fieldW    = renderBox.size.width;
    final fieldH    = renderBox.size.height;

    return OverlayEntry(
      builder: (_) => Positioned(
        width: fieldW,
        child: CompositedTransformFollower(
          link:             _layerLink,
          showWhenUnlinked: false,
          offset:           Offset(0, fieldH),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: _DropdownCard(
                suggestions: _suggestions,
                query:       widget.controller.text.trim(),
                onSelect:    _selectCity,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // Rebuild so the clear-button and border tint respond to state changes.
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (_, __) {
        final hasText = widget.controller.text.isNotEmpty;

        return CompositedTransformTarget(
          link: _layerLink,
          child: TextField(
            controller:         widget.controller,
            focusNode:          _focusNode,
            enabled:            widget.enabled,
            keyboardType:       TextInputType.streetAddress,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(
              color:      AppColors.text(context),
              fontSize:   15,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText:  widget.hint,
              hintStyle: const TextStyle(
                  color: AppColors.textLight, fontSize: 15),

              prefixIcon: Icon(
                widget.prefixIcon,
                size:  20,
                color: _dropdownOpen
                    ? AppColors.primaryOrange
                    : AppColors.textLight,
              ),

              // Clear 'X' when the field has text and is focused
              suffixIcon: hasText && _focusNode.hasFocus
                  ? GestureDetector(
                      onTap: () {
                        widget.controller.clear();
                        _close();
                      },
                      child: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textLight,
                        size:  18,
                      ),
                    )
                  : null,

              filled:    true,
              fillColor: AppColors.cardSoft(context),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 16),

              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: _dropdownOpen
                      ? AppColors.primaryOrange.withOpacity(.55)
                      : AppColors.border,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                    color: AppColors.primaryOrange, width: 1.5),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                    color: AppColors.border, width: 1),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:   BorderSide.none,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
//  DROPDOWN CARD
//  Pure stateless — rebuilt by the OverlayEntry on every markNeedsBuild()
// ────────────────────────────────────────────────────────────────────────────

class _DropdownCard extends StatelessWidget {
  final List<String>           suggestions;
  final String                 query;
  final void Function(String)  onSelect;

  const _DropdownCard({
    required this.suggestions,
    required this.query,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(                          // ← cap height, don't set it
        constraints: const BoxConstraints(maxHeight: 260),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.primaryOrange.withOpacity(.18),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withOpacity(isDark ? .32 : .10),
                blurRadius: 28,
                offset:     const Offset(0, 10),
              ),
              BoxShadow(
                color:      AppColors.primaryOrange.withOpacity(.06),
                blurRadius: 10,
                offset:     const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: ListView.separated(
              padding:          EdgeInsets.zero,
              shrinkWrap:       true,               // ← content drives height
              physics:          const BouncingScrollPhysics(), // ← allows scroll when capped
              itemCount:        suggestions.length,
              separatorBuilder: (_, __) => Divider(
                height:    1,
                thickness: 1,
                color:     AppColors.border.withOpacity(.45),
                indent:    52,
                endIndent: 16,
              ),
              itemBuilder: (_, i) => _SuggestionTile(
                city:    suggestions[i],
                query:   query,
                onTap:   onSelect,
                isFirst: i == 0,
                isLast:  i == suggestions.length - 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
//  SUGGESTION TILE
// ────────────────────────────────────────────────────────────────────────────

class _SuggestionTile extends StatefulWidget {
  final String                 city;
  final String                 query;
  final void Function(String)  onTap;
  final bool                   isFirst;
  final bool                   isLast;

  const _SuggestionTile({
    required this.city,
    required this.query,
    required this.onTap,
    required this.isFirst,
    required this.isLast,
  });

  @override
  State<_SuggestionTile> createState() => _SuggestionTileState();
}

class _SuggestionTileState extends State<_SuggestionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapCancel: ()  => setState(() => _pressed = false),
      onTap: () {
        setState(() => _pressed = false);
        widget.onTap(widget.city);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        color: _pressed
            ? AppColors.primaryOrange.withOpacity(.09)
            : Colors.transparent,
        padding: EdgeInsets.only(
          left:   16,
          right:  16,
          top:    widget.isFirst ? 10 : 10,
          bottom: widget.isLast  ? 10 : 10,
        ),
        child: Row(
          children: [

            // ── Pin icon badge ──────────────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 110),
              width:  34,
              height: 34,
              decoration: BoxDecoration(
                color: _pressed
                    ? AppColors.primaryOrange.withOpacity(.18)
                    : (isDark
                        ? const Color(0xFF2C2C2C)
                        : AppColors.orangeLight),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.location_on_rounded,
                size:  16,
                color: _pressed
                    ? AppColors.primaryOrange
                    : AppColors.primaryOrange.withOpacity(.65),
              ),
            ),

            const SizedBox(width: 12),

            // ── City name with match highlighted ───────────────────────
            Expanded(
              child: _HighlightText(
                full:  widget.city,
                match: widget.query,
              ),
            ),

            // ── Tap-to-fill arrow hint ──────────────────────────────────
            Icon(
              Icons.north_west_rounded,
              size:  13,
              color: _pressed
                  ? AppColors.primaryOrange
                  : AppColors.textLight.withOpacity(.4),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
//  HIGHLIGHT TEXT
//  Bolds the portion of the city name that matches the query.
// ────────────────────────────────────────────────────────────────────────────

class _HighlightText extends StatelessWidget {
  final String full;
  final String match;

  const _HighlightText({required this.full, required this.match});

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontSize:   14,
      fontWeight: FontWeight.w500,
      color:      AppColors.textMid,
    );

    if (match.isEmpty) {
      return Text(full, style: baseStyle, overflow: TextOverflow.ellipsis);
    }

    final lowerFull  = full.toLowerCase();
    final lowerMatch = match.toLowerCase();
    final start      = lowerFull.indexOf(lowerMatch);

    if (start == -1) {
      return Text(full, style: baseStyle, overflow: TextOverflow.ellipsis);
    }

    final end    = start + match.length;
    final before = full.substring(0, start);
    final bold   = full.substring(start, end);
    final after  = full.substring(end);

    return RichText(
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style:    baseStyle,
        children: [
          TextSpan(text: before),
          TextSpan(
            text:  bold,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color:      AppColors.text(context),
            ),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }
}