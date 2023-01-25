// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_libphonenumber/flutter_libphonenumber.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

import 'package:geo_monitor/ui/dashboard/dashboard_main.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:page_transition/page_transition.dart';
import 'package:restart_app/restart_app.dart';
import 'package:universal_platform/universal_platform.dart';
import 'firebase_options.dart';
import 'library/api/sharedprefs.dart';
import 'library/data/user.dart' as ur;
import 'library/bloc/theme_bloc.dart';
import 'library/bloc/upload_failed_media.dart';
import 'library/bloc/write_failed_media.dart';
import 'library/emojis.dart';
import 'library/functions.dart';
import 'library/hive_util.dart';
import 'ui/intro_page_viewer.dart';

int themeIndex = 0;
late FirebaseApp firebaseApp;
ur.User? user;
int doubleTapCount = 0;
int milliSecondsAtLastDoubleTap = 0;

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();


Future<void> mainSetup() async {
  try {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      if (kReleaseMode) exit(1);
    };
    themeIndex = await Prefs.getThemeIndex();
    // Pass all uncaught "fatal" errors from the framework to Crashlytics
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };
    // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    pp('${Emoji.heartGreen}${Emoji.heartGreen} FirebaseCrashlytics set up');
    // Prefs.deleteUser();
    await Hive.initFlutter();
    await cacheManager.initialize(forceInitialization: false);
    pp('${Emoji.heartGreen}${Emoji.heartGreen}}${Emoji.heartGreen} '
        'Hive initialized and boxCollection set up');

    writeFailedMedia.startTimer(const Duration(minutes: 25));
    uploadFailedMedia.startTimer(const Duration(minutes: 30));

    writeFailedMedia.writeFailedMedia();
    uploadFailedMedia.uploadFailedMedia();

    pp('${Emoji.heartGreen}${Emoji.heartGreen} writeFailedMedia/uploadFailedMedia '
        'timers started with 🍎 5 minute duration per tick ...');

    await FlutterLibphonenumber().init();
  } catch (e) {
    pp('$redDot problem with Firebase? or Hive? : $e');
  }

  await dotenv.load(fileName: ".env");
  pp('$heartBlue DotEnv has been loaded');

  pp('${Emoji.brocolli} Checking for current user : FirebaseAuth');

  if (user == null) {
    pp('${Emoji.redDot}${Emoji.redDot} Ding Dong! new Firebase user, sign in! - check that we do not create user every time $appleGreen  $appleGreen');
  } else {
    pp('${Emoji.blueDot}${Emoji.blueDot}${Emoji.blueDot}${Emoji.blueDot} User already exists. $blueDot Cool!');
  }
}

Future<void> initSettings() async {
  await Settings.init(
    cacheProvider: SharePreferenceCache(),
  );
  //accentColor = ValueNotifier(Colors.blueAccent);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  firebaseApp = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform);
  pp('${Emoji.heartGreen}${Emoji.heartGreen} Firebase App has been initialized: ${firebaseApp.name}');
  user = await Prefs.getUser();
  if (user == null) {
    pp('${Emoji.redDot}${Emoji.redDot}${Emoji.redDot}${Emoji.redDot} '
        'User is null; ensure that firebase is signed out ...');
    await fb.FirebaseAuth.instance.signOut();
  } else {
    pp('\n${Emoji.heartGreen}${Emoji.heartGreen} Prefs user available:: ${user!.toJson()}\n');
    String? token = await fb.FirebaseAuth.instance.currentUser?.getIdToken();
    if (token != null) {
      pp('👌👌👌==== $token ==== 👌👌👌');
    }
  }

  initSettings().then((value) {
    pp('🌀🌀🌀🌀 Settings functionality initialized');
    runApp(const MyApp());
  });
}

/// The main app.
class MyApp extends StatelessWidget {
  /// Constructs a [MyApp]
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    themeBloc.start();
    mainSetup();
    return GestureDetector(
      onTap: () {
        pp('🌀🌀🌀🌀 Tap detected; should dismiss keyboard');
        FocusManager.instance.primaryFocus?.unfocus();
      },
      // onLongPress: () async {
      //   //todo - REMOVE after testing
      //   pp('🌀🌀🌀🌀 onLongPress detected; should clear user stuff, count: $doubleTapCount');
      //     await sortOutNewHiveArtifacts(context);
      //
      // },
      child: StreamBuilder(
        stream: themeBloc.newThemeStream,
        initialData: themeIndex,
        builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
          if (snapshot.hasData) {
            themeIndex = snapshot.data;
          }
          return GetMaterialApp(
            scaffoldMessengerKey: rootScaffoldMessengerKey,
            debugShowCheckedModeBanner: false,
            title: 'GeoMonitor',
            theme: themeBloc.getTheme(themeIndex).darkTheme,
            darkTheme: themeBloc.getTheme(themeIndex).darkTheme,
            themeMode: ThemeMode.system,
            // home: const PhotoHandler(),
            // home: const OrgRegistrationPage(),
            // home: const IntroMain(),
            // home: user == null? const IntroPageViewer() :const DashboardMain(),
            // home: const PhoneLogin(),
            home: AnimatedSplashScreen(
              duration: 2000,
              splash: const SplashWidget(),
              animationDuration: const Duration(milliseconds: 2000),
              curve: Curves.easeInCirc,
              splashIconSize: 160.0,
              // nextScreen: const AudioMobile(),
              // nextScreen: const CreditCardHandlerMobile(),
              // nextScreen: const AppSettings(),
              nextScreen: user == null
                  ? const IntroPageViewer()
                  : const DashboardMain(),
              splashTransition: SplashTransition.fadeTransition,
              pageTransitionType: PageTransitionType.topToBottom,
              backgroundColor: Colors.pink.shade900,
            ),
          );
        },
      ),
    );
  }
}

class SplashWidget extends StatelessWidget {
  const SplashWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: AnimatedContainer(
        // width: 300, height: 300,
        curve: Curves.easeInOutCirc,
        duration: const Duration(milliseconds: 2000),
        child: Card(
          elevation: 24.0,
          shape: getRoundedBorder(radius: 16),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'GeoMonitor',
                        style: myNumberStyleLarger(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 4,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const FaIcon(FontAwesomeIcons.anchorCircleCheck),
                  const SizedBox(
                    width: 24,
                  ),
                  Text(
                    'We help you see!',
                    style: myTextStyleMedium(context),
                  ),
                  const SizedBox(
                    width: 24,
                  ),
                  const Text('🔷🔷'),
                ],
              ),
              const SizedBox(
                height: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> getOut(BuildContext context) async {
  //todo - REMOVE after testing
  pp('🌀🌀🌀🌀 Request to sign out of Firebase and the app!');

  fb.FirebaseAuth.instance.signOut();
  pp('🌀🌀🌀🌀  🍎 Signed out of Firebase!!! 🍎 ');
  Prefs.deleteUser();
  await cacheManager.initialize(forceInitialization: true);

  pp('🌀🌀🌀🌀 We good and clean now, Senor! .... restarting the app ....');
  var android = UniversalPlatform.isAndroid;
  var ios = UniversalPlatform.isIOS;
  if (android) {
    pp('🌀🌀🌀🌀 android platform: We should be in the process of restarting the app.');
    Restart.restartApp();
  }
  if (ios) {
    pp('🌀🌀🌀🌀 ios platform: We should notify the user : account closed.');

  }


}
