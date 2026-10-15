import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/app_exception.dart';
import '../../auth/repositories/auth_repository.dart';
import '../models/event.dart';
import '../repositories/event_repository.dart';
import 'event_provider.dart';

/// What the Expert typed in "Create New Event".
class EventDraft {
  const EventDraft({
    required this.title,
    required this.organizer,
    required this.description,
    required this.date,
    required this.time,
    required this.location,
    this.bannerName,
    this.bannerBytes,
  });

  final String title;
  final String organizer;
  final String description;
  final DateTime date;
  final TimeOfDay time;
  final String location;

  /// Optional banner photo, uploaded (POST /files/upload) before the event
  /// is saved; its link becomes the event's `image_url`.
  final String? bannerName;
  final Uint8List? bannerBytes;

  /// "2026-10-20", as the website's date field sends it.
  String get dateValue => DateFormat('yyyy-MM-dd').format(date);

  /// "14:30", as the website's time field sends it.
  String get timeValue =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}

/// Result of [EventCreator.create]: the saved event, or the message to show.
class CreateEventResult {
  const CreateEventResult.created(EventItem this.event) : message = null;
  const CreateEventResult.failed(String this.message) : event = null;

  final EventItem? event;
  final String? message;
}

/// Creates an event for the Expert Portal: banner upload (if any), then
/// POST /events. The Events list is reloaded afterwards.
class EventCreator {
  EventCreator(this._ref);

  final Ref _ref;

  static const String unknownOutcome =
      'We could not confirm that your event was created. Please check the '
      'Events page before trying again, so it is not posted twice.';

  Future<CreateEventResult> create(EventDraft draft) async {
    var imageUrl = '';
    final bytes = draft.bannerBytes;
    if (bytes != null) {
      try {
        final url = await _ref
            .read(authRepositoryProvider)
            .uploadFile(bytes, draft.bannerName ?? 'event-banner.jpg');
        if (url == null || url.isEmpty) {
          return const CreateEventResult.failed(
            'The banner photo could not be uploaded. Your event was not '
            'created. Please try again or remove the photo.',
          );
        }
        imageUrl = url;
      } on AppException catch (e) {
        return CreateEventResult.failed(
          'The banner photo could not be uploaded (${e.message}). Your '
          'event was not created.',
        );
      }
    }

    try {
      final event = await _ref
          .read(eventRepositoryProvider)
          .createEvent(
            title: draft.title.trim(),
            organizer: draft.organizer.trim(),
            description: draft.description.trim(),
            date: draft.dateValue,
            time: draft.timeValue,
            location: draft.location.trim(),
            imageUrl: imageUrl,
          );
      _ref.invalidate(eventsProvider);
      return CreateEventResult.created(event);
    } on AppValidationException catch (e) {
      return CreateEventResult.failed(e.message);
    } on AppAuthException catch (e) {
      return CreateEventResult.failed(e.message);
    } on AppNetworkException {
      return const CreateEventResult.failed(
        'No internet connection. Your event was not created.',
      );
    } on AppException {
      // Timeout or server error: the event may have been saved.
      _ref.invalidate(eventsProvider);
      return const CreateEventResult.failed(unknownOutcome);
    }
  }
}

final eventCreatorProvider = Provider<EventCreator>(EventCreator.new);
