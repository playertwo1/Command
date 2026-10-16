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
    this.isDefault = false,
    this.buttons = const [],
    this.autoSwitchApps,
  });

  /// Cópia com campos trocados, preservando os demais.
  DeckProfile copyWith({
    String? name,
    int? rows,
    int? columns,
    List<DeckButton>? buttons,
    List<String>? autoSwitchApps,
  }) =>
      DeckProfile(
        id: id,
        name: name ?? this.name,
        rows: rows ?? this.rows,
        columns: columns ?? this.columns,
        isDefault: isDefault,
        buttons: buttons ?? this.buttons,
        autoSwitchApps: autoSwitchApps ?? this.autoSwitchApps,
      );

  factory DeckProfile.fromJson(Map<String, dynamic> json) =>
      _$DeckProfileFromJson(json);

  Map<String, dynamic> toJson() => _$DeckProfileToJson(this);
}
