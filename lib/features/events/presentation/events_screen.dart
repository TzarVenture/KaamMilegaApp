import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../models/event.dart';

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  final List<EventItem> _events = [
    const EventItem(
      id: 'ev_1',
      title: 'India Blue-Collar & Logistics Career Expo 2026',
      organizer: 'KaamMilega HR Network & National Skill Council',
      dateString: 'Sat, Sep 28 • 10:00 AM IST',
      location: 'Online Live Stream & Mumbai BKC Expo Hall',
      imageUrl: 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?auto=format&fit=crop&q=80&w=800',
      attendeesCount: 1420,
      isRegistered: false,
    ),
    const EventItem(
      id: 'ev_2',
      title: 'Mastering Resume & Salary Negotiations with HR Leaders',
      organizer: 'Senior Talent Acquisition Team',
      dateString: 'Wed, Oct 2 • 6:30 PM IST',
      location: 'Interactive Zoom Webinar',
      imageUrl: 'https://images.unsplash.com/photo-1515187029135-18ee286d815b?auto=format&fit=crop&q=80&w=800',
      attendeesCount: 890,
      isRegistered: true,
    ),
  ];

  void _toggleRegistration(int index) {
    setState(() {
      final current = _events[index];
      _events[index] = current.copyWith(
        isRegistered: !current.isRegistered,
        attendeesCount: current.isRegistered
            ? current.attendeesCount - 1
            : current.attendeesCount + 1,
      );
    });

    final event = _events[index];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          event.isRegistered
              ? 'Registered for ${event.title}!'
              : 'Unregistered from ${event.title}.',
        ),
        backgroundColor: event.isRegistered
            ? AppColors.success
            : AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2EE),
      appBar: AppBar(
        title: const Text(
          'Events & Career Webinars',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _events.length,
        itemBuilder: (context, index) {
          final event = _events[index];
          return Container(
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
                  child: Image.network(
                    event.imageUrl,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 160,
                      color: AppColors.heroBg,
                      child: const Center(
                        child: Icon(
                          Icons.event_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.dateString,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
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
                      const SizedBox(height: 6),
                      Text(
                        'Hosted by ${event.organizer}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
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
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          Text(
                            '${event.attendeesCount} attending',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _toggleRegistration(index),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: event.isRegistered
                              ? Colors.grey.shade200
                              : AppColors.primary,
                          foregroundColor: event.isRegistered
                              ? AppColors.textPrimary
                              : Colors.white,
                          minimumSize: const Size(double.infinity, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          event.isRegistered
                              ? '✓ Registered'
                              : 'Register for Event',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
