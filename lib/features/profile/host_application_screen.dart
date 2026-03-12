import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart'; // add intl to pubspec.yaml
import 'package:staynear/core/app_colors.dart';

// ── PH Address data ───────────────────────────────────────────────────────────
const _phRegions = [
  'NCR – Metro Manila',
  'Region I – Ilocos Region',
  'Region II – Cagayan Valley',
  'Region III – Central Luzon',
  'Region IV-A – CALABARZON',
  'Region IV-B – MIMAROPA',
  'Region V – Bicol Region',
  'Region VI – Western Visayas',
  'Region VII – Central Visayas',
  'Region VIII – Eastern Visayas',
  'Region IX – Zamboanga Peninsula',
  'Region X – Northern Mindanao',
  'Region XI – Davao Region',
  'Region XII – SOCCSKSARGEN',
  'Region XIII – Caraga',
  'BARMM',
  'CAR – Cordillera Administrative Region',
];
const _phIdTypes = [
  'Philippine System ID (PhilSys)',
  'Passport',
  "Driver's License",
  'UMID / SSS ID',
  'Postal ID',
  "Voter's ID",
  'PRC ID',
  'Senior Citizen ID',
  'PWD ID',
  'Other Government-Issued ID',
];
// ─────────────────────────────────────────────────────────────────────────────
class HostApplicationScreen extends StatefulWidget {
  const HostApplicationScreen({super.key});
  @override
  State<HostApplicationScreen> createState() => _HostApplicationScreenState();
}
class _HostApplicationScreenState extends State<HostApplicationScreen>
    with TickerProviderStateMixin {
  // ── Wizard ────────────────────────────────────────────────────────────────
  int _step = 0;
  final _pageCtrl = PageController();
  // ── Step 1 – Identity ─────────────────────────────────────────────────────
  final lastNameCtrl   = TextEditingController();
  final firstNameCtrl  = TextEditingController();
  final middleNameCtrl = TextEditingController();
  final phoneCtrl      = TextEditingController();
  DateTime? _dob;
  String? _gender;
  String get _fullName {
    final parts = [
      firstNameCtrl.text.trim(),
      middleNameCtrl.text.trim(),
      lastNameCtrl.text.trim(),
    ].where((p) => p.isNotEmpty);
    return parts.join(' ');
  }
  // ── Step 2 – Address ──────────────────────────────────────────────────────
  String? _region;
  final provinceCtrl  = TextEditingController();
  final cityCtrl      = TextEditingController();
  final barangayCtrl  = TextEditingController();
  final streetCtrl    = TextEditingController();
  final zipCtrl       = TextEditingController();
  // ── Step 3 – Documents ────────────────────────────────────────────────────
  File? profileImage;
  File? governmentIdImage;
  File? secondaryCardImage;
  String? _idType;
  bool _consentGiven  = false;
  bool _showSecondary = false;
  // ── Misc ──────────────────────────────────────────────────────────────────
  bool loading         = false;
  bool profileRequired = false;
  final picker         = ImagePicker();
  final Map<String, String?> _step1Errors = {};
  final Map<String, String?> _step2Errors = {};
  final Map<String, String?> _step3Errors = {};
  late final AnimationController _heroAnim;
  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _heroAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _checkProfilePhoto();
    for (final c in [lastNameCtrl, firstNameCtrl, middleNameCtrl]) {
      c.addListener(() => setState(() {}));
    }
    for (final c in [cityCtrl, streetCtrl, barangayCtrl]) {
      c.addListener(() => setState(() {}));
    }
  }
  @override
  void dispose() {
    _heroAnim.dispose();
    _pageCtrl.dispose();
    for (final c in [lastNameCtrl, firstNameCtrl, middleNameCtrl,
        phoneCtrl, provinceCtrl, cityCtrl, barangayCtrl, streetCtrl, zipCtrl]) {
      c.dispose();
    }
    super.dispose();
  }
  Future<void> _checkProfilePhoto() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final photo = doc.data()?['photo'];
    if (photo == null || !photo.toString().startsWith('http')) {
      setState(() => profileRequired = true);
    }
    _heroAnim.forward();
  }
  // ── Validation ────────────────────────────────────────────────────────────
  bool _validateStep1() {
    final errs = <String, String?>{};
    if (lastNameCtrl.text.trim().isEmpty)  errs['lastName']  = 'Last name is required';
    if (firstNameCtrl.text.trim().isEmpty) errs['firstName'] = 'First name is required';
    if (phoneCtrl.text.trim().isEmpty) {
      errs['phone'] = 'Phone number is required';
    } else if (!RegExp(r'^(09|\+639)\d{9}$').hasMatch(phoneCtrl.text.trim())) {
      errs['phone'] = 'Enter a valid PH number (09XXXXXXXXX)';
    }
    if (_dob == null) {
      errs['dob'] = 'Date of birth is required';
    } else {
      final age = DateTime.now().difference(_dob!).inDays ~/ 365;
      if (age < 18) errs['dob'] = 'You must be at least 18 years old';
    }
    if (_gender == null) errs['gender'] = 'Please select your gender';
    setState(() { _step1Errors.clear(); _step1Errors.addAll(errs); });
    return errs.isEmpty;
  }
  bool _validateStep2() {
    final errs = <String, String?>{};
    if (_region == null)                  errs['region']   = 'Select your region';
    if (provinceCtrl.text.trim().isEmpty) errs['province'] = 'Province is required';
    if (cityCtrl.text.trim().isEmpty)     errs['city']     = 'City / Municipality is required';
    if (barangayCtrl.text.trim().isEmpty) errs['barangay'] = 'Barangay is required';
    if (streetCtrl.text.trim().isEmpty)   errs['street']   = 'Street / House No. is required';
    setState(() { _step2Errors.clear(); _step2Errors.addAll(errs); });
    return errs.isEmpty;
  }
  bool _validateStep3() {
    final errs = <String, String?>{};
    if (profileRequired && profileImage == null) errs['profile'] = 'Profile photo is required';
    if (_idType == null)                         errs['idType']  = 'Select an ID type';
    if (governmentIdImage == null)               errs['govId']   = 'Upload your government ID';
    if (!_consentGiven)                          errs['consent'] = 'Please confirm your consent to proceed';
    setState(() { _step3Errors.clear(); _step3Errors.addAll(errs); });
    return errs.isEmpty;
  }
  // ── Navigation ────────────────────────────────────────────────────────────
  void _nextStep() {
    final valid = _step == 0 ? _validateStep1() : _validateStep2();
    if (!valid) return;
    setState(() => _step++);
    _pageCtrl.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
  }
  void _prevStep() {
    if (_step == 0) { Navigator.pop(context); return; }
    setState(() => _step--);
    _pageCtrl.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
  }
  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_validateStep3()) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    setState(() => loading = true);
    try {
      if (profileRequired && profileImage != null) {
        final url = await _uploadImage(profileImage!, 'profile_photos/$uid.jpg');
        await FirebaseFirestore.instance.collection('users').doc(uid).update({'photo': url});
      }
      final govUrl = await _uploadImage(governmentIdImage!, 'host_verification/$uid/government_id.jpg');
      String? secUrl;
      if (secondaryCardImage != null) {
        secUrl = await _uploadImage(secondaryCardImage!, 'host_verification/$uid/secondary_card.jpg');
      }
      final age = DateTime.now().difference(_dob!).inDays ~/ 365;
      await FirebaseFirestore.instance
          .collection('host_requests')
          .doc(uid)
          .set({
        'userId': uid,
        // Name
        'firstName': firstNameCtrl.text.trim(),
        'middleName': middleNameCtrl.text.trim(),
        'lastName': lastNameCtrl.text.trim(),
        'fullName': _fullName,
        // Contact
        'phone': phoneCtrl.text.trim(),
        // Personal
        'dateOfBirth': _dob!.toIso8601String(),
        'age': age,
        'gender': _gender,
        // Structured address
        'address': {
          'street': streetCtrl.text.trim(),
          'barangay': barangayCtrl.text.trim(),
          'city': cityCtrl.text.trim(),
          'province': provinceCtrl.text.trim(),
          'region': _region,
          'zipCode': zipCtrl.text.trim(),
        },
        // Documents
        'idType': _idType,
        'governmentIdUrl': govUrl,
        'secondaryIdUrl': secUrl,
        // Status
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance
          .collection('users').doc(uid).update({'hostRequest': 'pending'});
      setState(() => loading = false);
      if (!mounted) return;
      Navigator.pop(context);
      _showSnack("Application submitted! We'll review within 24 hours ✓");
    } catch (e) {
      setState(() => loading = false);
      _showSnack("Something went wrong. Please try again.", isError: true);
    }
  }
  // ── Helpers ───────────────────────────────────────────────────────────────
  Future<String> _uploadImage(File file, String path) async {
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putFile(file);
    return ref.getDownloadURL();
  }
  Future<File?> _pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return null;
    return File(picked.path);
  }
  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
      backgroundColor: isError ? AppColors.danger : AppColors.primaryOrange,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }
  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25),
      firstDate: DateTime(1930),
      lastDate: DateTime(now.year - 15),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primaryOrange, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() { _dob = picked; _step1Errors.remove('dob'); });
  }
  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: Column(
        children: [
          _buildHeader(),
          _buildStepIndicator(),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [_buildStep1(), _buildStep2(), _buildStep3()],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }
  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    const titles    = ['Your Identity',    'Your Address',       'Verification Docs'];
    const subtitles = [
      'Personal information matching your ID',
      'Where are you located?',
      'Upload your documents for review',
    ];
    return Container(
      decoration: const BoxDecoration(
  color: AppColors.primaryOrange,
),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Row(
            children: [
              GestureDetector(
                onTap: _prevStep,
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titles[_step], style: const TextStyle(
                      color: Colors.white, fontSize: 22,
                      fontWeight: FontWeight.w800, letterSpacing: -0.4,
                    )),
                    Text(subtitles[_step],
                        style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Step ${_step + 1} of 3',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
  // ── Step indicator ────────────────────────────────────────────────────────
  Widget _buildStepIndicator() {
    const labels = ['Identity', 'Address', 'Documents'];
    return Container(
      color: AppColors.primaryOrange,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: List.generate(3, (i) {
          final done    = i < _step;
          final current = i == _step;
          return Expanded(
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: done || current ? Colors.white : Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: done
                        ? const Icon(Icons.check, size: 13, color: AppColors.primaryOrange)
                        : Text('${i + 1}', style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800,
                            color: current ? AppColors.primaryOrange : Colors.white.withOpacity(0.5))),
                  ),
                ),
                const SizedBox(width: 5),
                Text(labels[i], style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: current || done ? Colors.white : Colors.white.withOpacity(0.45),
                )),
                if (i < 2) ...[
                  const SizedBox(width: 5),
                  Expanded(child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    height: 2,
                    decoration: BoxDecoration(
                      color: done ? Colors.white : Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  )),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }
  // ── Bottom bar ────────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    final isLast = _step == 2;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 12, offset: const Offset(0, -3))],
      ),
      child: SizedBox(
        width: double.infinity, height: 52,
        child: ElevatedButton(
          onPressed: loading ? null : (isLast ? _submit : _nextStep),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryOrange, foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.orangeLight.withOpacity(0.4),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: loading
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(isLast ? 'Submit Application' : 'Continue',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  Icon(isLast ? Icons.send_rounded : Icons.arrow_forward_rounded, size: 18),
                ]),
        ),
      ),
    );
  }
  // ══════════════════════════════════════════════════════════════════════════
  // STEP 1 – IDENTITY
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel(Icons.badge_outlined, 'Legal Name'),
        const SizedBox(height: 4),
        _hint('Enter your name exactly as it appears on your government ID.'),
        const SizedBox(height: 12),
        _FormCard(children: [
          _FormField(
            controller: lastNameCtrl, label: 'Last Name (Surname)',
            icon: Icons.person_outline, error: _step1Errors['lastName'],
            onChanged: (_) => setState(() => _step1Errors.remove('lastName')),
          ),
          _divider(),
          IntrinsicHeight(
            child: Row(children: [
              Expanded(flex: 5, child: _FormField(
                controller: firstNameCtrl, label: 'First Name',
                icon: null, error: _step1Errors['firstName'],
                onChanged: (_) => setState(() => _step1Errors.remove('firstName')),
              )),
              VerticalDivider(width: 1, color: Colors.grey.shade100),
              Expanded(flex: 4, child: _FormField(
                controller: middleNameCtrl, label: 'Middle Name',
                icon: null, hint: 'Optional', error: null,
                onChanged: (_) => setState(() {}),
              )),
            ]),
          ),
        ]),
        if (_fullName.isNotEmpty) ...[
          const SizedBox(height: 10),
          _FullNamePreview(name: _fullName),
        ],
        const SizedBox(height: 22),
        _sectionLabel(Icons.cake_outlined, 'Date of Birth & Gender'),
        const SizedBox(height: 12),
        _FormCard(children: [
          GestureDetector(
            onTap: _pickDob,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Icon(Icons.calendar_today_outlined, size: 19,
                    color: _step1Errors['dob'] != null ? AppColors.danger : AppColors.orangeLight),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Date of Birth', style: TextStyle(
                      fontSize: 11.5, color: _step1Errors['dob'] != null ? AppColors.danger : AppColors.textMid)),
                  const SizedBox(height: 2),
                  Text(
                    _dob != null ? DateFormat('MMMM d, yyyy').format(_dob!) : 'Select date',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500,
                        color: _dob != null ? AppColors.text(context) : AppColors.textMid.withOpacity(0.5)),
                  ),
                  if (_step1Errors['dob'] != null)
                    Padding(padding: const EdgeInsets.only(top: 3),
                        child: Text(_step1Errors['dob']!,
                            style: const TextStyle(color: AppColors.danger, fontSize: 11))),
                ])),
                const Icon(Icons.chevron_right, color: AppColors.textMid, size: 20),
              ]),
            ),
          ),
          if (_dob != null) ...[
            _divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                const Icon(Icons.info_outline, size: 14, color: AppColors.textMid),
                const SizedBox(width: 8),
                Text('Age: ${DateTime.now().difference(_dob!).inDays ~/ 365} years old',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textMid)),
              ]),
            ),
          ],
          _divider(),
          _DropdownField<String>(
            value: _gender, label: 'Gender', icon: Icons.wc_outlined,
            error: _step1Errors['gender'],
            items: const ['Male', 'Female', 'Prefer not to say'],
            onChanged: (v) => setState(() { _gender = v; _step1Errors.remove('gender'); }),
          ),
        ]),
        const SizedBox(height: 22),
        _sectionLabel(Icons.phone_outlined, 'Contact'),
        const SizedBox(height: 12),
        _FormCard(children: [
          _FormField(
            controller: phoneCtrl, label: 'Phone Number',
            icon: Icons.phone_outlined, hint: '09XXXXXXXXX',
            inputType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(11)],
            error: _step1Errors['phone'],
            prefix: _phPrefix(),
            onChanged: (_) => setState(() => _step1Errors.remove('phone')),
          ),
        ]),
        const SizedBox(height: 80),
      ]),
    );
  }
  // ══════════════════════════════════════════════════════════════════════════
  // STEP 2 – ADDRESS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel(Icons.map_outlined, 'Region & Province'),
        const SizedBox(height: 4),
        _hint('Select your region first, then fill in the remaining fields.'),
        const SizedBox(height: 12),
        _FormCard(children: [
          _DropdownField<String>(
            value: _region, label: 'Region', icon: Icons.public_outlined,
            error: _step2Errors['region'], items: _phRegions,
            onChanged: (v) => setState(() { _region = v; _step2Errors.remove('region'); }),
          ),
          _divider(),
          _FormField(
            controller: provinceCtrl, label: 'Province',
            icon: Icons.location_city_outlined, error: _step2Errors['province'],
            onChanged: (_) => setState(() => _step2Errors.remove('province')),
          ),
          _divider(),
          _FormField(
            controller: cityCtrl, label: 'City / Municipality',
            icon: Icons.apartment_outlined, error: _step2Errors['city'],
            onChanged: (_) => setState(() => _step2Errors.remove('city')),
          ),
        ]),
        const SizedBox(height: 22),
        _sectionLabel(Icons.signpost_outlined, 'Specific Location'),
        const SizedBox(height: 12),
        _FormCard(children: [
          _FormField(
            controller: barangayCtrl, label: 'Barangay',
            icon: Icons.home_work_outlined, error: _step2Errors['barangay'],
            onChanged: (_) => setState(() => _step2Errors.remove('barangay')),
          ),
          _divider(),
          _FormField(
            controller: streetCtrl, label: 'Street / House No. / Building',
            icon: Icons.streetview_outlined, error: _step2Errors['street'],
            onChanged: (_) => setState(() => _step2Errors.remove('street')),
          ),
          _divider(),
          _FormField(
            controller: zipCtrl, label: 'ZIP Code (optional)',
            icon: Icons.pin_outlined, inputType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4)],
            error: null, onChanged: (_) {},
          ),
        ]),
        if (_region != null && cityCtrl.text.isNotEmpty && streetCtrl.text.isNotEmpty) ...[
          const SizedBox(height: 16),
          _AddressPreview(
            street: streetCtrl.text.trim(), barangay: barangayCtrl.text.trim(),
            city: cityCtrl.text.trim(), province: provinceCtrl.text.trim(),
            region: _region!, zip: zipCtrl.text.trim(),
          ),
        ],
        const SizedBox(height: 80),
      ]),
    );
  }
  // ══════════════════════════════════════════════════════════════════════════
  // STEP 3 – DOCUMENTS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (profileRequired) ...[
          _sectionLabel(Icons.person_outline, 'Profile Photo'),
          const SizedBox(height: 4),
          _hint('A clear photo of your face. This will be shown to guests.'),
          const SizedBox(height: 12),
          _ProfileUploadBox(
            image: profileImage, error: _step3Errors['profile'],
            onTap: () async {
              final img = await _pickImage();
              if (img != null) setState(() { profileImage = img; _step3Errors.remove('profile'); });
            },
          ),
          const SizedBox(height: 24),
        ],
        _sectionLabel(Icons.verified_user_outlined, 'Government ID'),
        const SizedBox(height: 4),
        _hint('Upload a clear, unobstructed photo of your valid government ID.'),
        const SizedBox(height: 12),
        _FormCard(children: [
          _DropdownField<String>(
            value: _idType, label: 'ID Type', icon: Icons.credit_card_outlined,
            error: _step3Errors['idType'], items: _phIdTypes,
            onChanged: (v) => setState(() { _idType = v; _step3Errors.remove('idType'); }),
          ),
        ]),
        const SizedBox(height: 12),
        _DocUploadTile(
          label: 'Government ID', subtitle: _idType ?? 'Select ID type above first',
          icon: Icons.credit_card_outlined, image: governmentIdImage,
          required: true, error: _step3Errors['govId'],
          onTap: () async {
            final img = await _pickImage();
            if (img != null) setState(() { governmentIdImage = img; _step3Errors.remove('govId'); });
          },
        ),
        const SizedBox(height: 22),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _sectionLabel(Icons.school_outlined, 'Secondary ID'),
          GestureDetector(
            onTap: () => setState(() => _showSecondary = !_showSecondary),
            child: Text(_showSecondary ? 'Hide' : '+ Add (Optional)',
                style: const TextStyle(color: AppColors.primaryOrange, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ]),
        if (_showSecondary) ...[
          const SizedBox(height: 4),
          _hint('School ID, Company ID, or any secondary identification.'),
          const SizedBox(height: 12),
          _DocUploadTile(
            label: 'Secondary Card', subtitle: 'School / Company ID',
            icon: Icons.school_outlined, image: secondaryCardImage,
            required: false, error: null,
            onTap: () async {
              final img = await _pickImage();
              if (img != null) setState(() => secondaryCardImage = img);
            },
          ),
        ],
        const SizedBox(height: 20),
        _ExpandableInfo(
          title: 'Why do we need your documents?',
          content: 'We verify your identity to keep the community safe. '
              'Your documents are encrypted, stored securely, and never shared with guests. '
              'Only our trust & safety team reviews them during the approval process.',
        ),
        const SizedBox(height: 14),
        // Security badge
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.orangeLight, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            const Icon(Icons.lock_outline, color: AppColors.primaryOrange, size: 18),
            const SizedBox(width: 10),
            const Expanded(child: Text(
              'Your data is encrypted and reviewed only by our trust & safety team. '
              'Usually approved within 24 hours.',
              style: TextStyle(color: AppColors.primaryOrange, fontSize: 12.5, height: 1.5),
            )),
          ]),
        ),
        const SizedBox(height: 14),
        // Consent
        GestureDetector(
          onTap: () => setState(() {
            _consentGiven = !_consentGiven;
            if (_consentGiven) _step3Errors.remove('consent');
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _consentGiven ? AppColors.orangeLight : AppColors.card(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _step3Errors['consent'] != null ? AppColors.danger
                    : _consentGiven ? AppColors.primaryOrange : Colors.grey.shade300,
              ),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: _consentGiven ? AppColors.primaryOrange : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _consentGiven ? AppColors.primaryOrange : Colors.grey.shade400, width: 1.5),
                ),
                child: _consentGiven ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  'I confirm that all documents and information I have provided are authentic, accurate, and belong to me.',
                  style: TextStyle(fontSize: 13, color: AppColors.text(context), height: 1.4),
                ),
                if (_step3Errors['consent'] != null)
                  Padding(padding: const EdgeInsets.only(top: 4),
                      child: Text(_step3Errors['consent']!,
                          style: const TextStyle(color: AppColors.danger, fontSize: 11))),
              ])),
            ]),
          ),
        ),
        const SizedBox(height: 80),
      ]),
    );
  }
  // ── Shared helpers ────────────────────────────────────────────────────────
  Widget _sectionLabel(IconData icon, String label) => Row(children: [
    Icon(icon, size: 15, color: AppColors.primaryOrange), const SizedBox(width: 6),
    Text(label.toUpperCase(), style: const TextStyle(
      fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.primaryOrange, letterSpacing: 1.4)),
  ]);
  Widget _hint(String text) => Text(text,
      style: const TextStyle(fontSize: 12.5, color: AppColors.textMid, height: 1.4));
  Widget _divider() => Divider(height: 1, indent: 16, endIndent: 16, color: Colors.grey.shade100);
  Widget _phPrefix() => Padding(
    padding: const EdgeInsets.only(left: 16, right: 4),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Text('🇵🇭', style: TextStyle(fontSize: 16)),
      const SizedBox(width: 4),
      Text('+63', style: const TextStyle(fontSize: 13, color: AppColors.textMid, fontWeight: FontWeight.w600)),
      Container(width: 1, height: 18, color: Colors.grey.shade300,
          margin: const EdgeInsets.symmetric(horizontal: 8)),
    ]),
  );
}
// ══════════════════════════════════════════════════════════════════════════════
// REUSABLE COMPONENTS
// ══════════════════════════════════════════════════════════════════════════════
class _FormCard extends StatelessWidget {
  const _FormCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.card(context), borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.055), blurRadius: 14, offset: const Offset(0, 4))],
    ),
    child: Column(children: children),
  );
}
class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller, required this.label, required this.icon,
    required this.error, required this.onChanged,
    this.hint, this.inputType, this.inputFormatters, this.prefix,
  });
  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final String? hint, error;
  final TextInputType? inputType;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? prefix;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: inputType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.text(context)),
      cursorColor: AppColors.primaryOrange,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: AppColors.textMid.withOpacity(0.45)),
        labelStyle: TextStyle(fontSize: 13, color: error != null ? AppColors.danger : AppColors.textMid),
        floatingLabelStyle: TextStyle(color: error != null ? AppColors.danger : AppColors.primaryOrange, fontSize: 12),
        prefixIcon: prefix ?? (icon != null ? Icon(icon, size: 19, color: AppColors.orangeLight) : null),
        suffixIcon: error != null
            ? const Icon(Icons.error_outline, size: 18, color: AppColors.danger)
            : controller.text.isNotEmpty
                ? const Icon(Icons.check_circle_outline, size: 18, color: Colors.green)
                : null,
        errorText: error,
        errorStyle: const TextStyle(fontSize: 11, color: AppColors.danger),
        border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.value,
    required this.label,
    required this.icon,
    required this.error,
    required this.items,
    required this.onChanged,
  });
  final T? value;
  final String label;
  final IconData icon;
  final String? error;
  final List<String> items;
  final ValueChanged<T?> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: DropdownButtonFormField<T>(
      isExpanded: true,
      value: value,
      onChanged: onChanged,
      dropdownColor: AppColors.card(context),
      icon: const Icon(Icons.expand_more, color: AppColors.primaryOrange),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 13, color: error != null ? AppColors.danger : AppColors.textMid),
        floatingLabelStyle: TextStyle(color: error != null ? AppColors.danger : AppColors.primaryOrange, fontSize: 12),
        prefixIcon: Icon(icon, size: 19, color: AppColors.orangeLight),
        errorText: error,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
      ),
      items: items.map((item) => DropdownMenuItem<T>(
        value: item as T,
        child: Text(
          item,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13.5, color: AppColors.text(context)),
        ),
      )).toList(),
    ),
  );
}
class _FullNamePreview extends StatelessWidget {
  const _FullNamePreview({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: name.isEmpty ? 0 : 1,
    duration: const Duration(milliseconds: 300),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.orangeLight, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        const Icon(Icons.preview_outlined, size: 15, color: AppColors.primaryOrange),
        const SizedBox(width: 8),
        const Text('Full name: ', style: TextStyle(fontSize: 12.5, color: AppColors.primaryOrange)),
        Expanded(child: Text(name,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryOrange),
          overflow: TextOverflow.ellipsis)),
      ]),
    ),
  );
}
class _AddressPreview extends StatelessWidget {
  const _AddressPreview({
    required this.street, required this.barangay, required this.city,
    required this.province, required this.region, required this.zip,
  });
  final String street, barangay, city, province, region, zip;
  @override
  Widget build(BuildContext context) {
    final parts = [street, barangay, city, province, region, if (zip.isNotEmpty) zip]
        .where((p) => p.isNotEmpty);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.orangeLight, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.location_on_outlined, color: AppColors.primaryOrange, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Address preview',
              style: TextStyle(fontSize: 11, color: AppColors.primaryOrange, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(parts.join(', '),
              style: const TextStyle(fontSize: 13, color: AppColors.primaryOrange, height: 1.4)),
        ])),
      ]),
    );
  }
}
class _ProfileUploadBox extends StatelessWidget {
  const _ProfileUploadBox({required this.image, required this.error, required this.onTap});
  final File? image;
  final String? error;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(children: [
      GestureDetector(
        onTap: onTap,
        child: Stack(children: [
          Container(
            width: 110, height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle, color: AppColors.orangeLight,
              border: Border.all(
                color: error != null ? AppColors.danger : image != null ? AppColors.primaryOrange : AppColors.border, width: 2),
              image: image != null
                  ? DecorationImage(image: FileImage(image!), fit: BoxFit.cover) : null,
            ),
            child: image == null
                ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_a_photo_outlined, size: 28, color: AppColors.primaryOrange),
                    SizedBox(height: 4),
                    Text('Tap to add', style: TextStyle(fontSize: 10, color: AppColors.primaryOrange, fontWeight: FontWeight.w600)),
                  ]) : null,
          ),
          Positioned(bottom: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: AppColors.primaryOrange, shape: BoxShape.circle),
              child: Icon(image == null ? Icons.add : Icons.edit, size: 14, color: Colors.white),
            )),
        ]),
      ),
      if (error != null) Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(error!, style: const TextStyle(color: AppColors.danger, fontSize: 11.5)),
      ),
    ]),
  );
}
class _DocUploadTile extends StatelessWidget {
  const _DocUploadTile({
    required this.label, required this.subtitle, required this.icon,
    required this.image, required this.required, required this.error, required this.onTap,
  });
  final String label, subtitle;
  final IconData icon;
  final File? image;
  final bool required;
  final String? error;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final uploaded = image != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: uploaded ? AppColors.orangeLight : AppColors.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: error != null ? AppColors.danger : uploaded ? AppColors.primaryOrange : Colors.grey.shade200,
            width: uploaded || error != null ? 1.5 : 1,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: uploaded
            ? ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Stack(children: [
                  SizedBox(height: 140, width: double.infinity,
                      child: Image.file(image!, fit: BoxFit.cover)),
                  Positioned(top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.primaryOrange, borderRadius: BorderRadius.circular(20)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.check_circle, size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text('Uploaded', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      ]),
                    )),
                  Positioned(bottom: 8, right: 8,
                    child: Container(padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: AppColors.primaryOrange, shape: BoxShape.circle),
                      child: const Icon(Icons.edit, size: 14, color: Colors.white),
                    )),
                ]))
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Row(children: [
                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        color: error != null ? AppColors.danger.withOpacity(0.08) : AppColors.orangeLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: error != null ? AppColors.danger : AppColors.primaryOrange, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(label, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.text(context))),
                        if (required) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.primaryOrange, borderRadius: BorderRadius.circular(4)),
                            child: const Text('Required', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 3),
                      Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMid)),
                    ])),
                    Icon(Icons.upload_rounded, color: error != null ? AppColors.danger : AppColors.primaryOrange, size: 22),
                  ]),
                  if (error != null) Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(children: [
                      const Icon(Icons.error_outline, size: 13, color: AppColors.danger),
                      const SizedBox(width: 4),
                      Text(error!, style: const TextStyle(color: AppColors.danger, fontSize: 11.5)),
                    ]),
                  ),
                ]),
              ),
      ),
    );
  }
}
class _ExpandableInfo extends StatefulWidget {
  const _ExpandableInfo({required this.title, required this.content});
  final String title, content;
  @override
  State<_ExpandableInfo> createState() => _ExpandableInfoState();
}
class _ExpandableInfoState extends State<_ExpandableInfo> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => setState(() => _expanded = !_expanded),
    child: Container(
      decoration: BoxDecoration(
        color: AppColors.card(context), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            const Icon(Icons.help_outline, size: 17, color: AppColors.textMid),
            const SizedBox(width: 10),
            Expanded(child: Text(widget.title,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text(context)))),
            const Icon(Icons.expand_more, size: 18, color: AppColors.textMid),
          ]),
        ),
        if (_expanded) Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Text(widget.content,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textMid, height: 1.5)),
        ),
      ]),
    ),
  );
}