import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_bn.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ha.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_id.dart';
import 'app_localizations_ig.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_nl.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_sw.dart';
import 'app_localizations_th.dart';
import 'app_localizations_tl.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_ur.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_yo.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('bn'),
    Locale('de'),
    Locale('en'),
    Locale('en', 'GB'),
    Locale('es'),
    Locale('fr'),
    Locale('ha'),
    Locale('hi'),
    Locale('id'),
    Locale('ig'),
    Locale('it'),
    Locale('ja'),
    Locale('ko'),
    Locale('nl'),
    Locale('pl'),
    Locale('pt'),
    Locale('ru'),
    Locale('sw'),
    Locale('th'),
    Locale('tl'),
    Locale('tr'),
    Locale('ur'),
    Locale('vi'),
    Locale('yo'),
    Locale('zh')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'VitalSeker'**
  String get appName;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Your AI Health Companion'**
  String get tagline;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @triage.
  ///
  /// In en, this message translates to:
  /// **'Triage'**
  String get triage;

  /// No description provided for @insights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insights;

  /// No description provided for @passport.
  ///
  /// In en, this message translates to:
  /// **'Passport'**
  String get passport;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcomeBack;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @orContinueWith.
  ///
  /// In en, this message translates to:
  /// **'or continue with'**
  String get orContinueWith;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @continueWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get continueWithApple;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get goodEvening;

  /// No description provided for @goodNight.
  ///
  /// In en, this message translates to:
  /// **'Good night'**
  String get goodNight;

  /// No description provided for @healthScore.
  ///
  /// In en, this message translates to:
  /// **'Health Score'**
  String get healthScore;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @checkSymptomsNow.
  ///
  /// In en, this message translates to:
  /// **'Check Symptoms Now'**
  String get checkSymptomsNow;

  /// No description provided for @healthPassport.
  ///
  /// In en, this message translates to:
  /// **'Health Passport'**
  String get healthPassport;

  /// No description provided for @myHistory.
  ///
  /// In en, this message translates to:
  /// **'My History'**
  String get myHistory;

  /// No description provided for @emergencySOS.
  ///
  /// In en, this message translates to:
  /// **'EMERGENCY SOS'**
  String get emergencySOS;

  /// No description provided for @recentChecks.
  ///
  /// In en, this message translates to:
  /// **'Recent Checks'**
  String get recentChecks;

  /// No description provided for @noSymptomsLogs.
  ///
  /// In en, this message translates to:
  /// **'No symptoms logs yet'**
  String get noSymptomsLogs;

  /// No description provided for @startTriage.
  ///
  /// In en, this message translates to:
  /// **'Start Triage'**
  String get startTriage;

  /// No description provided for @vitals.
  ///
  /// In en, this message translates to:
  /// **'Vitals'**
  String get vitals;

  /// No description provided for @logVitals.
  ///
  /// In en, this message translates to:
  /// **'Log Vitals'**
  String get logVitals;

  /// No description provided for @heartRate.
  ///
  /// In en, this message translates to:
  /// **'Heart Rate'**
  String get heartRate;

  /// No description provided for @bloodPressure.
  ///
  /// In en, this message translates to:
  /// **'Blood Pressure'**
  String get bloodPressure;

  /// No description provided for @spo2.
  ///
  /// In en, this message translates to:
  /// **'SpO2'**
  String get spo2;

  /// No description provided for @temperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get temperature;

  /// No description provided for @weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// No description provided for @bloodGlucose.
  ///
  /// In en, this message translates to:
  /// **'Blood Glucose'**
  String get bloodGlucose;

  /// No description provided for @respiratoryRate.
  ///
  /// In en, this message translates to:
  /// **'Respiratory Rate'**
  String get respiratoryRate;

  /// No description provided for @aiTriage.
  ///
  /// In en, this message translates to:
  /// **'AI Triage'**
  String get aiTriage;

  /// No description provided for @describeSymptoms.
  ///
  /// In en, this message translates to:
  /// **'Describe your symptoms...'**
  String get describeSymptoms;

  /// No description provided for @analyzingSymptoms.
  ///
  /// In en, this message translates to:
  /// **'Analyzing your symptoms'**
  String get analyzingSymptoms;

  /// No description provided for @aiProcessing.
  ///
  /// In en, this message translates to:
  /// **'AI is processing your health data'**
  String get aiProcessing;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @newChat.
  ///
  /// In en, this message translates to:
  /// **'New Chat'**
  String get newChat;

  /// No description provided for @viewDetailedResults.
  ///
  /// In en, this message translates to:
  /// **'View Detailed Results'**
  String get viewDetailedResults;

  /// No description provided for @monitorAtHome.
  ///
  /// In en, this message translates to:
  /// **'Monitor at Home'**
  String get monitorAtHome;

  /// No description provided for @whenToEscalate.
  ///
  /// In en, this message translates to:
  /// **'When to escalate'**
  String get whenToEscalate;

  /// No description provided for @saveToPassport.
  ///
  /// In en, this message translates to:
  /// **'Save to Passport'**
  String get saveToPassport;

  /// No description provided for @shareResult.
  ///
  /// In en, this message translates to:
  /// **'Share Result'**
  String get shareResult;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @helpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpSupport;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @privacyData.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Data'**
  String get privacyData;

  /// No description provided for @securityStorage.
  ///
  /// In en, this message translates to:
  /// **'Security & Storage'**
  String get securityStorage;

  /// No description provided for @exportData.
  ///
  /// In en, this message translates to:
  /// **'Export Data'**
  String get exportData;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @helpCenter.
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get helpCenter;

  /// No description provided for @contactConcierge.
  ///
  /// In en, this message translates to:
  /// **'Contact Concierge'**
  String get contactConcierge;

  /// No description provided for @aboutVitalSeker.
  ///
  /// In en, this message translates to:
  /// **'About VitalSeker'**
  String get aboutVitalSeker;

  /// No description provided for @medicalRecords.
  ///
  /// In en, this message translates to:
  /// **'Medical Records'**
  String get medicalRecords;

  /// No description provided for @medicalID.
  ///
  /// In en, this message translates to:
  /// **'Medical ID'**
  String get medicalID;

  /// No description provided for @medicalTranslation.
  ///
  /// In en, this message translates to:
  /// **'Medical Translation'**
  String get medicalTranslation;

  /// No description provided for @familyProfiles.
  ///
  /// In en, this message translates to:
  /// **'Family Profiles'**
  String get familyProfiles;

  /// No description provided for @addFamilyMember.
  ///
  /// In en, this message translates to:
  /// **'Add Family Member'**
  String get addFamilyMember;

  /// No description provided for @accountOwner.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT OWNER'**
  String get accountOwner;

  /// No description provided for @upgradeToPro.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro'**
  String get upgradeToPro;

  /// No description provided for @protectWholeCircle.
  ///
  /// In en, this message translates to:
  /// **'Protect the whole circle.'**
  String get protectWholeCircle;

  /// No description provided for @learnMore.
  ///
  /// In en, this message translates to:
  /// **'Learn More'**
  String get learnMore;

  /// No description provided for @medications.
  ///
  /// In en, this message translates to:
  /// **'Medications'**
  String get medications;

  /// No description provided for @addMedication.
  ///
  /// In en, this message translates to:
  /// **'Add Medication'**
  String get addMedication;

  /// No description provided for @appointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get appointments;

  /// No description provided for @addAppointment.
  ///
  /// In en, this message translates to:
  /// **'Add Appointment'**
  String get addAppointment;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @discontinued.
  ///
  /// In en, this message translates to:
  /// **'Discontinued'**
  String get discontinued;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @poweredBy.
  ///
  /// In en, this message translates to:
  /// **'Powered by Keter Marketing'**
  String get poweredBy;

  /// No description provided for @pressAndHold.
  ///
  /// In en, this message translates to:
  /// **'Press and hold to send emergency alert'**
  String get pressAndHold;

  /// No description provided for @holdFor3Seconds.
  ///
  /// In en, this message translates to:
  /// **'Hold for 3 seconds'**
  String get holdFor3Seconds;

  /// No description provided for @imSafeResolve.
  ///
  /// In en, this message translates to:
  /// **'I\'m Safe - Resolve'**
  String get imSafeResolve;

  /// No description provided for @shareMyLocation.
  ///
  /// In en, this message translates to:
  /// **'Share My Location'**
  String get shareMyLocation;

  /// No description provided for @findHospitalsNearMe.
  ///
  /// In en, this message translates to:
  /// **'Find Hospitals Near Me'**
  String get findHospitalsNearMe;

  /// No description provided for @quickDial.
  ///
  /// In en, this message translates to:
  /// **'Quick Dial'**
  String get quickDial;

  /// No description provided for @emergencyContacts.
  ///
  /// In en, this message translates to:
  /// **'Emergency Contacts'**
  String get emergencyContacts;

  /// No description provided for @medicalIDSection.
  ///
  /// In en, this message translates to:
  /// **'Medical ID'**
  String get medicalIDSection;

  /// No description provided for @noEmergencyContacts.
  ///
  /// In en, this message translates to:
  /// **'No emergency contacts configured'**
  String get noEmergencyContacts;

  /// No description provided for @addContactsInProfile.
  ///
  /// In en, this message translates to:
  /// **'Add contacts in your profile settings'**
  String get addContactsInProfile;

  /// No description provided for @noMedicalInfo.
  ///
  /// In en, this message translates to:
  /// **'No medical information on file'**
  String get noMedicalInfo;

  /// No description provided for @updateProfileMedicalID.
  ///
  /// In en, this message translates to:
  /// **'Update your profile to add medical ID data'**
  String get updateProfileMedicalID;

  /// No description provided for @symptomHistory.
  ///
  /// In en, this message translates to:
  /// **'Symptom History'**
  String get symptomHistory;

  /// No description provided for @noHistoryYet.
  ///
  /// In en, this message translates to:
  /// **'No History Yet'**
  String get noHistoryYet;

  /// No description provided for @symptomLogsAppearHere.
  ///
  /// In en, this message translates to:
  /// **'Your symptom logs will appear here'**
  String get symptomLogsAppearHere;

  /// No description provided for @startFirstTriage.
  ///
  /// In en, this message translates to:
  /// **'Start Your First Triage'**
  String get startFirstTriage;

  /// No description provided for @weeklyInsights.
  ///
  /// In en, this message translates to:
  /// **'Weekly Insights'**
  String get weeklyInsights;

  /// No description provided for @noInsightsYet.
  ///
  /// In en, this message translates to:
  /// **'No Insights Yet'**
  String get noInsightsYet;

  /// No description provided for @checkBackMonday.
  ///
  /// In en, this message translates to:
  /// **'No insights generated yet. Check back on Monday for your weekly AI health summary.'**
  String get checkBackMonday;

  /// No description provided for @generateNow.
  ///
  /// In en, this message translates to:
  /// **'Generate Now'**
  String get generateNow;

  /// No description provided for @upgradeProInsights.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro to unlock AI-powered weekly health insights.'**
  String get upgradeProInsights;

  /// No description provided for @proPlan.
  ///
  /// In en, this message translates to:
  /// **'Pro Plan'**
  String get proPlan;

  /// No description provided for @viewAllPlans.
  ///
  /// In en, this message translates to:
  /// **'View all plans'**
  String get viewAllPlans;

  /// No description provided for @exportMedicalReport.
  ///
  /// In en, this message translates to:
  /// **'Export Medical Report'**
  String get exportMedicalReport;

  /// No description provided for @generatePDF.
  ///
  /// In en, this message translates to:
  /// **'Generate PDF'**
  String get generatePDF;

  /// No description provided for @sendByEmail.
  ///
  /// In en, this message translates to:
  /// **'Send by Email'**
  String get sendByEmail;

  /// No description provided for @patientOverview.
  ///
  /// In en, this message translates to:
  /// **'Patient Overview & Vital Stats'**
  String get patientOverview;

  /// No description provided for @symptomsTriageLog.
  ///
  /// In en, this message translates to:
  /// **'Symptoms & Triage Log'**
  String get symptomsTriageLog;

  /// No description provided for @medicationsAllergies.
  ///
  /// In en, this message translates to:
  /// **'Medications & Allergies'**
  String get medicationsAllergies;

  /// No description provided for @aiAnalysisSummary.
  ///
  /// In en, this message translates to:
  /// **'AI Analysis Summary'**
  String get aiAnalysisSummary;

  /// No description provided for @dateRange.
  ///
  /// In en, this message translates to:
  /// **'Date Range'**
  String get dateRange;

  /// No description provided for @last30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 Days'**
  String get last30Days;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'PREVIEW'**
  String get preview;

  /// No description provided for @translate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get translate;

  /// No description provided for @translateMedicalTerms.
  ///
  /// In en, this message translates to:
  /// **'Translate medical terms'**
  String get translateMedicalTerms;

  /// No description provided for @targetLanguage.
  ///
  /// In en, this message translates to:
  /// **'Target Language'**
  String get targetLanguage;

  /// No description provided for @enterTextToTranslate.
  ///
  /// In en, this message translates to:
  /// **'Enter medical term or phrase to translate'**
  String get enterTextToTranslate;

  /// No description provided for @translationResult.
  ///
  /// In en, this message translates to:
  /// **'Translation Result'**
  String translationResult(Object lang);

  /// No description provided for @notificationPreferences.
  ///
  /// In en, this message translates to:
  /// **'Your notification preferences are saved to your account. Schedule customization is now available — tap any schedule to change it.'**
  String get notificationPreferences;

  /// No description provided for @triageReminders.
  ///
  /// In en, this message translates to:
  /// **'Triage Reminders'**
  String get triageReminders;

  /// No description provided for @medicationReminders.
  ///
  /// In en, this message translates to:
  /// **'Medication Reminders'**
  String get medicationReminders;

  /// No description provided for @appointmentReminders.
  ///
  /// In en, this message translates to:
  /// **'Appointment Reminders'**
  String get appointmentReminders;

  /// No description provided for @vitalsLoggingReminders.
  ///
  /// In en, this message translates to:
  /// **'Vitals Logging Reminders'**
  String get vitalsLoggingReminders;

  /// No description provided for @healthTips.
  ///
  /// In en, this message translates to:
  /// **'Health Tips'**
  String get healthTips;

  /// No description provided for @weeklyReport.
  ///
  /// In en, this message translates to:
  /// **'Weekly Report'**
  String get weeklyReport;

  /// No description provided for @reminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get reminders;

  /// No description provided for @insightsTips.
  ///
  /// In en, this message translates to:
  /// **'Insights & Tips'**
  String get insightsTips;

  /// No description provided for @thisActionIrreversible.
  ///
  /// In en, this message translates to:
  /// **'This action is irreversible. All your data will be permanently deleted.'**
  String get thisActionIrreversible;

  /// No description provided for @typeEmailToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Type your email to confirm:'**
  String get typeEmailToConfirm;

  /// No description provided for @deletePermanently.
  ///
  /// In en, this message translates to:
  /// **'Delete Permanently'**
  String get deletePermanently;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Account deleted. Sorry to see you go.'**
  String get accountDeleted;

  /// No description provided for @sendEmergencySOS.
  ///
  /// In en, this message translates to:
  /// **'Send Emergency SOS?'**
  String get sendEmergencySOS;

  /// No description provided for @sosMessageBody.
  ///
  /// In en, this message translates to:
  /// **'This will send an SMS with your live location to all of your emergency contacts.'**
  String get sosMessageBody;

  /// No description provided for @sendSOS.
  ///
  /// In en, this message translates to:
  /// **'Send SOS'**
  String get sendSOS;

  /// No description provided for @areYouSureSignOut.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get areYouSureSignOut;

  /// No description provided for @failedToSignOut.
  ///
  /// In en, this message translates to:
  /// **'Failed to sign out. Please try again.'**
  String get failedToSignOut;

  /// No description provided for @vitalsLogged.
  ///
  /// In en, this message translates to:
  /// **'Vitals Logged'**
  String get vitalsLogged;

  /// No description provided for @triageSessions.
  ///
  /// In en, this message translates to:
  /// **'Triage Sessions'**
  String get triageSessions;

  /// No description provided for @daysActive.
  ///
  /// In en, this message translates to:
  /// **'Days Active'**
  String get daysActive;

  /// No description provided for @vitalSekerPro.
  ///
  /// In en, this message translates to:
  /// **'VitalSeker Pro'**
  String get vitalSekerPro;

  /// No description provided for @signingOut.
  ///
  /// In en, this message translates to:
  /// **'Signing out...'**
  String get signingOut;

  /// No description provided for @manageMedicalCredentials.
  ///
  /// In en, this message translates to:
  /// **'Manage medical credentials'**
  String get manageMedicalCredentials;

  /// No description provided for @connectedMembers.
  ///
  /// In en, this message translates to:
  /// **'{count} connected member{s}'**
  String connectedMembers(int count, String s);

  /// No description provided for @alertsSmartReminders.
  ///
  /// In en, this message translates to:
  /// **'Alerts & smart reminders'**
  String get alertsSmartReminders;

  /// No description provided for @documentsImaging.
  ///
  /// In en, this message translates to:
  /// **'Documents & imaging'**
  String get documentsImaging;

  /// No description provided for @translateMedicalTermsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Translate medical terms'**
  String get translateMedicalTermsSubtitle;

  /// No description provided for @emergencyMedicalCard.
  ///
  /// In en, this message translates to:
  /// **'Emergency medical card'**
  String get emergencyMedicalCard;

  /// No description provided for @aes256EncryptionActive.
  ///
  /// In en, this message translates to:
  /// **'AES-256 encryption active'**
  String get aes256EncryptionActive;

  /// No description provided for @downloadYourHealthData.
  ///
  /// In en, this message translates to:
  /// **'Download your health data'**
  String get downloadYourHealthData;

  /// No description provided for @themePasswordAccount.
  ///
  /// In en, this message translates to:
  /// **'Theme, password, account'**
  String get themePasswordAccount;

  /// No description provided for @faqsDocumentation.
  ///
  /// In en, this message translates to:
  /// **'FAQs & documentation'**
  String get faqsDocumentation;

  /// No description provided for @priorityProSupport.
  ///
  /// In en, this message translates to:
  /// **'Priority Pro support'**
  String get priorityProSupport;

  /// No description provided for @aboutVitalSekerVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String aboutVitalSekerVersion(String version);

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get confirmNewPassword;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get passwordMinLength;

  /// No description provided for @passwordUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Password updated successfully'**
  String get passwordUpdatedSuccessfully;

  /// No description provided for @failedToUpdatePassword.
  ///
  /// In en, this message translates to:
  /// **'Failed to update password. Please try again.'**
  String get failedToUpdatePassword;

  /// No description provided for @deleteAccountIrreversible.
  ///
  /// In en, this message translates to:
  /// **'This action is irreversible. All your data — vitals, medications, appointments, symptom logs, family profiles, and health passport — will be permanently deleted.'**
  String get deleteAccountIrreversible;

  /// No description provided for @emailDoesNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Email does not match.'**
  String get emailDoesNotMatch;

  /// No description provided for @failedToDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete account. Please try again or contact support.'**
  String get failedToDeleteAccount;

  /// No description provided for @manageYourSubscription.
  ///
  /// In en, this message translates to:
  /// **'Manage your subscription'**
  String get manageYourSubscription;

  /// No description provided for @permanentlyRemoveYourData.
  ///
  /// In en, this message translates to:
  /// **'Permanently remove your data'**
  String get permanentlyRemoveYourData;

  /// No description provided for @endYourCurrentSession.
  ///
  /// In en, this message translates to:
  /// **'End your current session'**
  String get endYourCurrentSession;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemDefault;

  /// No description provided for @subscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subscription;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @chooseYourPlan.
  ///
  /// In en, this message translates to:
  /// **'Choose Your Plan'**
  String get chooseYourPlan;

  /// No description provided for @unlockFullPower.
  ///
  /// In en, this message translates to:
  /// **'Unlock the full power of VitalSeker'**
  String get unlockFullPower;

  /// No description provided for @paymentIntegrationPending.
  ///
  /// In en, this message translates to:
  /// **'In-app payment integration (RevenueCat / StoreKit) is pending. Plan changes are applied directly to your account for testing.'**
  String get paymentIntegrationPending;

  /// No description provided for @forever.
  ///
  /// In en, this message translates to:
  /// **'forever'**
  String get forever;

  /// No description provided for @perMonth.
  ///
  /// In en, this message translates to:
  /// **'/month'**
  String get perMonth;

  /// No description provided for @freePlanFeature1.
  ///
  /// In en, this message translates to:
  /// **'3 AI triage sessions/month'**
  String get freePlanFeature1;

  /// No description provided for @freePlanFeature2.
  ///
  /// In en, this message translates to:
  /// **'Basic health passport'**
  String get freePlanFeature2;

  /// No description provided for @freePlanFeature3.
  ///
  /// In en, this message translates to:
  /// **'QR code sharing'**
  String get freePlanFeature3;

  /// No description provided for @freePlanFeature4.
  ///
  /// In en, this message translates to:
  /// **'Emergency SOS alerts'**
  String get freePlanFeature4;

  /// No description provided for @freePlanFeature5.
  ///
  /// In en, this message translates to:
  /// **'Single user profile'**
  String get freePlanFeature5;

  /// No description provided for @proPlanFeature1.
  ///
  /// In en, this message translates to:
  /// **'Unlimited AI triage sessions'**
  String get proPlanFeature1;

  /// No description provided for @proPlanFeature2.
  ///
  /// In en, this message translates to:
  /// **'Advanced health passport'**
  String get proPlanFeature2;

  /// No description provided for @proPlanFeature3.
  ///
  /// In en, this message translates to:
  /// **'Weekly AI insights'**
  String get proPlanFeature3;

  /// No description provided for @proPlanFeature4.
  ///
  /// In en, this message translates to:
  /// **'Family profiles (up to 5)'**
  String get proPlanFeature4;

  /// No description provided for @proPlanFeature5.
  ///
  /// In en, this message translates to:
  /// **'PDF export with full history'**
  String get proPlanFeature5;

  /// No description provided for @proPlanFeature6.
  ///
  /// In en, this message translates to:
  /// **'Priority support'**
  String get proPlanFeature6;

  /// No description provided for @enterprisePlanFeature1.
  ///
  /// In en, this message translates to:
  /// **'Everything in Pro'**
  String get enterprisePlanFeature1;

  /// No description provided for @enterprisePlanFeature2.
  ///
  /// In en, this message translates to:
  /// **'Unlimited family profiles'**
  String get enterprisePlanFeature2;

  /// No description provided for @enterprisePlanFeature3.
  ///
  /// In en, this message translates to:
  /// **'Custom branding'**
  String get enterprisePlanFeature3;

  /// No description provided for @enterprisePlanFeature4.
  ///
  /// In en, this message translates to:
  /// **'API access'**
  String get enterprisePlanFeature4;

  /// No description provided for @enterprisePlanFeature5.
  ///
  /// In en, this message translates to:
  /// **'Dedicated support'**
  String get enterprisePlanFeature5;

  /// No description provided for @enterprisePlanFeature6.
  ///
  /// In en, this message translates to:
  /// **'SLA guarantee'**
  String get enterprisePlanFeature6;

  /// No description provided for @bestValue.
  ///
  /// In en, this message translates to:
  /// **'BEST VALUE'**
  String get bestValue;

  /// No description provided for @currentPlan.
  ///
  /// In en, this message translates to:
  /// **'Current Plan'**
  String get currentPlan;

  /// No description provided for @downgrade.
  ///
  /// In en, this message translates to:
  /// **'Downgrade'**
  String get downgrade;

  /// No description provided for @upgradeToPlan.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to {plan}'**
  String upgradeToPlan(String plan);

  /// No description provided for @mustBeSignedInToChangePlans.
  ///
  /// In en, this message translates to:
  /// **'You must be signed in to change plans.'**
  String get mustBeSignedInToChangePlans;

  /// No description provided for @switchToPlan.
  ///
  /// In en, this message translates to:
  /// **'Switch to {plan}?'**
  String switchToPlan(String plan);

  /// No description provided for @downgradeToFreeMessage.
  ///
  /// In en, this message translates to:
  /// **'You will lose access to Pro features at the end of your current billing period. Continue?'**
  String get downgradeToFreeMessage;

  /// No description provided for @upgradeToPlanMessage.
  ///
  /// In en, this message translates to:
  /// **'This will update your subscription to {plan}. In production this would launch the platform paywall; for now the change is applied directly to your account for testing.'**
  String upgradeToPlanMessage(String plan);

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @downgradedToFree.
  ///
  /// In en, this message translates to:
  /// **'Downgraded to Free. Pro access ends at the next billing period.'**
  String get downgradedToFree;

  /// No description provided for @welcomeToPlan.
  ///
  /// In en, this message translates to:
  /// **'Welcome to {plan}! All features unlocked.'**
  String welcomeToPlan(String plan);

  /// No description provided for @failedToUpdateSubscription.
  ///
  /// In en, this message translates to:
  /// **'Failed to update subscription. Please try again.'**
  String get failedToUpdateSubscription;

  /// No description provided for @purchasesRestored.
  ///
  /// In en, this message translates to:
  /// **'Purchases restored.'**
  String get purchasesRestored;

  /// No description provided for @failedToRestorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Failed to restore purchases.'**
  String get failedToRestorePurchases;

  /// No description provided for @contactSalesEnterprise.
  ///
  /// In en, this message translates to:
  /// **'Contact sales for custom Enterprise terms'**
  String get contactSalesEnterprise;

  /// No description provided for @emailSalesEnterprise.
  ///
  /// In en, this message translates to:
  /// **'Email sales@vitalseker.com for enterprise pricing.'**
  String get emailSalesEnterprise;

  /// No description provided for @poweredByProducer.
  ///
  /// In en, this message translates to:
  /// **'Powered by {producer}'**
  String poweredByProducer(String producer);

  /// No description provided for @frequentlyAskedQuestions.
  ///
  /// In en, this message translates to:
  /// **'Frequently Asked Questions'**
  String get frequentlyAskedQuestions;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get contactSupport;

  /// No description provided for @subject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get subject;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @otherWaysToReachUs.
  ///
  /// In en, this message translates to:
  /// **'Other Ways to Reach Us'**
  String get otherWaysToReachUs;

  /// No description provided for @emailUs.
  ///
  /// In en, this message translates to:
  /// **'Email Us'**
  String get emailUs;

  /// No description provided for @supportRequestSaved.
  ///
  /// In en, this message translates to:
  /// **'Your request is saved to your account and visible to our support team. We respond within 24 hours.'**
  String get supportRequestSaved;

  /// No description provided for @pleaseFillSubjectMessage.
  ///
  /// In en, this message translates to:
  /// **'Please fill in both subject and message.'**
  String get pleaseFillSubjectMessage;

  /// No description provided for @subjectMinLength.
  ///
  /// In en, this message translates to:
  /// **'Subject must be at least 5 characters.'**
  String get subjectMinLength;

  /// No description provided for @messageMinLength.
  ///
  /// In en, this message translates to:
  /// **'Message must be at least 10 characters.'**
  String get messageMinLength;

  /// No description provided for @mustBeSignedInToSubmitSupport.
  ///
  /// In en, this message translates to:
  /// **'You must be signed in to submit a support request.'**
  String get mustBeSignedInToSubmitSupport;

  /// No description provided for @urgentRequestReceived.
  ///
  /// In en, this message translates to:
  /// **'Urgent request received! Our team will prioritize this.'**
  String get urgentRequestReceived;

  /// No description provided for @supportRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Support request sent! We\'ll respond within 24 hours.'**
  String get supportRequestSent;

  /// No description provided for @failedToSubmitSupport.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit support request. Please try again or email support@vitalseker.com.'**
  String get failedToSubmitSupport;

  /// No description provided for @couldNotOpenEmailClient.
  ///
  /// In en, this message translates to:
  /// **'Could not open email client. Please email support@vitalseker.com manually.'**
  String get couldNotOpenEmailClient;

  /// No description provided for @faqQuestion1.
  ///
  /// In en, this message translates to:
  /// **'How does the AI symptom triage work?'**
  String get faqQuestion1;

  /// No description provided for @faqAnswer1.
  ///
  /// In en, this message translates to:
  /// **'Our AI analyzes your reported symptoms against a comprehensive medical database to provide urgency-based recommendations. It categorizes your condition into Low, Medium, High, or Emergency urgency levels and suggests appropriate next steps.'**
  String get faqAnswer1;

  /// No description provided for @faqQuestion2.
  ///
  /// In en, this message translates to:
  /// **'Is my health data secure?'**
  String get faqQuestion2;

  /// No description provided for @faqAnswer2.
  ///
  /// In en, this message translates to:
  /// **'Yes. All data is encrypted end-to-end using AES-256 encryption. We comply with GDPR and HIPAA standards. Your health information is never shared with third parties without your explicit consent.'**
  String get faqAnswer2;

  /// No description provided for @faqQuestion3.
  ///
  /// In en, this message translates to:
  /// **'How do I share my health passport?'**
  String get faqQuestion3;

  /// No description provided for @faqAnswer3.
  ///
  /// In en, this message translates to:
  /// **'Navigate to your Health Passport from the bottom navigation bar. Tap the QR code icon to generate a shareable QR code that healthcare providers can scan to access your critical health information securely.'**
  String get faqAnswer3;

  /// No description provided for @faqQuestion4.
  ///
  /// In en, this message translates to:
  /// **'Can I add family members?'**
  String get faqQuestion4;

  /// No description provided for @faqAnswer4.
  ///
  /// In en, this message translates to:
  /// **'Yes! Pro subscribers can add up to 5 family member profiles, and Enterprise subscribers have unlimited family profiles. Each family member gets their own health passport and triage capabilities.'**
  String get faqAnswer4;

  /// No description provided for @faqQuestion5.
  ///
  /// In en, this message translates to:
  /// **'How do I cancel my subscription?'**
  String get faqQuestion5;

  /// No description provided for @faqAnswer5.
  ///
  /// In en, this message translates to:
  /// **'Go to Profile > Subscription and select the Free plan to downgrade. Your Pro or Enterprise features will remain active until the end of your current billing period.'**
  String get faqAnswer5;

  /// No description provided for @exportConfigurePreview.
  ///
  /// In en, this message translates to:
  /// **'Configure and preview your comprehensive health summary before generating a secure PDF.'**
  String get exportConfigurePreview;

  /// No description provided for @includeSections.
  ///
  /// In en, this message translates to:
  /// **'Include Sections'**
  String get includeSections;

  /// No description provided for @last3Months.
  ///
  /// In en, this message translates to:
  /// **'Last 3 Months'**
  String get last3Months;

  /// No description provided for @yearToDate.
  ///
  /// In en, this message translates to:
  /// **'Year to Date'**
  String get yearToDate;

  /// No description provided for @allTime.
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get allTime;

  /// No description provided for @generating.
  ///
  /// In en, this message translates to:
  /// **'Generating…'**
  String get generating;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get sending;

  /// No description provided for @pdfIncludesProducer.
  ///
  /// In en, this message translates to:
  /// **'PDF includes {producer} credit as producer'**
  String pdfIncludesProducer(String producer);

  /// No description provided for @proFeature.
  ///
  /// In en, this message translates to:
  /// **'PRO FEATURE'**
  String get proFeature;

  /// No description provided for @proActive.
  ///
  /// In en, this message translates to:
  /// **'PRO ACTIVE'**
  String get proActive;

  /// No description provided for @manageHealthWholeFamily.
  ///
  /// In en, this message translates to:
  /// **'Manage health for your whole family (5 max)'**
  String get manageHealthWholeFamily;

  /// No description provided for @accountOwnerDefault.
  ///
  /// In en, this message translates to:
  /// **'Account Owner'**
  String get accountOwnerDefault;

  /// No description provided for @ownerProfile.
  ///
  /// In en, this message translates to:
  /// **'Owner profile'**
  String get ownerProfile;

  /// No description provided for @years.
  ///
  /// In en, this message translates to:
  /// **'{age} years'**
  String years(int age);

  /// No description provided for @scoreValue.
  ///
  /// In en, this message translates to:
  /// **'Score: {score}'**
  String scoreValue(int score);

  /// No description provided for @reachedProLimit.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached the 5-member Pro limit.'**
  String get reachedProLimit;

  /// No description provided for @limitReached.
  ///
  /// In en, this message translates to:
  /// **'Limit reached'**
  String get limitReached;

  /// No description provided for @pleaseFillNameRelationship.
  ///
  /// In en, this message translates to:
  /// **'Please fill in name and relationship'**
  String get pleaseFillNameRelationship;

  /// No description provided for @mustBeSignedInToAddFamily.
  ///
  /// In en, this message translates to:
  /// **'You must be signed in to add a family member'**
  String get mustBeSignedInToAddFamily;

  /// No description provided for @familyMemberAdded.
  ///
  /// In en, this message translates to:
  /// **'Family member added!'**
  String get familyMemberAdded;

  /// No description provided for @failedToAddFamily.
  ///
  /// In en, this message translates to:
  /// **'Failed to add family member. Please try again.'**
  String get failedToAddFamily;

  /// No description provided for @removeFamilyMember.
  ///
  /// In en, this message translates to:
  /// **'Remove Family Member'**
  String get removeFamilyMember;

  /// No description provided for @removeFamilyMemberConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove {name} from your family profiles?'**
  String removeFamilyMemberConfirm(String name);

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @familyMemberRemoved.
  ///
  /// In en, this message translates to:
  /// **'Family member removed'**
  String get familyMemberRemoved;

  /// No description provided for @failedToRemoveFamily.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove family member. Please try again.'**
  String get failedToRemoveFamily;

  /// No description provided for @fullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullNameLabel;

  /// No description provided for @relationshipExample.
  ///
  /// In en, this message translates to:
  /// **'Relationship (e.g., Spouse, Child)'**
  String get relationshipExample;

  /// No description provided for @bloodTypeOptional.
  ///
  /// In en, this message translates to:
  /// **'Blood Type (optional)'**
  String get bloodTypeOptional;

  /// No description provided for @removeMember.
  ///
  /// In en, this message translates to:
  /// **'Remove member'**
  String get removeMember;

  /// No description provided for @upgradeYourCare.
  ///
  /// In en, this message translates to:
  /// **'UPGRADE YOUR CARE'**
  String get upgradeYourCare;

  /// No description provided for @protectingWholeCircle.
  ///
  /// In en, this message translates to:
  /// **'You\'re protecting the whole circle.'**
  String get protectingWholeCircle;

  /// No description provided for @proMemberThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks for being a Pro member. You can monitor heart rate variability, sleep patterns, and AI-driven health risk assessments for up to 5 family members under a single subscription.'**
  String get proMemberThanks;

  /// No description provided for @proUpsellBody.
  ///
  /// In en, this message translates to:
  /// **'With VitalSeker Pro, you can monitor heart rate variability, sleep patterns, and AI-driven health risk assessments for up to 5 family members under a single subscription.'**
  String get proUpsellBody;

  /// No description provided for @upgradeToProPrice.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro — \${price}/mo'**
  String upgradeToProPrice(String price);

  /// No description provided for @manageSubscription.
  ///
  /// In en, this message translates to:
  /// **'Manage Subscription'**
  String get manageSubscription;

  /// No description provided for @failedToLoadProfiles.
  ///
  /// In en, this message translates to:
  /// **'Failed to load profiles'**
  String get failedToLoadProfiles;

  /// No description provided for @searchMedications.
  ///
  /// In en, this message translates to:
  /// **'Search medications...'**
  String get searchMedications;

  /// No description provided for @noMedicationsMatchSearch.
  ///
  /// In en, this message translates to:
  /// **'No medications match your search'**
  String get noMedicationsMatchSearch;

  /// No description provided for @noMedicationsYet.
  ///
  /// In en, this message translates to:
  /// **'No Medications Yet'**
  String get noMedicationsYet;

  /// No description provided for @addMedicationsTrack.
  ///
  /// In en, this message translates to:
  /// **'Add your medications to track dosages,\nfrequency, and adherence'**
  String get addMedicationsTrack;

  /// No description provided for @editMedicationName.
  ///
  /// In en, this message translates to:
  /// **'Edit {name}'**
  String editMedicationName(String name);

  /// No description provided for @dosage.
  ///
  /// In en, this message translates to:
  /// **'Dosage'**
  String get dosage;

  /// No description provided for @unit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unit;

  /// No description provided for @frequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get frequency;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @medicationDiscontinued.
  ///
  /// In en, this message translates to:
  /// **'Medication discontinued'**
  String get medicationDiscontinued;

  /// No description provided for @failedToDiscontinueMedication.
  ///
  /// In en, this message translates to:
  /// **'Failed to discontinue medication.'**
  String get failedToDiscontinueMedication;

  /// No description provided for @medicationUpdated.
  ///
  /// In en, this message translates to:
  /// **'Medication updated!'**
  String get medicationUpdated;

  /// No description provided for @failedToUpdateMedication.
  ///
  /// In en, this message translates to:
  /// **'Failed to update medication.'**
  String get failedToUpdateMedication;

  /// No description provided for @medicationMarkedCompleted.
  ///
  /// In en, this message translates to:
  /// **'Medication marked as completed'**
  String get medicationMarkedCompleted;

  /// No description provided for @deleteMedication.
  ///
  /// In en, this message translates to:
  /// **'Delete Medication'**
  String get deleteMedication;

  /// No description provided for @deleteMedicationConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {name}?'**
  String deleteMedicationConfirm(String name);

  /// No description provided for @medicationDeleted.
  ///
  /// In en, this message translates to:
  /// **'Medication deleted'**
  String get medicationDeleted;

  /// No description provided for @failedToDeleteMedication.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete medication.'**
  String get failedToDeleteMedication;

  /// No description provided for @editDetails.
  ///
  /// In en, this message translates to:
  /// **'Edit Details'**
  String get editDetails;

  /// No description provided for @markComplete.
  ///
  /// In en, this message translates to:
  /// **'Mark Complete'**
  String get markComplete;

  /// No description provided for @discontinue.
  ///
  /// In en, this message translates to:
  /// **'Discontinue'**
  String get discontinue;

  /// No description provided for @nextDose.
  ///
  /// In en, this message translates to:
  /// **'Next dose: {time}'**
  String nextDose(String time);

  /// No description provided for @onceDaily.
  ///
  /// In en, this message translates to:
  /// **'Once Daily'**
  String get onceDaily;

  /// No description provided for @twiceDaily.
  ///
  /// In en, this message translates to:
  /// **'Twice Daily'**
  String get twiceDaily;

  /// No description provided for @threeTimesDaily.
  ///
  /// In en, this message translates to:
  /// **'Three Times Daily'**
  String get threeTimesDaily;

  /// No description provided for @fourTimesDaily.
  ///
  /// In en, this message translates to:
  /// **'Four Times Daily'**
  String get fourTimesDaily;

  /// No description provided for @everyOtherDay.
  ///
  /// In en, this message translates to:
  /// **'Every Other Day'**
  String get everyOtherDay;

  /// No description provided for @weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// No description provided for @asNeeded.
  ///
  /// In en, this message translates to:
  /// **'As Needed'**
  String get asNeeded;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @noAppointmentsMatchFilter.
  ///
  /// In en, this message translates to:
  /// **'No appointments match the filter'**
  String get noAppointmentsMatchFilter;

  /// No description provided for @noAppointmentsYet.
  ///
  /// In en, this message translates to:
  /// **'No Appointments Yet'**
  String get noAppointmentsYet;

  /// No description provided for @scheduleFirstAppointment.
  ///
  /// In en, this message translates to:
  /// **'Schedule your first appointment to\nkeep track of visits'**
  String get scheduleFirstAppointment;

  /// No description provided for @appointmentMarkedCompleted.
  ///
  /// In en, this message translates to:
  /// **'Appointment marked as completed'**
  String get appointmentMarkedCompleted;

  /// No description provided for @failedToUpdateAppointment.
  ///
  /// In en, this message translates to:
  /// **'Failed to update appointment.'**
  String get failedToUpdateAppointment;

  /// No description provided for @appointmentCancelled.
  ///
  /// In en, this message translates to:
  /// **'Appointment cancelled'**
  String get appointmentCancelled;

  /// No description provided for @failedToCancelAppointment.
  ///
  /// In en, this message translates to:
  /// **'Failed to cancel appointment.'**
  String get failedToCancelAppointment;

  /// No description provided for @selectNewDate.
  ///
  /// In en, this message translates to:
  /// **'Select new date'**
  String get selectNewDate;

  /// No description provided for @selectNewTime.
  ///
  /// In en, this message translates to:
  /// **'Select new time'**
  String get selectNewTime;

  /// No description provided for @rescheduledTo.
  ///
  /// In en, this message translates to:
  /// **'Rescheduled to {date} at {time}'**
  String rescheduledTo(String date, String time);

  /// No description provided for @failedToRescheduleAppointment.
  ///
  /// In en, this message translates to:
  /// **'Failed to reschedule appointment.'**
  String get failedToRescheduleAppointment;

  /// No description provided for @deleteAppointment.
  ///
  /// In en, this message translates to:
  /// **'Delete Appointment'**
  String get deleteAppointment;

  /// No description provided for @deleteAppointmentConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete the appointment with {doctor}?'**
  String deleteAppointmentConfirm(String doctor);

  /// No description provided for @appointmentDeleted.
  ///
  /// In en, this message translates to:
  /// **'Appointment deleted'**
  String get appointmentDeleted;

  /// No description provided for @failedToDeleteAppointment.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete appointment.'**
  String get failedToDeleteAppointment;

  /// No description provided for @reschedule.
  ///
  /// In en, this message translates to:
  /// **'Reschedule'**
  String get reschedule;

  /// No description provided for @cancelAppointment.
  ///
  /// In en, this message translates to:
  /// **'Cancel Appointment'**
  String get cancelAppointment;

  /// No description provided for @medicalTranslationIntro.
  ///
  /// In en, this message translates to:
  /// **'Translate medical terms and phrases into your preferred language. Useful for travel, consultations, and discussing care with non-English-speaking providers.'**
  String get medicalTranslationIntro;

  /// No description provided for @medicalTermOrPhrase.
  ///
  /// In en, this message translates to:
  /// **'Medical term or phrase'**
  String get medicalTermOrPhrase;

  /// No description provided for @medicalTermHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. \"hypertension\", \"take twice daily with food\"'**
  String get medicalTermHint;

  /// No description provided for @translating.
  ///
  /// In en, this message translates to:
  /// **'Translating...'**
  String get translating;

  /// No description provided for @translationTargetLanguage.
  ///
  /// In en, this message translates to:
  /// **'Translation ({lang})'**
  String translationTargetLanguage(String lang);

  /// No description provided for @translationWillAppear.
  ///
  /// In en, this message translates to:
  /// **'Your translation will appear here.'**
  String get translationWillAppear;

  /// No description provided for @pleaseEnterTermToTranslate.
  ///
  /// In en, this message translates to:
  /// **'Please enter a medical term or phrase to translate.'**
  String get pleaseEnterTermToTranslate;

  /// No description provided for @noTranslationReturned.
  ///
  /// In en, this message translates to:
  /// **'No translation was returned. Please try a different term.'**
  String get noTranslationReturned;

  /// No description provided for @translationFailed.
  ///
  /// In en, this message translates to:
  /// **'Translation failed. Please try again.'**
  String get translationFailed;

  /// No description provided for @notificationSettings.
  ///
  /// In en, this message translates to:
  /// **'Notification Settings'**
  String get notificationSettings;

  /// No description provided for @failedToSaveNotificationSetting.
  ///
  /// In en, this message translates to:
  /// **'Failed to save notification setting'**
  String get failedToSaveNotificationSetting;

  /// No description provided for @keyFeatures.
  ///
  /// In en, this message translates to:
  /// **'Key Features'**
  String get keyFeatures;

  /// No description provided for @producer.
  ///
  /// In en, this message translates to:
  /// **'Producer'**
  String get producer;

  /// No description provided for @conceptDesignDevelopment.
  ///
  /// In en, this message translates to:
  /// **'Concept, Design & Development'**
  String get conceptDesignDevelopment;

  /// No description provided for @updateAccountCredentials.
  ///
  /// In en, this message translates to:
  /// **'Update your account credentials'**
  String get updateAccountCredentials;

  /// No description provided for @legal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get legal;

  /// No description provided for @aboutVitalSekerBody.
  ///
  /// In en, this message translates to:
  /// **'VitalSeker is your AI-powered health companion that puts you in control of your health journey. With intelligent symptom triage, a secure health passport, emergency SOS alerts, and personalized weekly insights, VitalSeker ensures you always have the information you need when it matters most. Built with cutting-edge AI technology and bank-grade security, your health data stays private and protected.'**
  String get aboutVitalSekerBody;

  /// No description provided for @featureAiTriageTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Symptom Triage'**
  String get featureAiTriageTitle;

  /// No description provided for @featureAiTriageDesc.
  ///
  /// In en, this message translates to:
  /// **'Get instant AI-powered health recommendations'**
  String get featureAiTriageDesc;

  /// No description provided for @featureHealthPassportTitle.
  ///
  /// In en, this message translates to:
  /// **'Health Passport'**
  String get featureHealthPassportTitle;

  /// No description provided for @featureHealthPassportDesc.
  ///
  /// In en, this message translates to:
  /// **'Carry your encrypted health profile everywhere'**
  String get featureHealthPassportDesc;

  /// No description provided for @featureQrSharingTitle.
  ///
  /// In en, this message translates to:
  /// **'QR Code Sharing'**
  String get featureQrSharingTitle;

  /// No description provided for @featureQrSharingDesc.
  ///
  /// In en, this message translates to:
  /// **'Share health info securely with any provider'**
  String get featureQrSharingDesc;

  /// No description provided for @featureEmergencySosTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency SOS'**
  String get featureEmergencySosTitle;

  /// No description provided for @featureEmergencySosDesc.
  ///
  /// In en, this message translates to:
  /// **'One-tap alerts with GPS location sharing'**
  String get featureEmergencySosDesc;

  /// No description provided for @featureWeeklyInsightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly Insights'**
  String get featureWeeklyInsightsTitle;

  /// No description provided for @featureWeeklyInsightsDesc.
  ///
  /// In en, this message translates to:
  /// **'AI-generated health summaries (Pro)'**
  String get featureWeeklyInsightsDesc;

  /// No description provided for @featureFamilyProfilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Family Profiles'**
  String get featureFamilyProfilesTitle;

  /// No description provided for @featureFamilyProfilesDesc.
  ///
  /// In en, this message translates to:
  /// **'Manage health for your entire family'**
  String get featureFamilyProfilesDesc;

  /// No description provided for @featurePdfExportTitle.
  ///
  /// In en, this message translates to:
  /// **'PDF Export'**
  String get featurePdfExportTitle;

  /// No description provided for @featurePdfExportDesc.
  ///
  /// In en, this message translates to:
  /// **'Generate and share health reports'**
  String get featurePdfExportDesc;

  /// No description provided for @termsOfServiceTitle.
  ///
  /// In en, this message translates to:
  /// **'{appName} Terms of Service'**
  String termsOfServiceTitle(String appName);

  /// No description provided for @lastUpdatedVersion.
  ///
  /// In en, this message translates to:
  /// **'Last updated: Version {version}'**
  String lastUpdatedVersion(String version);

  /// No description provided for @tosSection1Title.
  ///
  /// In en, this message translates to:
  /// **'Acceptance of Terms'**
  String get tosSection1Title;

  /// No description provided for @tosSection1Para1.
  ///
  /// In en, this message translates to:
  /// **'By creating an account, accessing, or using the {appName} mobile application (\"the Service\"), you agree to be bound by these Terms of Service (\"Terms\"). If you do not agree to these Terms, you must not access or use the Service.'**
  String tosSection1Para1(String appName);

  /// No description provided for @tosSection1Para2.
  ///
  /// In en, this message translates to:
  /// **'The Service is provided by {producer} (\"we\", \"us\", or \"our\"). These Terms form a legally binding agreement between you and us.'**
  String tosSection1Para2(String producer);

  /// No description provided for @tosSection2Title.
  ///
  /// In en, this message translates to:
  /// **'Eligibility & Account'**
  String get tosSection2Title;

  /// No description provided for @tosSection2Para1.
  ///
  /// In en, this message translates to:
  /// **'You must be at least 13 years old to use the Service. If you are under 18, you represent that your parent or legal guardian has read and agreed to these Terms on your behalf.'**
  String get tosSection2Para1;

  /// No description provided for @tosSection2Para2.
  ///
  /// In en, this message translates to:
  /// **'You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account. Notify us immediately of any unauthorized use of your account.'**
  String get tosSection2Para2;

  /// No description provided for @tosSection3Title.
  ///
  /// In en, this message translates to:
  /// **'Health Information — Not Medical Advice'**
  String get tosSection3Title;

  /// No description provided for @tosSection3Para1.
  ///
  /// In en, this message translates to:
  /// **'{appName} is a health companion application intended for informational and organizational purposes only. The Service is NOT a medical device and does not provide medical advice, diagnosis, or treatment recommendations.'**
  String tosSection3Para1(String appName);

  /// No description provided for @tosSection3Para2.
  ///
  /// In en, this message translates to:
  /// **'The AI triage feature provides general guidance based on the symptoms you report. It is not a substitute for professional medical judgment. Always seek the advice of a qualified healthcare provider with any questions you may have regarding a medical condition. Never disregard professional medical advice or delay seeking it because of something you read in this Service.'**
  String get tosSection3Para2;

  /// No description provided for @tosSection3Para3.
  ///
  /// In en, this message translates to:
  /// **'In a medical emergency, call your local emergency number (e.g. 911, 112) immediately. Do not rely on the Service for emergency response.'**
  String get tosSection3Para3;

  /// No description provided for @tosSection4Title.
  ///
  /// In en, this message translates to:
  /// **'Use of the Service'**
  String get tosSection4Title;

  /// No description provided for @tosSection4Intro.
  ///
  /// In en, this message translates to:
  /// **'You agree NOT to:'**
  String get tosSection4Intro;

  /// No description provided for @tosSection4Bullet1.
  ///
  /// In en, this message translates to:
  /// **'Use the Service for any unlawful purpose;'**
  String get tosSection4Bullet1;

  /// No description provided for @tosSection4Bullet2.
  ///
  /// In en, this message translates to:
  /// **'Attempt to reverse-engineer, decompile, or disassemble the app;'**
  String get tosSection4Bullet2;

  /// No description provided for @tosSection4Bullet3.
  ///
  /// In en, this message translates to:
  /// **'Upload content that is malicious, fraudulent, or violates intellectual property rights;'**
  String get tosSection4Bullet3;

  /// No description provided for @tosSection4Bullet4.
  ///
  /// In en, this message translates to:
  /// **'Interfere with the proper functioning of the Service or attempt to access data belonging to other users;'**
  String get tosSection4Bullet4;

  /// No description provided for @tosSection4Bullet5.
  ///
  /// In en, this message translates to:
  /// **'Use the Service to send unsolicited communications or spam.'**
  String get tosSection4Bullet5;

  /// No description provided for @tosSection5Title.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions & Payments'**
  String get tosSection5Title;

  /// No description provided for @tosSection5Para1.
  ///
  /// In en, this message translates to:
  /// **'Certain features of the Service require a paid subscription (\"Pro\" or \"Enterprise\" plan). Subscription fees are billed monthly through the platform application store (Apple App Store or Google Play Store) subject to their respective terms.'**
  String get tosSection5Para1;

  /// No description provided for @tosSection5Para2.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current billing period. You can manage or cancel your subscription at any time through your platform\'s account settings.'**
  String get tosSection5Para2;

  /// No description provided for @tosSection5Para3.
  ///
  /// In en, this message translates to:
  /// **'We may change subscription fees upon reasonable notice. Fee changes will not apply to your current billing period.'**
  String get tosSection5Para3;

  /// No description provided for @tosSection6Title.
  ///
  /// In en, this message translates to:
  /// **'Your Data'**
  String get tosSection6Title;

  /// No description provided for @tosSection6Para1.
  ///
  /// In en, this message translates to:
  /// **'You retain ownership of the health data you submit to the Service. Our use of your data is described in our Privacy Policy, which is incorporated into these Terms by reference.'**
  String get tosSection6Para1;

  /// No description provided for @tosSection6Para2.
  ///
  /// In en, this message translates to:
  /// **'You may export your data at any time via the in-app Export feature, and you may permanently delete your account and all associated data via Settings → Delete Account.'**
  String get tosSection6Para2;

  /// No description provided for @tosSection7Title.
  ///
  /// In en, this message translates to:
  /// **'Disclaimers'**
  String get tosSection7Title;

  /// No description provided for @tosSection7Para1.
  ///
  /// In en, this message translates to:
  /// **'THE SERVICE IS PROVIDED \"AS IS\" AND \"AS AVAILABLE\" WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.'**
  String get tosSection7Para1;

  /// No description provided for @tosSection7Para2.
  ///
  /// In en, this message translates to:
  /// **'We do not warrant that the Service will be uninterrupted, error-free, or secure, or that the AI triage recommendations will be accurate or appropriate for your specific situation.'**
  String get tosSection7Para2;

  /// No description provided for @tosSection8Title.
  ///
  /// In en, this message translates to:
  /// **'Limitation of Liability'**
  String get tosSection8Title;

  /// No description provided for @tosSection8Para1.
  ///
  /// In en, this message translates to:
  /// **'TO THE MAXIMUM EXTENT PERMITTED BY LAW, IN NO EVENT SHALL {producer} BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, OR ANY LOSS OF DATA, ARISING OUT OF OR RELATED TO YOUR USE OF (OR INABILITY TO USE) THE SERVICE, WHETHER BASED ON WARRANTY, CONTRACT, TORT, OR ANY OTHER LEGAL THEORY.'**
  String tosSection8Para1(String producer);

  /// No description provided for @tosSection9Title.
  ///
  /// In en, this message translates to:
  /// **'Termination'**
  String get tosSection9Title;

  /// No description provided for @tosSection9Para1.
  ///
  /// In en, this message translates to:
  /// **'You may stop using the Service and delete your account at any time via Settings. We may suspend or terminate your access to the Service if you violate these Terms or if we reasonably believe we are required to do so by law.'**
  String get tosSection9Para1;

  /// No description provided for @tosSection9Para2.
  ///
  /// In en, this message translates to:
  /// **'Upon termination, all licenses granted to you will end, and your data will be deleted in accordance with our Privacy Policy.'**
  String get tosSection9Para2;

  /// No description provided for @tosSection10Title.
  ///
  /// In en, this message translates to:
  /// **'Changes to These Terms'**
  String get tosSection10Title;

  /// No description provided for @tosSection10Para1.
  ///
  /// In en, this message translates to:
  /// **'We may update these Terms from time to time. We will notify you of material changes via the app or by email. Continued use of the Service after changes take effect constitutes acceptance of the revised Terms.'**
  String get tosSection10Para1;

  /// No description provided for @tosSection11Title.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get tosSection11Title;

  /// No description provided for @tosSection11Para1.
  ///
  /// In en, this message translates to:
  /// **'Questions about these Terms? Contact us at support@vitalseker.com.'**
  String get tosSection11Para1;

  /// No description provided for @tosCopyright.
  ///
  /// In en, this message translates to:
  /// **'© {year} {producer}. All rights reserved. Version {version}.'**
  String tosCopyright(int year, String producer, String version);

  /// No description provided for @free.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// No description provided for @pro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get pro;

  /// No description provided for @enterprise.
  ///
  /// In en, this message translates to:
  /// **'Enterprise'**
  String get enterprise;

  /// No description provided for @nA.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get nA;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @enterVitalSeker.
  ///
  /// In en, this message translates to:
  /// **'Enter VitalSeker'**
  String get enterVitalSeker;

  /// No description provided for @onboardingTitle1.
  ///
  /// In en, this message translates to:
  /// **'Know your body.'**
  String get onboardingTitle1;

  /// No description provided for @onboardingDescription1.
  ///
  /// In en, this message translates to:
  /// **'Check any symptom and get reliable medical insights in seconds.'**
  String get onboardingDescription1;

  /// No description provided for @onboardingTitle2.
  ///
  /// In en, this message translates to:
  /// **'Your health, always with you.'**
  String get onboardingTitle2;

  /// No description provided for @onboardingDescription2.
  ///
  /// In en, this message translates to:
  /// **'Store your full medical profile, records, and digital insurance cards in one secure, encrypted vault.'**
  String get onboardingDescription2;

  /// No description provided for @onboardingTitle3.
  ///
  /// In en, this message translates to:
  /// **'Works everywhere.\nEven offline.'**
  String get onboardingTitle3;

  /// No description provided for @onboardingDescription3.
  ///
  /// In en, this message translates to:
  /// **'Supported in 40+ languages and counting. Your data stays with you, syncing automatically the moment you\'re back online.'**
  String get onboardingDescription3;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your VitalSeker account'**
  String get signInSubtitle;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get signingIn;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailRequired;

  /// No description provided for @enterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get enterValidEmail;

  /// No description provided for @enterValidEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get enterValidEmailAddress;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// No description provided for @enterEmailFirst.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email address first.'**
  String get enterEmailFirst;

  /// No description provided for @passwordResetSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset link sent to {email}'**
  String passwordResetSent(String email);

  /// No description provided for @google.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get google;

  /// No description provided for @apple.
  ///
  /// In en, this message translates to:
  /// **'Apple'**
  String get apple;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @creatingAccount.
  ///
  /// In en, this message translates to:
  /// **'Creating account...'**
  String get creatingAccount;

  /// No description provided for @joinVitalSeker.
  ///
  /// In en, this message translates to:
  /// **'Join VitalSeker and take control of your health'**
  String get joinVitalSeker;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameRequired;

  /// No description provided for @nameMinChars.
  ///
  /// In en, this message translates to:
  /// **'Name must be at least 2 characters'**
  String get nameMinChars;

  /// No description provided for @atLeast6Chars.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get atLeast6Chars;

  /// No description provided for @includeUppercase.
  ///
  /// In en, this message translates to:
  /// **'Include at least one uppercase letter'**
  String get includeUppercase;

  /// No description provided for @includeLowercase.
  ///
  /// In en, this message translates to:
  /// **'Include at least one lowercase letter'**
  String get includeLowercase;

  /// No description provided for @includeNumber.
  ///
  /// In en, this message translates to:
  /// **'Include at least one number'**
  String get includeNumber;

  /// No description provided for @includeSymbol.
  ///
  /// In en, this message translates to:
  /// **'Include at least one symbol (!@#\$%^&*)'**
  String get includeSymbol;

  /// No description provided for @confirmPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get confirmPasswordRequired;

  /// No description provided for @optionalDetails.
  ///
  /// In en, this message translates to:
  /// **'Optional Details'**
  String get optionalDetails;

  /// No description provided for @dateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get dateOfBirth;

  /// No description provided for @selectDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Select Date of Birth'**
  String get selectDateOfBirth;

  /// No description provided for @selectDateOfBirthHint.
  ///
  /// In en, this message translates to:
  /// **'Select your date of birth'**
  String get selectDateOfBirthHint;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @selectGender.
  ///
  /// In en, this message translates to:
  /// **'Select gender'**
  String get selectGender;

  /// No description provided for @bloodType.
  ///
  /// In en, this message translates to:
  /// **'Blood Type'**
  String get bloodType;

  /// No description provided for @selectBloodType.
  ///
  /// In en, this message translates to:
  /// **'Select blood type'**
  String get selectBloodType;

  /// No description provided for @iAgreeTo.
  ///
  /// In en, this message translates to:
  /// **'I agree to the '**
  String get iAgreeTo;

  /// No description provided for @andText.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get andText;

  /// No description provided for @acceptTermsRequired.
  ///
  /// In en, this message translates to:
  /// **'Please accept the Terms of Service and Privacy Policy to continue.'**
  String get acceptTermsRequired;

  /// No description provided for @accountCreatedVerifyEmail.
  ///
  /// In en, this message translates to:
  /// **'Account created! Please check your email to verify your account.'**
  String get accountCreatedVerifyEmail;

  /// No description provided for @userFallback.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get userFallback;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @failedLoadRecentChecks.
  ///
  /// In en, this message translates to:
  /// **'Failed to load recent checks'**
  String get failedLoadRecentChecks;

  /// No description provided for @pullDownRetry.
  ///
  /// In en, this message translates to:
  /// **'Pull down to retry'**
  String get pullDownRetry;

  /// No description provided for @goodCondition.
  ///
  /// In en, this message translates to:
  /// **'Good condition'**
  String get goodCondition;

  /// No description provided for @fairCondition.
  ///
  /// In en, this message translates to:
  /// **'Fair condition'**
  String get fairCondition;

  /// No description provided for @needsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get needsAttention;

  /// No description provided for @poorCondition.
  ///
  /// In en, this message translates to:
  /// **'Poor condition'**
  String get poorCondition;

  /// No description provided for @critical.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get critical;

  /// No description provided for @overallHealthIndicator.
  ///
  /// In en, this message translates to:
  /// **'Your overall health indicator'**
  String get overallHealthIndicator;

  /// No description provided for @tapForWeeklyInsights.
  ///
  /// In en, this message translates to:
  /// **'Tap for weekly insights'**
  String get tapForWeeklyInsights;

  /// No description provided for @aiPoweredTriage60s.
  ///
  /// In en, this message translates to:
  /// **'AI-powered triage in 60 seconds'**
  String get aiPoweredTriage60s;

  /// No description provided for @qrAndMedicalInfo.
  ///
  /// In en, this message translates to:
  /// **'QR & medical info'**
  String get qrAndMedicalInfo;

  /// No description provided for @pastChecksAndVitals.
  ///
  /// In en, this message translates to:
  /// **'Past checks & vitals'**
  String get pastChecksAndVitals;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String hoursAgo(int hours);

  /// No description provided for @todayLabel.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayLabel;

  /// No description provided for @yesterdayLabel.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterdayLabel;

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String daysAgo(int days);

  /// No description provided for @symptomCheck.
  ///
  /// In en, this message translates to:
  /// **'Symptom check'**
  String get symptomCheck;

  /// No description provided for @severity.
  ///
  /// In en, this message translates to:
  /// **'Severity'**
  String get severity;

  /// No description provided for @aiGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hello! I\'m VitalSeker AI. How are you feeling today? Describe your symptoms and I\'ll help assess your condition.'**
  String get aiGreeting;

  /// No description provided for @triageAssessmentIntro.
  ///
  /// In en, this message translates to:
  /// **'Based on your symptoms, here\'s my assessment:'**
  String get triageAssessmentIntro;

  /// No description provided for @urgencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Urgency'**
  String get urgencyLabel;

  /// No description provided for @careRecommendationLabel.
  ///
  /// In en, this message translates to:
  /// **'Care recommendation'**
  String get careRecommendationLabel;

  /// No description provided for @redFlagsLabel.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Red flags:'**
  String get redFlagsLabel;

  /// No description provided for @recommendationsLabel.
  ///
  /// In en, this message translates to:
  /// **'Recommendations:'**
  String get recommendationsLabel;

  /// No description provided for @tapForFullAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Tap \"View Detailed Results\" below for the full analysis.'**
  String get tapForFullAnalysis;

  /// No description provided for @triageErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'I\'m sorry, I encountered an error analyzing your symptoms. Please try again or describe your symptoms differently.\n\nError: {error}'**
  String triageErrorMessage(String error);

  /// No description provided for @generalDiscomfort.
  ///
  /// In en, this message translates to:
  /// **'General discomfort'**
  String get generalDiscomfort;

  /// No description provided for @selfCareRecommended.
  ///
  /// In en, this message translates to:
  /// **'Self-Care Recommended'**
  String get selfCareRecommended;

  /// No description provided for @scheduleAppointmentCare.
  ///
  /// In en, this message translates to:
  /// **'Schedule an Appointment'**
  String get scheduleAppointmentCare;

  /// No description provided for @visitUrgentCare.
  ///
  /// In en, this message translates to:
  /// **'Visit Urgent Care'**
  String get visitUrgentCare;

  /// No description provided for @seekEmergencyCare.
  ///
  /// In en, this message translates to:
  /// **'Seek Emergency Care'**
  String get seekEmergencyCare;

  /// No description provided for @consultHealthcareProvider.
  ///
  /// In en, this message translates to:
  /// **'Consult a Healthcare Provider'**
  String get consultHealthcareProvider;

  /// No description provided for @mild.
  ///
  /// In en, this message translates to:
  /// **'Mild'**
  String get mild;

  /// No description provided for @moderate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get moderate;

  /// No description provided for @significant.
  ///
  /// In en, this message translates to:
  /// **'Significant'**
  String get significant;

  /// No description provided for @severeLabel.
  ///
  /// In en, this message translates to:
  /// **'Severe'**
  String get severeLabel;

  /// No description provided for @extreme.
  ///
  /// In en, this message translates to:
  /// **'Extreme'**
  String get extreme;

  /// No description provided for @triageResults.
  ///
  /// In en, this message translates to:
  /// **'Triage Results'**
  String get triageResults;

  /// No description provided for @urgencyScoreCaption.
  ///
  /// In en, this message translates to:
  /// **'Urgency Score: {score}/100'**
  String urgencyScoreCaption(int score);

  /// No description provided for @redFlags.
  ///
  /// In en, this message translates to:
  /// **'Red Flags'**
  String get redFlags;

  /// No description provided for @recommendations.
  ///
  /// In en, this message translates to:
  /// **'Recommendations'**
  String get recommendations;

  /// No description provided for @possibleConditions.
  ///
  /// In en, this message translates to:
  /// **'Possible Conditions'**
  String get possibleConditions;

  /// No description provided for @followUpQuestions.
  ///
  /// In en, this message translates to:
  /// **'Follow-up Questions'**
  String get followUpQuestions;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// No description provided for @seeDoctorSoon.
  ///
  /// In en, this message translates to:
  /// **'See a Doctor Soon'**
  String get seeDoctorSoon;

  /// No description provided for @emergencyCareNow.
  ///
  /// In en, this message translates to:
  /// **'Emergency Care Now'**
  String get emergencyCareNow;

  /// No description provided for @triageDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'This is not a medical diagnosis. Always consult a healthcare professional for proper medical advice.'**
  String get triageDisclaimer;

  /// No description provided for @escalateLow1.
  ///
  /// In en, this message translates to:
  /// **'Symptoms worsen or spread to new body areas'**
  String get escalateLow1;

  /// No description provided for @escalateLow2.
  ///
  /// In en, this message translates to:
  /// **'Fever rises above 39°C (102°F)'**
  String get escalateLow2;

  /// No description provided for @escalateLow3.
  ///
  /// In en, this message translates to:
  /// **'No improvement after 48 hours of self-care'**
  String get escalateLow3;

  /// No description provided for @escalateMedium1.
  ///
  /// In en, this message translates to:
  /// **'Symptoms persist beyond 3 days'**
  String get escalateMedium1;

  /// No description provided for @escalateMedium2.
  ///
  /// In en, this message translates to:
  /// **'Pain intensifies or becomes unmanageable'**
  String get escalateMedium2;

  /// No description provided for @escalateMedium3.
  ///
  /// In en, this message translates to:
  /// **'New red-flag symptoms appear'**
  String get escalateMedium3;

  /// No description provided for @escalateHigh1.
  ///
  /// In en, this message translates to:
  /// **'Symptoms rapidly worsen'**
  String get escalateHigh1;

  /// No description provided for @escalateHigh2.
  ///
  /// In en, this message translates to:
  /// **'Difficulty breathing or chest tightness develops'**
  String get escalateHigh2;

  /// No description provided for @escalateHigh3.
  ///
  /// In en, this message translates to:
  /// **'High fever (>39°C) that doesn\'t respond to medication'**
  String get escalateHigh3;

  /// No description provided for @escalateEmergency1.
  ///
  /// In en, this message translates to:
  /// **'Call emergency services immediately'**
  String get escalateEmergency1;

  /// No description provided for @escalateEmergency2.
  ///
  /// In en, this message translates to:
  /// **'Do not drive yourself — get a ride or ambulance'**
  String get escalateEmergency2;

  /// No description provided for @escalateEmergency3.
  ///
  /// In en, this message translates to:
  /// **'Bring this triage result and any medications you take'**
  String get escalateEmergency3;

  /// No description provided for @showQrCode.
  ///
  /// In en, this message translates to:
  /// **'Show QR Code'**
  String get showQrCode;

  /// No description provided for @inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// No description provided for @knownAllergies.
  ///
  /// In en, this message translates to:
  /// **'Known Allergies'**
  String get knownAllergies;

  /// No description provided for @currentMedications.
  ///
  /// In en, this message translates to:
  /// **'Current Medications'**
  String get currentMedications;

  /// No description provided for @chronicConditions.
  ///
  /// In en, this message translates to:
  /// **'Chronic Conditions'**
  String get chronicConditions;

  /// No description provided for @insurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get insurance;

  /// No description provided for @qrCode.
  ///
  /// In en, this message translates to:
  /// **'QR Code'**
  String get qrCode;

  /// No description provided for @exportPdf.
  ///
  /// In en, this message translates to:
  /// **'Export PDF'**
  String get exportPdf;

  /// No description provided for @noHealthPassportYet.
  ///
  /// In en, this message translates to:
  /// **'No Health Passport Yet'**
  String get noHealthPassportYet;

  /// No description provided for @completeFirstTriage.
  ///
  /// In en, this message translates to:
  /// **'Complete your first triage to generate\nyour health passport'**
  String get completeFirstTriage;

  /// No description provided for @heightAndWeight.
  ///
  /// In en, this message translates to:
  /// **'Height & Weight'**
  String get heightAndWeight;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @yearsOld.
  ///
  /// In en, this message translates to:
  /// **'{count} years old'**
  String yearsOld(int count);

  /// No description provided for @allergiesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} Allergy} other{{count} Allergies}}'**
  String allergiesCount(int count);

  /// No description provided for @medicationsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} Medication} other{{count} Medications}}'**
  String medicationsCount(int count);

  /// No description provided for @healthPassportQr.
  ///
  /// In en, this message translates to:
  /// **'Health Passport QR'**
  String get healthPassportQr;

  /// No description provided for @pointQrReader.
  ///
  /// In en, this message translates to:
  /// **'Point this at any QR reader to securely share your vitals.'**
  String get pointQrReader;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'DOWNLOAD'**
  String get download;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'SHARE'**
  String get share;

  /// No description provided for @noQrCodeGenerated.
  ///
  /// In en, this message translates to:
  /// **'No QR Code Generated'**
  String get noQrCodeGenerated;

  /// No description provided for @generateQrCode.
  ///
  /// In en, this message translates to:
  /// **'Generate QR Code'**
  String get generateQrCode;

  /// No description provided for @expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expired;

  /// No description provided for @validFor.
  ///
  /// In en, this message translates to:
  /// **'Valid for {hours}h {minutes}m'**
  String validFor(int hours, int minutes);

  /// No description provided for @emergencySosTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency SOS'**
  String get emergencySosTitle;

  /// No description provided for @keepHolding.
  ///
  /// In en, this message translates to:
  /// **'Keep holding...'**
  String get keepHolding;

  /// No description provided for @nearbyHospitals.
  ///
  /// In en, this message translates to:
  /// **'Nearby Hospitals'**
  String get nearbyHospitals;

  /// No description provided for @allergies.
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get allergies;

  /// No description provided for @conditions.
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get conditions;

  /// No description provided for @noMedicalInfoPrefix.
  ///
  /// In en, this message translates to:
  /// **'No medical information on file. Update your profile to '**
  String get noMedicalInfoPrefix;

  /// No description provided for @addMedicalIdData.
  ///
  /// In en, this message translates to:
  /// **'add medical ID data'**
  String get addMedicalIdData;

  /// No description provided for @sosTip.
  ///
  /// In en, this message translates to:
  /// **'SOS sends your GPS location to your emergency contacts via SMS. Make sure your contacts are configured in your profile.'**
  String get sosTip;

  /// No description provided for @sendingCaps.
  ///
  /// In en, this message translates to:
  /// **'SENDING'**
  String get sendingCaps;

  /// No description provided for @sosFailed.
  ///
  /// In en, this message translates to:
  /// **'SOS FAILED'**
  String get sosFailed;

  /// No description provided for @sosActive.
  ///
  /// In en, this message translates to:
  /// **'SOS ACTIVE'**
  String get sosActive;

  /// No description provided for @sendingEmergencyAlert.
  ///
  /// In en, this message translates to:
  /// **'Sending Emergency Alert'**
  String get sendingEmergencyAlert;

  /// No description provided for @alertCouldNotBeSent.
  ///
  /// In en, this message translates to:
  /// **'Alert Could Not Be Sent'**
  String get alertCouldNotBeSent;

  /// No description provided for @emergencyAlertSent.
  ///
  /// In en, this message translates to:
  /// **'Emergency Alert Sent'**
  String get emergencyAlertSent;

  /// No description provided for @sendingIn.
  ///
  /// In en, this message translates to:
  /// **'Sending in {seconds}…'**
  String sendingIn(int seconds);

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @euEmergency.
  ///
  /// In en, this message translates to:
  /// **'EU Emergency'**
  String get euEmergency;

  /// No description provided for @usEmergency.
  ///
  /// In en, this message translates to:
  /// **'US Emergency'**
  String get usEmergency;

  /// No description provided for @samuEmergency.
  ///
  /// In en, this message translates to:
  /// **'SAMU (FR)'**
  String get samuEmergency;

  /// No description provided for @opensMapsHospitals.
  ///
  /// In en, this message translates to:
  /// **'Opens your maps app with emergency hospitals nearby'**
  String get opensMapsHospitals;

  /// No description provided for @liveLocation.
  ///
  /// In en, this message translates to:
  /// **'Live Location'**
  String get liveLocation;

  /// No description provided for @acquiringGps.
  ///
  /// In en, this message translates to:
  /// **'Acquiring GPS coordinates…'**
  String get acquiringGps;

  /// No description provided for @locationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Location unavailable'**
  String get locationUnavailable;

  /// No description provided for @contactsNotified.
  ///
  /// In en, this message translates to:
  /// **'Contacts Notified'**
  String get contactsNotified;

  /// No description provided for @contactsNotifiedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} contact reached via SMS} other{{count} contacts reached via SMS}}'**
  String contactsNotifiedCount(int count);

  /// No description provided for @failedLoadHistory.
  ///
  /// In en, this message translates to:
  /// **'Failed to load history'**
  String get failedLoadHistory;

  /// No description provided for @thisMonthCount.
  ///
  /// In en, this message translates to:
  /// **'{count} THIS MONTH'**
  String thisMonthCount(int count);

  /// No description provided for @noLogsMatchFilters.
  ///
  /// In en, this message translates to:
  /// **'No logs match your filters'**
  String get noLogsMatchFilters;

  /// No description provided for @tryDifferentSearch.
  ///
  /// In en, this message translates to:
  /// **'Try a different search or filter.'**
  String get tryDifferentSearch;

  /// No description provided for @searchLogs.
  ///
  /// In en, this message translates to:
  /// **'Search logs...'**
  String get searchLogs;

  /// No description provided for @filterGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get filterGreen;

  /// No description provided for @filterYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get filterYellow;

  /// No description provided for @filterRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get filterRed;

  /// No description provided for @severityCaption.
  ///
  /// In en, this message translates to:
  /// **'Severity: {score}/10'**
  String severityCaption(int score);

  /// No description provided for @allSymptoms.
  ///
  /// In en, this message translates to:
  /// **'All Symptoms'**
  String get allSymptoms;

  /// No description provided for @bodyRegionsCaption.
  ///
  /// In en, this message translates to:
  /// **'Body Regions: {regions}'**
  String bodyRegionsCaption(String regions);

  /// No description provided for @durationCaption.
  ///
  /// In en, this message translates to:
  /// **'Duration: {duration}'**
  String durationCaption(String duration);

  /// No description provided for @aiRecommendationCaption.
  ///
  /// In en, this message translates to:
  /// **'AI Recommendation: {recommendation}'**
  String aiRecommendationCaption(String recommendation);

  /// No description provided for @viewFullTriageResult.
  ///
  /// In en, this message translates to:
  /// **'View Full Triage Result'**
  String get viewFullTriageResult;

  /// No description provided for @notesCaption.
  ///
  /// In en, this message translates to:
  /// **'Notes: {notes}'**
  String notesCaption(String notes);

  /// No description provided for @export30DayReport.
  ///
  /// In en, this message translates to:
  /// **'Export 30-day Report (Pro)'**
  String get export30DayReport;

  /// No description provided for @weeklyBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Weekly Breakdown'**
  String get weeklyBreakdown;

  /// No description provided for @proAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Pro Analysis'**
  String get proAnalysis;

  /// No description provided for @yourHealthThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Your health this week'**
  String get yourHealthThisWeek;

  /// No description provided for @scoreChangePts.
  ///
  /// In en, this message translates to:
  /// **'{change} pts'**
  String scoreChangePts(int change);

  /// No description provided for @trendAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Trend Analysis'**
  String get trendAnalysis;

  /// No description provided for @symptomFrequency4w.
  ///
  /// In en, this message translates to:
  /// **'SYMPTOM FREQUENCY (4W)'**
  String get symptomFrequency4w;

  /// No description provided for @chartHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get chartHigh;

  /// No description provided for @chartAvg.
  ///
  /// In en, this message translates to:
  /// **'Avg'**
  String get chartAvg;

  /// No description provided for @chartLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get chartLow;

  /// No description provided for @tipSleepTitle.
  ///
  /// In en, this message translates to:
  /// **'Extend deep sleep'**
  String get tipSleepTitle;

  /// No description provided for @tipSleepBody.
  ///
  /// In en, this message translates to:
  /// **'Your core temperature dropped late this week. Try maintaining a cooler room environment (65°F) to accelerate onset of deep sleep phases.'**
  String get tipSleepBody;

  /// No description provided for @tipHydrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Front-load hydration'**
  String get tipHydrationTitle;

  /// No description provided for @tipHydrationBody.
  ///
  /// In en, this message translates to:
  /// **'Mild dehydration markers detected in afternoon logs. Shift 40% of your daily water intake to before 10 AM to stabilize metabolic rate.'**
  String get tipHydrationBody;

  /// No description provided for @tipActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Pacing activity'**
  String get tipActivityTitle;

  /// No description provided for @tipActivityBody.
  ///
  /// In en, this message translates to:
  /// **'Spikes in joint pain correlate with abrupt intensity increases. Ensure a 10-minute dynamic warm-up before pushing past zone 2 cardio.'**
  String get tipActivityBody;

  /// No description provided for @personalizedFocus.
  ///
  /// In en, this message translates to:
  /// **'Personalized Focus'**
  String get personalizedFocus;

  /// No description provided for @refreshingAiInsights.
  ///
  /// In en, this message translates to:
  /// **'Refreshing your AI insights…'**
  String get refreshingAiInsights;

  /// No description provided for @generateNewInsights.
  ///
  /// In en, this message translates to:
  /// **'Generate New Insights'**
  String get generateNewInsights;

  /// No description provided for @symptoms.
  ///
  /// In en, this message translates to:
  /// **'Symptoms'**
  String get symptoms;

  /// No description provided for @avgSeverity.
  ///
  /// In en, this message translates to:
  /// **'Avg Severity'**
  String get avgSeverity;

  /// No description provided for @scoreChange.
  ///
  /// In en, this message translates to:
  /// **'Score Change'**
  String get scoreChange;

  /// No description provided for @checkBackMondayOrGenerate.
  ///
  /// In en, this message translates to:
  /// **'No insights generated yet. Check back on Monday for your weekly AI health summary, or tap below to generate one now.'**
  String get checkBackMondayOrGenerate;

  /// No description provided for @upgradeProInsightsFull.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro to unlock AI-powered weekly health insights. Get personalized recommendations and trend analysis every Monday.'**
  String get upgradeProInsightsFull;

  /// No description provided for @proPlanMonthly.
  ///
  /// In en, this message translates to:
  /// **'Pro Plan - \${price}/mo'**
  String proPlanMonthly(double price);

  /// No description provided for @weeklyInsightsUnlimitedTriage.
  ///
  /// In en, this message translates to:
  /// **'Weekly insights, unlimited triage'**
  String get weeklyInsightsUnlimitedTriage;

  /// No description provided for @couldNotLoadInsights.
  ///
  /// In en, this message translates to:
  /// **'Could not load insights'**
  String get couldNotLoadInsights;

  /// No description provided for @couldNotLaunchCall.
  ///
  /// In en, this message translates to:
  /// **'Could not launch call to {phoneNumber}'**
  String couldNotLaunchCall(String phoneNumber);

  /// No description provided for @medicalDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'This information does not constitute a medical diagnosis. VitalSeker does not replace a qualified healthcare professional.'**
  String get medicalDisclaimer;

  /// No description provided for @poweredByGlm.
  ///
  /// In en, this message translates to:
  /// **'Powered by GLM-4'**
  String get poweredByGlm;

  /// No description provided for @aiTriageIn90Seconds.
  ///
  /// In en, this message translates to:
  /// **'AI-powered triage in 90 seconds'**
  String get aiTriageIn90Seconds;

  /// No description provided for @vitalValueOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'Value out of expected range'**
  String get vitalValueOutOfRange;

  /// No description provided for @vitalRangeHintHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Heart rate should be between 30 and 220 BPM'**
  String get vitalRangeHintHeartRate;

  /// No description provided for @vitalRangeHintBloodPressure.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure should be between 60-250 (systolic) and 40-150 (diastolic)'**
  String get vitalRangeHintBloodPressure;

  /// No description provided for @vitalRangeHintTemperature.
  ///
  /// In en, this message translates to:
  /// **'Body temperature should be between 30 and 45 °C'**
  String get vitalRangeHintTemperature;

  /// No description provided for @vitalRangeHintOxygen.
  ///
  /// In en, this message translates to:
  /// **'Blood oxygen should be between 50 and 100 %'**
  String get vitalRangeHintOxygen;

  /// No description provided for @vitalRangeHintGlucose.
  ///
  /// In en, this message translates to:
  /// **'Blood glucose should be between 20 and 600 mg/dL'**
  String get vitalRangeHintGlucose;

  /// No description provided for @vitalRangeHintWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight should be between 2 and 500 kg'**
  String get vitalRangeHintWeight;

  /// No description provided for @vitalRangeHintHeight.
  ///
  /// In en, this message translates to:
  /// **'Height should be between 30 and 250 cm'**
  String get vitalRangeHintHeight;

  /// No description provided for @familyProfilesProOnly.
  ///
  /// In en, this message translates to:
  /// **'Family Profiles is a Pro feature. Upgrade to add family members.'**
  String get familyProfilesProOnly;

  /// No description provided for @exportProOnly.
  ///
  /// In en, this message translates to:
  /// **'PDF Export is a Pro feature. Upgrade to generate reports.'**
  String get exportProOnly;

  /// No description provided for @triageLimitReached.
  ///
  /// In en, this message translates to:
  /// **'You have reached your free monthly triage limit (3). Upgrade to Pro for unlimited triages.'**
  String get triageLimitReached;

  /// No description provided for @monthlyTriageLimit.
  ///
  /// In en, this message translates to:
  /// **'3 triages per month (Free plan)'**
  String get monthlyTriageLimit;

  /// No description provided for @viewQrCode.
  ///
  /// In en, this message translates to:
  /// **'View QR Code'**
  String get viewQrCode;

  /// No description provided for @shareMedicalId.
  ///
  /// In en, this message translates to:
  /// **'Share Medical ID'**
  String get shareMedicalId;

  /// No description provided for @translationTooLong.
  ///
  /// In en, this message translates to:
  /// **'Text is too long (max {max} characters). Please shorten and try again.'**
  String translationTooLong(int max);

  /// No description provided for @profileFieldsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Account created, but optional profile fields (date of birth, gender, blood type) couldn\'t be saved. You can edit them later in Profile > Edit Profile.'**
  String get profileFieldsSaveFailed;

  /// No description provided for @privacyPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicyTitle;

  /// No description provided for @privacyLastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated: March 2025'**
  String get privacyLastUpdated;

  /// No description provided for @privacyIntro.
  ///
  /// In en, this message translates to:
  /// **'At {appName}, your privacy is paramount. This Privacy Policy explains how we collect, use, store, and protect your personal and health-related data. By using our services, you agree to the practices described below.'**
  String privacyIntro(String appName);

  /// No description provided for @privacySectionDataCollection.
  ///
  /// In en, this message translates to:
  /// **'1. Data Collection'**
  String get privacySectionDataCollection;

  /// No description provided for @privacyDataCollectionBody.
  ///
  /// In en, this message translates to:
  /// **'We collect the following categories of data:\n\n• Personal Information: Name, email address, phone number, date of birth, and gender.\n• Health Data: Blood type, allergies, chronic conditions, medications, vital signs, symptom logs, and triage results.\n• Emergency Contacts: Names, phone numbers, and relationships of your designated contacts.\n• Device Data: Device type, operating system, and app version for compatibility and support.\n• Usage Data: Feature interactions and anonymized analytics to improve our services.\n\nWe only collect data that is necessary for providing our health companion services. You have full control over what information you provide.'**
  String get privacyDataCollectionBody;

  /// No description provided for @privacySectionDataStorage.
  ///
  /// In en, this message translates to:
  /// **'2. Data Storage & Encryption'**
  String get privacySectionDataStorage;

  /// No description provided for @privacyDataStorageBody.
  ///
  /// In en, this message translates to:
  /// **'Your data is stored using industry-leading security measures:\n\n• Encryption at Rest: All data stored in our databases is encrypted using AES-256 encryption.\n• Encryption in Transit: All data transmitted between your device and our servers uses TLS 1.3 encryption.\n• Health Passport: Your health passport data is encrypted with a unique key derived from your credentials.\n• QR Code Sharing: Shared health data via QR codes is encrypted and time-limited.\n• Infrastructure: Our servers are hosted in SOC 2 Type II certified data centers with 24/7 monitoring.\n\nWe do not store payment card information. All payment processing is handled by certified third-party providers.'**
  String get privacyDataStorageBody;

  /// No description provided for @privacySectionGdpr.
  ///
  /// In en, this message translates to:
  /// **'3. GDPR Compliance'**
  String get privacySectionGdpr;

  /// No description provided for @privacyGdprBody.
  ///
  /// In en, this message translates to:
  /// **'{appName} is fully compliant with the General Data Protection Regulation (GDPR):\n\n• Lawful Basis: We process your data based on your explicit consent and contractual necessity.\n• Data Minimization: We only collect and process data that is strictly necessary.\n• Purpose Limitation: Your data is used only for the purposes for which it was collected.\n• Right to Access: You can request a complete copy of your personal data at any time.\n• Right to Rectification: You can update or correct your data through the app settings.\n• Right to Erasure: You can request complete deletion of your account and data.\n• Right to Portability: You can export your data in a machine-readable format.\n• Data Processing Agreements: All third-party processors have signed DPAs.\n• Cross-Border Transfers: Data is processed within the EU/EEA unless explicit consent is given otherwise.'**
  String privacyGdprBody(String appName);

  /// No description provided for @privacySectionYourRights.
  ///
  /// In en, this message translates to:
  /// **'4. Your Rights'**
  String get privacySectionYourRights;

  /// No description provided for @privacyRightsBody.
  ///
  /// In en, this message translates to:
  /// **'You have the following rights regarding your data:\n\n• Access: View all your personal and health data within the app or request a data export.\n• Correction: Edit your profile information at any time through Edit Profile.\n• Deletion: Request account deletion through Settings > Data & Privacy > Delete Account.\n• Restriction: Limit how certain data is processed by adjusting your notification and sharing preferences.\n• Objection: Object to specific data processing activities by contacting our Data Protection Officer.\n• Withdrawal of Consent: You may withdraw consent at any time without affecting the lawfulness of prior processing.\n\nTo exercise any of these rights, contact us at privacy@vitalseker.com or through the in-app support feature.'**
  String get privacyRightsBody;

  /// No description provided for @privacySectionContactUs.
  ///
  /// In en, this message translates to:
  /// **'5. Contact Us'**
  String get privacySectionContactUs;

  /// No description provided for @privacyContactBody.
  ///
  /// In en, this message translates to:
  /// **'If you have any questions or concerns about this Privacy Policy or our data practices, please contact us:\n\n• Email: privacy@vitalseker.com\n• Support: support@vitalseker.com\n• Data Protection Officer: dpo@vitalseker.com\n• Address: {producer}, Data Protection Office\n\nWe aim to respond to all privacy-related inquiries within 30 days.'**
  String privacyContactBody(String producer);

  /// No description provided for @privacyCopyright.
  ///
  /// In en, this message translates to:
  /// **'© 2025 {producer}. All rights reserved.'**
  String privacyCopyright(String producer);

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get chooseFromGallery;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a Photo'**
  String get takePhoto;

  /// No description provided for @removePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove Photo'**
  String get removePhoto;

  /// No description provided for @avatarUpdated.
  ///
  /// In en, this message translates to:
  /// **'Avatar updated!'**
  String get avatarUpdated;

  /// No description provided for @avatarUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload avatar. Please try again.'**
  String get avatarUploadFailed;

  /// No description provided for @avatarRemoved.
  ///
  /// In en, this message translates to:
  /// **'Avatar removed.'**
  String get avatarRemoved;

  /// No description provided for @avatarRemoveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove avatar. Please try again.'**
  String get avatarRemoveFailed;

  /// No description provided for @profileUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully!'**
  String get profileUpdatedSuccessfully;

  /// No description provided for @profileUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile. Please try again.'**
  String get profileUpdateFailed;

  /// No description provided for @editProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfileTitle;

  /// No description provided for @errorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorPrefix(String error);

  /// No description provided for @personalInformation.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personalInformation;

  /// No description provided for @measurements.
  ///
  /// In en, this message translates to:
  /// **'Measurements'**
  String get measurements;

  /// No description provided for @heightCm.
  ///
  /// In en, this message translates to:
  /// **'Height (cm)'**
  String get heightCm;

  /// No description provided for @weightKg.
  ///
  /// In en, this message translates to:
  /// **'Weight (kg)'**
  String get weightKg;

  /// No description provided for @emergencyContactSection.
  ///
  /// In en, this message translates to:
  /// **'Emergency Contact'**
  String get emergencyContactSection;

  /// No description provided for @contactName.
  ///
  /// In en, this message translates to:
  /// **'Contact Name'**
  String get contactName;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @relationshipHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Spouse, Parent, Sibling'**
  String get relationshipHint;

  /// No description provided for @addAllergy.
  ///
  /// In en, this message translates to:
  /// **'Add Allergy'**
  String get addAllergy;

  /// No description provided for @noAllergiesAdded.
  ///
  /// In en, this message translates to:
  /// **'No allergies added'**
  String get noAllergiesAdded;

  /// No description provided for @addCondition.
  ///
  /// In en, this message translates to:
  /// **'Add Condition'**
  String get addCondition;

  /// No description provided for @noConditionsAdded.
  ///
  /// In en, this message translates to:
  /// **'No conditions added'**
  String get noConditionsAdded;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @healthTitle.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get healthTitle;

  /// No description provided for @weeklyInsightsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Weekly Insights'**
  String get weeklyInsightsTooltip;

  /// No description provided for @yourHealthScore.
  ///
  /// In en, this message translates to:
  /// **'Your Health Score'**
  String get yourHealthScore;

  /// No description provided for @scoreDescriptionGreat.
  ///
  /// In en, this message translates to:
  /// **'Your health metrics are looking great! Keep it up.'**
  String get scoreDescriptionGreat;

  /// No description provided for @scoreDescriptionGood.
  ///
  /// In en, this message translates to:
  /// **'Good progress. A few areas could use attention.'**
  String get scoreDescriptionGood;

  /// No description provided for @scoreDescriptionModerate.
  ///
  /// In en, this message translates to:
  /// **'Some health metrics need improvement. Consider our recommendations.'**
  String get scoreDescriptionModerate;

  /// No description provided for @scoreDescriptionLow.
  ///
  /// In en, this message translates to:
  /// **'Several areas need attention. Please consult a healthcare provider.'**
  String get scoreDescriptionLow;

  /// No description provided for @scoreDescriptionCritical.
  ///
  /// In en, this message translates to:
  /// **'Immediate attention recommended. Please seek medical advice.'**
  String get scoreDescriptionCritical;

  /// No description provided for @riskFactors.
  ///
  /// In en, this message translates to:
  /// **'Risk Factors'**
  String get riskFactors;

  /// No description provided for @allergyCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Allergies'**
  String allergyCount(int count);

  /// No description provided for @chronicConditionCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Chronic Conditions'**
  String chronicConditionCount(int count);

  /// No description provided for @noRiskFactors.
  ///
  /// In en, this message translates to:
  /// **'No risk factors identified'**
  String get noRiskFactors;

  /// No description provided for @recentTriageResults.
  ///
  /// In en, this message translates to:
  /// **'Recent Triage Results'**
  String get recentTriageResults;

  /// No description provided for @noTriageResults.
  ///
  /// In en, this message translates to:
  /// **'No triage results yet'**
  String get noTriageResults;

  /// No description provided for @recommendedActions.
  ///
  /// In en, this message translates to:
  /// **'Recommended Actions'**
  String get recommendedActions;

  /// No description provided for @actionScheduleCheckup.
  ///
  /// In en, this message translates to:
  /// **'Schedule a Check-up'**
  String get actionScheduleCheckup;

  /// No description provided for @actionScheduleCheckupDesc.
  ///
  /// In en, this message translates to:
  /// **'Your health score suggests it\'s time for a medical review.'**
  String get actionScheduleCheckupDesc;

  /// No description provided for @actionLogVitals.
  ///
  /// In en, this message translates to:
  /// **'Log Your Vitals'**
  String get actionLogVitals;

  /// No description provided for @actionLogVitalsDesc.
  ///
  /// In en, this message translates to:
  /// **'Track your blood pressure, heart rate, and other key metrics.'**
  String get actionLogVitalsDesc;

  /// No description provided for @actionRunSymptomCheck.
  ///
  /// In en, this message translates to:
  /// **'Run a Symptom Check'**
  String get actionRunSymptomCheck;

  /// No description provided for @actionRunSymptomCheckDesc.
  ///
  /// In en, this message translates to:
  /// **'Use AI triage to assess any symptoms you\'re experiencing.'**
  String get actionRunSymptomCheckDesc;

  /// No description provided for @actionImproveSleep.
  ///
  /// In en, this message translates to:
  /// **'Improve Sleep Quality'**
  String get actionImproveSleep;

  /// No description provided for @actionImproveSleepDesc.
  ///
  /// In en, this message translates to:
  /// **'Quality sleep is essential for recovery and immune function.'**
  String get actionImproveSleepDesc;

  /// No description provided for @actionStayActive.
  ///
  /// In en, this message translates to:
  /// **'Stay Active'**
  String get actionStayActive;

  /// No description provided for @actionStayActiveDesc.
  ///
  /// In en, this message translates to:
  /// **'Regular exercise helps maintain cardiovascular health.'**
  String get actionStayActiveDesc;

  /// No description provided for @viewWeeklyInsights.
  ///
  /// In en, this message translates to:
  /// **'View Weekly Insights'**
  String get viewWeeklyInsights;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String minutesAgo(int minutes);

  /// No description provided for @weeksAgo.
  ///
  /// In en, this message translates to:
  /// **'{weeks}w ago'**
  String weeksAgo(int weeks);

  /// No description provided for @failedToLoadVitals.
  ///
  /// In en, this message translates to:
  /// **'Failed to load vitals'**
  String get failedToLoadVitals;

  /// No description provided for @noVitalsYet.
  ///
  /// In en, this message translates to:
  /// **'No Vitals Yet'**
  String get noVitalsYet;

  /// No description provided for @startLoggingVitalsPrompt.
  ///
  /// In en, this message translates to:
  /// **'Start logging your vital signs to track your health over time'**
  String get startLoggingVitalsPrompt;

  /// No description provided for @logFirstVital.
  ///
  /// In en, this message translates to:
  /// **'Log Your First Vital'**
  String get logFirstVital;

  /// No description provided for @day.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get day;

  /// No description provided for @week.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get week;

  /// No description provided for @month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get noData;

  /// No description provided for @trendUp.
  ///
  /// In en, this message translates to:
  /// **'UP'**
  String get trendUp;

  /// No description provided for @trendDown.
  ///
  /// In en, this message translates to:
  /// **'DOWN'**
  String get trendDown;

  /// No description provided for @trendStable.
  ///
  /// In en, this message translates to:
  /// **'STABLE'**
  String get trendStable;

  /// No description provided for @logVitalTitle.
  ///
  /// In en, this message translates to:
  /// **'Log Vital'**
  String get logVitalTitle;

  /// No description provided for @vitalTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'VITAL TYPE'**
  String get vitalTypeLabel;

  /// No description provided for @valueLabel.
  ///
  /// In en, this message translates to:
  /// **'VALUE'**
  String get valueLabel;

  /// No description provided for @systolic.
  ///
  /// In en, this message translates to:
  /// **'Systolic'**
  String get systolic;

  /// No description provided for @diastolic.
  ///
  /// In en, this message translates to:
  /// **'Diastolic'**
  String get diastolic;

  /// No description provided for @dateTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'DATE & TIME'**
  String get dateTimeLabel;

  /// No description provided for @notesOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'NOTES (OPTIONAL)'**
  String get notesOptionalLabel;

  /// No description provided for @notesHint.
  ///
  /// In en, this message translates to:
  /// **'Add any notes about this reading...'**
  String get notesHint;

  /// No description provided for @saveVitalType.
  ///
  /// In en, this message translates to:
  /// **'Save {vitalType}'**
  String saveVitalType(String vitalType);

  /// No description provided for @vitalSavedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'{vitalType} saved successfully'**
  String vitalSavedSuccessfully(String vitalType);

  /// No description provided for @vitalSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save vital. Please try again.'**
  String get vitalSaveFailed;

  /// No description provided for @vitalsHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Vitals History'**
  String get vitalsHistoryTitle;

  /// No description provided for @range7Days.
  ///
  /// In en, this message translates to:
  /// **'7D'**
  String get range7Days;

  /// No description provided for @range1Month.
  ///
  /// In en, this message translates to:
  /// **'1M'**
  String get range1Month;

  /// No description provided for @range3Months.
  ///
  /// In en, this message translates to:
  /// **'3M'**
  String get range3Months;

  /// No description provided for @range6Months.
  ///
  /// In en, this message translates to:
  /// **'6M'**
  String get range6Months;

  /// No description provided for @range1Year.
  ///
  /// In en, this message translates to:
  /// **'1Y'**
  String get range1Year;

  /// No description provided for @noVitalTypeData.
  ///
  /// In en, this message translates to:
  /// **'No {vitalType} Data'**
  String noVitalTypeData(String vitalType);

  /// No description provided for @noReadingsForPeriod.
  ///
  /// In en, this message translates to:
  /// **'No readings found for the selected time period'**
  String get noReadingsForPeriod;

  /// No description provided for @singleReading.
  ///
  /// In en, this message translates to:
  /// **'1 reading'**
  String get singleReading;

  /// No description provided for @average.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get average;

  /// No description provided for @min.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get min;

  /// No description provided for @max.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get max;

  /// No description provided for @latest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get latest;

  /// No description provided for @readingsLabel.
  ///
  /// In en, this message translates to:
  /// **'READINGS'**
  String get readingsLabel;

  /// No description provided for @value.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get value;

  /// No description provided for @source.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get source;

  /// No description provided for @showingReadingsCount.
  ///
  /// In en, this message translates to:
  /// **'Showing 20 of {total} readings'**
  String showingReadingsCount(int total);

  /// No description provided for @addMedicationTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Medication'**
  String get addMedicationTitle;

  /// No description provided for @medicationNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Medication Name'**
  String get medicationNameLabel;

  /// No description provided for @dosageLabel.
  ///
  /// In en, this message translates to:
  /// **'Dosage'**
  String get dosageLabel;

  /// No description provided for @unitLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unitLabel;

  /// No description provided for @frequencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get frequencyLabel;

  /// No description provided for @startDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get startDateLabel;

  /// No description provided for @setEndDate.
  ///
  /// In en, this message translates to:
  /// **'Set end date'**
  String get setEndDate;

  /// No description provided for @endDateLabel.
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get endDateLabel;

  /// No description provided for @doseTimesLabel.
  ///
  /// In en, this message translates to:
  /// **'DOSE TIMES'**
  String get doseTimesLabel;

  /// No description provided for @doseNumber.
  ///
  /// In en, this message translates to:
  /// **'Dose {number}'**
  String doseNumber(int number);

  /// No description provided for @notesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get notesOptional;

  /// No description provided for @remindersLabel.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get remindersLabel;

  /// No description provided for @saveMedication.
  ///
  /// In en, this message translates to:
  /// **'Save Medication'**
  String get saveMedication;

  /// No description provided for @medicationAddedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Medication added successfully!'**
  String get medicationAddedSuccessfully;

  /// No description provided for @medicationAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add medication. Please try again.'**
  String get medicationAddFailed;

  /// No description provided for @addAppointmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Appointment'**
  String get addAppointmentTitle;

  /// No description provided for @doctorNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Doctor Name'**
  String get doctorNameLabel;

  /// No description provided for @specialtyLabel.
  ///
  /// In en, this message translates to:
  /// **'Specialty'**
  String get specialtyLabel;

  /// No description provided for @selectSpecialtyHint.
  ///
  /// In en, this message translates to:
  /// **'Select specialty'**
  String get selectSpecialtyHint;

  /// No description provided for @locationOptional.
  ///
  /// In en, this message translates to:
  /// **'Location / Address (optional)'**
  String get locationOptional;

  /// No description provided for @reminderLabel.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get reminderLabel;

  /// No description provided for @saveAppointment.
  ///
  /// In en, this message translates to:
  /// **'Save Appointment'**
  String get saveAppointment;

  /// No description provided for @appointmentScheduledSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Appointment scheduled successfully!'**
  String get appointmentScheduledSuccessfully;

  /// No description provided for @appointmentScheduleFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to schedule appointment. Please try again.'**
  String get appointmentScheduleFailed;

  /// No description provided for @specialtyCardiologist.
  ///
  /// In en, this message translates to:
  /// **'Cardiologist'**
  String get specialtyCardiologist;

  /// No description provided for @specialtyDermatologist.
  ///
  /// In en, this message translates to:
  /// **'Dermatologist'**
  String get specialtyDermatologist;

  /// No description provided for @specialtyEndocrinologist.
  ///
  /// In en, this message translates to:
  /// **'Endocrinologist'**
  String get specialtyEndocrinologist;

  /// No description provided for @specialtyGeneralPractice.
  ///
  /// In en, this message translates to:
  /// **'General Practice'**
  String get specialtyGeneralPractice;

  /// No description provided for @specialtyNeurologist.
  ///
  /// In en, this message translates to:
  /// **'Neurologist'**
  String get specialtyNeurologist;

  /// No description provided for @specialtyOphthalmologist.
  ///
  /// In en, this message translates to:
  /// **'Ophthalmologist'**
  String get specialtyOphthalmologist;

  /// No description provided for @specialtyOrthopedic.
  ///
  /// In en, this message translates to:
  /// **'Orthopedic'**
  String get specialtyOrthopedic;

  /// No description provided for @specialtyPediatrician.
  ///
  /// In en, this message translates to:
  /// **'Pediatrician'**
  String get specialtyPediatrician;

  /// No description provided for @specialtyPsychiatrist.
  ///
  /// In en, this message translates to:
  /// **'Psychiatrist'**
  String get specialtyPsychiatrist;

  /// No description provided for @specialtyOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get specialtyOther;

  /// No description provided for @recordsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load records. Please try again.'**
  String get recordsLoadFailed;

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get notAvailable;

  /// No description provided for @editRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Record'**
  String get editRecordTitle;

  /// No description provided for @addMedicalRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Medical Record'**
  String get addMedicalRecordTitle;

  /// No description provided for @titleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get titleLabel;

  /// No description provided for @typeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get typeLabel;

  /// No description provided for @recordTypeLabResults.
  ///
  /// In en, this message translates to:
  /// **'Lab Results'**
  String get recordTypeLabResults;

  /// No description provided for @recordTypePrescriptions.
  ///
  /// In en, this message translates to:
  /// **'Prescriptions'**
  String get recordTypePrescriptions;

  /// No description provided for @recordTypeImaging.
  ///
  /// In en, this message translates to:
  /// **'Imaging'**
  String get recordTypeImaging;

  /// No description provided for @recordTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get recordTypeOther;

  /// No description provided for @descriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get descriptionLabel;

  /// No description provided for @recordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Record updated!'**
  String get recordUpdated;

  /// No description provided for @recordAdded.
  ///
  /// In en, this message translates to:
  /// **'Record added!'**
  String get recordAdded;

  /// No description provided for @recordUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update record.'**
  String get recordUpdateFailed;

  /// No description provided for @recordAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add record.'**
  String get recordAddFailed;

  /// No description provided for @deleteRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Record'**
  String get deleteRecordTitle;

  /// No description provided for @deleteRecordConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{title}\"? This cannot be undone.'**
  String deleteRecordConfirm(String title);

  /// No description provided for @recordDeleted.
  ///
  /// In en, this message translates to:
  /// **'Record deleted.'**
  String get recordDeleted;

  /// No description provided for @recordDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete record.'**
  String get recordDeleteFailed;

  /// No description provided for @medicalRecordsTitle.
  ///
  /// In en, this message translates to:
  /// **'Medical Records'**
  String get medicalRecordsTitle;

  /// No description provided for @searchRecordsHint.
  ///
  /// In en, this message translates to:
  /// **'Search records...'**
  String get searchRecordsHint;

  /// No description provided for @noRecordsFound.
  ///
  /// In en, this message translates to:
  /// **'No records found'**
  String get noRecordsFound;

  /// No description provided for @tapToAddRecord.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add a medical record'**
  String get tapToAddRecord;

  /// No description provided for @untitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitled;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'ar',
        'bn',
        'de',
        'en',
        'es',
        'fr',
        'ha',
        'hi',
        'id',
        'ig',
        'it',
        'ja',
        'ko',
        'nl',
        'pl',
        'pt',
        'ru',
        'sw',
        'th',
        'tl',
        'tr',
        'ur',
        'vi',
        'yo',
        'zh'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'en':
      {
        switch (locale.countryCode) {
          case 'GB':
            return AppLocalizationsEnGb();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'bn':
      return AppLocalizationsBn();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'ha':
      return AppLocalizationsHa();
    case 'hi':
      return AppLocalizationsHi();
    case 'id':
      return AppLocalizationsId();
    case 'ig':
      return AppLocalizationsIg();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'nl':
      return AppLocalizationsNl();
    case 'pl':
      return AppLocalizationsPl();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'sw':
      return AppLocalizationsSw();
    case 'th':
      return AppLocalizationsTh();
    case 'tl':
      return AppLocalizationsTl();
    case 'tr':
      return AppLocalizationsTr();
    case 'ur':
      return AppLocalizationsUr();
    case 'vi':
      return AppLocalizationsVi();
    case 'yo':
      return AppLocalizationsYo();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
