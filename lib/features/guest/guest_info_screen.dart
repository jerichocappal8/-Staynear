// ════════════════════════════════════════════════════════════════════════════
//  FILE: lib/features/guest/guest_info_screen.dart
//
//  Step 2 of the booking flow — Guest information form.
//  Supports BOTH daily (calendar range picker) and monthly (duration stepper).
//  Pops with a GuestInfoModel when the user taps SAVE.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/app_colors.dart';
import '../../models/guest_info_model.dart';
import '../../models/room_offer.dart';

class GuestInfoScreen extends StatefulWidget {
  /// The selected room — used to detect pricingMode and calculate costs.
  final RoomOffer room;

  const GuestInfoScreen({
    super.key,
    required this.room,
  });

  @override
  State<GuestInfoScreen> createState() => _GuestInfoScreenState();
}

class _GuestInfoScreenState extends State<GuestInfoScreen> {

  // ── Form ─────────────────────────────────────────────────────────────────
  final _formKey       = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  final _requestsCtrl  = TextEditingController();

  // ── Daily state ───────────────────────────────────────────────────────────
  DateTime  _focusedDay = DateTime.now();
  DateTime? _checkIn;
  DateTime? _checkOut;

  // ── Monthly state ─────────────────────────────────────────────────────────
  int       _stayMonths  = 1;
  DateTime? _moveInDate;

  // ── Convenience ───────────────────────────────────────────────────────────
  bool get _isDaily => widget.room.pricingMode == 'daily';

  int get _nights =>
      (_checkIn != null && _checkOut != null)
          ? _checkOut!.difference(_checkIn!).inDays
          : 0;

  double get _priceDaily   => double.tryParse(widget.room.priceDaily.trim())    ?? 0;
  double get _priceMonthly => double.tryParse(widget.room.priceMonthly.trim())  ?? 0;
  double get _serviceFee   => double.tryParse((widget.room.serviceFee ?? '').trim()) ?? 0;

  double get _stayTotal =>
      _isDaily ? (_priceDaily * _nights) : (_priceMonthly * _stayMonths);

  double get _grandTotal => _stayTotal + _serviceFee;

  // ── Dispose ───────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _requestsCtrl.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════════
  //  CALENDAR ACTIONS
  // ════════════════════════════════════════════════════════════════════════

  void _onDaySelected(DateTime selected, DateTime focused) {
    setState(() {
      _focusedDay = focused;

      // First tap, or starting over after a complete selection.
      if (_checkIn == null || (_checkIn != null && _checkOut != null)) {
        _checkIn  = selected;
        _checkOut = null;
        return;
      }

      // Second tap: must be strictly after check-in (min 1 night).
      if (selected.isAfter(_checkIn!)) {
        _checkOut = selected;
      } else {
        // Tapped before or on check-in — restart from this date.
        _checkIn  = selected;
        _checkOut = null;
      }
    });
  }

  bool _isInRange(DateTime day) {
    if (_checkIn == null || _checkOut == null) return false;
    return day.isAfter(_checkIn!) && day.isBefore(_checkOut!);
  }

  bool _isRangeStart(DateTime day) =>
      _checkIn != null && isSameDay(day, _checkIn);

  bool _isRangeEnd(DateTime day) =>
      _checkOut != null && isSameDay(day, _checkOut);

  // ════════════════════════════════════════════════════════════════════════
  //  MOVE-IN DATE PICKER  (monthly only)
  // ════════════════════════════════════════════════════════════════════════

