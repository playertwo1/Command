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

  /// Dimensão visual em casas da grade; 1×1 mantém compatibilidade com decks existentes.
  @JsonKey(name: 'columnSpan', defaultValue: 1)
  final int columnSpan;

  @JsonKey(name: 'rowSpan', defaultValue: 1)
  final int rowSpan;

  /// 8–18. Nulo mantém o tamanho automático.
  @JsonKey(name: 'labelFontSize')
  final int? labelFontSize;

  /// left, center ou right.
  @JsonKey(name: 'labelAlign')
  final String? labelAlign;

  /// top, center ou bottom.
  @JsonKey(name: 'labelVAlign')
  final String? labelVAlign;

  @JsonKey(name: 'hideLabel', defaultValue: false)
  final bool hideLabel;

  /// 0 = quadrado, valores altos = pílula. Nulo = cantos do tema.
  @JsonKey(name: 'cornerRadius')
  final int? cornerRadius;

  @JsonKey(name: 'borderWidth')
  final int? borderWidth;

  @JsonKey(name: 'borderColor')
  final String? borderColor;

  /// off, light, medium ou heavy. Nulo = vibração do app.
  @JsonKey(name: 'haptic')
  final String? haptic;

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
    int columnSpan = 1,
    int rowSpan = 1,
    int? labelFontSize,
    this.labelAlign,
    this.labelVAlign,
    this.hideLabel = false,
    int? cornerRadius,
    int? borderWidth,
    this.borderColor,
    this.haptic,
  })  : columnSpan = columnSpan.clamp(1, 4).toInt(),
        rowSpan = rowSpan.clamp(1, 4).toInt(),
        labelFontSize = labelFontSize?.clamp(8, 18).toInt(),
        cornerRadius = cornerRadius?.clamp(0, 48).toInt(),
        borderWidth = borderWidth?.clamp(0, 6).toInt();

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
    int? columnSpan,
    int? rowSpan,
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
        columnSpan: columnSpan ?? this.columnSpan,
        rowSpan: rowSpan ?? this.rowSpan,
        labelFontSize: labelFontSize,
        labelAlign: labelAlign,
        labelVAlign: labelVAlign,
        hideLabel: hideLabel,
        cornerRadius: cornerRadius,
        borderWidth: borderWidth,
        borderColor: borderColor,
        haptic: haptic,
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
