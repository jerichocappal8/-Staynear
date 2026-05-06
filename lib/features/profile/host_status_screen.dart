import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:staynear/core/auth_helper.dart';
import 'package:staynear/core/app_colors.dart';
import '../host/host_dashboard_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Status configuration — drives colours, icons, and copy for each state
// ─────────────────────────────────────────────────────────────────────────────

class _StatusCfg {
  const _StatusCfg({
    required this.themeColor,
    required this.lightColor,
    required this.icon,
    required this.heroTitle,
    required this.heroSubtitle,
    required this.cardTitle,
    required this.cardBody,
    required this.activeStep,
  });
  final Color themeColor;
  final Color lightColor;
  final IconData icon;
  final String heroTitle;
  final String heroSubtitle;
  final String cardTitle;
  final String cardBody;
  final int activeStep; // 0 = submitted, 1 = under review, 2 = decided
}

_StatusCfg _cfgFor(String? status) {
  switch (status) {
    case 'approved':
      return const _StatusCfg(
        themeColor: Color(0xFF22C55E),
        lightColor: Color(0xFFDCFCE7),
        icon: Icons.verified_rounded,
        heroTitle: "You're Approved!",
        heroSubtitle: 'Welcome to the StayNear host community',
        cardTitle: "You're now a StayNear host",
        cardBody: 'Your host tools are now unlocked. Start listing your property and welcoming guests today.',
        activeStep: 2,
      );
    case 'rejected':
      return const _StatusCfg(
        themeColor: Color(0xFFEF4444),
        lightColor: Color(0xFFFEE2E2),
        icon: Icons.info_outline_rounded,
        heroTitle: 'Application Needs Attention',
        heroSubtitle: 'Please review the information below',
        cardTitle: 'We could not approve your application',
        cardBody: 'Your documents did not meet our current requirements. You may contact support or reapply after resolving the noted issues.',
        activeStep: 2,
      );
    default: // pending
      return const _StatusCfg(
        themeColor: AppColors.primaryOrange,
        lightColor: AppColors.orangeLight,
        icon: Icons.hourglass_top_rounded,
        heroTitle: 'Application Submitted',
        heroSubtitle: "We're reviewing your documents",
        cardTitle: 'Your application is under review',
        cardBody: 'Our team is verifying your identity and documents. This usually takes less than 24 hours.',
        activeStep: 1,
      );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────────────────────────────────────

class HostStatusScreen extends StatelessWidget {
  const HostStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthHelper.uid;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('host_requests')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryOrange),
            );
          }

          if (!snapshot.data!.exists) {
            return const _NoApplicationView();
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = data['status'] as String?;
          final cfg   = _cfgFor(status);

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeroHeader(cfg: cfg, context: context),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StatusCard(cfg: cfg, status: status),
                      const SizedBox(height: 16),
                      _TimelineCard(cfg: cfg, status: status),
                      const SizedBox(height: 16),
                      if (status == 'pending') ...[
                        _WhatHappensNextCard(themeColor: cfg.themeColor),
                        const SizedBox(height: 16),
                      ],
                      if (status == 'approved')
                        _hostDashboardButton(context, cfg.themeColor)
                      else
                        _backButton(context, cfg.themeColor),
                      if (status == 'pending') ...[
                        const SizedBox(height: 10),
                        const Center(
                          child: Text(
                            'You can still use StayNear while waiting.',
                            style: TextStyle(fontSize: 12.5, color: AppColors.textMid),
                          ),
                        ),
                      ],
                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _backButton(BuildContext context, Color themeColor) {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_rounded, size: 18),
        label: const Text('Back to Profile',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: themeColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _hostDashboardButton(BuildContext context, Color themeColor) {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HostDashboardScreen()),
          (route) => false,
        ),
        icon: const Icon(Icons.home_work_rounded, size: 18),
        label: const Text(
          'Go to Host Dashboard',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: themeColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Hero header
// ─────────────────────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.cfg, required this.context});
  final _StatusCfg cfg;
  final BuildContext context;

  @override
  Widget build(BuildContext ctx) {
    return Container(
      color: cfg.themeColor,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            children: [
              // Top bar
              Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 15),
                  ),
                ),
                const Spacer(),
                Text(
                  'Host Application',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 36),
              ]),
              const SizedBox(height: 28),
              // Status icon
              Container(
                width: 76, height: 76,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(cfg.icon, size: 38, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                cfg.heroTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                cfg.heroSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.8), fontSize: 13.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Status explanation card
// ─────────────────────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.cfg, required this.status});
  final _StatusCfg cfg;
  final String? status;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: cfg.lightColor,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(cfg.icon, color: cfg.themeColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  cfg.cardTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text(context),
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Text(
            cfg.cardBody,
            style: const TextStyle(
                fontSize: 13.5, color: AppColors.textMid, height: 1.5),
          ),
          if (status == 'pending') ...[
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: cfg.lightColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: cfg.themeColor.withOpacity(0.25), width: 1),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.access_time_rounded,
                    size: 13, color: cfg.themeColor),
                const SizedBox(width: 6),
                Text(
                  'Usually reviewed within 24 hours',
                  style: TextStyle(
                    fontSize: 12,
                    color: cfg.themeColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Timeline progress card
// ─────────────────────────────────────────────────────────────────────────────

enum _StepState { done, active, upcoming }

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.cfg, required this.status});
  final _StatusCfg cfg;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('APPLICATION PROGRESS'),
          const SizedBox(height: 16),
          ...List.generate(steps.length, (i) {
            final state = _stateFor(i);
            return _TimelineStep(
              label: steps[i][0],
              description: steps[i][1],
              state: state,
              themeColor: cfg.themeColor,
              isLast: i == steps.length - 1,
              context: context,
            );
          }),
        ],
      ),
    );
  }

  _StepState _stateFor(int index) {
    if (index < cfg.activeStep) return _StepState.done;
    if (index == cfg.activeStep) return _StepState.active;
    return _StepState.upcoming;
  }

  List<List<String>> _buildSteps() {
    final finalLabel = status == 'rejected' ? 'Decision Made' : 'Approved';
    final finalDesc = status == 'rejected'
        ? 'Application was not approved'
        : status == 'approved'
            ? "You're now a host on StayNear!"
            : 'You will be notified once decided';
    return [
      ['Submitted',    'Application received & logged'],
      ['Under Review', 'Documents being verified'],
      [finalLabel,     finalDesc],
    ];
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.label,
    required this.description,
    required this.state,
    required this.themeColor,
    required this.isLast,
    required this.context,
  });
  final String label;
  final String description;
  final _StepState state;
  final Color themeColor;
  final bool isLast;
  final BuildContext context;

  @override
  Widget build(BuildContext ctx) {
    final isDone   = state == _StepState.done;
    final isActive = state == _StepState.active;

    final circleColor = (isDone || isActive) ? themeColor : Colors.grey.shade200;
    final lineColor   = isDone ? themeColor : Colors.grey.shade200;

    final Widget circleChild = isDone
        ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
        : isActive
            ? Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
              )
            : Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                    color: Colors.grey.shade400, shape: BoxShape.circle),
              );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dot + connector
        SizedBox(
          width: 28,
          child: Column(children: [
            Container(
              width: 28, height: 28,
              decoration:
                  BoxDecoration(color: circleColor, shape: BoxShape.circle),
              child: Center(child: circleChild),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 44,
                decoration: BoxDecoration(
                  color: lineColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
          ]),
        ),
        const SizedBox(width: 14),
        // Label + description
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 4, bottom: isLast ? 0 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                    color: isActive || isDone
                        ? AppColors.text(context)
                        : AppColors.textMid,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: isActive ? themeColor : AppColors.textMid,
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  What happens next card  (pending only)
// ─────────────────────────────────────────────────────────────────────────────

class _NextItem {
  const _NextItem(this.icon, this.title, this.desc);
  final IconData icon;
  final String title;
  final String desc;
}

class _WhatHappensNextCard extends StatelessWidget {
  const _WhatHappensNextCard({required this.themeColor});
  final Color themeColor;

  static const _items = [
    _NextItem(
      Icons.manage_search_rounded,
      'Admin reviews your documents',
      'Your ID and details are verified by our trust & safety team.',
    ),
    _NextItem(
      Icons.notifications_active_outlined,
      'You will be notified',
      "You'll receive an in-app notification once a decision is made.",
    ),
    _NextItem(
      Icons.home_work_rounded,
      'Host tools unlock',
      'Once approved, list your property and start welcoming guests.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('WHAT HAPPENS NEXT?'),
          const SizedBox(height: 14),
          ...List.generate(_items.length, (i) {
            final item = _items[i];
            return Padding(
              padding: EdgeInsets.only(bottom: i < _items.length - 1 ? 14 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.orangeLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.icon, size: 18, color: themeColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text(context),
                            )),
                        const SizedBox(height: 2),
                        Text(item.desc,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMid,
                              height: 1.4,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  No-application fallback
// ─────────────────────────────────────────────────────────────────────────────

class _NoApplicationView extends StatelessWidget {
  const _NoApplicationView();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.orangeLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new,
                      color: AppColors.primaryOrange, size: 15),
                ),
              ),
            ]),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72, height: 72,
                      decoration: const BoxDecoration(
                          color: AppColors.orangeLight,
                          shape: BoxShape.circle),
                      child: const Icon(Icons.home_work_outlined,
                          size: 32, color: AppColors.primaryOrange),
                    ),
                    const SizedBox(height: 18),
                    Text('No Application Found',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text(context),
                        )),
                    const SizedBox(height: 8),
                    const Text(
                      "You haven't submitted a host application yet.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13.5, color: AppColors.textMid, height: 1.5),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity, height: 52,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Back to Profile',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared small components
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.055),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: AppColors.primaryOrange,
          letterSpacing: 1.4,
        ),
      );
}
