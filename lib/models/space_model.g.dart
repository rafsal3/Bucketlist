// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'space_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SpaceAdapter extends TypeAdapter<Space> {
  @override
  final int typeId = 2;

  @override
  Space read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Space(
      id: fields[0] as String,
      name: fields[1] as String,
      icon: fields[2] as String?,
      isHidden: fields[3] as bool,
      categories: (fields[4] as List?)?.cast<Category>(),
      uncategorizedItems: (fields[5] as List?)?.cast<ChecklistItem>(),
    );
  }

  @override
  void write(BinaryWriter writer, Space obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.icon)
      ..writeByte(3)
      ..write(obj.isHidden)
      ..writeByte(4)
      ..write(obj.categories)
      ..writeByte(5)
      ..write(obj.uncategorizedItems);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpaceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
