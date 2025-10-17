// lib/models/compliance_data.dart

class ComplianceData {
  final int dosesTaken;
  final int dosesMissed;
  final int totalDoses;

  ComplianceData({
    required this.dosesTaken,
    required this.dosesMissed,
    required this.totalDoses,
  });

  // Tính tỷ lệ tuân thủ từ 0.0 đến 1.0
  double get compliance {
    if (totalDoses == 0) {
      return 0.0;
    }
    return dosesTaken / totalDoses;
  }
}
