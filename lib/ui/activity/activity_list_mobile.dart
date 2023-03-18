import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geo_monitor/library/bloc/fcm_bloc.dart';
import 'package:geo_monitor/library/bloc/organization_bloc.dart';
import 'package:geo_monitor/library/data/location_request.dart';
import 'package:geo_monitor/library/data/location_response.dart';
import 'package:geo_monitor/ui/activity/activity_header.dart';
import 'package:geo_monitor/ui/activity/activity_stream_card.dart';

import '../../l10n/translation_handler.dart';
import '../../library/api/prefs_og.dart';
import '../../library/bloc/project_bloc.dart';
import '../../library/bloc/user_bloc.dart';
import '../../library/data/activity_model.dart';
import '../../library/data/audio.dart';
import '../../library/data/geofence_event.dart';
import '../../library/data/org_message.dart';
import '../../library/data/photo.dart';
import '../../library/data/project.dart';
import '../../library/data/project_polygon.dart';
import '../../library/data/project_position.dart';
import '../../library/data/settings_model.dart';
import '../../library/data/user.dart';
import '../../library/data/video.dart';
import '../../library/functions.dart';
import '../../library/generic_functions.dart';

class ActivityListMobile extends StatefulWidget {
  const ActivityListMobile({
    Key? key,
    required this.onPhotoTapped,
    required this.onVideoTapped,
    required this.onAudioTapped,
    required this.onUserTapped,
    required this.onProjectTapped,
    required this.onProjectPositionTapped,
    required this.onPolygonTapped,
    required this.onGeofenceEventTapped,
    required this.onOrgMessage,
    required this.user,
    required this.project,
    required this.onLocationResponse,
    required this.onLocationRequest,
  }) : super(key: key);

  final Function(Photo) onPhotoTapped;
  final Function(Video) onVideoTapped;
  final Function(Audio) onAudioTapped;
  final Function(User) onUserTapped;
  final Function(Project) onProjectTapped;
  final Function(ProjectPosition) onProjectPositionTapped;
  final Function(ProjectPolygon) onPolygonTapped;
  final Function(GeofenceEvent) onGeofenceEventTapped;
  final Function(OrgMessage) onOrgMessage;
  final Function(LocationResponse) onLocationResponse;
  final Function(LocationRequest) onLocationRequest;

  final User? user;
  final Project? project;

  @override
  State<ActivityListMobile> createState() => ActivityListMobileState();
}

