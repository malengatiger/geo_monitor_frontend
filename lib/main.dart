import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geo_monitor/library/auth/app_auth.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:page_transition/page_transition.dart';

import 'firebase_options.dart';
import 'library/api/data_api.dart';
import 'library/api/prefs_og.dart';
import 'library/bloc/theme_bloc.dart';
import 'library/data/country.dart';
import 'library/emojis.dart';
import 'library/functions.dart';
import 'library/geofence/geofencer_two.dart';
import 'library/hive_util.dart';
import 'ui/dashboard/dashboard_main.dart';
import 'ui/intro/intro_main.dart';

int themeIndex = 0;
late FirebaseApp firebaseApp;
fb.User? fbAuthedUser;
final mx =
    '${E.heartGreen}${E.heartGreen}${E.heartGreen}${E.heartGreen} main: ';
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  firebaseApp = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform);
  pp('$xx main: '
      ' Firebase App has been initialized: ${firebaseApp.name}, checking for authed current user');
  fbAuthedUser = fb.FirebaseAuth.instance.currentUser;
  await GetStorage.init(cacheName);

  /// check user auth status
  if (fbAuthedUser == null) {
    pp('$xx main: fbAuthedUser is NULL ${E.redDot}${E.redDot}${E.redDot}');
  } else {
    pp('$xx main: fbAuthedUser is OK! check whether user exists, '
        'auth could be from old instance of app${E.leaf}${E.leaf}${E.leaf}');
    var user = await prefsOGx.getUser();
    if (user == null) {
      pp('$xx main: 🔴🔴🔴 user is null; cleanup necessary! '
          '🔴fbAuthedUser will be set to null');
      await fb.FirebaseAuth.instance.signOut();
      fbAuthedUser = null;
    }
  }
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const GeoMonitorApp());
}

const xx = '🎽🎽🎽🎽🎽🎽initializeGeoMonitor: ';

Future<void> _initializeGeoMonitor() async {
  pp('$xx _initializeGeoMonitor: ... GET CACHED SETTINGS; set themeIndex .............. ');
  var settings = await prefsOGx.getSettings();
  if (settings != null) {
    themeIndex = settings.themeIndex!;
    themeBloc.themeStreamController.sink.add(settings.themeIndex!);
  }

  if (fbAuthedUser != null) {
    pp('$xx _initializeGeoMonitor: Firebase user is OK, checking cached user ...');
    var user = await prefsOGx.getUser();
    if (user == null) {
      pp('\n\n$xx no cached user found, will set fbAuthedUser to null ...');
      fbAuthedUser = null;
      //await fb.FirebaseAuth.instance.signOut();
    } else {
      pp('$xx _initializeGeoMonitor: GeoMonitor user is OK');
    }
  } else {
    pp('$xx Firebase has no current user!');
  }
  //user = await prefsOGx.getUser();
  pp('$xx _initializeGeoMonitor: THEME: themeIndex up top is: $themeIndex ');
  //pp('THEME: user up top is: ${user!.name}');
  await dotenv.load(fileName: ".env");
  pp('$xx $heartBlue DotEnv has been loaded');
  await Hive.initFlutter(hiveName);
  await cacheManager.initialize(forceInitialization: false);
  pp('$xx ${E.heartGreen}${E.heartGreen}}${E.heartGreen} '
      '_initializeGeoMonitor: Hive initialized and boxCollection set up');

  await AppAuth.listenToFirebaseAuthentication();

  _buildGeofences();

  if (settings != null) {
    pp('\n\n$xx ${E.heartGreen}${E.heartGreen}}${E.heartGreen} _initializeGeoMonitor: App Settings are 🍎${settings.toJson()}🍎\n\n');
  }
}

void _buildGeofences() async {
  pp('\n$xx _buildGeofences starting ........................');
  theGreatGeofencer.buildGeofences();
  pp('$xx _buildGeofences should be done and dusted ....');
}

Future<void> signOutForcedForTesting() async {
  await fb.FirebaseAuth.instance.signOut();
  await prefsOGx.resetFCMSubscriptionFlag();
  if (0 == 0) {
    throw Exception('... Tooting my HORN! and faking it!');
  }
}

