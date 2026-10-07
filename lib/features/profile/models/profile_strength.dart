import '../../../core/constants/api_constants.dart';
import '../../auth/models/user_profile.dart';

/// One thing that makes a profile complete, its share of the score and
/// what to tell the user to do.
enum ProfileStep {
  experience(15, 'Add your work experience'),
  photo(15, 'Add a profile photo'),
  education(15, 'Add your education'),
  skills(15, 'Add at least 3 skills'),
  about(15, 'Write a short About section'),
  headline(15, 'Add a headline and your city'),
  email(10, 'Verify your email');

  const ProfileStep(this.points, this.action);

  final int points;
  final String action;
}

/// How complete a profile is (0 to 100) and what is still missing, in the
/// order above. Used by the Profile screen and the Home card, so both
/// always show the same number.
class ProfileStrength {
  const ProfileStrength._(this.percent, this.missing);

  final int percent;
  final List<ProfileStep> missing;

  bool get isComplete => missing.isEmpty;

  /// The first missing step, or null when complete.
  ProfileStep? get next => missing.isEmpty ? null : missing.first;

  bool has(ProfileStep step) => !missing.contains(step);

  /// [failedPhotoUrl]: a saved photo that did not load is not counted.
  factory ProfileStrength.of(UserProfile user, {String? failedPhotoUrl}) {
    final photoUrl = ApiConstants.resolveImageUrl(user.profileImage);
    final done = <ProfileStep, bool>{
      ProfileStep.experience: user.experience.isNotEmpty,
      ProfileStep.photo: photoUrl.isNotEmpty && photoUrl != failedPhotoUrl,
      ProfileStep.education: user.education.isNotEmpty,
      ProfileStep.skills: user.skills.length >= 3,
      ProfileStep.about: user.about.isNotEmpty,
      ProfileStep.headline: user.headline.isNotEmpty && user.city.isNotEmpty,
      ProfileStep.email: user.isEmailVerified,
    };
    var percent = 0;
    final missing = <ProfileStep>[];
    for (final step in ProfileStep.values) {
      if (done[step]!) {
        percent += step.points;
      } else {
        missing.add(step);
      }
    }
    return ProfileStrength._(percent, missing);
  }
}
