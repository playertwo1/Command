// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'deck_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeckProfile _$DeckProfileFromJson(Map<String, dynamic> json) => DeckProfile(
  id: json['id'] as String,
  name: json['name'] as String? ?? 'New Profile',
  rows: (json['rows'] as num?)?.toInt() ?? 3,
  columns: (json['columns'] as num?)?.toInt() ?? 4,
  useCustomGrid: json['useCustomGrid'] as bool? ?? false,
  backgroundColor: json['backgroundColor'] as String?,
  backgroundColorEnd: json['backgroundColorEnd'] as String?,
  backgroundImageBase64: json['backgroundImageBase64'] as String?,
  gap: (json['gap'] as num?)?.toInt() ?? 8,
  margin: (json['margin'] as num?)?.toInt() ?? 0,
  isDefault: json['isDefault'] as bool? ?? false,
  buttons:
      (json['buttons'] as List<dynamic>?)
          ?.map((e) => DeckButton.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  autoSwitchApps: (json['autoSwitchApps'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$DeckProfileToJson(DeckProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'rows': instance.rows,
      'columns': instance.columns,
      'useCustomGrid': instance.useCustomGrid,
      'backgroundColor': instance.backgroundColor,
      'backgroundColorEnd': instance.backgroundColorEnd,
      'backgroundImageBase64': instance.backgroundImageBase64,
      'gap': instance.gap,
      'margin': instance.margin,
      'isDefault': instance.isDefault,
      'buttons': instance.buttons,
      'autoSwitchApps': instance.autoSwitchApps,
    };
