/// User-facing copy. Kept in one place so the entire product voice is
/// reviewable. Phase 1 language never makes medical or disease claims.
library;

class AppStrings {
  AppStrings._();

  // Brand
  static const String appName = 'AarogyaDrishti';
  static const String tagline = 'Track. Understand. Prevent.';

  // Welcome
  static const String welcomeTitle = 'Understand your everyday habits';
  static const String welcomeSubtitle =
      'Discover patterns that can help you build a healthier lifestyle - '
      'one small daily check-in at a time.';
  static const String getStarted = 'Get Started';
  static const String alreadyHaveAccount = 'Already have an account?';

  // Auth
  static const String login = 'Login';
  static const String signUp = 'Sign Up';
  static const String logout = 'Logout';
  static const String forgotPassword = 'Forgot password?';
  static const String emailHint = 'Email';
  static const String passwordHint = 'Password';
  static const String nameHint = 'Full Name';
  static const String confirmPasswordHint = 'Confirm Password';
  static const String createAccount = 'Create Account';
  static const String createAccountTitle = 'Create your account';
  static const String createAccountSubtitle =
      'Start understanding your lifestyle, one day at a time.';
  static const String loginTitle = 'Welcome back';
  static const String loginSubtitle = 'Sign in to continue your lifestyle journey.';
  static const String continueWithGoogle = 'Continue with Google';
  static const String creatingAccount = 'Creating account\u2026';
  static const String loggingIn = 'Signing in\u2026';
  static const String newHere = 'New here?';

  // Validation
  static const String errNameRequired = 'Please enter your name.';
  static const String errEmailRequired = 'Please enter your email address.';
  static const String errEmailInvalid = 'Please enter a valid email address.';
  static const String errPasswordRequired = 'Please enter a password.';
  static const String errPasswordWeakShort = 'Use at least 8 characters.';
  static const String errPasswordWeakMix =
      'Use a mix of letters, numbers or symbols.';
  static const String errConfirmRequired = 'Please confirm your password.';
  static const String errConfirmMismatch = 'Passwords do not match.';

  // Backend / network errors (meaningful, never generic).
  static const String errNetworkDefault = 'No internet connection. Please try again.';
  static const String errServerBusy =
      'Our servers are busy. Please try again shortly.';
  static const String errSignup = 'Unable to create your account. Please try again.';
  static const String errLogin = 'Unable to sign in. Please check your details.';

  // Onboarding - goals
  static const String goalTitle = 'What would you like to improve?';
  static const String goalSubtitle =
      'Pick the one that matters most to you right now. You can change it anytime.';
  static const String goalSelectionHint = 'Select one area to continue.';

  // Onboarding - routine
  static const String routineTitle = 'Tell us about your daily routine';
  static const String routineSubtitle =
      'This helps us personalise your observations. Skip anything you\u2019d '
      'rather not share \u2014 every question is optional.';

  // Onboarding - health permission
  static const String healthPermissionTitle = 'Connect your health data';
  static const String healthPermissionBody =
      'AarogyaDrishti can use selected health data from your phone to reduce '
      'manual tracking. This is optional and you control what we can read.';
  static const String connectHealthData = 'Connect Health Data';
  static const String skipForNow = 'Skip for now';
  static const String continueWithManual = 'Continue with manual tracking';

  // Dashboard
  static const String morningHello = 'Good morning';
  static const String afternoonHello = 'Good afternoon';
  static const String eveningHello = 'Good evening';
  static const String dashboardTitle = 'Here\u2019s your health summary';
  static const String dashboardSubtitle = 'Here\u2019s your health summary';
  static const String todayOverview = 'Today\u2019s Overview';
  static const String lifestyleScore = 'Lifestyle Score';
  static const String lifestyleScoreCaption = 'Based on your recent check-ins';
  static const String noDataYet = 'No data yet';
  static const String profileSheet = 'Profile';
  static const String baselineLearning =
      'Keep checking in. We\u2019re learning your baseline.';
  static const String baselineReady = 'Your baseline is ready.';

  // Home CTAs
  static const String dailyCheckinCta = 'Daily Check-in';
  static const String dailyCheckinCtaSubtitle = 'Takes less than a minute.';
  static const String startCheckin = 'Start check-in';
  static const String checkedInToday = 'Checked in today';

  // Check-in
  static const String checkInTitle = 'Daily Check-in';
  static const String checkInSubtitle = 'Takes less than a minute.';
  static const String saveCheckIn = 'Save Check-in';
  static const String checkInSaved = 'Check-in saved';
  static const String checkinConfirmTitle = 'Check-in saved';
  static const String checkinConfirmBody =
      'Thanks for checking in. Your dashboard has been updated.';

  // Insights
  static const String insightsTitle = 'Insights';
  static const String insightsSubtitle = 'Your personal patterns';
  static const String yourPatterns = 'Your Patterns';
  static const String notEnoughData = 'Not enough data yet';
  static const String notEnoughDataHint =
      'Keep checking in to unlock your personal patterns.';
  static const String noDataAvailable = 'No data available';

  // Experiments
  static const String experimentsTitle = 'Experiments';
  static const String todayProgress = 'Today\u2019s Progress';
  static const String whyThisMatters = 'Why this matters';
  static const String tipsForYou = 'Tips for you';
  static const String logIntake = 'Log Intake';
  static const String dayOf = 'Day {day} of {total}';

  // Coach
  static const String coachTitle = 'Your Personal Coach';
  static const String coachSafetyNote =
      'I\u2019m a lifestyle coach, not a doctor. I never diagnose or treat. '
      'For medical concerns, please speak with a professional.';
  static const String tryExperiment = 'Try an experiment';
  static const String viewInsights = 'View insights';
  static const String dismiss = 'Dismiss';
  static const String coachChatEntry = 'Chat with your coach';

  // Profile
  static const String profileTitle = 'Profile';
  static const String myGoals = 'My Goals';
  static const String connectedHealthData = 'Connected Health Data';
  static const String privacy = 'Privacy';
  static const String notifications = 'Notifications';
  static const String preferences = 'Preferences';
  static const String aboutApp = 'About AarogyaDrishti';
  static const String edit = 'Edit';
  static const String noGoalsSelected = 'No goals selected yet';
  static const String deleteAccount = 'Delete account';

  // Check-in quick pickers
  static const String moodQuestion = 'How are you feeling today?';
  static const String sleepQuestion = 'How was your sleep?';
  static const String energyQuestion = 'Energy level';
  static const String stressQuestion = 'Stress level';
  static const String waterQuestion = 'Water intake';
  static const String activityQuestion = 'Activity today';
  static const String low = 'Low';
  static const String medium = 'Medium';
  static const String high = 'High';
  static const String checkInSavedBody =
      'Thanks for checking in. Your dashboard has been updated.';

  // Health connect
  static const String healthConnectUnavailable =
      'Health Connect is not available on this device. You can continue with '
      'manual tracking.';
  static const String emptyHealthData =
      'No health data found for this period yet.';
  static const String duplicateCheckIn =
      'You already checked in for today. You can update it from History.';

  // History
  static const String historyTitle = 'History';
  static const String historyEmpty =
      'No check-ins yet. Your daily entries will show up here.';

  // Errors / states
  static const String noInternet = 'No internet connection. Please try again.';
  static const String apiUnavailable =
      'We could not reach our servers. Please try again shortly.';
  static const String somethingWentWrong = 'Something went wrong. Please try again.';
  static const String sessionExpired = 'Your session has expired. Please sign in again.';
  static const String permissionDenied =
      'You can continue with manual tracking instead.';
}