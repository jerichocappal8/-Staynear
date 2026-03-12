class RentalTerms {
  final int minimumStayMonths;
  final double securityDepositAmount;
  final int advanceMonthsRequired;

  const RentalTerms({
    required this.minimumStayMonths,
    required this.securityDepositAmount,
    required this.advanceMonthsRequired,
  });

  factory RentalTerms.fromMap(Map<String, dynamic> m) => RentalTerms(
        minimumStayMonths: (m['minimumStayMonths'] ?? 1) as int,
        securityDepositAmount: (m['securityDepositAmount'] ?? 0 as num).toDouble(),
        advanceMonthsRequired: (m['advanceMonthsRequired'] ?? 1) as int,
      );

  static RentalTerms empty() => const RentalTerms(
        minimumStayMonths: 1,
        securityDepositAmount: 0,
        advanceMonthsRequired: 1,
      );
}