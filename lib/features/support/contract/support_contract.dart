import 'dart:io';
import 'package:keep_sims/core/result.dart';
import '../data/models/support_ticket.dart';

abstract class SupportContract {
  Future<Result<List<SupportTicket>>> getUserTickets();
  Future<Result<SupportTicket>> createTicket({
    required String subject,
    required String description,
    required String category,
    File? attachment,
  });
}
