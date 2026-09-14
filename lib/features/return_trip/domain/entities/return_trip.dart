/// Return Trip Entity
library;

class ReturnTrip {
  final String id;
  final String userId;
  final String simLineId;
  final String destinationCountryId;
  final DateTime arrivalDate;
  final String status; // 'planning', 'data_ready', 'arrived', 'completed', 'cancelled'
  final String? chosenPackageType; // 'esim', 'carrier_ussd', 'physical_voucher'
  final String? chosenPackageId;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ReturnTrip({
    required this.id,
    required this.userId,
    required this.simLineId,
    required this.destinationCountryId,
    required this.arrivalDate,
    required this.status,
    this.chosenPackageType,
    this.chosenPackageId,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isReady => status == 'data_ready' || status == 'arrived';

  factory ReturnTrip.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return ReturnTrip(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      simLineId: json['sim_line_id'] as String? ?? '',
      destinationCountryId: json['destination_country_id'] as String? ?? '',
      arrivalDate: parseDate(json['arrival_date']),
      status: json['status'] as String? ?? 'planning',
      chosenPackageType: json['chosen_package_type'] as String?,
      chosenPackageId: json['chosen_package_id'] as String?,
      notes: json['notes'] as String?,
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'sim_line_id': simLineId,
    'destination_country_id': destinationCountryId,
    'arrival_date': arrivalDate.toIso8601String().split('T').first,
    'status': status,
    'chosen_package_type': chosenPackageType,
    'chosen_package_id': chosenPackageId,
    'notes': notes,
  };
}
