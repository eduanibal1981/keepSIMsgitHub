/// A duration intent contains no client-calculated price or supplier authority.
class EsimDailySelection {
  const EsimDailySelection({
    required this.packageId,
    required this.days,
    this.profileId,
    this.offerVersion,
    this.quantity = 1,
  });
  final String packageId;
  final int days, quantity;
  final String? profileId, offerVersion;
  bool get valid =>
      days >= 1 &&
      days <= 365 &&
      quantity >= 1 &&
      quantity <= 3 &&
      packageId.isNotEmpty &&
      (profileId == null || offerVersion != null);
  @override
  bool operator ==(Object other) =>
      other is EsimDailySelection &&
      packageId == other.packageId &&
      days == other.days &&
      quantity == other.quantity &&
      profileId == other.profileId &&
      offerVersion == other.offerVersion;
  @override
  int get hashCode =>
      Object.hash(packageId, days, quantity, profileId, offerVersion);
}