class GeoMonitorApp extends StatelessWidget {
  const GeoMonitorApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        pp('🌀🌀🌀🌀 Tap detected; should dismiss keyboard ...');
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: StreamBuilder(
          stream: themeBloc.themeStream,
          builder: (_, snapshot) {
            if (snapshot.hasData) {
              pp('\n\n${E.check}${E.check}${E.check}${E.check}${E.check} '
                  'main: theme index has changed to ${snapshot.data}\n\n');
              themeIndex = snapshot.data!;
            }
            return MaterialApp(
              scaffoldMessengerKey: rootScaffoldMessengerKey,
              debugShowCheckedModeBanner: false,
              title: 'GeoMonitor',
              theme: themeBloc.getTheme(themeIndex).darkTheme,
              darkTheme: themeBloc.getTheme(themeIndex).darkTheme,
              themeMode: ThemeMode.dark,
              home: AnimatedSplashScreen(
                duration: 2000,
                splash: const SplashWidget(),
                animationDuration: const Duration(milliseconds: 2000),
                curve: Curves.easeInCirc,
                splashIconSize: 160.0,
                nextScreen: fbAuthedUser == null
                    ? const IntroMain()
                    : const DashboardMain(),
                // nextScreen: const UserListMain(),
                splashTransition: SplashTransition.fadeTransition,
                pageTransitionType: PageTransitionType.leftToRight,
                backgroundColor: Colors.pink.shade900,
              ),
            );
          }),
    );
  }
}

class SplashWidget extends StatefulWidget {
  const SplashWidget({Key? key}) : super(key: key);

  @override
  State<SplashWidget> createState() => _SplashWidgetState();
}

class _SplashWidgetState extends State<SplashWidget> {
  @override
  void initState() {
    super.initState();
    _performSetup();
  }

  void _performSetup() async {
    _initializeGeoMonitor();
  }

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
                    'We help you see more!',
                    style: myTextStyleSmall(context),
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

class StorageTesterPage extends StatefulWidget {
  const StorageTesterPage({
    super.key,
  });

  @override
  State<StorageTesterPage> createState() => _StorageTesterPageState();
}

class _StorageTesterPageState extends State<StorageTesterPage> {
  var countries = <Country>[];
  bool busy = false;
  final mm =
      '${E.heartBlue}${E.heartBlue}${E.heartBlue}${E.heartBlue} Tester: ';
  Country? mCountry;

  @override
  void initState() {
    super.initState();
    _getCountries();
  }

  void _getCountries() async {
    pp('$mm .......... getting countries ....');
    setState(() {
      busy = true;
    });
    mCountry = await prefsOGx.getCountry();
    countries = await cacheManager.getCountries();
    if (countries.isEmpty) {
      countries = await DataAPI.getCountries();
    }
    setState(() {
      busy = false;
    });
  }

  Future<void> _handleCountry(Country country) async {
    pp('$mm country tapped: ${country.name!}');
    setState(() {
      mCountry = country;
    });
    prefsOGx.saveCountry(country);
    var index = await themeBloc.changeToRandomTheme();
    pp('$mm index theme set to: $index');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Testing Storage',
          style: myTextStyleSmall(context),
        ),
      ),
      body: Stack(
        children: [
          Center(
            child: busy
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 6,
                      backgroundColor: Colors.indigo,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      elevation: 4,
                      shape: getRoundedBorder(radius: 16),
                      child: Column(
                        children: [
                          const SizedBox(
                            height: 28,
                          ),
                          Text(
                            'Countries',
                            style: myTextStyleLarge(context),
                          ),
                          const SizedBox(
                            height: 28,
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'A country that is selected should be stored in local cache, whatever type is finally selected. '
                              'Let us choose the local cache carefully so that it performs the work necessary to handle cached objects quickly!',
                              style: myTextStyleSmall(context),
                            ),
                          ),
                          const SizedBox(
                            height: 12,
                          ),
                          mCountry == null
                              ? const SizedBox()
                              : Text(
                                  '${mCountry!.name}',
                                  style: GoogleFonts.lato(
                                      textStyle:
                                          Theme.of(context).textTheme.bodyLarge,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 24,
                                      color: Theme.of(context).primaryColor),
                                ),
                          const SizedBox(
                            height: 20,
                          ),
                          Expanded(
                            child: ListView.builder(
                                itemCount: countries.length,
                                itemBuilder: (_, index) {
                                  var country = countries.elementAt(index);
                                  return Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: InkWell(
                                      onTap: () {
                                        _handleCountry(country);
                                      },
                                      child: Card(
                                        elevation: 4,
                                        shape: getRoundedBorder(radius: 16),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Text(
                                            country.name!,
                                            style: myTextStyleSmall(context),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
