import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:animations/animations.dart';
import 'package:badges/badges.dart';
import 'package:flutter/material.dart';
import 'package:geo_monitor/library/api/sharedprefs.dart';
import 'package:geo_monitor/library/bloc/organization_bloc.dart';
import 'package:geo_monitor/library/bloc/project_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../api/data_api.dart';
import '../../data/city.dart';
import '../../data/photo.dart';
import '../../data/project.dart';
import '../../data/position.dart' as local;
import '../../data/project_polygon.dart';
import '../../data/project_position.dart';
import '../../data/user.dart';
import '../../emojis.dart';
import '../../functions.dart';
import '../../location/loc_bloc.dart';

class ProjectMapMobile extends StatefulWidget {
  final Project project;
  final List<ProjectPosition> projectPositions;
  final List<ProjectPolygon> projectPolygons;
  final Photo? photo;

  const ProjectMapMobile(
      {super.key,
      required this.project,
      required this.projectPositions,
      this.photo,
      required this.projectPolygons});

  @override
  ProjectMapMobileState createState() => ProjectMapMobileState();
}

class ProjectMapMobileState extends State<ProjectMapMobile>
    with SingleTickerProviderStateMixin {
  final mm = '🔷🔷🔷ProjectMapMobile: ';
  late AnimationController _animationController;
  final Completer<GoogleMapController> _mapController = Completer();

  BitmapDescriptor markerIcon = BitmapDescriptor.defaultMarker;
  Map<MarkerId, Marker> markers = <MarkerId, Marker>{};
  var random = Random(DateTime.now().millisecondsSinceEpoch);
  final _key = GlobalKey<ScaffoldState>();
  bool _showNewPositionUI = false;
  bool busy = false;
  User? user;
  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14.4746,
  );
  final Set<Polygon> _polygons = HashSet<Polygon>();
  var projectPolygons = <ProjectPolygon>[];
  var projectPositions = <ProjectPosition>[];

  @override
  void initState() {
    _animationController = AnimationController(
        value: 0.0,
        duration: const Duration(milliseconds: 2000),
        reverseDuration: const Duration(milliseconds: 1500),
        vsync: this);
    super.initState();
    projectPolygons = widget.projectPolygons;
    projectPositions = widget.projectPositions;
    _getUser();
    _setMarkerIcon();
  }

  void _setMarkerIcon() async {
    BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(4.0,4.0)), "assets/avatar.png",)
        .then(
          (icon) {
        setState(() {
          markerIcon = icon;
        });
      },
    );
  }

  void _getUser() async {
    user = await Prefs.getUser();
    _refreshData(false);
  }

  void _refreshData(bool forceRefresh) async {
    setState(() {
      busy = true;
    });
    try {
      projectPolygons = await projectBloc.getProjectPolygons(
          projectId: widget.project.projectId!, forceRefresh: forceRefresh);
      projectPositions = await projectBloc.getProjectPositions(
          projectId: widget.project.projectId!, forceRefresh: forceRefresh);
    } catch (e) {
      pp(e);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    setState(() {
      busy = false;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  GoogleMapController? googleMapController;
  double _latitude = 0.0, _longitude = 0.0;

  Future<void> _addMarkers() async {
    pp('$mm _addMarkers: ....... 🍎 ${widget.projectPositions.length}');
    if (projectPositions.isEmpty) {
      pp('There are no positions found ${E.redDot}');
      return;
    }
    markers.clear();
    var latLongs = <LatLng>[];
    var cnt = 0;
    for (var projectPosition in projectPositions) {
      var latLng = LatLng(projectPosition.position!.coordinates[1],
          projectPosition.position!.coordinates[0]);
      latLongs.add(latLng);
      cnt++;
      final MarkerId markerId =
          MarkerId('${projectPosition.projectId}_${random.nextInt(9999988)}');
      final Marker marker = Marker(
        markerId: markerId,
        icon: markerIcon,
        position: LatLng(
          projectPosition.position!.coordinates.elementAt(1),
          projectPosition.position!.coordinates.elementAt(0),
        ),
        infoWindow: InfoWindow(
            title: projectPosition.projectName,
            snippet:
                'Project Location #$cnt of ${projectPositions.length} Here'),
        onTap: () {
          _onMarkerTapped(projectPosition);
        },
      );
      markers[markerId] = marker;
    }
    googleMapController = await _mapController.future;
    if (projectPositions.isNotEmpty) {
      var lat = projectPositions.first.position!.coordinates[1];
      var lng = projectPositions.first.position!.coordinates[0];
      _animateCamera(latitude: lat, longitude: lng, zoom: 10.0);
    }
  }

  void _buildProjectPolygons() {
    pp('$mm _buildProjectPolygons happening ... projectPolygons: ${projectPolygons.length}');
    _polygons.clear();
    for (var polygon in projectPolygons) {
      var points = <LatLng>[];
      for (var position in polygon.positions) {
        points.add(LatLng(position.coordinates[1], position.coordinates[0]));
      }
      _polygons.add(Polygon(
        polygonId: PolygonId(polygon.projectPolygonId!),
        points: points,
        fillColor: Colors.black26,
        strokeColor: Colors.pink,
        geodesic: true,
        strokeWidth: 4,
      ));
    }

    pp('$mm _buildProjectPolygons: 🍏project polygons created.: '
        '🔵 ${_polygons.length} points in polygon ...');
    if (projectPolygons.isNotEmpty) {
      var p = projectPolygons.first.positions.first;
      var lat = p.coordinates[1];
      var lng = p.coordinates[0];
      _animateCamera(latitude: lat, longitude: lng, zoom: 10.0);
    }
    setState(() {});
  }

  void _onMarkerTapped(ProjectPosition projectPosition) {
    pp('💜 💜 💜 💜 💜 💜 ProjectMapMobile: _onMarkerTapped ....... ${projectPosition.projectName}');
  }

  void _onLongPress(LatLng argument) {
    pp('$mm Map detected a long press! at $argument');
    if (user!.userType == UserType.fieldMonitor) {
      pp('$mm Field Monitor not allowed to create new project position; 🔶 quitting!');
      return;
    }
    setState(() {
      _latitude = argument.latitude;
      _longitude = argument.longitude;
      _showNewPositionUI = true;
    });
    _animationController.forward();
  }

  Future<bool> _isLocationWithinProjectMonitorDistance(
      {required double latitude, required double longitude}) async {
    pp('$mm calculating _isLocationWithinProjectMonitorDistance .... '
        '${widget.project.monitorMaxDistanceInMetres!} metres');

    var map = <double, ProjectPosition>{};
    for (var i = 0; i < widget.projectPositions.length; i++) {
      var projPos = widget.projectPositions.elementAt(i);
      var dist = await locationBloc.getDistance(
          latitude: projPos.position!.coordinates.elementAt(1),
          longitude: projPos.position!.coordinates.elementAt(0),
          toLatitude: latitude,
          toLongitude: longitude);

      map[dist] = projPos;
      pp('$mm Distance: 🌶 $dist metres 🌶 projectId: ${projPos.projectId} 🐊 projectPositionId: ${projPos.projectPositionId}');
    }
    if (map.isEmpty) {
      return false;
    }

    var list = map.keys.toList();
    list.sort();
    pp('$mm Distances in list, length: : ${list.length} $list');
    if (list.elementAt(0) <=
        widget.project.monitorMaxDistanceInMetres!.toInt()) {
      return true;
    } else {
      return false;
    }
  }

  bool isWithin = false;

  Future<void> _submitNewPosition() async {
    setState(() {
      busy = true;
    });
    try {
      var isWithinRange = await _isLocationWithinProjectMonitorDistance(
          latitude: _latitude, longitude: _longitude);
      if (isWithinRange) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              padding: const EdgeInsets.all(0.0),
              duration: const Duration(seconds: 10),
              content: Card(
                  elevation: 8,
                  color: Theme.of(context).errorColor,
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                        'There is a project monitoring location nearby. This new one is not needed'),
                  ))));
        }
        _animationController.reverse().then((value) {
          setState(() {
            busy = false;
            _showNewPositionUI = false;
          });
        });
        return;
      }
      pp('Go and find nearest cities to this location : lat: $_latitude lng: $_longitude ...');
      List<City> cities = await DataAPI.findCitiesByLocation(
          latitude: _latitude, longitude: _longitude, radiusInKM: 5.0);

      pp('$mm Cities around this project position: ${cities.length}');

      var pos = ProjectPosition(
          projectName: widget.project.name,
          caption: 'tbd',
          projectPositionId: const Uuid().v4(),
          created: DateTime.now().toUtc().toIso8601String(),
          position: local.Position(
              coordinates: [_longitude, _latitude], type: 'Point'),
          nearestCities: cities,
          organizationId: widget.project.organizationId,
          projectId: widget.project.projectId);

      var resultPosition = await DataAPI.addProjectPosition(position: pos);
      organizationBloc.addProjectPositionToStream(resultPosition);
      projectPositions.add(resultPosition);
      _addMarkers();
      setState(() {

      });
    } catch (e) {
      pp(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            duration: const Duration(seconds: 10), content: Text('$e')));
      }
    }
    _animationController.reverse().then((value) {
      setState(() {
        busy = false;
        _showNewPositionUI = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        key: _key,
        appBar: AppBar(
          title: Text(
            'Project Locations & Areas',
            style: myTextStyleSmall(context),
          ),
          actions: [
            IconButton(
                onPressed: () {
                  _refreshData(true);
                },
                icon: Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: Theme.of(context).primaryColor,
                ))
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const SizedBox(width: 12,),
                    Flexible(
                      child: Text(
                        widget.project.name!,
                        style: myTextStyleSmall(context),
                      ),
                    ),
                    const SizedBox(width: 28,),
                    ProjectPositionChooser(projectPositions: projectPositions,
                        projectPolygons: projectPolygons, onSelected: _onSelected),

                    const SizedBox(width: 12,),
                    busy
                        ? const SizedBox(
                            width: 48,
                          )
                        : const SizedBox(),
                    busy
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              backgroundColor: Colors.pink,
                            ),
                          )
                        : const SizedBox(),
                  ],
                ),
                const SizedBox(
                  height: 16,
                )
              ],
            ),
          ),
        ),
        body: Stack(
          children: [
            GestureDetector(
              onTap: () async {
                var loc = await locationBloc.getLocation();
                _animateCamera(
                    latitude: loc.latitude, longitude: loc.longitude, zoom: 12.0);
              },
              child: Badge(
                badgeColor: Colors.pink,
                badgeContent:
                    Text('${projectPositions.length + projectPolygons.length}'),
                padding: const EdgeInsets.all(8.0),
                position: BadgePosition.topEnd(top: 8, end: 8),
                elevation: 8,
                child: GoogleMap(
                  mapType: MapType.hybrid,
                  mapToolbarEnabled: true,
                  initialCameraPosition: _kGooglePlex,
                  onMapCreated: (GoogleMapController controller) {
                    pp('🍎🍎🍎........... GoogleMap onMapCreated ... ready to rumble!');
                    _mapController.complete(controller);
                    googleMapController = controller;
                    _addMarkers();
                    _buildProjectPolygons();
                    setState(() {});
                  },
                  // myLocationEnabled: true,
                  markers: Set<Marker>.of(markers.values),
                  compassEnabled: true,
                  buildingsEnabled: true,
                  zoomControlsEnabled: true,
                  onLongPress: _onLongPress,
                  polygons: _polygons,
                ),
              ),
            ),
            widget.photo != null
                ? Positioned(
                    left: 12,
                    top: 12,
                    child: AnimatedBuilder(
                      animation: _animationController,
                      builder: (BuildContext context, Widget? child) {
                        return FadeScaleTransition(
                          animation: _animationController,
                          child: child,
                        );
                      },
                      child: Card(
                        elevation: 8,
                        color: Colors.black26,
                        child: SizedBox(
                          height: 180,
                          width: 160,
                          child: Column(
                            children: [
                              const SizedBox(
                                height: 12,
                              ),
                              Image.network(
                                widget.photo!.thumbnailUrl!,
                                width: 140,
                                height: 140,
                                fit: BoxFit.fill,
                              ),
                              Text(
                                getFormattedDateShortestWithTime(
                                    widget.photo!.created!, context),
                                style: Styles.whiteTiny,
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : Container(),
            _showNewPositionUI
                ? Positioned(
                    right: 8,
                    top: 16,
                    child: AnimatedBuilder(
                      animation: _animationController,
                      builder: (BuildContext context, Widget? child) {
                        return FadeScaleTransition(
                          animation: _animationController,
                          child: child,
                        );
                      },
                      child: Card(
                        elevation: 8,
                        shape: getRoundedBorder(radius: 16),
                        color: Colors.black38,
                        child: Center(
                            child: SizedBox(
                          height: 240,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Project Location',
                                      style: myTextStyleLarge(context),
                                    ),
                                    const SizedBox(
                                      width: 60,
                                    ),
                                    IconButton(
                                        onPressed: () {
                                          _animationController
                                              .reverse()
                                              .then((value) {
                                            setState(() {
                                              _showNewPositionUI = false;
                                            });
                                          });
                                        },
                                        icon: const Icon(Icons.close)),
                                  ],
                                ),
                                const SizedBox(
                                  height: 24,
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 80,
                                        child: Text('Latitude:',
                                            style: myTextStyleSmall(context)),
                                      ),
                                      const SizedBox(
                                        width: 8,
                                      ),
                                      Text(_latitude.toStringAsFixed(5),
                                          style: myNumberStyleSmall(context)),
                                    ],
                                  ),
                                ),
                                const SizedBox(
                                  height: 8,
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 80,
                                        child: Text('Longitude:',
                                            style: myTextStyleSmall(context)),
                                      ),
                                      const SizedBox(
                                        width: 8,
                                      ),
                                      Text(
                                        _longitude.toStringAsFixed(5),
                                        style: myNumberStyleSmall(context),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(
                                  height: 24,
                                ),
                                busy
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 4,
                                          backgroundColor: Colors.pink,
                                        ),
                                      )
                                    : ElevatedButton(
                                        onPressed: _submitNewPosition,
                                        child: Text(
                                          'Save Project Location',
                                          style: myTextStyleMedium(context),
                                        )),
                              ],
                            ),
                          ),
                        )),
                      ),
                    ))
                : const SizedBox(),
          ],
        ),
      ),
    );
  }

  void _animateCamera({required double latitude, required double longitude, required double zoom}) {
    final CameraPosition cameraPosition = CameraPosition(
      target: LatLng(latitude, longitude),
      zoom: zoom,
    );
    googleMapController!
        .animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }

  _onSelected(local.Position p1) {
    _animateCamera(latitude: p1.coordinates[1], longitude: p1.coordinates[0], zoom: 14.6);
  }
}

