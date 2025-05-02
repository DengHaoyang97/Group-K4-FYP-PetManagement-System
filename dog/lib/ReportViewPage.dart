import 'package:flutter/material.dart';

class ReportViewPage extends StatelessWidget {
  final String reportName;
  final String rawText;

  const ReportViewPage({
    super.key,
    required this.reportName,
    required this.rawText,
  });

  @override
  Widget build(BuildContext context) {
    final lines = rawText.split('\n');

    // Max 4 Column
    List<List<String>> tableData = lines
        .map((line) {
          final parts = line.trim().split(RegExp(r'\s+'));
          return [
            parts.isNotEmpty ? parts[0] : '',
            parts.length > 1 ? parts[1] : '',
            parts.length > 2 ? parts[2] : '',
            parts.length > 3 ? parts.sublist(3).join(' ') : '',
          ];
        })
        .where((row) => row.any((cell) => cell.isNotEmpty))
        .toList();

    //Header
    const columns = [
      DataColumn(label: Text('Item')),
      DataColumn(label: Text('Value')),
      DataColumn(label: Text('Unit')),
      DataColumn(label: Text('Range')),
    ];

    // Table
    final rows = tableData.map((row) {
      final isHigh = row.join(' ').toLowerCase().contains('high');
      final isLow = row.join(' ').toLowerCase().contains('low');
      final rowColor = isHigh
          ? Colors.red[100]
          : isLow
              ? Colors.blue[100]
              : null;

      return DataRow(
        color: rowColor != null ? MaterialStateProperty.all(rowColor) : null,
        cells: row.map((cell) {
          return DataCell(
            TextFormField(
              initialValue: cell,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
              ),
              style: const TextStyle(fontSize: 14),
            ),
          );
        }).toList(),
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(title: Text(reportName)),
      body: CustomScrollView(
        slivers: [
          // 固定表头
          SliverPersistentHeader(
            pinned: true, // 固定在顶部
            delegate: _SliverHeaderDelegate(
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: DataTable(
                  columnSpacing: 20,
                  columns: columns,
                  rows: const [],
                  dataRowHeight: 48,
                ),
              ),
            ),
          ),
          // Scroll
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: DataTable(
                  columnSpacing: 20,
                  columns: columns,
                  rows: rows,
                  headingRowHeight: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SliverHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _SliverHeaderDelegate({required this.child});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  double get maxExtent => 56.0;

  @override
  double get minExtent => 56.0;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}
