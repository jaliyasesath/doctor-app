class StockValidation {
  const StockValidation._();

  static String? receive({
    required String batchNumber,
    required num quantity,
    required num costPrice,
    required num sellingPrice,
    DateTime? expiryDate,
    DateTime? now,
  }) {
    if (batchNumber.trim().isEmpty) return 'Batch number is required.';
    if (!quantity.isFinite) return 'Quantity must be a valid number.';
    if (quantity <= 0) return 'Quantity must be greater than zero.';
    if (!costPrice.isFinite ||
        !sellingPrice.isFinite ||
        costPrice < 0 ||
        sellingPrice < 0) {
      return 'Prices cannot be negative.';
    }
    if (expiryDate != null) {
      final current = now ?? DateTime.now();
      final today = DateTime(current.year, current.month, current.day);
      final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
      if (expiry.isBefore(today)) return 'Expired stock cannot be received.';
    }
    return null;
  }

  static String? adjustment({
    required num quantity,
    required String reason,
  }) {
    if (!quantity.isFinite) return 'Quantity must be a valid number.';
    if (quantity <= 0) return 'Quantity must be greater than zero.';
    if (reason.trim().isEmpty) return 'Adjustment reason is required.';
    return null;
  }
}
