import 'dart:async';

import 'package:dots_indicator/dots_indicator.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:geo_monitor/library/data/settings_model.dart';
import 'package:geo_monitor/library/ui/settings/settings_form.dart';
import 'package:geo_monitor/ui/auth/auth_registration_main.dart';
import 'package:geo_monitor/ui/auth/auth_signin_main.dart';
import 'package:geo_monitor/ui/dashboard/dashboard_main.dart';
import 'package:page_transition/page_transition.dart';

import '../../l10n/translation_handler.dart';
import '../../library/api/prefs_og.dart';
import '../../library/cache_manager.dart';
import '../../library/data/user.dart' as ur;
import '../../library/emojis.dart';
import '../../library/functions.dart';
import '../../library/generic_functions.dart';
import '../dashboard/dashboard_portrait.dart';
import '../intro/intro_page_one.dart';

class IntroPageViewerPortrait extends StatefulWidget {
  const IntroPageViewerPortrait({
    Key? key,
  }) : super(key: key);

  @override
  IntroPageViewerPortraitState createState() => IntroPageViewerPortraitState();
}

class IntroPageViewerPortraitState extends State<IntroPageViewerPortrait>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final PageController _pageController = PageController();
  bool authed = false;
  fb.FirebaseAuth firebaseAuth = fb.FirebaseAuth.instance;
  ur.User? user;


  final mm =
      '${E.pear}${E.pear}${E.pear}${E.pear} IntroPageViewerPortrait: ${E.pear} ';

  SettingsModel? settingsModel;
  @override
  void initState() {
    _animationController = AnimationController(vsync: this);
    super.initState();
    _setTexts();
    _getAuthenticationStatus();
  }

  IntroStrings? introStrings;
  Future _setTexts({String? selectedLocale}) async {
    settingsModel = await prefsOGx.getSettings();
    late String locale;
    if (settingsModel == null) {
      settingsModel = SettingsModel(
          distanceFromProject: 500,
          photoSize: 1,
          maxVideoLengthInSeconds: 120,
          maxAudioLengthInMinutes: 30,
          themeIndex: 0,
          settingsId: null,
          created: null,
          organizationId: null,
          projectId: null,
          numberOfDays: 7,
          locale: selectedLocale,
          activityStreamHours: 24);
      await prefsOGx.saveSettings(settingsModel!);
      locale = selectedLocale == null?'en':selectedLocale!;
    } else {
      locale = settingsModel!.locale!;
    }
    introStrings = await IntroStrings.getTranslated();
    setState(() {});
  }

  void _getAuthenticationStatus() async {
    pp('\n\n$mm _getAuthenticationStatus ....... '
        'check both Firebase user ang Geo user');
    var user = await prefsOGx.getUser();
    var firebaseUser = firebaseAuth.currentUser;

    if (user != null && firebaseUser != null) {
      pp('$mm _getAuthenticationStatus .......  '
          '🥬🥬🥬auth is DEFINITELY authenticated and OK');
      authed = true;
    } else {
      pp('$mm _getAuthenticationStatus ....... NOT AUTHENTICATED! '
          '${E.redDot}${E.redDot}${E.redDot} ... will clean house!!');
      authed = false;
      //todo - ensure that the right thing gets done!
      prefsOGx.deleteUser();
      firebaseAuth.signOut();
      cacheManager.initialize(forceInitialization: true);
      pp('$mm _getAuthenticationStatus .......  '
          '${E.redDot}${E.redDot}${E.redDot}'
          'the device should be ready for sign in or registration');
    }
    pp('$mm ......... _getAuthenticationStatus ....... setting state, authed = $authed ');
    setState(() {});
  }

  void _navigateToDashboard() {
    if (user != null) {
      //Navigator.of(context).pop(user);
      Navigator.push(
          context,
          PageTransition(
              type: PageTransitionType.scale,
              alignment: Alignment.topLeft,
              duration: const Duration(seconds: 2),
              child: const DashboardMain()));
    } else {
      pp('User is null,  🔆 🔆 🔆 🔆 cannot navigate to Dashboard');
    }
  }

  void _navigateToDashboardWithoutUser() {
    Navigator.of(context).pop();
    Navigator.push(
        context,
        PageTransition(
            type: PageTransitionType.scale,
            alignment: Alignment.topLeft,
            duration: const Duration(seconds: 2),
            child: const DashboardPortrait()));
  }

  Future<void> _navigateToSignIn() async {
    pp('$mm _navigateToSignIn ....... ');

    await Navigator.push(
        context,
        PageTransition(
            type: PageTransitionType.scale,
            alignment: Alignment.topLeft,
            duration: const Duration(seconds: 1),
            child: const AuthSignInMain()));

    pp('$mm _navigateToSignIn ....... back from PhoneLogin with maybe a user ..');
    user = await prefsOGx.getUser();
    pp('\n\n$mm 😡😡Returned from sign in, checking if login succeeded 😡');

    if (user != null) {
      pp('$mm _navigateToSignIn: 👌👌👌 Returned from sign in; '
          'will navigate to Dashboard :  👌👌👌 ${user!.toJson()}');
      setState(() {});
      _navigateToDashboard();
    } else {
      pp('$mm 😡😡 Returned from sign in; cached user not found. '
          '${E.redDot}${E.redDot} NOT GOOD! ${E.redDot}');
      if (mounted) {
        showToast(
            message: 'Phone Sign In Failed',
            duration: const Duration(seconds: 5),
            backgroundColor: Theme.of(context).primaryColor,
            padding: 12.0,
            context: context);
      }
    }
  }

  Future<void> _navigateToOrgRegistration() async {
    //mainSetup();
    var result = await Navigator.push(
        context,
        PageTransition(
            type: PageTransitionType.scale,
            alignment: Alignment.topLeft,
            duration: const Duration(seconds: 1),
            child: const AuthRegistrationMain()));

    if (result is ur.User) {
      pp(' 👌👌👌 Returned from sign in; will navigate to Dashboard :  👌👌👌 ${result.toJson()}');
      setState(() {
        user = result;
      });
      _navigateToDashboard();
    } else {
      pp(' 😡  😡  Returned from sign in is NOT a user :  😡 $result');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  double currentIndexPage = 0.0;
  int pageIndex = 0;
  String? hint;
  void _onPageChanged(int value) {
    if (mounted) {
      setState(() {
        currentIndexPage = value.toDouble();
      });
    }
  }

  void onSignIn() {
    pp('$mm onSignIn ...');
    _navigateToSignIn();
  }

  void onRegistration() {
    pp('$mm onRegistration ...');
    _navigateToOrgRegistration();
  }

  onSelected(Locale p1, String p2) async {
    pp('$mm locale selected: $p1 - $p2');
    await _setTexts(selectedLocale: p1.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
      appBar: AppBar(
        title: Text(
          introStrings == null ? 'Geo Information' : introStrings!.information!,
          style: myTextStyleLarge(context),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(authed ? 36 : 100),
          child: authed
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    LocaleChooser(
                        onSelected: onSelected,
                        hint: introStrings == null ? 'Select Language' : introStrings!.hint),
                  ],
                )
              : Card(
                  elevation: 4,
                  color: Colors.black26,
                  // shape: getRoundedBorder(radius: 16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                              onPressed: onSignIn, child:  Text(introStrings == null?
                              'Sign In': introStrings!.signIn)),
                          TextButton(
                              onPressed: onRegistration,
                              child: Text(introStrings == null
                                  ? 'Register Organization'
                                  : introStrings!.registerOrganization)),
                        ],
                      ),
                      Row(mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          LocaleChooser(
                              onSelected: onSelected,
                              hint: introStrings == null ? 'Select Language' : introStrings!.hint),

                        ],
                      )
                    ],
                  ),
                ),
        ),
      ),
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            children: [
              IntroPage(
                title: 'Geo',
                assetPath: 'assets/intro/pic2.jpg',
                text: introStrings == null ? lorem : introStrings!.infrastructure,
              ),
              IntroPage(
                title: introStrings == null ? 'Organizations' : introStrings!.organizations,
                assetPath: 'assets/intro/pic5.jpg',
                text: introStrings == null ? lorem : introStrings!.youth,
              ),
              IntroPage(
                title: introStrings == null ? 'People' : introStrings!.managementPeople,
                assetPath: 'assets/intro/pic1.jpg',
                text: introStrings == null ? lorem : introStrings!.community,
              ),
              IntroPage(
                title: introStrings == null ? 'Field Monitors' : introStrings!.fieldWorkers,
                assetPath: 'assets/intro/pic5.jpg',
                text: lorem,
              ),
              IntroPage(
                title: introStrings == null ? 'Thank You' : introStrings!.thankYou,
                assetPath: 'assets/intro/pic3.webp',
                text: introStrings == null ? lorem : introStrings!.thankYouMessage,
              ),
            ],
          ),
          Positioned(
            bottom: 2,
            left: 48,
            right: 40,
            child: SizedBox(
              width: 200,
              height: 48,
              child: Card(
                color: Colors.black12,
                shape: getRoundedBorder(radius: 8),
                child: DotsIndicator(
                  dotsCount: 5,
                  position: currentIndexPage,
                  decorator: const DotsDecorator(
                    colors: [
                      Colors.grey,
                      Colors.grey,
                      Colors.grey,
                      Colors.grey,
                      Colors.grey,
                    ], // Inactive dot colors
                    activeColors: [
                      Colors.pink,
                      Colors.blue,
                      Colors.teal,
                      Colors.indigo,
                      Colors.deepOrange,
                    ], // Àctive dot colors
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ));
  }
}

class IntroStrings {
  late String organizations,
      managementPeople,
      fieldWorkers,
      executives,
      information,
      thankYou,
      thankYouMessage,
      infrastructure,
      govt,
      youth,
      hint, signIn,
      community,
      registerOrganization;

  IntroStrings(
      {required this.organizations,
      required this.managementPeople,
      required this.fieldWorkers,
      required this.executives,
      required this.information,
      required this.thankYou,
      required this.thankYouMessage,
      required this.infrastructure,
      required this.govt,
      required this.youth,
      required this.hint,
        required this.signIn,
      required this.community,
      required this.registerOrganization});

  static Future<IntroStrings> getTranslated() async {
    var settingsModel = await prefsOGx.getSettings();
    var hint = await mTx.translate('selectLanguage', settingsModel!.locale!);

    var signIn = await mTx.translate('signIn', settingsModel.locale!);
    var organizations =
        await mTx.translate('organizations', settingsModel.locale!);
    var managementPeople =
        await mTx.translate('managementPeople', settingsModel.locale!);
    var fieldWorkers =
        await mTx.translate('fieldWorkers', settingsModel.locale!);
    var executives = await mTx.translate('executives', settingsModel.locale!);
    var information = await mTx.translate('information', settingsModel.locale!);
    var thankYou = await mTx.translate('thankYou', settingsModel.locale!);
    var thankYouMessage =
        await mTx.translate('thankYouMessage', settingsModel.locale!);

    var infrastructure =
        await mTx.translate('infrastructure', settingsModel.locale!);
    var govt = await mTx.translate('govt', settingsModel.locale!);
    var youth = await mTx.translate('youth', settingsModel.locale!);
    var community = await mTx.translate('community', settingsModel.locale!);
    var registerOrganization =
        await mTx.translate('registerOrganization', settingsModel.locale!);

    final m = IntroStrings(
        organizations: organizations,
        managementPeople: managementPeople,
        fieldWorkers: fieldWorkers,
        executives: executives,
        information: information,
        thankYou: thankYou,
        signIn: signIn,
        thankYouMessage: thankYouMessage,
        infrastructure: infrastructure,
        govt: govt,
        youth: youth,
        hint: hint,
        community: community,
        registerOrganization: registerOrganization);
    return m;
  }
}
