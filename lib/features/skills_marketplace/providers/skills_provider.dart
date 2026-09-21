import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/skill_item.dart';
import '../repositories/skills_repository.dart';

class SkillsState {
  final List<SkillItem> skills;
  final List<String> categories;
  final String selectedCategory;
  final String searchQuery;
  final bool isLoading;
  final String? error;

  const SkillsState({
    this.skills = const [],
    this.categories = const ['All'],
    this.selectedCategory = 'All',
    this.searchQuery = '',
    this.isLoading = false,
    this.error,
  });

  SkillsState copyWith({
    List<SkillItem>? skills,
    List<String>? categories,
    String? selectedCategory,
    String? searchQuery,
    bool? isLoading,
    String? error,
  }) {
    return SkillsState(
      skills: skills ?? this.skills,
      categories: categories ?? this.categories,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class SkillsNotifier extends Notifier<SkillsState> {
  late final SkillsRepository _repository;

  @override
  SkillsState build() {
    _repository = ref.watch(skillsRepositoryProvider);
    Future.microtask(() => init());
    return const SkillsState();
  }

  Future<void> init() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        _repository.getCategories(),
        _repository.getSkills(),
      ]);

      final categories = ['All', ...results[0] as List<String>];
      final skills = results[1] as List<SkillItem>;

      state = state.copyWith(
        isLoading: false,
        categories: categories,
        skills: skills,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> filterByCategory(String category) async {
    if (state.selectedCategory == category) return;
    state = state.copyWith(selectedCategory: category, isLoading: true);
    try {
      final skills = await _repository.getSkills(
        category: category,
        query: state.searchQuery,
      );
      state = state.copyWith(skills: skills, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> search(String query) async {
    state = state.copyWith(searchQuery: query, isLoading: true);
    try {
      final skills = await _repository.getSkills(
        category: state.selectedCategory,
        query: query,
      );
      state = state.copyWith(skills: skills, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final skillsProvider = NotifierProvider<SkillsNotifier, SkillsState>(() {
  return SkillsNotifier();
});
