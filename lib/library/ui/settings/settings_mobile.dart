import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geo_monitor/library/ui/settings/settings_form.dart';
import 'package:geo_monitor/library/ui/settings/settings_form_monitor.dart';

import '../../../l10n/translation_handler.dart';
import '../../api/prefs_og.dart';
import '../../bloc/fcm_bloc.dart';
import '../../cache_manager.dart';
import '../../data/project.dart';
import '../../data/settings_model.dart';
import '../../data/user.dart';
import '../../functions.dart';
import '../../generic_functions.dart';

class SettingsMobile extends StatefulWidget {
  const SettingsMobile({Key? key}) : super(key: key);

  @override
  SettingsMobileState createState() => SettingsMobileState();
}

class SettingsMobileState extends State<SettingsMobile>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  SettingsModel? settingsModel;
  var distController = TextEditingController(text: '500');
  var videoController = TextEditingController(text: '20');
  var audioController = TextEditingController(text: '60');
  var activityController = TextEditingController(text: '24');

  late StreamSubscription<SettingsModel> settingsSubscriptionFCM;


  var orgSettings = <SettingsModel>[];

  int photoSize = 0;
  int currentThemeIndex = 0;
  int groupValue = 0;
  bool busy = false;
  bool busyWritingToDB = false;
  Project? selectedProject;
  User? user;

  @override
  void initState() {
    _animationController = AnimationController(vsync: this);
    super.initState();
    _setTexts();
    _listenToFCM();
    _getOrganizationSettings();
  }

  String? title;
  bool showMonitorForm = false;
  void _handleOnLocaleChanged(String locale) async {
    pp('SettingsForm 😎😎😎😎 _handleOnLocaleChanged: $locale');
    _setTexts();
  }

  Future _setTexts() async {
    settingsModel = await prefsOGx.getSettings();
      title = await translator.translate('settings', settingsModel!.locale!);
    user = await prefsOGx.getUser();
    if (user!.userType! == UserType.fieldMonitor) {
      showMonitorForm = true;
    }
    setState(() {});
  }

  void _listenToFCM() async {

    settingsSubscriptionFCM =
        fcmBloc.settingsStream.listen((SettingsModel event) async {
          if (mounted) {
            await _setTexts();
          }
        });

  }


  void _getOrganizationSettings() async {
    pp('🍎🍎 ............. getting user from prefs ...');
    user = await prefsOGx.getUser();
    setState(() {
      busy = true;
    });
    try {
      orgSettings = await cacheManager.getOrganizationSettings();
    } catch (e) {
      pp(e);
      if (mounted) {
        showToast(
            duration: const Duration(seconds: 5),
            message: '$e',
            context: context);
      }
    }
    setState(() {
      busy = false;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    settingsSubscriptionFCM.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
      appBar: AppBar(
        title: Text(
          title == null ? 'Settings' : title!,
          style: myTextStyleLarge(context),
        ),
        bottom:  PreferredSize(
          preferredSize: Size.fromHeight(showMonitorForm? 40: 8),
          child: const SizedBox(),
        ),
      ),
      body: busy
          ? const Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      backgroundColor: Colors.pink,
                    )),
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: showMonitorForm
                  ? SettingsFormMonitor(
                      onLocaleChanged: (locale) {
                        _handleOnLocaleChanged(locale);
                      },
                      padding: 20)
                  : SettingsForm(
                      padding: 8,
                      onLocaleChanged: (String locale) {
                        _handleOnLocaleChanged(locale);
                      },
                    ),
            ),
    ));
  }
}
