import 'package:droiddeck/core/droiddeck_client/models/deck_button.dart';

/// Reorganiza somente a representação visual em ordem de leitura.
/// Os botões persistidos e suas posições originais não são alterados.
List<DeckButton> reflowButtons(List<DeckButton> buttons, int columns) {
  final safeColumns = columns.clamp(1, 20).toInt();
  final ordered = [...buttons]
    ..sort((a, b) {
      final byRow = a.row.compareTo(b.row);
      if (byRow != 0) return byRow;
      final byColumn = a.column.compareTo(b.column);
      if (byColumn != 0) return byColumn;
      return a.id.compareTo(b.id);
    });

  return [
    for (var index = 0; index < ordered.length; index++)
      ordered[index].copyWith(
        row: index ~/ safeColumns,
        column: index % safeColumns,
      ),
  ];
}
