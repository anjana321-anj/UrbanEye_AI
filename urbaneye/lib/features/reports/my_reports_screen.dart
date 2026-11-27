import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/utils.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/models.dart';
import '../../state/reports_controller.dart';
import '../../widgets/ue_widgets.dart';
import '../report/report_flow_screen.dart';
import 'report_detail_screen.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});
  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  static const _tabs = ['All', 'Pending', 'In Progress', 'Resolved'];
  final _pc = PageController();
  int _tab = 0;
  String _query = '';
  bool _searching = false;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  List<Report> _filter(List<Report> all, int tab) {
    var l = switch (tab) {
      1 => all.where((r) => r.status.bucket == StatusBucket.pending || r.status == ReportStatus.rejected).toList(),
      2 => all.where((r) => r.status.bucket == StatusBucket.inProgress).toList(),
      3 => all.where((r) => r.status.bucket == StatusBucket.resolved).toList(),
      _ => all,
    };
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      l = l.where((r) => r.ticket.toLowerCase().contains(q) || r.category.label.toLowerCase().contains(q) || r.location.area.toLowerCase().contains(q)).toList();
    }
    return l;
  }

  @override
  Widget build(BuildContext context) {
    final rc = context.watch<ReportsController>();
    final counts = [for (var i = 0; i < 4; i++) _filter(rc.mine, i).length];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: Motion.d(context, 250),
                  child: _searching
                      ? TextField(
                          key: const ValueKey('search'),
                          autofocus: true,
                          onChanged: (v) => setState(() => _query = v),
                          decoration: InputDecoration(
                            hintText: context.t('Search ticket, category, area'),
                            prefixIcon: const Icon(Icons.search_rounded),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        )
                      : Semantics(header: true, child: Text(context.t('My Reports'), key: const ValueKey('title'), style: AppText.h1(context))),
                ),
              ),
              IconButton(
                tooltip: context.t(_searching ? 'Close search' : 'Search'),
                icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
                onPressed: () => setState(() {
                  _searching = !_searching;
                  if (!_searching) _query = '';
                }),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 0, 12),
            child: SegmentedTabs(
              labels: _tabs,
              index: _tab,
              counts: counts,
              onChanged: (i) {
                setState(() => _tab = i);
                _pc.animateToPage(i, duration: Motion.d(context, 350), curve: Curves.easeOutCubic);
              },
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pc,
              itemCount: _tabs.length,
              onPageChanged: (i) {
                Haptics.tap();
                setState(() => _tab = i);
              },
              itemBuilder: (_, i) => _list(rc, _filter(rc.mine, i), i),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _list(ReportsController rc, List<Report> items, int tab) {
    if (rc.state == LoadState.loading && rc.mine.isEmpty) {
      return const SingleChildScrollView(padding: EdgeInsets.symmetric(horizontal: 20), child: LoadingSkeleton());
    }
    if (rc.state == LoadState.error && rc.mine.isEmpty) {
      return ErrorState(kind: ErrorKind.network, onRetry: rc.refresh);
    }
    return RefreshIndicator(
      onRefresh: rc.refresh,
      child: items.isEmpty
          ? ListView(children: [
              SizedBox(
                height: 420,
                child: _query.isNotEmpty
                    ? const EmptyState(kind: EmptyKind.search)
                    : EmptyState(
                        kind: EmptyKind.reports,
                        title: tab == 0 ? null : 'Nothing here yet',
                        actionLabel: 'Report a City Issue',
                        onAction: () => context.push(const ReportFlowScreen()),
                      ),
              ),
            ])
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              itemCount: items.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FadeSlideIn(
                  index: i,
                  child: ReportCard(report: items[i], onTap: () => context.push(ReportDetailScreen(reportId: items[i].id))),
                ),
              ),
            ),
    );
  }
}
