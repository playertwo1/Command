import 'package:json_annotation/json_annotation.dart';
import 'deck_action.dart';

part 'deck_button.g.dart';

@JsonSerializable()
class DeckButton {
  @JsonKey(name: 'id')
  final String id;

  @JsonKey(name: 'row')
  final int row;

  @JsonKey(name: 'column')
  final int column;

  @JsonKey(name: 'label')
  final String? label;

  @JsonKey(name: 'iconBase64')
  final String? iconBase64;

  @JsonKey(name: 'iconName')
  final String? iconName;

  @JsonKey(name: 'backgroundColor')
  final String? backgroundColor;

  /// Cor exibida quando o botão está "ativo" (toggle ligado: mute/discord).
  /// Se nulo, o runtime usa vermelho como padrão.
  @JsonKey(name: 'activeColor')
  final String? activeColor;

  @JsonKey(name: 'action')
  final DeckAction? action;

  @JsonKey(name: 'dynamicType')
  final String? dynamicType;

  /// Ação do toque longo. Sem ela, o toque longo abre o editor no celular.
  @JsonKey(name: 'longPressAction')
  final DeckAction? longPressAction;

  /// Ação do toque duplo. Com ela, o toque simples espera um instante para diferenciar.
  @JsonKey(name: 'doubleTapAction')
  final DeckAction? doubleTapAction;

  /// Alterna entre desligado e ligado a cada toque (estado guardado no PC).
  @JsonKey(name: 'toggle', defaultValue: false)
  final bool toggle;

  /// Com [toggle]: ação do toque quando ligado. Null = a mesma do toque.
  @JsonKey(name: 'activeAction')
  final DeckAction? activeAction;

  /// Rótulo e ícone quando o botão está ativo (pelo toggle ou pelo estado da ação).
  @JsonKey(name: 'activeLabel')
  final String? activeLabel;

  @JsonKey(name: 'activeIconName')
  final String? activeIconName;

  @JsonKey(name: 'activeIconBase64')
  final String? activeIconBase64;

  /// Parâmetros do botão de informação (cidade do clima, comando, URL...).
  @JsonKey(name: 'dynamicParameters')
  final Map<String, String>? dynamicParameters;

  DeckButton({
    required this.id,
    required this.row,
    required this.column,
    this.label,
    this.iconBase64,
    this.iconName,
    this.backgroundColor,
    this.activeColor,
    this.action,
    this.dynamicType,
    this.longPressAction,
    this.doubleTapAction,
    this.toggle = false,
    this.activeAction,
    this.activeLabel,
    this.activeIconName,
    this.activeIconBase64,
    this.dynamicParameters,
  });

  bool get hasActiveLook =>
      (activeLabel?.isNotEmpty ?? false) ||
      (activeIconName?.isNotEmpty ?? false) ||
      (activeIconBase64?.isNotEmpty ?? false);

  /// Cópia com campos trocados. Use isto em vez do construtor ao mexer num botão
  /// existente, senão campos novos (gestos...) se perdem no caminho.
  DeckButton copyWith({
    String? id,
    int? row,
    int? column,
    String? label,
    DeckAction? action,
  }) =>
      DeckButton(
        id: id ?? this.id,
        row: row ?? this.row,
        column: column ?? this.column,
        label: label ?? this.label,
        iconBase64: iconBase64,
        iconName: iconName,
        backgroundColor: backgroundColor,
        activeColor: activeColor,
        action: action ?? this.action,
        dynamicType: dynamicType,
        longPressAction: longPressAction,
        doubleTapAction: doubleTapAction,
        toggle: toggle,
        activeAction: activeAction,
        activeLabel: activeLabel,
        activeIconName: activeIconName,
        activeIconBase64: activeIconBase64,
        dynamicParameters: dynamicParameters,
      );

  /// Ação de um gesto: 'tap', 'longPress' ou 'doubleTap'.
  DeckAction? actionFor(String gesture) => switch (gesture) {
        'longPress' => longPressAction,
        'doubleTap' => doubleTapAction,
        _ => action,
      };

  factory DeckButton.fromJson(Map<String, dynamic> json) =>
      _$DeckButtonFromJson(json);

  Map<String, dynamic> toJson() => _$DeckButtonToJson(this);
}
