import 'package:json_annotation/json_annotation.dart';
import 'deck_button.dart';

part 'deck_profile.g.dart';

@JsonSerializable()
class DeckProfile {
  @JsonKey(name: 'id')
  final String id;

  @JsonKey(name: 'name')
  final String name;

  @JsonKey(name: 'rows')
  final int rows;

  @JsonKey(name: 'columns')
  final int columns;

  /// Grade escolhida pelo usuário. Falso mantém o encaixe automático na tela.
  @JsonKey(name: 'useCustomGrid', defaultValue: false)
  final bool useCustomGrid;

  @JsonKey(name: 'backgroundColor')
  final String? backgroundColor;

  @JsonKey(name: 'backgroundColorEnd')
  final String? backgroundColorEnd;

  @JsonKey(name: 'backgroundImageBase64')
  final String? backgroundImageBase64;

  @JsonKey(name: 'gap', defaultValue: 8)
  final int gap;

  @JsonKey(name: 'margin', defaultValue: 0)
  final int margin;

  @JsonKey(name: 'isDefault')
  final bool isDefault;

  @JsonKey(name: 'buttons')
  final List<DeckButton> buttons;

  /// Processos (sem .exe) que trazem este perfil para a frente quando ganham o foco no PC.
  @JsonKey(name: 'autoSwitchApps')
  final List<String>? autoSwitchApps;

  DeckProfile({
    required this.id,
    this.name = 'New Profile',
    this.rows = 3,
    this.columns = 4,
    this.useCustomGrid = false,
    this.backgroundColor,
    this.backgroundColorEnd,
    this.backgroundImageBase64,
    int gap = 8,
    int margin = 0,
    this.isDefault = false,
    this.buttons = const [],
    this.autoSwitchApps,
  })  : gap = gap.clamp(4, 24).toInt(),
        margin = margin.clamp(0, 32).toInt();

  /// Cópia com campos trocados, preservando os demais.
  DeckProfile copyWith({
    String? name,
    int? rows,
    int? columns,
    bool? useCustomGrid,
    String? backgroundColor,
    String? backgroundColorEnd,
    String? backgroundImageBase64,
    int? gap,
    int? margin,
    bool clearBackgroundImage = false,
    List<DeckButton>? buttons,
    List<String>? autoSwitchApps,
  }) =>
      DeckProfile(
        id: id,
        name: name ?? this.name,
        rows: rows ?? this.rows,
        columns: columns ?? this.columns,
        useCustomGrid: useCustomGrid ?? this.useCustomGrid,
        backgroundColor: backgroundColor ?? this.backgroundColor,
        backgroundColorEnd: backgroundColorEnd ?? this.backgroundColorEnd,
        backgroundImageBase64: clearBackgroundImage
            ? null
            : backgroundImageBase64 ?? this.backgroundImageBase64,
        gap: gap ?? this.gap,
        margin: margin ?? this.margin,
        isDefault: isDefault,
        buttons: buttons ?? this.buttons,
        autoSwitchApps: autoSwitchApps ?? this.autoSwitchApps,
      );

  factory DeckProfile.fromJson(Map<String, dynamic> json) =>
      _$DeckProfileFromJson(json);

  Map<String, dynamic> toJson() => _$DeckProfileToJson(this);
}
