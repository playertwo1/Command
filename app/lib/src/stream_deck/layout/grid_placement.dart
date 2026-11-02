import 'package:droiddeck/core/droiddeck_client/models/deck_button.dart';

/// Um botão e seu espaço visual efetivo dentro da grade.
class GridPlacement {
  final DeckButton button;
  final int row;
  final int column;
  final int rowSpan;
  final int columnSpan;

  const GridPlacement({
    required this.button,
    required this.row,
    required this.column,
    required this.rowSpan,
    required this.columnSpan,
  });
}

/// Layout determinístico: não sobrescreve outra âncora e reduz o botão até caber.
class GridLayout {
  final int rows;
  final int columns;
  final List<GridPlacement> placements;
  final Set<String> _covered;

  const GridLayout._(this.rows, this.columns, this.placements, this._covered);

  static String _key(int row, int column) => '$row:$column';

  bool isFree(int row, int column) => !_covered.contains(_key(row, column));

  factory GridLayout.of(List<DeckButton> buttons, int rows, int columns) {
    final safeRows = rows.clamp(1, 200).toInt();
    final safeColumns = columns.clamp(1, 20).toInt();
    final sorted = [...buttons]
      ..sort((a, b) {
        final byRow = a.row.compareTo(b.row);
        if (byRow != 0) return byRow;
        final byColumn = a.column.compareTo(b.column);
        return byColumn != 0 ? byColumn : a.id.compareTo(b.id);
      });
    final anchors = <String>{
      for (final button in sorted)
        if (button.row >= 0 &&
            button.row < safeRows &&
            button.column >= 0 &&
            button.column < safeColumns)
          _key(button.row, button.column),
    };
    final covered = <String>{};
    final placements = <GridPlacement>[];

    for (final button in sorted) {
      final row = button.row;
      final column = button.column;
      if (row < 0 || row >= safeRows || column < 0 || column >= safeColumns)
        continue;
      if (covered.contains(_key(row, column))) continue;

      final maxRows = button.rowSpan.clamp(1, safeRows - row).toInt();
      final maxColumns = button.columnSpan
          .clamp(1, safeColumns - column)
          .toInt();
      var chosenRows = 1;
      var chosenColumns = 1;
      var chosenArea = 0;

      bool fits(int rowSpan, int columnSpan) {
        for (var r = row; r < row + rowSpan; r++) {
          for (var c = column; c < column + columnSpan; c++) {
            final key = _key(r, c);
            if ((r != row || c != column) &&
                (covered.contains(key) || anchors.contains(key)))
              return false;
          }
        }
        return true;
      }

      for (var rowSpan = 1; rowSpan <= maxRows; rowSpan++) {
        for (var columnSpan = 1; columnSpan <= maxColumns; columnSpan++) {
          if (!fits(rowSpan, columnSpan)) continue;
          final area = rowSpan * columnSpan;
          final widerTieBreak =
              area == chosenArea && columnSpan > chosenColumns;
          if (area > chosenArea || widerTieBreak) {
            chosenArea = area;
            chosenRows = rowSpan;
            chosenColumns = columnSpan;
          }
        }
      }

      for (var r = row; r < row + chosenRows; r++) {
        for (var c = column; c < column + chosenColumns; c++) {
          covered.add(_key(r, c));
        }
      }
      placements.add(
        GridPlacement(
          button: button,
          row: row,
          column: column,
          rowSpan: chosenRows,
          columnSpan: chosenColumns,
        ),
      );
    }
    return GridLayout._(safeRows, safeColumns, placements, covered);
  }
}

/// Encaixe da grade. Sem colunas e linhas informadas, calcula pelo tamanho da tela.
class DeckGridFit {
  final int columns;
  final int rows;
  final double cell;
  final double spacing;

  const DeckGridFit({
    required this.columns,
    required this.rows,
    required this.cell,
    required this.spacing,
  });
}

DeckGridFit fitDeckGrid({
  required double width,
  required double height,
  int? customColumns,
  int? customRows,
  double spacing = 8,
}) {
  final gap = spacing.clamp(4.0, 24.0).toDouble();
  const target = 96.0;
  final int cols;
  final int rows;
  if (customColumns != null && customRows != null) {
    cols = customColumns.clamp(2, 8).toInt();
    rows = customRows.clamp(2, 6).toInt();
  } else {
    cols = ((width + gap) / (target + gap)).floor().clamp(1, 20).toInt();
    rows = ((height + gap) / (target + gap)).floor().clamp(1, 20).toInt();
  }
  final cellW = cols <= 1 ? width : (width - gap * (cols - 1)) / cols;
  final cellH = rows <= 1 ? height : (height - gap * (rows - 1)) / rows;
  var cell = cellW < cellH ? cellW : cellH;
  if (cell < 1) cell = 1;
  return DeckGridFit(columns: cols, rows: rows, cell: cell, spacing: gap);
}

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
