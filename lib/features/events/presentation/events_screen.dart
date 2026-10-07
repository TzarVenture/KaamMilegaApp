import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/presentation/widgets/profile_drawer.dart';
import '../../../shared/widgets/category_top_header.dart';
import '../../../shared/widgets/themed_category_bottom_nav.dart';
import '../models/event.dart';
import '../providers/event_provider.dart';
import 'event_detail_screen.dart';
import 'widgets/event_attendees.dart';
import 'widgets/event_pricing_filter.dart';
import '../../../shared/widgets/banner_image.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/pressable_scale.dart';

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  EventPricingFilter _pricing = EventPricingFilter.all;
  final Set<String> _registeringEventIds = {};
  Timer? _searchDebounce;

  /// Where the events start in the list (the banner scrolls here).
  final _eventsStartKey = GlobalKey();

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  EventsQuery get _query => ref.read(eventsQueryProvider);

  void _setQuery(EventsQuery query) =>
      ref.read(eventsQueryProvider.notifier).set(query);

  /// Search runs on the server (title, organizer, category) after a short
  /// pause in typing, so every page of results is searched.
  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value.trim());
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 400),
      () => _setQuery(_query.copyWith(search: value.trim())),
    );
  }

  void _onPricingChanged(EventPricingFilter value) {
    setState(() => _pricing = value);
    _setQuery(_query.withPricing(EventPricingChips.isPaidParam(value)));
  }

  Future<void> _loadMore() async {
    final ok = await ref.read(eventsProvider.notifier).loadMore();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load more events. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleRegistration(EventItem event) async {
    final authState = ref.read(authProvider);
    if (!authState.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please log in to register for events.'),
          backgroundColor: AppColors.primary,
          action: SnackBarAction(
            label: 'Login',
            textColor: Colors.white,
            onPressed: () => context.push('/login'),
          ),
        ),
      );
      return;
    }

    if (event.isRegistered) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You are already registered for ${event.title}!'),
          backgroundColor: AppColors.primaryLight,
        ),
      );
      return;
    }

    setState(() => _registeringEventIds.add(event.id));

    try {
      final success = await ref
          .read(eventsProvider.notifier)
          .registerForEvent(event.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Successfully registered for ${event.title}!'
                  : 'Could not complete registration. Please try again.',
            ),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _registeringEventIds.remove(event.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsProvider);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF4F2EE),
      endDrawer: const ProfileDrawer(),
      bottomNavigationBar: const ThemedCategoryBottomNav(
        activeColor: AppColors.moduleEvents,
        secondaryColor: AppColors.brandNavy,
        categoryLabel: 'Events',
        categoryIcon: Icons.event_available_rounded,
      ),
      body: SafeArea(
        child: Column(
          children: [
            CategoryTopHeader(
              showSearchIcon: false, // search bar below is enough
              scaffoldKey: _scaffoldKey,
              themeColor: AppColors.moduleEvents,
              searchHint: 'Search events, webinars & summits...',
              // Search matches event title, organizer and category.
              searchHintExamples: const [
                'Events',
                'Webinars',
                'Workshops',
                'Summits',
                'Meetups',
                'Job Fairs',
              ],
              searchController: _searchController,
              onSearchChanged: _onSearchChanged,
              onSearchSubmitted: () {
                _searchDebounce?.cancel();
                final text = _searchController.text.trim();
                setState(() => _searchQuery = text);
                _setQuery(_query.copyWith(search: text));
              },
            ),
            EventPricingChips(
              selected: _pricing,
              onChanged: _onPricingChanged,
              trailing: FilterChip(
                label: const Text('Soonest date'),
                avatar: const Icon(Icons.event_rounded, size: 16),
                showCheckmark: false,
                selected: ref.watch(
                  eventsQueryProvider.select((q) => q.upcomingFirst),
                ),
                tooltip: 'Show events with the nearest date first',
                onSelected: (on) =>
                    _setQuery(_query.copyWith(upcomingFirst: on)),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFFD97706),
                onRefresh: () => ref.read(eventsProvider.notifier).refresh(),
                child: eventsAsync.when(
                  data: (events) {
                    final q = _searchQuery.toLowerCase();
                    final filteredEvents = events.where((e) {
                      if (!_pricing.matches(e)) return false;
                      if (q.isEmpty) return true;
                      return e.title.toLowerCase().contains(q) ||
                          e.description.toLowerCase().contains(q) ||
                          e.organizer.toLowerCase().contains(q) ||
                          e.category.toLowerCase().contains(q) ||
                          e.location.toLowerCase().contains(q);
                    }).toList();
                    // Why the list is empty: search, pricing, or no events
                    final emptyTitle = _searchQuery.isNotEmpty
                        ? 'No matching events found'
                        : switch (_pricing) {
                            EventPricingFilter.all => 'No Upcoming Events',
                            EventPricingFilter.free =>
                              'No free events right now',
                            EventPricingFilter.paid =>
                              'No paid masterclasses right now',
                          };
                    final emptyMessage = _searchQuery.isNotEmpty
                        ? 'Try searching for different keywords or clear the search filter.'
                        : _pricing == EventPricingFilter.all
                        ? 'New career webinars and hiring expos will appear here once scheduled.'
                        : 'Tap "All Events" to see every upcoming event.';

                    if (filteredEvents.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        children: [
                          _buildHeroBanner(),
                          _buildMyTicketsLink(),
                          SizedBox(key: _eventsStartKey),
                          const SizedBox(height: 48),
                          FadeSlideIn(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  children: [
                                    Icon(
                                      _searchQuery.isEmpty
                                          ? Icons.event_busy_rounded
                                          : Icons.search_off_rounded,
                                      size: 56,
                                      color: AppColors.textLight,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      emptyTitle,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      emptyMessage,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      children: [
                        _buildHeroBanner(),
                        _buildMyTicketsLink(),
                        SizedBox(key: _eventsStartKey),
                        const SizedBox(height: 16),
                        ...filteredEvents.map((event) {
                          final isRegistering = _registeringEventIds.contains(
                            event.id,
                          );
                          return FadeSlideIn(
                            index: filteredEvents.indexOf(event),
                            child: _buildEventCard(event, isRegistering),
                          );
                        }),
                        _buildLoadMore(),
                      ],
                    );
                  },
                  loading: () => ListView(
                    padding: const EdgeInsets.all(16),
                    children: const [
                      ShimmerLoadingList(count: 3, itemHeight: 280),
                    ],
                  ),
                  error: (error, stackTrace) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.25,
                      ),
                      FadeSlideIn(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  size: 56,
                                  color: AppColors.error,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Unable to load events',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  error.toString(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () => ref
                                      .read(eventsProvider.notifier)
                                      .refresh(),
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Try Again'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "Load more events" while the server has more pages.
  Widget _buildLoadMore() {
    final notifier = ref.read(eventsProvider.notifier);
    if (!notifier.hasMore) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      child: Column(
        children: [
          Text(
            'Showing ${ref.read(eventsProvider).value?.length ?? 0} of '
            '${notifier.total} events',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: notifier.isLoadingMore ? null : _loadMore,
              child: notifier.isLoadingMore
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Load more events'),
            ),
          ),
        ],
      ),
    );
  }

  void _openDetails(EventItem event) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
    );
  }

  /// Free events register from the card; paid tickets and registered
  /// events (to view the ticket) open the details screen.
  VoidCallback? _cardAction(EventItem event) {
    if (event.isRegistered) return () => _openDetails(event);
    if (event.isSoldOut) return null;
    if (event.requiresPayment) return () => _openDetails(event);
    return () => _handleRegistration(event);
  }

  String _cardLabel(EventItem event) {
    if (event.isRegistered) return 'Registered';
    if (event.isSoldOut) return 'Sold out';
    if (event.requiresPayment) return 'Buy ticket · ${event.priceLabel}';
    return 'Register for Event';
  }

  /// Signed-in users only (tickets are account data).
  Widget _buildMyTicketsLink() {
    final signedIn = ref.watch(authProvider.select((s) => s.isAuthenticated));
    if (!signedIn) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: () => context.push('/my-tickets'),
        icon: const Icon(Icons.confirmation_number_outlined, size: 18),
        label: const Text('My tickets'),
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
    );
  }

  Widget _buildEventCard(EventItem event, bool isRegistering) {
    return PressableScale(
      child: InkWell(
        onTap: () => _openDetails(event),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child:
                    (event.imageUrl.isNotEmpty &&
                        (event.imageUrl.startsWith('http://') ||
                            event.imageUrl.startsWith('https://')))
                    ? Image.network(
                        event.imageUrl,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildImagePlaceholder(),
                      )
                    : _buildImagePlaceholder(),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.dateString,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _PriceBadge(event: event),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (event.organizer.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Hosted by ${event.organizer}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (event.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        event.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        // Opens who is attending (as on the website)
                        InkWell(
                          onTap: event.attendeesCount > 0
                              ? () => showEventAttendeesFor(context, event.id)
                              : null,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${event.attendeesCount} attending',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: event.attendeesCount > 0
                                        ? AppColors.blue
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                if (event.attendeesCount > 0)
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 16,
                                    color: AppColors.blue,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: isRegistering ? null : _cardAction(event),
                      style: ElevatedButton.styleFrom(
                        // Same colour as the Events + button
                        backgroundColor: event.isRegistered
                            ? Colors.grey.shade200
                            : AppColors.moduleEvents,
                        foregroundColor: event.isRegistered
                            ? AppColors.textPrimary
                            : Colors.white,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      child: isRegistering
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                              ),
                            )
                          : Text(
                              _cardLabel(event),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    // Brand banner image (its "Explore Events" button is part of the
    // picture): tapping it scrolls to the events.
    return FadeSlideIn(
      child: BannerImage(
        asset: 'assets/images/events_hero.webp',
        pixelWidth: 1080,
        pixelHeight: 754,
        semanticLabel:
            'Join events. Build network. Be a part of community. '
            'Explore events',
        onTap: _scrollToEvents,
      ),
    );
  }

  /// Scrolls the list to the first event (below the banner).
  void _scrollToEvents() {
    final target = _eventsStartKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 160,
      color: AppColors.heroBg,
      child: const Center(
        child: Icon(Icons.event_rounded, size: 48, color: Colors.white),
      ),
    );
  }
}

/// "Free" or the ticket price, shown on each event card.
class _PriceBadge extends StatelessWidget {
  const _PriceBadge({required this.event});

  final EventItem event;

  @override
  Widget build(BuildContext context) {
    final paid = event.requiresPayment;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: paid ? AppColors.moduleEventsLight : AppColors.successLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        event.priceLabel,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: paid ? AppColors.textPrimary : AppColors.success,
        ),
      ),
    );
  }
}
