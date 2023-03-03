import 'package:hive/hive.dart';

import '../data/position.dart';
import '../data/project.dart';

part 'photo_for_upload.g.dart';

@HiveType(typeId: 33)
class PhotoForUpload extends HiveObject {
  @HiveField(0)
  String? filePath;
  @HiveField(1)
  String? thumbnailPath;
  @HiveField(2)
  Project? project;
  @HiveField(3)
  String? projectPositionId;
  @HiveField(4)
  String? projectPolygonId;
  @HiveField(5)
  Position? position;
  @HiveField(6)
  String? date;
  @HiveField(7)
  String? photoId;
  @HiveField(8)
  String? userId;
  @HiveField(9)
  String? userName;
  @HiveField(10)
  String? organizationId;
  @HiveField(11)
  String? userThumbnailUrl;

  PhotoForUpload(
      {required this.filePath,
      required this.thumbnailPath,
      this.projectPositionId,
      this.projectPolygonId,
      required this.project,
      required this.position,
      required this.photoId,
      required this.date,
      required this.userId,
      required this.userName,
      required this.userThumbnailUrl,
      required this.organizationId});

  PhotoForUpload.fromJson(Map data) {
    photoId = data['photoId'];
    filePath = data['filePath'];
    thumbnailPath = data['thumbnailPath'];
    date = data['date'];

    userId = data['userId'];
    userName = data['userName'];
    organizationId = data['organizationId'];
    userThumbnailUrl = data['userThumbnailUrl'];


    projectPolygonId = data['projectPolygonId'];
    projectPositionId = data['projectPositionId'];

    if (data['project'] != null) {
      project = Project.fromJson(data['project']);
    }

    if (data['position'] != null) {
      position = Position.fromJson(data['position']);
    }
  }
  Map<String, dynamic> toJson() {
    Map<String, dynamic> map = {
      'photoId': photoId,
      'filePath': filePath,
      'thumbnailPath': thumbnailPath,
      'project': project == null ? null : project!.toJson(),
      'projectPositionId': projectPositionId,
      'projectPolygonId': projectPolygonId,
      'date': date,
      'organizationId': organizationId,
      'userName': userName,
      'userId': userId,
      'userThumbnailUrl': userThumbnailUrl,
      'position': position == null ? null : position!.toJson(),
    };
    return map;
  }
}
