// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'photo_for_upload.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PhotoForUploadAdapter extends TypeAdapter<PhotoForUpload> {
  @override
  final int typeId = 33;

  @override
  PhotoForUpload read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PhotoForUpload(
      filePath: fields[0] as String?,
      thumbnailPath: fields[1] as String?,
      projectPositionId: fields[3] as String?,
      projectPolygonId: fields[4] as String?,
      project: fields[2] as Project?,
      position: fields[5] as Position?,
      date: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PhotoForUpload obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.filePath)
      ..writeByte(1)
      ..write(obj.thumbnailPath)
      ..writeByte(2)
      ..write(obj.project)
      ..writeByte(3)
      ..write(obj.projectPositionId)
      ..writeByte(4)
      ..write(obj.projectPolygonId)
      ..writeByte(5)
      ..write(obj.position)
      ..writeByte(6)
      ..write(obj.date);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoForUploadAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