class ProjectPositionChooser extends StatelessWidget {
  const ProjectPositionChooser(
      {Key? key,
      required this.projectPositions,
      required this.projectPolygons,
      required this.onSelected})
      : super(key: key);
  final List<ProjectPosition> projectPositions;
  final List<ProjectPolygon> projectPolygons;
  final Function(local.Position) onSelected;
  @override
  Widget build(BuildContext context) {
    var list = <local.Position>[];
    // projectPositions.sort((a,b) => a.created!.compareTo(b.created!));
    pp('this sort breaks cause created is null');
    for (var value in projectPositions) {
      list.add(value.position!);
    }
    for (var value in projectPolygons) {
      list.add(value.positions.first);
      // for (var element in value.positions) {
      //
      // }
    }
    var cnt = 0;
    var menuItems = <DropdownMenuItem>[];
    for (var pos in list) {
      cnt++;
      menuItems.add(
        DropdownMenuItem<local.Position>(
          value: pos,
          child: Row(
            children: [
               Text('Location No. ', style: myTextStyleSmall(context),),
              const SizedBox(
                width: 8,
              ),
              Text('$cnt', style: myNumberStyleSmall(context),),
            ],
          ),
        ),
      );
    }
    return DropdownButton(
        hint: Text(
          'Locations',
          style: myTextStyleSmall(context),
        ),
        items: menuItems,
        onChanged: (value) {
          onSelected(value);
        });
  }
}
