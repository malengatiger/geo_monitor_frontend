import 'dart:async';

import 'package:geofence_service/geofence_service.dart';
import '../../main.dart';
import '../api/data_api.dart';
import '../api/sharedprefs.dart';
import '../data/geofence_event.dart';
import '../data/project_position.dart';
import '../data/user.dart';
import 'package:uuid/uuid.dart';

import '../functions.dart';
import '../location/loc_bloc.dart';

final GeofencerTwo geofencerTwo = GeofencerTwo();

class GeofencerTwo {
  static const mm = '💦 💦 💦 💦 💦 GeofencerTwo: 💦 💦 ';
  final xx = '😡 😡 😡 😡 😡 😡 😡 😡 😡 GeofencerTwo: ';
  final StreamController<GeofenceEvent> _streamController =
      StreamController.broadcast();
  Stream<GeofenceEvent> get geofenceEventStream => _streamController.stream;

  final _geofenceList = <Geofence>[];
  User? _user;

  // Future initialize() async {
  //   pp('$mm Create a [GeofenceService] instance and set options.....');
  //   geofenceService = GeofenceService.instance.setup(
  //       interval: 5000,
  //       accuracy: 100,
  //       loiteringDelayMs: 30000,
  //       statusChangeDelayMs: 10000,
  //       useActivityRecognition: true,
  //       allowMockLocations: false,
  //       printDevLog: true,
  //       geofenceRadiusSortType: GeofenceRadiusSortType.DESC);
  //
  //   pp('\n\n$mm GeofenceService initialized .... 🌺 🌺 🌺 ');
  //
  //   _user = await Prefs.getUser();
  //   if (_user != null) {
  //     pp('$mm Geofences for Organization: ${_user!.organizationId} name: ${_user!.organizationName} .... 🌺 🌺 🌺 ');
  //     pp('$mm Geofences for User: ${_user!.toJson()}');
  //   }
  // }

  Future<List<ProjectPosition>> _findProjectPositionsByLocation(
      {required String organizationId,
      required double latitude,
      required double longitude,
      required double radiusInKM}) async {
    var mList = await DataAPI.findProjectPositionsByLocation(
        organizationId: organizationId,
        latitude: latitude,
        longitude: longitude,
        radiusInKM: radiusInKM);
    // var mList = await cacheManager.getOrganizationProjectPositions(organizationId: organizationId);
    pp('\n$mm _getProjectPositionsByLocation: found ${mList.length}\n');
    return mList;
  }

  Future buildGeofences({double? radiusInKM}) async {
    _user ??= await Prefs.getUser();

    await locationBloc.requestPermission();
    pp('$mm buildGeofences .... build geofences for the organization 🌀 ${_user!.organizationName}  🌀 \n\n');
    var loc = await locationBloc.getLocation();
    try {
      var list = await _findProjectPositionsByLocation(
          organizationId: _user!.organizationId!,
          latitude: loc.latitude,
          longitude: loc.longitude,
          radiusInKM: radiusInKM ?? defaultRadiusInKM);

      for (var pos in list) {
        await addGeofence(projectPosition: pos);
      }

      geofenceService.addGeofenceList(_geofenceList);

      geofenceService.addGeofenceStatusChangeListener(
          (geofence, geofenceRadius, geofenceStatus, location) async {
        pp('$xx Geofence Listener 💠 FIRED!! '
            '🔵 🔵 🔵 geofenceStatus: ${geofenceStatus.name}  at ${geofence.data['projectName']}');
        // pp('$mm geofence: ${geofence.toJson()}');
        pp('$mm geofenceRadius: ${geofenceRadius.toJson()}');
        pp('$mm geofenceStatus: ${geofenceStatus.toString()}');

        await _processGeofenceEvent(
            geofence: geofence,
            geofenceRadius: geofenceRadius,
            geofenceStatus: geofenceStatus,
            location: location);
      });

      try {
        pp('\n\n$mm  🔶🔶🔶🔶🔶🔶 Starting GeofenceService ...... 🔶🔶🔶🔶🔶🔶 ');
        await geofenceService.start().onError((error, stackTrace) => {
              pp('\n\n\n$reds GeofenceService failed to start, onError: 🔴 $error 🔴 \n\n\n')
            });

        pp('$mm  ✅ ✅ ✅ GeofenceService 🍐🍐🍐 STARTED 🍐🍐🍐: '
            '✅  🔆 🔆 🔆 🔆 🔆 🔆  ...... waiting for geofence status change.... 🔵 🔵 🔵 🔵 🔵 ');
      } catch (e) {
        pp(' GeofenceService failed to start: 🔴 $e 🔴 }');
      }
    } catch (e) {
      pp('$reds ERROR: probably to do with API call: 🔴 $e 🔴');
      pp(e);
    }
  }

  final reds = '🔴 🔴 🔴 🔴 🔴 🔴 GeofencerTwo: ';
  void onError() {}

  Future _processGeofenceEvent(
      {required Geofence geofence,
      required GeofenceRadius geofenceRadius,
      required GeofenceStatus geofenceStatus,
      required Location location}) async {
    pp('$mm $xx _processing new GeofenceEvent;  🔵 ${geofence.data['projectName']} '
        '🔵 with geofenceStatus: ${geofenceStatus.toString()}');

    var event = GeofenceEvent(
        status: geofenceStatus.toString(),
        userId: _user!.userId,
        user: _user,
        geofenceEventId: const Uuid().v4(),
        projectPositionId: geofence.id,
        projectName: geofence.data['projectName'],
        date: DateTime.now().toUtc().toIso8601String());

    String status = geofenceStatus.toString();
    switch (status) {
      case 'GeofenceStatus.ENTER':
        event.status = 'ENTER';
        pp('$mm IGNORING geofence ENTER event for ${event.projectName}');
        break;
      case 'GeofenceStatus.DWELL':
        event.status = 'DWELL';
        var gfe = await DataAPI.addGeofenceEvent(event);
        pp('$mm $xx geofence event added to database for ${event.projectName}');
        _streamController.sink.add(gfe);
        break;
      case 'GeofenceStatus.EXIT':
        event.status = 'EXIT';
        var gfe = await DataAPI.addGeofenceEvent(event);
        pp('$mm $xx geofence event added to database for ${event.projectName}');
        _streamController.sink.add(gfe);
        break;
    }



  }

  Future addGeofence({required ProjectPosition projectPosition}) async {
    projectPosition.nearestCities = [];
    var fence = Geofence(
      id: projectPosition.projectPositionId!,
      data: projectPosition.toJson(),
      latitude: projectPosition.position!.coordinates[1],
      longitude: projectPosition.position!.coordinates[0],
      radius: [
        GeofenceRadius(id: 'radius_150m', length: 150),
        // GeofenceRadius(id: 'radius_100m', length: 100),
      ],
    );

    _geofenceList.add(fence);
    pp('$mm added Geofence .... 👽👽👽👽👽 id: ${fence.id} 👽👽 _geofenceList now has ${_geofenceList.length} fences 🍎 ');
  }

  var defaultRadiusInKM = 100.0;
  var defaultRadiusInMetres = 150.0;
  var defaultDwellInMilliSeconds = 30;

  close() {
    _streamController.close();
  }
}
