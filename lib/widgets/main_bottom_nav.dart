// lib/widgets/main_bottom_nav.dart
//
// Design system:
// ┌──────────────────────────────────────────────────────────────────────┐
// │  Floating pill container sits above the scaffold content.            │
// │  Active tab renders:  filled orange pill + scaled icon + label       │
// │  Inactive tab renders: icon only (label hidden)                      │
// │                                                                      │
// │  Animations                                                          │
// │  • AnimatedContainer — pill width expands/contracts                  │
// │  • AnimatedScale     — icon pops up on selection                     │
// │  • AnimatedOpacity   — label fades in/out                            │
// │  • AnimatedSlide     — indicator slides across tabs                  │
// └──────────────────────────────────────────────────────────────────────┘

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  TAB DATA MODEL
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;

  const _NavItem({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
  });
}

const _kItems = [
  _NavItem(
    activeIcon:   Icons.home_rounded,
    inactiveIcon: Icons.home_outlined,
    label:        'Home',
  ),
  _NavItem(
    activeIcon:   Icons.explore_rounded,
    inactiveIcon: Icons.explore_outlined,
    label:        'Explore',
  ),
  _NavItem(
    activeIcon:   Icons.chat_bubble_rounded,
    inactiveIcon: Icons.chat_bubble_outline_rounded,
    label:        'Chat',
  ),
_NavItem(
  activeIcon:   Icons.calendar_month_rounded,
  inactiveIcon: Icons.calendar_month_outlined,
  label:        'Bookings',
),
  _NavItem(
    activeIcon:   Icons.person_rounded,
    inactiveIcon: Icons.person_outline_rounded,
    label:        'Profile',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
//  MAIN WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class MainBottomNav extends StatefulWidget {
  final int currentIndex;
  final void Function(int) onTap;

  const MainBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<MainBottomNav> createState() => _MainBottomNavState();
}

class _MainBottomNavState extends State<MainBottomNav>
    with SingleTickerProviderStateMixin {

  // Tracks the previous index so we can animate away from it
  late int _previousIndex;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.currentIndex;
  }

  @override
  void didUpdateWidget(MainBottomNav old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _previousIndex = old.currentIndex;
    }
  }

  void _handleTap(int index) {
    if (index == widget.currentIndex) return;
    // Light haptic on every tab switch — feels premium
    HapticFeedback.lightImpact();
    widget.onTap(index);
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        // Floating margin — lifts bar off the screen edge
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: _NavContainer(
          isDark: isDark,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_kItems.length, (i) {
              return Flexible(
                fit: FlexFit.loose,
                child: _NavTile(
                  item:       _kItems[i],
                  isActive:   i == widget.currentIndex,
                  isDark:     isDark,
                  onTap:      () => _handleTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  FLOATING CONTAINER
// ─────────────────────────────────────────────────────────────────────────────

class _NavContainer extends StatelessWidget {
  final bool isDark;
  final Widget child;

  const _NavContainer({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkNavbar : AppColors.cardWhite,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? AppColors.darkCardSoft.withOpacity(0.6)
              : AppColors.border,
          width: 1,
        ),
        boxShadow: [
          // Primary depth shadow
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.45)
                : Colors.black.withOpacity(0.10),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
          // Subtle ambient shadow for light mode
          if (!isDark)
            BoxShadow(
              color: AppColors.primaryOrange.withOpacity(0.06),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  INDIVIDUAL TAB TILE
// ─────────────────────────────────────────────────────────────────────────────

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _NavTile({
    required this.item,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 64,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            // Active tile: pill expands to fit icon + label
            // Inactive tile: compact circle for icon only
            padding: isActive
                ? const EdgeInsets.symmetric(horizontal: 8, vertical: 8)
                : const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primaryOrange
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: FittedBox(
  fit: BoxFit.scaleDown,
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
                // ── Animated icon ────────────────────────────────────────
                AnimatedScale(
                  scale:    isActive ? 1.0 : 0.88,
                  duration: const Duration(milliseconds: 280),
                  curve:    Curves.easeOutBack,
                  child: Icon(
                    isActive ? item.activeIcon : item.inactiveIcon,
                    size:  20,
                    color: isActive
                        ? Colors.white
                        : isDark
                            ? AppColors.textLight
                            : AppColors.textMid,
                  ),
                ),

                // ── Animated label (only visible when active) ────────────
AnimatedSize(
  duration: const Duration(milliseconds: 280),
  curve: Curves.easeOutCubic,
child: isActive
    ? Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 4),
          AnimatedOpacity(
            opacity: isActive ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 220),
            child: Text(
              item.label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      )
      : const SizedBox.shrink(),
),

              ],
  ),
            ),
          ),
        ),
      ),
    );
  }
}