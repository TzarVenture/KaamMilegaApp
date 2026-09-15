import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_provider.dart';

/// Screen displaying the Candidate's Active Chat Conversations
class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);
    final currentUser = ref.watch(authProvider).user;
    final currentUserId = currentUser?.id ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Messages & Chats',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(conversationsProvider);
          await ref.read(conversationsProvider.future);
        },
        child: conversationsAsync.when(
          data: (conversations) {
            if (conversations.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: const [
                          Icon(
                            Icons.forum_outlined,
                            size: 56,
                            color: AppColors.textLight,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No messages yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Start networking or apply to jobs to chat directly with hiring recruiters!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conv = conversations[index];
                final otherUserId = conv.getOtherParticipant(currentUserId);
                final displayName =
                    'Recruiter / Candidate #${otherUserId.substring(0, otherUserId.length > 6 ? 6 : otherUserId.length)}';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.borderLight),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryLight,
                      radius: 24,
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          conv.formattedTime,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        conv.lastMessage.isNotEmpty
                            ? conv.lastMessage
                            : 'Tap to start conversation',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    onTap: () {
                      context.push(
                        '/chats/${conv.id}',
                        extra: {
                          'receiverId': otherUserId,
                          'title': displayName,
                        },
                      );
                    },
                  ),
                );
              },
            );
          },
          loading: () => const MyApplicationsSkeleton(),
          error: (err, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text('Failed to load conversations: $err'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(conversationsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
