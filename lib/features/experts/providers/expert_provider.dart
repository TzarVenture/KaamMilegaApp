import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../models/expert_profile.dart';
import '../repositories/expert_repository.dart';

class ExpertState {
  final List<ExpertItem> experts;
  final String selectedCategory;
  final String searchQuery;
  final bool isLoading;
  final String? error;

  const ExpertState({
    this.experts = const [],
    this.selectedCategory = 'All',
    this.searchQuery = '',
    this.isLoading = false,
    this.error,
  });

  ExpertState copyWith({
    List<ExpertItem>? experts,
    String? selectedCategory,
    String? searchQuery,
    bool? isLoading,
    String? error,
  }) {
    return ExpertState(
      experts: experts ?? this.experts,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ExpertNotifier extends Notifier<ExpertState> {
  late final ExpertRepository _repository;

  @override
  ExpertState build() {
    _repository = ref.watch(expertRepositoryProvider);
    Future.microtask(() => loadExperts());
    return const ExpertState();
  }

  Future<void> loadExperts() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final list = await _repository.getExperts(
        category: state.selectedCategory,
        query: state.searchQuery,
      );
      state = state.copyWith(isLoading: false, experts: list, error: null);
    } catch (e) {
      final errorMsg = e is AppNotFoundException
          ? 'Expert mentorship service is currently under development.'
          : (e is AppNetworkException
                ? 'No internet connection. Please check your network.'
                : e.toString());
      state = state.copyWith(isLoading: false, error: errorMsg);
    }
  }

  void setCategory(String category) {
    if (state.selectedCategory == category) return;
    state = state.copyWith(selectedCategory: category);
    loadExperts();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    loadExperts();
  }
}

final expertProvider = NotifierProvider<ExpertNotifier, ExpertState>(() {
  return ExpertNotifier();
});