class ActivityListMobileState extends State<ActivityListMobile>
    with SingleTickerProviderStateMixin {
  final ScrollController listScrollController = ScrollController();
  SettingsModel? settings;
  var models = <ActivityModel>[];
  late AnimationController _animationController;
  late StreamSubscription<ActivityModel> subscription;
  late StreamSubscription<SettingsModel> settingsSubscriptionFCM;
  late StreamSubscription<GeofenceEvent> geofenceSubscriptionFCM;

  static const userActive = 0, projectActive = 1, orgActive = 2;
  late int activeType;
  User? user;
  bool busy = true;
  String? prefix, suffix, name, title, loadingActivities;
  final mm = '😎😎😎😎😎😎 ActivityListMobile: ';

  @override
  void initState() {
    _animationController = AnimationController(
        duration: const Duration(milliseconds: 2000),
        reverseDuration: const Duration(milliseconds: 1000),
        vsync: this);
    super.initState();
    _setTexts();
    _getData(true);
    _listenToFCM();
  }

  @override
  void dispose() {
    geofenceSubscriptionFCM.cancel();
    settingsSubscriptionFCM.cancel();
    subscription.cancel();
    super.dispose();
  }

  String? locale;
  ActivityStrings? activityStrings;
  void _setTexts() async {
    user = await prefsOGx.getUser();
    settings = await prefsOGx.getSettings();
    if (settings != null) {
      locale = settings!.locale;
      if (widget.project != null) {
        title = await mTx.translate('projectActivity', settings!.locale!);
        name = widget.project!.name!;
      } else if (widget.user != null) {
        title = await mTx.translate('memberActivity', settings!.locale!);
        name = widget.user!.name;
      } else {
        title = await mTx.translate('organizationActivity', settings!.locale!);
        name = user!.organizationName;
      }
      activityStrings = await ActivityStrings.getTranslated();
      loadingActivities =
          await mTx.translate('loadingActivities', settings!.locale!);

      var sub = await mTx.translate('activityTitle', settings!.locale!);
      int index = sub.indexOf('\$');
      prefix = sub.substring(0, index);
      suffix = sub.substring(index + 6);
      setState(() {});
    }
  }

  void _getData(bool forceRefresh) async {
    pp('$mm ... getting activity data ... forceRefresh: $forceRefresh');
    if (models.isNotEmpty) {
      _animationController.reverse().then((value) {
        setState(() {
          busy = true;
        });
      });
    } else {
      setState(() {
        busy = true;
      });
    }
    pp('$mm ... getting activity data ... forceRefresh: $forceRefresh');
    try {
      settings = await prefsOGx.getSettings();
      var hours = 12;
      if (settings != null) {
        hours = settings!.activityStreamHours!;
      }
      pp('$mm ... get Activity (n hours) ... : $hours');
      if (widget.project != null) {
        activeType = projectActive;
        await _getProjectData(forceRefresh, hours);
      } else if (widget.user != null) {
        activeType = userActive;
        await _getUserData(forceRefresh, hours);
      } else {
        activeType = orgActive;
        await _getOrganizationData(forceRefresh, hours);
      }
      _sortDescending();
      _animationController.reset();
      _animationController.forward();
    } catch (e) {
      pp(e);
      if (mounted) {
        showToast(message: '$e', context: context);
      }
    }
    setState(() {
      busy = false;
    });
  }

  Future _getOrganizationData(bool forceRefresh, int hours) async {
    models = await organizationBloc.getOrganizationActivity(
        organizationId: settings!.organizationId!,
        hours: hours,
        forceRefresh: forceRefresh);
  }

  Future _getProjectData(bool forceRefresh, int hours) async {
    models = await projectBloc.getProjectActivity(
        projectId: widget.project!.projectId!,
        hours: hours,
        forceRefresh: forceRefresh);
  }

  Future _getUserData(bool forceRefresh, int hours) async {
    models = await userBloc.getUserActivity(
        userId: widget.user!.userId!, hours: hours, forceRefresh: forceRefresh);
  }

  void _listenToFCM() async {
    pp('$mm ... _listenToFCM activityStream ...');

    geofenceSubscriptionFCM =
        fcmBloc.geofenceStream.listen((GeofenceEvent event) async {
      pp('$mm: 🍎geofenceSubscriptionFCM: 🍎 GeofenceEvent: '
          'user ${event.user!.name} arrived: ${event.projectName} ');
      var arr = await mTx.translate('arrivedAt', settings!.locale!);
      if (event.projectName != null) {
        var arr1 = arr.replaceAll('\$member', event.user!.name!);
        var arrivedAt = arr1.replaceAll('\$project', event.projectName!);
        if (mounted) {
          showToast(
              duration: const Duration(seconds: 5),
              backgroundColor: Theme.of(context).primaryColor,
              padding: 20,
              textStyle: myTextStyleMedium(context),
              message: arrivedAt,
              context: context);
        }
      }
    });
    settingsSubscriptionFCM =
        fcmBloc.settingsStream.listen((SettingsModel event) {
      _getData(false);
    });

    subscription = fcmBloc.activityStream.listen((ActivityModel model) {
      pp('$mm activityStream delivered activity data ... ${model.date!}');
      _getData(false);
      if (isActivityValid(model)) {
        models.insert(0, model);
      }
      if (mounted) {
        setState(() {});
      }
    });
  }

  bool isActivityValid(ActivityModel m) {
    if (widget.project == null && widget.user == null) {
      return true;
    }
    if (widget.project != null) {
      if (m.projectId == widget.project!.projectId) {
        return true;
      }
    }
    if (widget.user != null) {
      if (m.userId == widget.user!.userId) {
        return true;
      }
    }
    return false;
  }

  bool sortedByDateAscending = false;
  void _sort() {
    if (sortedByDateAscending) {
      _sortDescending();
    } else {
      _sortAscending();
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _sortAscending() {
    models.sort((a, b) => a.date!.compareTo(b.date!));
    sortedByDateAscending = true;
  }

  void _sortDescending() {
    models.sort((a, b) => b.date!.compareTo(a.date!));
    sortedByDateAscending = false;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (busy) {
      return Scaffold(
        body: Center(
          child: Card(
            shape: getRoundedBorder(radius: 16),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: SizedBox(
                height: 100,
                child: Column(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        backgroundColor: Colors.pink,
                      ),
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    Text(
                      loadingActivities == null
                          ? 'Loading activities ...'
                          : loadingActivities!,
                      style: myTextStyleSmall(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (models.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(title == null ? 'Org Activity' : title!),
        ),
        body: Center(
          child: InkWell(
            onTap: () {
              _getData(true);
            },
            child: Card(
              shape: getRoundedBorder(radius: 16),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'No activities happening yet\n\nTap to Refresh',
                  style: myTextStyleMediumPrimaryColor(context),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return SafeArea(
        child: Scaffold(
      appBar: AppBar(
        title: Text(
          title == null ? 'Activity' : title!,
          style: myTextStyleMediumBold(context),
        ),
        actions: [
          IconButton(
              onPressed: () {
                _getData(true);
              },
              icon: Icon(
                Icons.refresh,
                color: Theme.of(context).primaryColor,
              )),
        ],
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name == null ? 'Name' : name!,
                      style: myTextStyleLargePrimaryColor(context),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 24,
                )
              ],
            )),
      ),
      body: Column(
        children: [
          InkWell(
            onTap: () {
              _getData(true);
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: prefix == null
                  ? const SizedBox()
                  : ActivityHeader(
                      prefix: prefix!,
                      suffix: suffix!,
                      onRefreshRequested: () {
                        _getData(true);
                      },
                      hours: settings == null
                          ? 12
                          : settings!.activityStreamHours!,
                      number: models.length,
                    ),
            ),
          ),
          const SizedBox(
            height: 8,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: ListView.builder(
                  itemCount: models.length,
                  controller: listScrollController,
                  itemBuilder: (_, index) {
                    var act = models.elementAt(index);
                    return GestureDetector(
                        onTap: () {
                          _handleTappedActivity(act);
                        },
                        child: activityStrings == null
                            ? const SizedBox()
                            : locale == null? const SizedBox():ActivityStreamCard(
                                activityStrings: activityStrings!,
                                activityModel: act,
                                frontPadding: 36,
                                thinMode: false,
                                width: width, locale: locale!,
                              ));
                  }),
            ),
          ),
        ],
      ),
    ));
  }

  Future<void> _handleTappedActivity(ActivityModel act) async {
    if (act.photo != null) {
      widget.onPhotoTapped(act.photo!);
    }
    if (act.video != null) {
      widget.onVideoTapped(act.video!);
    }

    if (act.audio != null) {
      widget.onAudioTapped(act.audio!);
    }

    if (act.user != null) {}
    if (act.projectPosition != null) {
      widget.onProjectPositionTapped(act.projectPosition!);
    }
    if (act.locationRequest != null) {
      widget.onLocationRequest(act.locationRequest!);
    }
    if (act.locationResponse != null) {
      widget.onLocationResponse(act.locationResponse!);
    }
    if (act.geofenceEvent != null) {
      widget.onGeofenceEventTapped(act.geofenceEvent!);
    }
    if (act.orgMessage != null) {
      widget.onOrgMessage(act.orgMessage!);
    }
  }
}
