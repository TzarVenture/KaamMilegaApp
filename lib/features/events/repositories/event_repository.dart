import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/network/response_list.dart';
import '../../wallet/models/wallet_summary.dart';
import '../models/event.dart';
import '../models/event_participant.dart';
import '../models/event_ticket.dart';

/// Repository for handling Career Events and Webinars with km-backend
class EventRepository {
  final ApiClient _client;

  EventRepository(this._client);

  /// Fetch events from backend with pagination and optional search
  Future<List<EventItem>> getEvents({
    String? search,
    String? location,
    int page = 1,
    int limit = 20,
    String? currentUserId,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'limit': limit};
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (location != null && location.trim().isNotEmpty) {
      queryParams['location'] = location.trim();
    }

    final response = await _client.get(
      ApiConstants.events,
      queryParameters: queryParams,
    );

    final dynamic body = response.data;
    List<dynamic> list = [];

    if (body is Map<String, dynamic>) {
      if (body['data'] is List) {
        list = body['data'];
      } else if (body['events'] is List) {
        list = body['events'];
      }
    } else if (body is List) {
      list = body;
    }

    if (list.isNotEmpty) {
      return list
          .map(
            (e) => EventItem.fromJson(
              e as Map<String, dynamic>,
              currentUserId: currentUserId,
            ),
          )
          .toList();
    }
    return [];
  }

  /// Register candidate for a specific event
  Future<bool> registerForEvent(String eventId) async {
    final response = await _client.post(
      '${ApiConstants.events}/$eventId/register',
    );
    if (response.statusCode != null &&
        response.statusCode! >= 200 &&
        response.statusCode! < 300) {
      return true;
    }
    return false;
  }

  /// Paid ticket, step 1 (POST /events/:id/create-order): the server creates
  /// a Razorpay order for the event's real price.
  Future<PaymentOrder> createTicketOrder(
    String eventId,
    EventAttendee attendee,
  ) async {
    final response = await _client.post(
      '${ApiConstants.events}/$eventId/create-order',
      data: attendee.toJson(),
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final order = PaymentOrder.fromJson(data);
      if (order.isValid) return order;
    }
    throw const AppValidationException(
      'Could not start the payment. Please try again.',
    );
  }

  /// Paid ticket, step 3 (POST /events/:id/verify-payment): the server checks
  /// the Razorpay signature and issues the ticket. Safe to call again with
  /// the same payment: the server returns the ticket it already issued.
  Future<EventTicket> verifyTicketPayment({
    required String eventId,
    required String orderId,
    required String paymentId,
    required String signature,
    required EventAttendee attendee,
  }) async {
    final response = await _client.post(
      '${ApiConstants.events}/$eventId/verify-payment',
      data: {
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
        ...attendee.toJson(),
      },
    );
    return _ticketFrom(response.data);
  }

  /// Paid ticket from the wallet main balance
  /// (POST /events/:id/wallet-checkout). Returns the ticket and, when sent,
  /// the fresh wallet balances.
  Future<({EventTicket ticket, WalletSummary? wallet})> buyTicketWithWallet(
    String eventId,
    EventAttendee attendee,
  ) async {
    final response = await _client.post(
      '${ApiConstants.events}/$eventId/wallet-checkout',
      data: attendee.toJson(),
    );
    final data = response.data;
    final wallet =
        data is Map<String, dynamic> && data['wallet'] is Map<String, dynamic>
        ? WalletSummary.fromJson(data['wallet'] as Map<String, dynamic>)
        : null;
    return (ticket: _ticketFrom(data), wallet: wallet);
  }

  /// Tickets of the signed-in user, free and paid (GET /events/my/tickets).
  Future<List<EventTicket>> getMyTickets() async {
    final response = await _client.get(ApiConstants.eventsMyTickets);
    return readListResponse(
      response.data,
      keys: const ['tickets', 'data'],
    ).map(EventTicket.fromJson).toList();
  }

  /// Who is attending (GET /events/:id/attendees, public). 404 when the
  /// event no longer exists.
  Future<EventAttendees> getAttendees(String eventId) async {
    final response = await _client.get(
      '${ApiConstants.events}/$eventId/attendees',
    );
    final data = response.data;
    if (data is Map<String, dynamic>) return EventAttendees.fromJson(data);
    throw const AppValidationException(
      'Could not read who is attending. Please try again.',
    );
  }

  /// Reads `{message, ticket}`; a success without a ticket is an error, not
  /// a silent success.
  static EventTicket _ticketFrom(dynamic data) {
    if (data is Map<String, dynamic> &&
        data['ticket'] is Map<String, dynamic>) {
      final ticket = EventTicket.fromJson(
        data['ticket'] as Map<String, dynamic>,
      );
      if (ticket.ticketNumber.isNotEmpty) return ticket;
    }
    throw const AppValidationException(
      'The ticket could not be read from the server response.',
    );
  }
}

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository(ref.watch(apiClientProvider));
});
