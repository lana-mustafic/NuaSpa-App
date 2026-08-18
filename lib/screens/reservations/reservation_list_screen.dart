import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api/api_error_messages.dart';
import '../../core/platform/nua_spa_platform.dart';
import '../../providers/auth_provider.dart';
import '../../core/api/services/api_service.dart';
import '../../models/rezervacija.dart';
import 'reservation_create_screen.dart';
import '../../core/payments/stripe_payment_service.dart';
import '../../core/reservations/cancel_rezervacija_messages.dart';
import '../../ui/widgets/page_header.dart';
import '../../ui/widgets/primary_button.dart';
import '../../ui/theme/mobile_spa_theme.dart';
import '../catalog/service_details_screen.dart';

bool _isCompletedReservation(Rezervacija r) =>
    !r.isOtkazana && r.status.toLowerCase() == 'completed';

class ReservationListScreen extends StatefulWidget {
  const ReservationListScreen({super.key});

  @override
  State<ReservationListScreen> createState() => _ReservationListScreenState();
}

class _ReservationListScreenState extends State<ReservationListScreen> {
  final ApiService _apiService = ApiService();
  final StripePaymentService _stripe = StripePaymentService();

  late Future<List<Rezervacija>> _futureReservations;
  final ScrollController _scrollController = ScrollController();
  bool _includeOtkazane = false;

