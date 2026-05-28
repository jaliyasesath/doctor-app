class PrescriptionItem {
  final String medicineName;
  final String dosage;
  final String frequency;
  final String duration;
  final String instructions;

  final bool prescriptionOnly;
  final double unitPrice;
  final double quantity;
  final double lineTotal;

  PrescriptionItem({
    required this.medicineName,
    required this.dosage,
    required this.frequency,
    required this.duration,
    required this.instructions,
    this.prescriptionOnly = false,
    this.unitPrice = 0,
    this.quantity = 1,
    this.lineTotal = 0,
  });
}