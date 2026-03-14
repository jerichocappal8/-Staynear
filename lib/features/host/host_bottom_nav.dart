// lib/widgets/host_bottom_nav.dart
//
// Design system — mirrors MainBottomNav exactly:
// ┌──────────────────────────────────────────────────────────────────────┐
// │  Floating pill container sits above the scaffold content.            │
// │  Active tab renders:  filled orange pill + scaled icon + label       │
// │  Inactive tab renders: icon only (label hidden)                      │
// │                                                                      │
// │  Animations                                                          │
// │  • AnimatedContainer — pill width expands/contracts                  │
// │  • AnimatedScale     — icon pops up on selection                     │
// │  • AnimatedOpacity   — label fades in/out                            │
// │  • AnimatedSize      — label space collapses smoothly                │
// │                                                                      │
// │  Tabs (3 only — spaced wider than the 5-tab user nav)                │
// │    0 · Dashboard                                                     │
// │    1 · Messages                                                      │
// │    2 · Profile                                                       │
// └──────────────────────────────────────────────────────────────────────┘

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../core/animations/slide_page_route.dart';
import '../host/host_dashboard_screen.dart';
import '../host/host_profile_screen.dart';
import '../chat/chat_list_host_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ─────────────────────────────────────────────────────────────────────────────
//  TAB DATA MODEL
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String   label;

  const _NavItem({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
  });
}

const _kHostItems = [
  _NavItem(
    activeIcon:   Icons.dashboard_rounded,
    inactiveIcon: Icons.dashboard_outlined,
    label:        'Dashboard',
  ),
  _NavItem(
    activeIcon:   Icons.chat_bubble_rounded,
    inactiveIcon: Icons.chat_bubble_outline_rounded,
    label:        'Messages',
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

class HostBottomNav extends StatefulWidget {
  final int                  currentIndex;
  final void Function(int)   onTap;

  const HostBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<HostBottomNav> createState() => _HostBottomNavState();
}

class _HostBottomNavState extends State<HostBottomNav>
    with SingleTickerProviderStateMixin {

  late int _previousIndex;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.currentIndex;
  }

  @override
  void didUpdateWidget(HostBottomNav old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _previousIndex = old.currentIndex;
    }
  }

  void _handleTap(int index) {
  if (index == widget.currentIndex) return;

  HapticFeedback.lightImpact();

  if (index == 0) {
    Navigator.pushReplacement(
      context,
      SlidePageRoute(
        page: const HostDashboardScreen(),
      ),
    );
  }

if (index == 1) {
  Navigator.pushReplacement(
    context,
    SlidePageRoute(
      page: ChatListHostScreen(
        hostId: FirebaseAuth.instance.currentUser!.uid,
      ),
    ),
  );
}

  if (index == 2) {
    Navigator.pushReplacement(
      context,
      SlidePageRoute(
        page: const HostProfileScreen(),
      ),
    );
  }
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
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: _NavContainer(
          isDark: isDark,
          child: Row(
            // spaceEvenly works well for 3 tabs — each gets equal real estate
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_kHostItems.length, (i) {
              return Flexible(
                fit: FlexFit.loose,
                child: _NavTile(
                  item:     _kHostItems[i],
                  isActive: i == widget.currentIndex,
                  isDark:   isDark,
                  onTap:    () => _handleTap(i),
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
//  FLOATING CONTAINER  (identical to MainBottomNav)
// ─────────────────────────────────────────────────────────────────────────────

class _NavContainer extends StatelessWidget {
  final bool   isDark;
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
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.45)
                : Colors.black.withOpacity(0.10),
            blurRadius:   24,
            spreadRadius: 0,
            offset:       const Offset(0, 8),
          ),
          if (!isDark)
            BoxShadow(
              color:        AppColors.primaryOrange.withOpacity(0.06),
              blurRadius:   12,
              spreadRadius: 0,
              offset:       const Offset(0, 2),
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
//  INDIVIDUAL TAB TILE  (identical animation logic to MainBottomNav)
// ─────────────────────────────────────────────────────────────────────────────

class _NavTile extends StatelessWidget {
  final _NavItem     item;
  final bool         isActive;
  final bool         isDark;
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
      onTap:     onTap,
      behavior:  HitTestBehavior.opaque,
      child: SizedBox(
        height: 64,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve:    Curves.easeOutCubic,
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

                  // ── animated icon ──────────────────────────────────────
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

                  // ── animated label (visible only when active) ──────────
                  AnimatedSize(
                    duration: const Duration(milliseconds: 280),
                    curve:    Curves.easeOutCubic,
                    child: isActive
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 4),
                              AnimatedOpacity(
                                opacity:  isActive ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 220),
                                child: Text(
                                  item.label,
                                  style: const TextStyle(
                                    fontSize:   12,
                                    fontWeight: FontWeight.w700,
                                    color:      Colors.white,
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