  @override
  void initState() {
    super.initState();
    _futureReservations = _apiService.getRezervacije();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _futureReservations =
          _apiService.getRezervacijeFiltered(includeOtkazane: _includeOtkazane);
    });
  }

  Future<void> _cancelReservation(Rezervacija r) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => _CancelReservationDialog(reservation: r),
    );
    if (reason == null || reason.trim().isEmpty || !mounted) return;

    try {
      final result = await _apiService.cancelRezervacija(
        r.id,
        razlogOtkaza: reason.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result?.otkazana == true
                ? cancelRezervacijaSuccessMessage(result!)
                : 'Cancellation failed.',
          ),
        ),
      );
      if (result?.otkazana == true) _refresh();
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiErrorMessages.fromObject(
              e,
              fallback: 'Cancellation failed.',
            ),
          ),
        ),
      );
    }
  }

  String _statusLabel(Rezervacija r) {
    if (r.isOtkazana) return 'Cancelled';
    if (_isCompletedReservation(r)) return 'Completed';
    if (r.isPotvrdjena) return 'Confirmed';
    return 'Pending';
  }

  Future<void> _openCreateReservation() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => const ReservationCreateScreen(),
      ),
    );
    if (created == true && mounted) _refresh();
  }

  Widget _buildMobile(BuildContext context) {
    final hideFab = context.watch<AuthProvider>().isZaposlenik;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: MobileSpaColors.softWhite,
      appBar: AppBar(
        backgroundColor: MobileSpaColors.softWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: MobileSpaColors.royalPurple,
        title: const Text('My reservations'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: hideFab
          ? null
          : FloatingActionButton.extended(
              onPressed: _openCreateReservation,
              backgroundColor: MobileSpaColors.royalPurple,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Book'),
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'View your bookings, payment status, and actions.',
              style: tt.bodyMedium?.copyWith(
                color: MobileSpaColors.royalPurple.withValues(alpha: 0.65),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                label: const Text('Show cancelled'),
                selected: _includeOtkazane,
                onSelected: (value) {
                  setState(() => _includeOtkazane = value);
                  _refresh();
                },
                selectedColor: MobileSpaColors.royalPurple,
                checkmarkColor: Colors.white,
                labelStyle: tt.labelLarge?.copyWith(
                  color: _includeOtkazane
                      ? Colors.white
                      : MobileSpaColors.royalPurple.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: MobileSpaColors.lavender.withValues(alpha: 0.35),
                side: BorderSide(
                  color: _includeOtkazane
                      ? MobileSpaColors.royalPurple
                      : MobileSpaColors.lavender.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<Rezervacija>>(
              future: _futureReservations,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }

                final data = snapshot.data ?? [];
                if (data.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_busy_outlined,
                            size: 48,
                            color: MobileSpaColors.royalPurple
                                .withValues(alpha: 0.35),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No reservations yet',
                            style: tt.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Book a treatment to see it here.',
                            style: tt.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          if (!hideFab) ...[
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: _openCreateReservation,
                              style: FilledButton.styleFrom(
                                backgroundColor: MobileSpaColors.royalPurple,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Book now'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  color: MobileSpaColors.royalPurple,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    itemCount: data.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final r = data[index];
                      return _MobileReservationCard(
                        reservation: r,
                        statusLabel: _statusLabel(r),
                        hideClientActions: hideFab,
                        onCancel: () => _cancelReservation(r),
                        onReview: () {
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => ServiceDetailsScreen(
                                serviceId: r.uslugaId,
                                initialRezervacijaId: r.id,
                              ),
                            ),
                          );
                        },
                        onPay: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          if (!StripePaymentService.paymentSheetSupported) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Online payment is available on Android and iOS only.',
                                ),
                              ),
                            );
                            return;
                          }
                          final ok = await _stripe.payForReservation(r.id);
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                ok ? 'Payment completed' : 'Payment was not completed.',
                              ),
                            ),
                          );
                          if (ok) _refresh();
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (nuaspaUseMobileShell()) {
      return _buildMobile(context);
    }

    final hideFab = context.watch<AuthProvider>().isZaposlenik;

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 22, 26, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          PageHeader(
            title: 'Moje rezervacije',
            subtitle: 'Pregled vaših rezervacija, statusa i plaćanja.',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Osvježi',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Prikaži otkazane',
                  child: FilterChip(
                    label: const Text('Otkazane'),
                    selected: _includeOtkazane,
                    onSelected: (v) {
                      setState(() => _includeOtkazane = v);
                      _refresh();
                    },
                  ),
                ),
                if (!hideFab) ...[
                  const SizedBox(width: 8),
                  PrimaryButton(
                    label: 'Nova rezervacija',
                    icon: Icons.add,
                    tooltip: 'Kreiraj novu rezervaciju',
                    onPressed: () async {
                      final created = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ReservationCreateScreen(),
                        ),
                      );
                      if (created == true && mounted) _refresh();
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: FutureBuilder<List<Rezervacija>>(
              future: _futureReservations,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data ?? [];
                if (data.isEmpty) {
                  return Center(
                    child: Text(
                      'Trenutno nema rezervacija.',
                      style:
                          TextStyle(color: Colors.white.withValues(alpha: 0.75)),
                    ),
                  );
                }

                return Scrollbar(
                  controller: _scrollController,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    primary: false,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: DataTable(
                        headingRowHeight: 44,
                        dataRowMinHeight: 54,
                        dataRowMaxHeight: 66,
                        columns: const [
                          DataColumn(label: Text('Usluga')),
                          DataColumn(label: Text('Datum & vrijeme')),
                          DataColumn(label: Text('Terapeut')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Plaćanje')),
                          DataColumn(label: Text('Akcije')),
                        ],
                        rows: [
                          for (final r in data)
                            DataRow(
                              onSelectChanged: (_) {},
                              cells: [
                                DataCell(Text(r.uslugaNaziv ?? 'Usluga')),
                                DataCell(Text(
                                  r.datumRezervacije
                                      .toLocal()
                                      .toString()
                                      .split('.')
                                      .first,
                                )),
                                DataCell(Text(r.zaposlenikIme ?? '-')),
                                DataCell(
                                  Chip(
                                    label: Text(
                                      r.isOtkazana
                                          ? 'Otkazana'
                                          : (_isCompletedReservation(r)
                                              ? 'Završena'
                                              : (r.isPotvrdjena
                                                  ? 'Potvrđena'
                                                  : 'Na čekanju')),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (r.isPlacena)
                                        const Text(
                                          'Plaćeno',
                                          style: TextStyle(color: Colors.green),
                                        )
                                      else if (r.isOtkazana)
                                        const Text(
                                          '—',
                                          style: TextStyle(color: Colors.white70),
                                        )
                                      else
                                        SizedBox(
                                          height: 34,
                                          child: Tooltip(
                                            message:
                                                'Plati Online (Stripe, Android/iOS)',
                                            child: FilledButton(
                                            onPressed: () async {
                                              final messenger =
                                                  ScaffoldMessenger.of(context);
                                              if (!StripePaymentService
                                                  .paymentSheetSupported) {
                                                messenger.showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Online plaćanje (Stripe) dostupno je samo na Android i iOS uređajima.',
                                                    ),
                                                  ),
                                                );
                                                return;
                                              }
                                              final ok = await _stripe
                                                  .payForReservation(r.id);
                                              if (!mounted) return;
                                              messenger.showSnackBar(
                                                SnackBar(
                                                  content: Text(ok
                                                      ? 'Plaćeno'
                                                      : 'Plaćanje nije završeno.'),
                                                ),
                                              );
                                              if (ok) _refresh();
                                            },
                                            child: const Text('Plati'),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!hideFab && _isCompletedReservation(r))
                                        Tooltip(
                                          message:
                                              'Ocijeni uslugu nakon završenog termina',
                                          child: IconButton(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      ServiceDetailsScreen(
                                                    serviceId: r.uslugaId,
                                                    initialRezervacijaId: r.id,
                                                  ),
                                                ),
                                              );
                                            },
                                            icon: const Icon(
                                              Icons.rate_review_outlined,
                                            ),
                                          ),
                                        ),
                                      Tooltip(
                                        message: r.isOtkazana
                                            ? 'Već otkazana'
                                            : (_isCompletedReservation(r)
                                                ? 'Završene rezervacije se ne mogu otkazati'
                                                : (r.isPlacena
                                                    ? 'Otkaži i refundiraj plaćenu rezervaciju'
                                                    : 'Otkaži rezervaciju')),
                                        child: IconButton(
                                          onPressed: r.isOtkazana ||
                                                  _isCompletedReservation(r)
                                              ? null
                                              : () => _cancelReservation(r),
                                          icon: const Icon(Icons.cancel_outlined),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          ],
        ),
      ),
    );
  }
}

class _MobileReservationCard extends StatelessWidget {
  const _MobileReservationCard({
    required this.reservation,
    required this.statusLabel,
    required this.hideClientActions,
    required this.onCancel,
    required this.onReview,
    required this.onPay,
  });

  final Rezervacija reservation;
  final String statusLabel;
  final bool hideClientActions;
  final VoidCallback onCancel;
  final VoidCallback onReview;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final r = reservation;
    final when = r.datumRezervacije.toLocal().toString().split('.').first;
    final completed = !r.isOtkazana && r.status.toLowerCase() == 'completed';

    return Material(
      color: Colors.white.withValues(alpha: 0.82),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: MobileSpaColors.lavender.withValues(alpha: 0.35),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    r.uslugaNaziv ?? 'Service',
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                _StatusChip(label: statusLabel, cancelled: r.isOtkazana),
              ],
            ),
            const SizedBox(height: 10),
            _InfoRow(icon: Icons.schedule_rounded, text: when),
            if ((r.zaposlenikIme ?? '').isNotEmpty)
              _InfoRow(icon: Icons.person_outline_rounded, text: r.zaposlenikIme!),
            const SizedBox(height: 12),
            Row(
              children: [
                if (r.isPlacena)
                  Text(
                    'Paid',
                    style: tt.labelLarge?.copyWith(
                      color: const Color(0xFF16A34A),
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else if (!r.isOtkazana)
                  TextButton(
                    onPressed: onPay,
                    child: const Text('Pay online'),
                  ),
                const Spacer(),
                if (!hideClientActions && completed)
                  IconButton(
                    tooltip: 'Leave a review',
                    onPressed: onReview,
                    icon: const Icon(Icons.rate_review_outlined),
                  ),
                IconButton(
                  tooltip: r.isOtkazana
                      ? 'Already cancelled'
                      : (completed
                          ? 'Completed bookings cannot be cancelled'
                          : 'Cancel booking'),
                  onPressed: r.isOtkazana || completed ? null : onCancel,
                  icon: const Icon(Icons.cancel_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.cancelled});

  final String label;
  final bool cancelled;

  @override
  Widget build(BuildContext context) {
    final color = cancelled
        ? const Color(0xFFEC4899)
        : MobileSpaColors.royalPurple;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: MobileSpaColors.royalPurple.withValues(alpha: 0.55),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelReservationDialog extends StatefulWidget {
  const _CancelReservationDialog({required this.reservation});

  final Rezervacija reservation;

  @override
  State<_CancelReservationDialog> createState() =>
      _CancelReservationDialogState();
}

class _CancelReservationDialogState extends State<_CancelReservationDialog> {
  final TextEditingController _reasonCtrl = TextEditingController();
  String? _formError;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reasonCtrl.text.trim();
    if (reason.isEmpty) {
      setState(() => _formError = 'Cancellation reason is required.');
      return;
    }
    Navigator.pop(context, reason);
  }

  @override
  Widget build(BuildContext context) {
    final mobile = nuaspaUseMobileShell();
    final r = widget.reservation;
    final when = r.datumRezervacije.toLocal().toString().split('.').first;

    return AlertDialog(
      backgroundColor: mobile ? MobileSpaColors.softWhite : null,
      title: Text(mobile ? 'Cancel booking?' : 'Otkazati rezervaciju?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(r.uslugaNaziv ?? (mobile ? 'Service' : 'Usluga')),
            const SizedBox(height: 6),
            Text(
              when,
              style: TextStyle(
                color: mobile
                    ? MobileSpaColors.royalPurple.withValues(alpha: 0.65)
                    : Colors.white.withValues(alpha: 0.70),
              ),
            ),
            if (r.isPlacena) ...[
              const SizedBox(height: 10),
              Text(
                mobile
                    ? 'This booking is paid. Cancelling will start a card refund.'
                    : 'Rezervacija je plaćena. Otkazivanje uključuje povrat sredstava na karticu.',
                style: TextStyle(
                  color: mobile
                      ? const Color(0xFFB45309)
                      : Colors.amber.shade200,
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _reasonCtrl,
              maxLength: 400,
              minLines: 2,
              maxLines: 4,
              autofocus: true,
              decoration: InputDecoration(
                labelText: mobile ? 'Reason (required)' : 'Razlog (obavezno)',
                errorText: _formError,
              ),
              onChanged: (_) {
                if (_formError != null) {
                  setState(() => _formError = null);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(mobile ? 'Back' : 'Nazad'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.cancel_outlined),
          label: Text(
            r.isPlacena
                ? (mobile ? 'Cancel & refund' : 'Otkaži i refundiraj')
                : (mobile ? 'Cancel' : 'Otkaži'),
          ),
        ),
      ],
    );
  }
}

