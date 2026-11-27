import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/services/media_service.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import '../../widgets/scene_image.dart';
import '../../widgets/ue_widgets.dart';
import '../waste/waste_screens.dart';
import 'category_hub_screen.dart';
import 'report_flow_screen.dart';

// ===========================================================================
// Report Center (tab)
// ===========================================================================

class ReportCenterScreen extends StatefulWidget {
  const ReportCenterScreen({super.key});
  @override
  State<ReportCenterScreen> createState() => _ReportCenterScreenState();
}

class _ReportCenterScreenState extends State<ReportCenterScreen> {
  bool _analyzing = false;

  void _open(ReportCategory c) {
    if (c == ReportCategory.waste) {
      context.push(const WasteHubScreen());
    } else if (c == ReportCategory.other) {
      context.push(const ReportFlowScreen(category: ReportCategory.other));
    } else {
      context.push(CategoryHubScreen(category: c));
    }
  }

  /// "Not sure what to choose?" — upload a photo and let AI suggest.
  Future<void> _aiPick() async {
    Evidence? e;
    try {
      e = await MediaService.pickSinglePhoto();
    } catch (_) {
      if (mounted) showToast(context, 'Photo access was denied', kind: ToastKind.error);
      return;
    }
    if (e == null || !mounted) return;
    setState(() => _analyzing = true);
    AiReportAnalysis? a;
    try {
      a = await Services.I.ai.analyzeReportImage(e.bytes!);
    } catch (_) {
      a = null;
    }
    if (!mounted) return;
    setState(() => _analyzing = false);
    if (a == null) {
      showToast(context, 'AI analysis unavailable — choose a category manually', kind: ToastKind.warning);
      context.push(ReportFlowScreen(initialEvidence: [e]));
      return;
    }
    final analysis = a;
    final ev = e;
    final go = await showUeSheet<bool>(context, builder: (ctx) {
      final ue = ctx.ue;
      final a = analysis;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: SizedBox(height: 170, child: EvidenceImage(evidence: ev, category: a.category)),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Icon(Icons.auto_awesome, color: ue.secondary, size: 18),
          const SizedBox(width: 6),
          Text(ctx.t('AI suggestion'), style: AppText.caption(ctx)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          IconTile(icon: a.category.icon, color: a.category.color, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ctx.t(a.subtype ?? a.category.label), style: AppText.h3(ctx)),
              Text('${ctx.t(a.category.label)} · ${(a.confidence * 100).round()}% ${ctx.t('confidence')}', style: AppText.caption(ctx)),
            ]),
          ),
          SeverityBadge(severity: a.suggestedSeverity),
        ]),
        const SizedBox(height: 14),
        Text('"${a.suggestedDescription}"', style: AppText.bodySm(ctx).copyWith(fontStyle: FontStyle.italic)),
        const SizedBox(height: 18),
        UeButton(label: 'Continue with this', icon: Icons.arrow_forward_rounded, trailingIcon: true, onPressed: () => Navigator.pop(ctx, true)),
        const SizedBox(height: 8),
        UeButton(label: 'Choose category myself', variant: ButtonVariant.ghost, onPressed: () => Navigator.pop(ctx, false)),
      ]);
    });
    if (!mounted || go == null) return;
    context.push(ReportFlowScreen(initialEvidence: [ev], initialAnalysis: go ? analysis : null));
  }

  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          children: [
            FadeSlideIn(child: Semantics(header: true, child: Text(context.t('Report an Issue'), style: AppText.h1(context)))),
            const SizedBox(height: 6),
            FadeSlideIn(index: 1, child: Text(context.t('What did you spot? Choose a category to begin.'), style: AppText.bodySm(context))),
            const SizedBox(height: 20),
            FadeSlideIn(
              index: 2,
              child: AppCard(
                onTap: _analyzing ? null : _aiPick,
                gradient: LinearGradient(colors: [ue.secondary.withValues(alpha: 0.14), AppColors.emerald.withValues(alpha: 0.12)]),
                child: Row(children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: ue.surface, borderRadius: BorderRadius.circular(16)),
                    child: _analyzing
                        ? const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2.5))
                        : Icon(Icons.auto_awesome, color: ue.secondary, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(context.t(_analyzing ? 'Analyzing your photo…' : 'Not sure what to choose?'), style: AppText.title(context)),
                      const SizedBox(height: 2),
                      Text(context.t('Upload a photo and our AI will suggest the category.'), style: AppText.caption(context)),
                    ]),
                  ),
                  Icon(Icons.chevron_right_rounded, color: ue.textSubtle),
                ]),
              ),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth > 560 ? 3 : 2;
              final w = (c.maxWidth - (cols - 1) * 12) / cols;
              return Wrap(spacing: 12, runSpacing: 12, children: [
                for (var i = 0; i < ReportCategory.values.length; i++)
                  SizedBox(
                    width: w,
                    height: 150,
                    child: FadeSlideIn(
                      index: 3 + i,
                      child: CategoryCard(category: ReportCategory.values[i], large: true, onTap: () => _open(ReportCategory.values[i])),
                    ),
                  ),
              ]);
            }),
            const SizedBox(height: 16),
            UeButton(
              label: 'Quick report with camera',
              icon: Icons.photo_camera_rounded,
              variant: ButtonVariant.secondary,
              onPressed: () => context.push(const ReportFlowScreen()),
            ),
          ],
        ),
      ),
    );
  }
}

