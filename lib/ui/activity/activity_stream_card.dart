import 'package:flutter/material.dart';
import 'package:geo_monitor/library/data/activity_model.dart';
import 'package:geo_monitor/library/functions.dart';

import '../../library/data/activity_type_enum.dart';
import 'activity_cards.dart';

class ActivityStreamCard extends StatefulWidget {
  const ActivityStreamCard(
      {Key? key,
      required this.model,
      required this.frontPadding,
      required this.thinMode,
      required this.width})
      : super(key: key);

  final ActivityModel model;
  final double frontPadding;
  final bool thinMode;
  final double width;

  @override
  ActivityStreamCardState createState() => ActivityStreamCardState();
}

class ActivityStreamCardState extends State<ActivityStreamCard> {
  @override
  void initState() {
    super.initState();
  }

  Widget _getUserAdded(Icon icon, String msg) {
    final localDate =
        DateTime.parse(widget.model.date!).toLocal().toIso8601String();
    final dt = getFormattedDateHourMinuteSecond(
        date: DateTime.parse(localDate), context: context);
    return widget.thinMode
        ? Card(
            shape: getRoundedBorder(radius: 16),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  const SizedBox(
                    height: 8,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          dt,
                          style: myTextStyleSmallBoldPrimaryColor(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  widget.model.userThumbnailUrl == null
                      ? const CircleAvatar(
                          radius: 16,
                        )
                      : CircleAvatar(
                          radius: 16,
                          backgroundImage:
                              NetworkImage(widget.model.userThumbnailUrl!),
                        ),
                  const SizedBox(
                    height: 8,
                  ),
                  Text(
                    widget.model.userName!,
                    style: myTextStyleTiny(context),
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 14.0),
                    child: Text(
                      msg,
                      style: myTextStyleTiny(context),
                    ),
                  ),
                  const SizedBox(
                    height: 24,
                  ),
                ],
              ),
            ),
          )
        : Card(
            shape: getRoundedBorder(radius: 16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                height: 120,
                child: Column(
                  children: [
                    Row(
                      children: [
                        icon,
                        const SizedBox(
                          width: 8,
                        ),
                        Text(
                          msg,
                          style: myTextStyleSmall(context),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: widget.frontPadding),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          widget.model.userThumbnailUrl == null
                              ? const CircleAvatar(
                                  radius: 16,
                                )
                              : CircleAvatar(
                                  radius: 16,
                                  backgroundImage: NetworkImage(
                                      widget.model.userThumbnailUrl!),
                                ),
                          const SizedBox(
                            width: 8,
                          ),
                          Text(
                            widget.model.userName!,
                            style: myTextStyleSmall(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    Padding(
                      padding: EdgeInsets.only(left: widget.frontPadding),
                      child: Row(
                        children: [
                          Text(
                            getFormattedDateShortWithTime(
                                widget.model.date!, context),
                            style: myTextStyleTiny(context),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
  }

  Widget _getGeneric(Icon icon, String msg, double height) {
    return widget.thinMode
        ? ThinCard(
            model: widget.model,
            width: 420,
            height: height,
            icon: icon,
            message: msg)
        : WideCard(
            model: widget.model,
            width: 600,
            height: height,
            icon: icon,
            message: msg);
  }

  @override
  Widget build(BuildContext context) {
    late Icon icon;
    late String message;

    switch (widget.model.activityType!) {
      case ActivityType.projectAdded:
        icon = Icon(Icons.access_time, color: Theme.of(context).primaryColor);
        message = 'Project added: ${widget.model.projectName}';
        return _getGeneric(icon, message, 80.0);
        break;
      case ActivityType.photoAdded:
        icon = Icon(Icons.camera_alt, color: Theme.of(context).primaryColor);
        message = '${widget.model.projectName}';
        return _getGeneric(icon, message, 132.0);
        break;
      case ActivityType.videoAdded:
        icon = Icon(Icons.video_camera_front,
            color: Theme.of(context).primaryColorLight);
        message = '${widget.model.projectName}';
        return _getGeneric(icon, message, 132.0);
        break;
      case ActivityType.audioAdded:
        icon = Icon(Icons.mic, color: Theme.of(context).primaryColor);
        message = '${widget.model.projectName}';
        return _getGeneric(icon, message, 132.0);
        break;
      case ActivityType.messageAdded:
        icon = Icon(Icons.message, color: Theme.of(context).primaryColor);
        message = 'Message added';
        return _getGeneric(icon, message, 100);
        break;
      case ActivityType.userAddedOrModified:
        icon = Icon(Icons.person, color: Theme.of(context).primaryColor);
        message = 'Added, modified or signed in';
        return _getUserAdded(icon, message);
        break;
      case ActivityType.positionAdded:
        icon = Icon(Icons.home, color: Theme.of(context).primaryColor);
        message = 'Location added: ${widget.model.projectName}';
        return _getGeneric(icon, message, 140);
        break;
      case ActivityType.polygonAdded:
        icon =
            Icon(Icons.circle_outlined, color: Theme.of(context).primaryColor);
        message = 'Area added: ${widget.model.projectName}';
        return _getGeneric(icon, message, 100);
        break;
      case ActivityType.settingsChanged:
        icon = Icon(Icons.settings, color: Theme.of(context).primaryColor);
        message = 'Settings changed or added';
        return _getGeneric(icon, message, 80);
        break;
      case ActivityType.geofenceEventAdded:
        icon = Icon(Icons.person_2, color: Theme.of(context).primaryColor);
        message = 'at: ${widget.model.geofenceEvent!.projectName!}';
        return _getUserAdded(icon, message);
        break;
      case ActivityType.conditionAdded:
        icon = Icon(Icons.access_alarm, color: Theme.of(context).primaryColor);
        message = 'Project Condition added';
        return _getGeneric(icon, message, 120);
        break;
      case ActivityType.locationRequest:
        icon = Icon(Icons.location_on, color: Theme.of(context).primaryColor);
        message =
            'Location requested from ${widget.model.locationRequest!.userName}';
        return _getGeneric(icon, message, 120);
        break;
      case ActivityType.locationResponse:
        icon =
            Icon(Icons.location_history, color: Theme.of(context).primaryColor);
        message =
            'Location request responded to by ${widget.model.locationResponse!.userName}';
        return _getGeneric(icon, message, 120);
        break;
      case ActivityType.kill:
        icon = Icon(Icons.cancel, color: Theme.of(context).primaryColor);
        message = 'User KILL request made, cancel ${widget.model.userName}';
        return _getGeneric(icon, message, 120);
        break;
      default:
        return const SizedBox(
          width: 300,
          child: Text('We got a problem, Senor!'),
        );
        break;
    }
  }
}
