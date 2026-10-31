import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../services/purchase_service.dart';
import '../../viewmodels/index.dart';

String _formatDate(DateTime d) =>
    '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

/// プレミアムプランのペイウォール（設定画面から遷移）。
/// 「購入を復元」ボタンはApp Store審査上必須のため常に表示する。
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function(AppLocalizations l10n) action) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      await action(l10n);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _purchase() => _run((l10n) async {
        try {
          await ref.read(purchaseSubscriptionProvider)(SubscriptionPlan.monthly);
          _snack(l10n.purchaseSuccessMessage);
        } on PurchaseCanceledException {
          _snack(l10n.purchaseCanceledMessage);
        } on PurchaseUnavailableException catch (e) {
          _snack(e.message);
        } catch (e) {
          _snack(l10n.purchaseFailedMessage('$e'));
        }
      });

  Future<void> _restore() => _run((l10n) async {
        try {
          final restored = await ref.read(restorePurchasesProvider)();
          _snack(restored
              ? l10n.restoreSuccessMessage
              : l10n.restoreNothingMessage);
        } on PurchaseUnavailableException catch (e) {
          _snack(e.message);
        } catch (e) {
          _snack(l10n.purchaseFailedMessage('$e'));
        }
      });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entitlements = ref.watch(userEntitlementsProvider).value;
    final active = entitlements?.isPremiumActive(DateTime.now()) ?? false;
    final product =
        ref.watch(subscriptionProductProvider(SubscriptionPlan.monthly)).value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.paywallTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(l10n.paywallHeadline,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          for (final benefit in [
            l10n.paywallBenefitSupport,
            l10n.paywallBenefitFuture,
          ])
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: Text(benefit),
            ),
          const SizedBox(height: 16),
          if (active)
            Card(
              child: ListTile(
                key: const ValueKey('premium-active'),
                leading: const Icon(Icons.workspace_premium),
                title: Text(l10n.paywallActiveMessage(
                    _formatDate(entitlements!.premiumEndDate!))),
              ),
            )
          else ...[
            Card(
              child: ListTile(
                title: Text(l10n.premiumMonthlyLabel),
                trailing: Text(product?.price ?? l10n.premiumMonthlyFallbackPrice),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('subscribe-button'),
              onPressed: _busy ? null : _purchase,
              child: Text(l10n.subscribeButton),
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            key: const ValueKey('restore-purchases-button'),
            onPressed: _busy ? null : _restore,
            child: Text(l10n.restorePurchasesButton),
          ),
          const SizedBox(height: 16),
          Text(l10n.paywallLegalNote,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
