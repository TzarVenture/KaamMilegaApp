import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_provider.dart';
import '../../notifications/providers/notification_provider.dart';
import '../../profile/presentation/widgets/profile_drawer.dart';

/// Screen allowing candidates/professionals to apply to be an Expert on KaamMilega
/// Matches the web portal design & responsive mobile layout.
class ApplyExpertScreen extends ConsumerStatefulWidget {
  const ApplyExpertScreen({super.key});

  @override
  ConsumerState<ApplyExpertScreen> createState() => _ApplyExpertScreenState();
}

class _ApplyExpertScreenState extends ConsumerState<ApplyExpertScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _rateController = TextEditingController(
    text: '0',
  );
  final TextEditingController _resumeController = TextEditingController();
  final TextEditingController _idProofController = TextEditingController();

  String? _selectedCategory;
  bool _isSubmitting = false;

  final List<String> _categories = [
    'Software Development',
    'Design & UI/UX',
    'Product Management',
    'Marketing & Growth',
    'Business Strategy & Sales',
    'Finance & Accounting',
    'Data Science & AI',
    'Career Coaching & Resume Review',
    'Content & Copywriting',
    'Engineering & DevOps',
    'Other Expertise',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _bioController.dispose();
    _rateController.dispose();
    _resumeController.dispose();
    _idProofController.dispose();
    super.dispose();
  }

  void _handleSearchSubmit() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      context.push('/jobs');
    }
  }

  void _submitApplication() async {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an expertise category.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_bioController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please share a brief bio about your expertise.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!ref.read(authProvider).isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to apply as an Expert.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final pricing = double.tryParse(_rateController.text.trim()) ?? 0;
    final documents = <Map<String, String>>[
      if (_resumeController.text.trim().isNotEmpty)
        {'name': 'Resume', 'url': _resumeController.text.trim()},
      if (_idProofController.text.trim().isNotEmpty)
        {'name': 'Identity Proof', 'url': _idProofController.text.trim()},
    ];

    setState(() => _isSubmitting = true);
    final ok = await ref
        .read(authProvider.notifier)
        .applyForExpert(
          category: _selectedCategory!,
          bio: _bioController.text.trim(),
          pricing: pricing,
          documents: documents,
        );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(authProvider).error ??
                'Failed to submit application. Please try again.',
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF16A34A),
              size: 28,
            ),
            SizedBox(width: 10),
            Text(
              'Application Sent',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Thank you for applying to be an Expert on KaamMilega! Our team will review your credentials and get back to you shortly.',
          style: TextStyle(color: Color(0xFF475569), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            },
            child: const Text(
              'Done',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF2563EB),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadNotifs = ref.watch(unreadNotificationsCountProvider);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      endDrawer: const ProfileDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: GestureDetector(
          onTap: () => context.go('/home'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: 30,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8),
              Image.asset(
                'assets/images/logo_text.png',
                height: 18,
                fit: BoxFit.contain,
              ),
            ],
          ),
        ),
        actions: [
          // 1. Search Icon
          IconButton(
            icon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF1E293B),
              size: 22,
            ),
            splashRadius: 20,
            tooltip: 'Search Jobs',
            onPressed: () => context.push('/jobs'),
          ),

          // 2. Notification Bell with Badge
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  color: Color(0xFF1E293B),
                  size: 24,
                ),
                if (unreadNotifs > 0)
                  Positioned(
                    top: -1,
                    right: -1,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            splashRadius: 20,
            tooltip: 'Notifications',
            onPressed: () => context.push('/notifications'),
          ),

          // 3. Hamburger Menu (Drawer)
          IconButton(
            icon: const Icon(
              Icons.menu_rounded,
              color: Color(0xFF1E293B),
              size: 24,
            ),
            splashRadius: 20,
            tooltip: 'Menu',
            onPressed: () {
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. SEARCH / GO BAR (Matches Web Portal single pill design)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: const Color(0xFFD1D5DB),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF9CA3AF),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onSubmitted: (_) => _handleSearchSubmit(),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF111827),
                            fontWeight: FontWeight.w400,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Job Title/Category',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            filled: false,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: SizedBox(
                          height: 34,
                          child: ElevatedButton(
                            onPressed: _handleSearchSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF172554),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(17),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              elevation: 0,
                              minimumSize: Size.zero,
                            ),
                            child: const Text(
                              'Go',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),

              // 2. HERO TITLE SECTION
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 32,
                ),
                color: const Color(0xFFFAFAFA),
                child: Column(
                  children: const [
                    Text(
                      'Apply to be an Expert',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Share your knowledge, mentor others, and sell courses.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF6B7280),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),

              // 3. FORM FIELDS CONTAINER
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Field 1: Category
                      const Text(
                        'Category',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        hint: const Text(
                          'Select a category',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF111827),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF6B7280),
                        ),
                        isExpanded: true,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                              color: Color(0xFFD1D5DB),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                              color: Color(0xFFD1D5DB),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                              color: Color(0xFF2563EB),
                              width: 1.5,
                            ),
                          ),
                        ),
                        items: _categories.map((cat) {
                          return DropdownMenuItem<String>(
                            value: cat,
                            child: Text(
                              cat,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF111827),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedCategory = val);
                        },
                      ),

                      const SizedBox(height: 18),

                      // Field 2: Bio
                      const Text(
                        'Bio',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _bioController,
                        maxLines: 4,
                        minLines: 4,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF111827),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Tell us about your expertise...',
                          hintStyle: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF9CA3AF),
                            fontWeight: FontWeight.w400,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.all(14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                              color: Color(0xFFD1D5DB),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                              color: Color(0xFFD1D5DB),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                              color: Color(0xFF2563EB),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Field 3: Hourly Mentorship Rate (₹)
                      const Text(
                        'Hourly Mentorship Rate (₹)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _rateController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF111827),
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                              color: Color(0xFFD1D5DB),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                              color: Color(0xFFD1D5DB),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                              color: Color(0xFF2563EB),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      // Field 4: Documents Header
                      const Text(
                        'Documents (Provide URLs for now)',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Resume Sub-label & Input
                      const Text(
                        'Resume',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 5),
                      TextFormField(
                        controller: _resumeController,
                        keyboardType: TextInputType.url,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF111827),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Link to your Resume',
                          hintStyle: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF9CA3AF),
                            fontWeight: FontWeight.w400,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                              color: Color(0xFFD1D5DB),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                              color: Color(0xFFD1D5DB),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                              color: Color(0xFF2563EB),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Identity Proof Sub-label & Input
                      const Text(
                        'Identity Proof',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 5),
                      TextFormField(
                        controller: _idProofController,
                        keyboardType: TextInputType.url,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF111827),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Link to your Identity Proof',
                          hintStyle: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF9CA3AF),
                            fontWeight: FontWeight.w400,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                              color: Color(0xFFD1D5DB),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                              color: Color(0xFFD1D5DB),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                              color: Color(0xFF2563EB),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Apply Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitApplication,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            disabledBackgroundColor: const Color(0xFF93C5FD),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Apply',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
