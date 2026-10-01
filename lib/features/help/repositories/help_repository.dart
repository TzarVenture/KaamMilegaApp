import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/response_list.dart';

/// One frequently asked question, written by the KaamMilega team in the
/// website admin (km-backend `Question`).
class FaqItem {
  final String id;
  final String question;
  final String answer;

  const FaqItem({
    required this.id,
    required this.question,
    required this.answer,
  });

  factory FaqItem.fromJson(Map<String, dynamic> json) => FaqItem(
    id: json['id']?.toString() ?? '',
    question: json['question']?.toString().trim() ?? '',
    answer: json['answer']?.toString().trim() ?? '',
  );
}

class HelpRepository {
  HelpRepository(this._client);

  final ApiClient _client;

  /// Largest page asked for; the admin list is short.
  static const int pageSize = 100;

  /// Questions and answers (GET /questions, public; `{data: [...]}`).
  /// Throws on failure so the screen shows an error, never "no questions".
  Future<List<FaqItem>> getFaqs() async {
    final response = await _client.get(
      ApiConstants.faqQuestions,
      queryParameters: {'page': 1, 'limit': pageSize},
    );
    return readListResponse(response.data)
        .map(FaqItem.fromJson)
        .where((f) => f.question.isNotEmpty && f.answer.isNotEmpty)
        .toList();
  }
}

final helpRepositoryProvider = Provider<HelpRepository>(
  (ref) => HelpRepository(ref.watch(apiClientProvider)),
);

final faqProvider = FutureProvider.autoDispose<List<FaqItem>>(
  (ref) => ref.watch(helpRepositoryProvider).getFaqs(),
);