  Future<void> _pickMoveInDate() async {
    final today  = DateTime.now();
    final picked = await showDatePicker(
      context:     context,
      initialDate: _moveInDate ?? today,
      firstDate:   today,
      lastDate:    today.add(const Duration(days: 365 * 2)),
      helpText:    'SELECT MOVE-IN DATE',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary:   AppColors.primaryOrange,
            onPrimary: Colors.white,
            onSurface: AppColors.text(ctx),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _moveInDate = picked);
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SAVE
  // ════════════════════════════════════════════════════════════════════════

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    // Validate date selection for daily rooms.
    if (_isDaily && (_checkIn == null || _checkOut == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select your check-in and check-out dates.'),
          backgroundColor: AppColors.primaryOrange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    // Validate move-in date for monthly rooms.
    if (!_isDaily && _moveInDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select your move-in date.'),
          backgroundColor: AppColors.primaryOrange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    // For monthly rooms checkIn = selected move-in date,
    // checkOut = checkIn + selected months (calendar arithmetic, not days/30).
    final checkIn = _isDaily ? _checkIn! : _moveInDate!;
    final checkOut = _isDaily
        ? _checkOut!
        : DateTime(checkIn.year, checkIn.month + _stayMonths, checkIn.day);

    final model = GuestInfoModel(
      firstName:       _firstNameCtrl.text.trim(),
      lastName:        _lastNameCtrl.text.trim(),
      email:           _emailCtrl.text.trim(),
      phone:           _phoneCtrl.text.trim(),
      checkInDate:     checkIn,
      checkOutDate:    checkOut,
      roomsCount:      1,
      guestsCount:     1,
      specialRequests: _requestsCtrl.text.trim(),
      stayMonths:      _isDaily ? 0 : _stayMonths,
    );

    Navigator.pop(context, model);
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarBrightness: Theme.of(context).brightness == Brightness.dark
          ? Brightness.dark
          : Brightness.light,
    ));

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: _buildAppBar(context),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Subtitle hint ─────────────────────────────────────
                    Text(
                      'Guest names must match the valid ID which will be used at check-in.',
                      style: TextStyle(
                        fontSize: 13,
                        color:    AppColors.textMid,
                        height:   1.45,
                      ),
                    ),
                    const SizedBox(height: 22),

                    // ── Section 1: Guest Info ─────────────────────────────
                    _SectionLabel(label: 'Guest Info'),
                    const SizedBox(height: 10),
                    _GuestInfoCard(
                      firstNameCtrl: _firstNameCtrl,
                      lastNameCtrl:  _lastNameCtrl,
                      emailCtrl:     _emailCtrl,
                      phoneCtrl:     _phoneCtrl,
                    ),
                    const SizedBox(height: 20),

                    // ── Section 2: Stay Duration ──────────────────────────
                    _SectionLabel(
                      label: _isDaily
                          ? 'Stay Duration'
                          : 'Move-in Date & Duration',
                    ),
                    const SizedBox(height: 10),
                    if (_isDaily)
                      _DailyCalendarCard(
                        focusedDay:     _focusedDay,
                        checkIn:        _checkIn,
                        checkOut:       _checkOut,
                        onDaySelected:  _onDaySelected,
                        isInRange:      _isInRange,
                        isRangeStart:   _isRangeStart,
                        isRangeEnd:     _isRangeEnd,
                        onFocusChanged: (day) =>
                            setState(() => _focusedDay = day),
                      )
                    else
                      _MonthlyDurationCard(
                        months:      _stayMonths,
                        moveInDate:  _moveInDate,
                        onChanged:   (v) => setState(() => _stayMonths = v),
                        onPickDate:  _pickMoveInDate,
                      ),
                    const SizedBox(height: 20),

                    // ── Section 3: Price Summary ──────────────────────────
                    _SectionLabel(label: 'Price Summary'),
                    const SizedBox(height: 10),
                    _PriceSummaryCard(
                      room:       widget.room,
                      isDaily:    _isDaily,
                      nights:     _nights,
                      stayMonths: _stayMonths,
                      stayTotal:  _stayTotal,
                      serviceFee: _serviceFee,
                      grandTotal: _grandTotal,
                    ),
                    const SizedBox(height: 20),

                    // ── Section 4: Special Requests ───────────────────────
                    _SectionLabel(
                      label:    'Special Requests',
                      optional: true,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'The property will do its best, but cannot guarantee to fulfil all requests.',
                      style: TextStyle(fontSize: 12, color: AppColors.textLight),
                    ),
                    const SizedBox(height: 10),
                    _SpecialRequestsCard(controller: _requestsCtrl),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // ── Fixed SAVE button ─────────────────────────────────────────
            _SaveButton(onTap: _save),
          ],
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor:  AppColors.background(context),
      elevation:        0,
      surfaceTintColor: Colors.transparent,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.only(left: 16),
          decoration: BoxDecoration(
            color:        AppColors.card(context),
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(color: AppColors.border),
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size:  16,
            color: AppColors.text(context),
          ),
        ),
      ),
      leadingWidth: 58,
      centerTitle:  true,
      title: Text(
        'Guest Info',
        style: TextStyle(
          fontSize:      17,
          fontWeight:    FontWeight.w800,
          color:         AppColors.text(context),
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DAILY — CALENDAR RANGE PICKER CARD
// ─────────────────────────────────────────────────────────────────────────────

class _DailyCalendarCard extends StatelessWidget {
  final DateTime   focusedDay;
  final DateTime?  checkIn;
  final DateTime?  checkOut;
  final void Function(DateTime, DateTime) onDaySelected;
  final bool Function(DateTime) isInRange;
  final bool Function(DateTime) isRangeStart;
  final bool Function(DateTime) isRangeEnd;
  final ValueChanged<DateTime> onFocusChanged;

  const _DailyCalendarCard({
    required this.focusedDay,
    required this.checkIn,
    required this.checkOut,
    required this.onDaySelected,
    required this.isInRange,
    required this.isRangeStart,
    required this.isRangeEnd,
    required this.onFocusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 10),
      child: Column(
        children: [

          // ── Check-in / check-out badges ───────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _DateBadge(
                  label: 'Check-in',
                  date:  checkIn,
                  icon:  Icons.login_rounded,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 16, color: AppColors.textLight),
                ),
                _DateBadge(
                  label: 'Check-out',
                  date:  checkOut,
                  icon:  Icons.logout_rounded,
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── TableCalendar ─────────────────────────────────────────────
          TableCalendar(
            firstDay:  DateTime.now(),
            lastDay:   DateTime.now().add(const Duration(days: 365 * 2)),
            focusedDay: focusedDay,

            // Mark start and end of selection.
            selectedDayPredicate: (day) =>
                isRangeStart(day) || isRangeEnd(day),

            onDaySelected:  onDaySelected,
            onPageChanged:  onFocusChanged,

            calendarStyle: CalendarStyle(
              // Today circle
              todayDecoration: BoxDecoration(
                color: AppColors.primaryOrange.withOpacity(.18),
                shape: BoxShape.circle,
              ),
              todayTextStyle: const TextStyle(
                color:      AppColors.primaryOrange,
                fontWeight: FontWeight.w700,
              ),

              // Range start / end (orange filled circle)
              rangeStartDecoration: const BoxDecoration(
                color: AppColors.primaryOrange,
                shape: BoxShape.circle,
              ),
              rangeEndDecoration: const BoxDecoration(
                color: AppColors.primaryOrange,
                shape: BoxShape.circle,
              ),
              rangeStartTextStyle: const TextStyle(
                color:      Colors.white,
                fontWeight: FontWeight.w700,
              ),
              rangeEndTextStyle: const TextStyle(
                color:      Colors.white,
                fontWeight: FontWeight.w700,
              ),

              // Days within the range (light orange strip)
              withinRangeDecoration: BoxDecoration(
                color: AppColors.primaryOrange.withOpacity(.12),
                shape: BoxShape.rectangle,
              ),
              withinRangeTextStyle: const TextStyle(
                color: AppColors.primaryOrange,
              ),

              // Selected single day (fallback)
              selectedDecoration: const BoxDecoration(
                color: AppColors.primaryOrange,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: const TextStyle(
                color:      Colors.white,
                fontWeight: FontWeight.w700,
              ),

              defaultTextStyle: TextStyle(
                color: AppColors.text(context),
              ),
              weekendTextStyle: TextStyle(
                color: AppColors.text(context),
              ),
              disabledTextStyle: const TextStyle(color: AppColors.textLight),
              outsideTextStyle:  const TextStyle(color: AppColors.textLight),
              outsideDaysVisible: false,
            ),

            // Custom builder to render within-range days as a filled strip.
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (ctx, day, focused) {
                if (isInRange(day)) {
                  return Container(
                    margin:    EdgeInsets.zero,
                    color:     AppColors.primaryOrange.withOpacity(.12),
                    alignment: Alignment.center,
                    child: Text(
                      '${day.day}',
                      style: const TextStyle(
                        color:      AppColors.primaryOrange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }
                return null;
              },
            ),

            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered:       true,
              titleTextStyle: TextStyle(
                fontSize:   15,
                fontWeight: FontWeight.w700,
                color:      AppColors.text(context),
              ),
              leftChevronIcon: Icon(
                Icons.chevron_left_rounded,
                color: AppColors.text(context),
              ),
              rightChevronIcon: Icon(
                Icons.chevron_right_rounded,
                color: AppColors.text(context),
              ),
              headerPadding: const EdgeInsets.symmetric(vertical: 4),
            ),

            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: const TextStyle(
                fontSize:   12,
                fontWeight: FontWeight.w600,
                color:      AppColors.textMid,
              ),
              weekendStyle: const TextStyle(
                fontSize:   12,
                fontWeight: FontWeight.w600,
                color:      AppColors.textMid,
              ),
            ),
          ),

          // ── Nights summary pill ───────────────────────────────────────
          if (checkIn != null && checkOut != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Container(
                width:   double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color:        AppColors.orangeLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.nights_stay_outlined,
                        size: 15, color: AppColors.primaryOrange),
                    const SizedBox(width: 6),
                    Text(
                      () {
                        final n = checkOut!.difference(checkIn!).inDays;
                        return '$n night${n == 1 ? '' : 's'} selected';
                      }(),
                      style: const TextStyle(
                        fontSize:   13,
                        fontWeight: FontWeight.w700,
                        color:      AppColors.primaryOrange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DATE BADGE (inside calendar header row)
// ─────────────────────────────────────────────────────────────────────────────

class _DateBadge extends StatelessWidget {
  final String    label;
  final DateTime? date;
  final IconData  icon;

  const _DateBadge({
    required this.label,
    required this.date,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final hasDate = date != null;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: hasDate ? AppColors.orangeLight : AppColors.background(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasDate ? AppColors.primaryOrange : AppColors.border,
            width: hasDate ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size:  14,
                color: hasDate ? AppColors.primaryOrange : AppColors.textLight),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize:      10,
                      fontWeight:    FontWeight.w600,
                      color:         hasDate
                          ? AppColors.primaryOrange
                          : AppColors.textLight,
                      letterSpacing: 0.2,
                    ),
                  ),
                  Text(
                    hasDate ? GuestInfoModel.fmtDate(date!) : 'Select',
                    style: TextStyle(
                      fontSize:   12.5,
                      fontWeight: FontWeight.w700,
                      color:      hasDate
                          ? AppColors.text(context)
                          : AppColors.textLight,
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
}

// ─────────────────────────────────────────────────────────────────────────────
//  MONTHLY — MOVE-IN DATE + DURATION SELECTOR CARD
// ─────────────────────────────────────────────────────────────────────────────

class _MonthlyDurationCard extends StatelessWidget {
  final int               months;
  final DateTime?         moveInDate;
  final ValueChanged<int> onChanged;
  final VoidCallback      onPickDate;

  const _MonthlyDurationCard({
    required this.months,
    required this.moveInDate,
    required this.onChanged,
    required this.onPickDate,
  });

  @override
  Widget build(BuildContext context) {
    final hasDate = moveInDate != null;
    final endDate = hasDate
        ? DateTime(moveInDate!.year, moveInDate!.month + months, moveInDate!.day)
        : null;

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Move-in date tap target ────────────────────────────────────
          GestureDetector(
            onTap: onPickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: hasDate ? AppColors.orangeLight : AppColors.background(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasDate
                      ? AppColors.primaryOrange
                      : AppColors.border,
                  width: hasDate ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event_rounded,
                    size:  16,
                    color: hasDate ? AppColors.primaryOrange : AppColors.textLight,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Move-in Date',
                          style: TextStyle(
                            fontSize:      10,
                            fontWeight:    FontWeight.w600,
                            color:         hasDate
                                ? AppColors.primaryOrange
                                : AppColors.textLight,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasDate
                              ? GuestInfoModel.fmtDateLong(moveInDate!)
                              : 'Tap to select date',
                          style: TextStyle(
                            fontSize:   13,
                            fontWeight: FontWeight.w700,
                            color:      hasDate
                                ? AppColors.text(context)
                                : AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size:  18,
                    color: AppColors.textLight,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Duration stepper row ───────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color:        AppColors.orangeLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.calendar_month_rounded,
                    size: 18, color: AppColors.primaryOrange),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stay Duration',
                      style: TextStyle(
                        fontSize:   14,
                        fontWeight: FontWeight.w700,
                        color:      AppColors.text(context),
                      ),
                    ),
                    Text(
                      '$months month${months == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color:    AppColors.textMid,
                      ),
                    ),
                  ],
                ),
              ),
              _StepperBtn(
                icon:  Icons.remove_rounded,
                onTap: months > 1 ? () => onChanged(months - 1) : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '$months',
                  style: TextStyle(
                    fontSize:   20,
                    fontWeight: FontWeight.w800,
                    color:      AppColors.text(context),
                  ),
                ),
              ),
              _StepperBtn(
                icon:   Icons.add_rounded,
                onTap:  () => onChanged(months + 1),
                filled: true,
              ),
            ],
          ),

          // ── Expected end date pill ─────────────────────────────────────
          if (hasDate) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color:        AppColors.orangeLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.flag_rounded,
                      size: 13, color: AppColors.primaryOrange),
                  const SizedBox(width: 6),
                  Text(
                    'Expected end: ${GuestInfoModel.fmtDateLong(endDate!)}',
                    style: const TextStyle(
                      fontSize:   12,
                      fontWeight: FontWeight.w600,
                      color:      AppColors.primaryOrange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PRICE SUMMARY CARD
// ─────────────────────────────────────────────────────────────────────────────

class _PriceSummaryCard extends StatelessWidget {
  final RoomOffer room;
  final bool      isDaily;
  final int       nights;
  final int       stayMonths;
  final double    stayTotal;
  final double    serviceFee;
  final double    grandTotal;

  const _PriceSummaryCard({
    required this.room,
    required this.isDaily,
    required this.nights,
    required this.stayMonths,
    required this.stayTotal,
    required this.serviceFee,
    required this.grandTotal,
  });

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    final basePrice  = isDaily
        ? (double.tryParse(room.priceDaily.trim())   ?? 0)
        : (double.tryParse(room.priceMonthly.trim()) ?? 0);
    final unitLabel  = isDaily ? '/day' : '/month';
    final qtyLabel   = isDaily
        ? '$nights night${nights == 1 ? '' : 's'}'
        : '$stayMonths month${stayMonths == 1 ? '' : 's'}';
    final incomplete = isDaily && nights == 0;

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Base rate line ────────────────────────────────────────────
          _SummaryRow(
            label: '₱${_fmt(basePrice)} $unitLabel × $qtyLabel',
            value: incomplete ? '—' : '₱${_fmt(stayTotal)}',
          ),

          // ── Service fee line (only if > 0) ────────────────────────────
          if (serviceFee > 0) ...[
            const SizedBox(height: 8),
            _SummaryRow(
              label: 'Service fee',
              value: '₱${_fmt(serviceFee)}',
            ),
          ],

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(height: 1, color: AppColors.border),
          ),

          // ── Grand total ───────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  fontSize:   15,
                  fontWeight: FontWeight.w800,
                  color:      AppColors.text(context),
                ),
              ),
              Text(
                incomplete ? '—' : '₱${_fmt(grandTotal)}',
                style: const TextStyle(
                  fontSize:   17,
                  fontWeight: FontWeight.w800,
                  color:      AppColors.primaryOrange,
                ),
              ),
            ],
          ),

          // ── Date selection nudge ──────────────────────────────────────
          if (incomplete) ...[
            const SizedBox(height: 8),
            Text(
              'Select your dates above to see the total price.',
              style: TextStyle(fontSize: 12, color: AppColors.textLight),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(fontSize: 13.5, color: AppColors.textMid),
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize:   13.5,
          fontWeight: FontWeight.w600,
          color:      AppColors.text(context),
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION LABEL
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool   optional;
  const _SectionLabel({required this.label, this.optional = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize:      15,
            fontWeight:    FontWeight.w800,
            color:         AppColors.text(context),
            letterSpacing: -0.2,
          ),
        ),
        if (optional) ...[
          const SizedBox(width: 6),
          Text(
            '(Optional)',
            style: const TextStyle(
              fontSize:   12,
              fontWeight: FontWeight.w500,
              color:      AppColors.textLight,
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHARED CARD SHELL
// ─────────────────────────────────────────────────────────────────────────────

class _CardShell extends StatelessWidget {
  final Widget      child;
  final EdgeInsets? padding;
  const _CardShell({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:        AppColors.card(context),
        borderRadius: BorderRadius.circular(22),
        border:       Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(.055),
            blurRadius: 18,
            offset:     const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 1 — GUEST INFO CARD
// ─────────────────────────────────────────────────────────────────────────────

class _GuestInfoCard extends StatelessWidget {
  final TextEditingController firstNameCtrl;
  final TextEditingController lastNameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;

  const _GuestInfoCard({
    required this.firstNameCtrl,
    required this.lastNameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _LabeledField(
                  label:              'First Name',
                  controller:         firstNameCtrl,
                  hint:               'First Name',
                  validator:          _validateName,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters:    [
                    // Literal space only — \s also matches tabs/newlines
                    FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z \-']")),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LabeledField(
                  label:              'Last Name',
                  controller:         lastNameCtrl,
                  hint:               'Last Name',
                  validator:          _validateName,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters:    [
                    FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z \-']")),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _LabeledField(
            label:        'Email Address',
            controller:   emailCtrl,
            hint:         'email@example.com',
            keyboardType: TextInputType.emailAddress,
            prefixIcon:   Icons.email_outlined,
            validator:    _validateEmail,
          ),
          const SizedBox(height: 16),
          _LabeledField(
            label:        'Phone Number',
            controller:   phoneCtrl,
            hint:         '09XXXXXXXXX',
            keyboardType: TextInputType.number,
            prefixIcon:   Icons.phone_outlined,
            validator:    _validatePhone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
            ],
          ),
        ],
      ),
    );
  }

  static String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    if (!RegExp(r"^[a-zA-Z '\-]+$").hasMatch(v.trim())) return 'Letters only';
    return null;
  }

  static String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    if (!RegExp(r'^09\d{9}$').hasMatch(v.trim())) return 'Enter a valid PH number (09XXXXXXXXX)';
    return null;
  }

  static String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final ok =
        RegExp(r'^[\w.+\-]+@[\w\-]+\.[a-zA-Z]{2,}$').hasMatch(v.trim());
    return ok ? null : 'Enter a valid email';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION: SPECIAL REQUESTS
// ─────────────────────────────────────────────────────────────────────────────

class _SpecialRequestsCard extends StatelessWidget {
  final TextEditingController controller;
  const _SpecialRequestsCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      padding: EdgeInsets.zero,
      child: TextFormField(
        controller: controller,
        maxLines:   5,
        minLines:   4,
        style: TextStyle(
          fontSize: 14,
          color:    AppColors.text(context),
          height:   1.5,
        ),
        decoration: InputDecoration(
          hintText: "Let the property know if there's anything they can assist you with.",
          hintStyle: TextStyle(
            fontSize: 13.5,
            color:    AppColors.textLight,
            height:   1.5,
          ),
          contentPadding: const EdgeInsets.all(18),
          border:         InputBorder.none,
          enabledBorder:  InputBorder.none,
          focusedBorder:  InputBorder.none,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  LABELED TEXT FIELD
// ─────────────────────────────────────────────────────────────────────────────

class _LabeledField extends StatelessWidget {
  final String                       label;
  final TextEditingController        controller;
  final String                       hint;
  final TextInputType                keyboardType;
  final IconData?                    prefixIcon;
  final String? Function(String?)?   validator;
  final TextCapitalization           textCapitalization;
  final List<TextInputFormatter>?    inputFormatters;

  const _LabeledField({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType       = TextInputType.text,
    this.prefixIcon,
    this.validator,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize:      12,
            fontWeight:    FontWeight.w600,
            color:         AppColors.textMid,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller:         controller,
          keyboardType:       keyboardType,
          textCapitalization: textCapitalization,
          validator:          validator,
          inputFormatters:    inputFormatters,
          style: TextStyle(
            fontSize:   14,
            fontWeight: FontWeight.w600,
            color:      AppColors.text(context),
          ),
          decoration: InputDecoration(
            hintText:  hint,
            hintStyle: const TextStyle(
              fontSize:   14,
              color:      AppColors.textLight,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 18, color: AppColors.textLight)
                : null,
            filled:    true,
            fillColor: AppColors.background(context),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 13),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:   BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:   const BorderSide(
                  color: AppColors.primaryOrange, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:   const BorderSide(color: AppColors.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:   const BorderSide(
                  color: AppColors.danger, width: 1.5),
            ),
            errorStyle: const TextStyle(
              fontSize: 11,
              color:    AppColors.danger,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  STEPPER BUTTON (shared by monthly card)
// ─────────────────────────────────────────────────────────────────────────────

class _StepperBtn extends StatelessWidget {
  final IconData      icon;
  final VoidCallback? onTap;
  final bool          filled;

  const _StepperBtn({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width:  34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled
              ? (enabled ? AppColors.primaryOrange : AppColors.border)
              : AppColors.background(context),
          border: filled
              ? null
              : Border.all(
                  color: enabled ? AppColors.primaryOrange : AppColors.border,
                  width: 1.5,
                ),
        ),
        child: Icon(
          icon,
          size:  16,
          color: filled
              ? Colors.white
              : (enabled ? AppColors.primaryOrange : AppColors.textLight),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SAVE BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SaveButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color:  AppColors.background(context),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [Color(0xFFFF8C00), AppColors.primaryOrange],
              begin:  Alignment.centerLeft,
              end:    Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color:      AppColors.primaryOrange.withOpacity(.38),
                blurRadius: 18,
                offset:     const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text(
            'SAVE',
            style: TextStyle(
              color:         Colors.white,
              fontSize:      16,
              fontWeight:    FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}