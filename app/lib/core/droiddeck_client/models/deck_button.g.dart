// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'deck_button.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeckButton _$DeckButtonFromJson(Map<String, dynamic> json) => DeckButton(
  id: json['id'] as String,
  row: (json['row'] as num).toInt(),
  column: (json['column'] as num).toInt(),
  label: json['label'] as String?,
  iconBase64: json['iconBase64'] as String?,
  iconName: json['iconName'] as String?,
  backgroundColor: json['backgroundColor'] as String?,
  activeColor: json['activeColor'] as String?,
  action: json['action'] == null
      ? null
      : DeckAction.fromJson(json['action'] as Map<String, dynamic>),
  dynamicType: json['dynamicType'] as String?,
  longPressAction: json['longPressAction'] == null
      ? null
      : DeckAction.fromJson(json['longPressAction'] as Map<String, dynamic>),
  doubleTapAction: json['doubleTapAction'] == null
      ? null
      : DeckAction.fromJson(json['doubleTapAction'] as Map<String, dynamic>),
  toggle: json['toggle'] as bool? ?? false,
  activeAction: json['activeAction'] == null
      ? null
      : DeckAction.fromJson(json['activeAction'] as Map<String, dynamic>),
  activeLabel: json['activeLabel'] as String?,
  activeIconName: json['activeIconName'] as String?,
  activeIconBase64: json['activeIconBase64'] as String?,
  dynamicParameters: (json['dynamicParameters'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
  columnSpan: (json['columnSpan'] as num?)?.toInt() ?? 1,
  rowSpan: (json['rowSpan'] as num?)?.toInt() ?? 1,
  labelFontSize: (json['labelFontSize'] as num?)?.toInt(),
  labelAlign: json['labelAlign'] as String?,
  labelVAlign: json['labelVAlign'] as String?,
  hideLabel: json['hideLabel'] as bool? ?? false,
  cornerRadius: (json['cornerRadius'] as num?)?.toInt(),
  borderWidth: (json['borderWidth'] as num?)?.toInt(),
  borderColor: json['borderColor'] as String?,
  haptic: json['haptic'] as String?,
);

Map<String, dynamic> _$DeckButtonToJson(DeckButton instance) =>
    <String, dynamic>{
      'id': instance.id,
      'row': instance.row,
      'column': instance.column,
      'label': instance.label,
      'iconBase64': instance.iconBase64,
      'iconName': instance.iconName,
      'backgroundColor': instance.backgroundColor,
      'activeColor': instance.activeColor,
      'action': instance.action,
      'dynamicType': instance.dynamicType,
      'longPressAction': instance.longPressAction,
      'doubleTapAction': instance.doubleTapAction,
      'toggle': instance.toggle,
      'activeAction': instance.activeAction,
      'activeLabel': instance.activeLabel,
      'activeIconName': instance.activeIconName,
      'activeIconBase64': instance.activeIconBase64,
      'dynamicParameters': instance.dynamicParameters,
      'columnSpan': instance.columnSpan,
      'rowSpan': instance.rowSpan,
      'labelFontSize': instance.labelFontSize,
      'labelAlign': instance.labelAlign,
      'labelVAlign': instance.labelVAlign,
      'hideLabel': instance.hideLabel,
      'cornerRadius': instance.cornerRadius,
      'borderWidth': instance.borderWidth,
      'borderColor': instance.borderColor,
      'haptic': instance.haptic,
    };
