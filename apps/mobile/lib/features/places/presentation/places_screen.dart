import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harvest/app/router.dart';
import 'package:harvest/core/app/current_day.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/confirm_dialog.dart';
import 'package:harvest/core/ui/widgets/empty_state.dart';
import 'package:harvest/core/ui/widgets/text_prompt.dart';
import 'package:harvest/features/places/data/location_gateway.dart';
import 'package:harvest/features/places/data/places_repository.dart';
import 'package:harvest/features/places/domain/place.dart';
import 'package:harvest/features/places/presentation/place_form.dart';
import 'package:harvest/features/places/presentation/places_providers.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// How much of the calendar the map shows at once.
enum PlacesRange { day, week, month }

/// Where I went, and what I did there ([[Places]]): a date strip, the
/// map with the trail and a pin per action, and the day as a timeline.
class PlacesScreen extends ConsumerStatefulWidget {
  const PlacesScreen({this.title, this.tabs, super.key});

  final String? title;
  final PreferredSizeWidget? tabs;

  @override
  ConsumerState<PlacesScreen> createState() => _PlacesScreenState();
}

enum _Menu {
  trail,
  pause1h,
  pauseTomorrow,
  resume,
  accuracy,
  deleteDay,
  deleteAll,
}

class _PlacesScreenState extends ConsumerState<PlacesScreen> {
  HarvestDay? _anchor;
  PlacesRange _range = PlacesRange.day;
  MapLibreMapController? _map;
  var _styleReady = false;

  /// The pin a timeline row or a tap last pointed at.
  String? _selected;

  /// Where I was the last time the phone knew, drawn as the blue dot.
  Fix? _here;

  /// A location link coming in from an entity: the day and the action
  /// whose pin the map should land on.
  ({String table, String uuid})? _pendingFocus;

  /// The style the map was last given. The map widget reloads its style
  /// when this prop changes; the pins go with the old style, so a change
  /// means drawing them again once the new one has loaded.
  String? _style;

  HarvestDay get _day => _anchor ?? ref.read(currentHarvestDayProvider);

  PlacesSpan get _span => switch (_range) {
    PlacesRange.day => (from: _day, to: _day),
    PlacesRange.week => (from: _day.weekStart, to: _day.weekStart.addDays(6)),
    PlacesRange.month => (
      from: HarvestDay.fromDate(DateTime(_day.year, _day.month)),
      to: HarvestDay.fromDate(DateTime(_day.year, _day.month + 1, 0)),
    ),
  };

  @override
  void initState() {
    super.initState();
    // The blue dot is the phone's last known fix, remembered locally —
    // the map never asks the platform engines that the geotags refuse
    // ([[ADR-010-Maps]]).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_seedHere());
      // A location link that opened this screen.
      final focus = ref.read(placesFocusRequestProvider);
      if (focus != null) _claimFocus(focus);
    });
  }

  /// A location link from an entity: land on its day, then on its pin
  /// once that day's geotags arrive. Claimed outside build — the
  /// request is cleared as it is taken, so it never fires twice.
  void _claimFocus(PlacesFocus focus) {
    if (!mounted) return;
    ref.read(placesFocusRequestProvider.notifier).clear();
    setState(() {
      _anchor = focus.day;
      _range = PlacesRange.day;
      _pendingFocus = (table: focus.table, uuid: focus.uuid);
    });
  }

  Future<void> _seedHere() async {
    final fix = await ref.read(locationGatewayProvider).lastKnown();
    if (fix == null || !mounted) return;
    setState(() => _here = fix);
  }

  void _step(int direction) => setState(() {
    _anchor = switch (_range) {
      PlacesRange.day => _day.addDays(direction),
      PlacesRange.week => _day.addDays(7 * direction),
      PlacesRange.month => HarvestDay.fromDate(
        DateTime(_day.year, _day.month + direction),
      ),
    };
  });

  Future<void> _pickDay() async {
    final today = ref.read(currentHarvestDayProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: _day.toDateTime(),
      firstDate: DateTime(2020),
      lastDate: today.toDateTime(),
    );
    if (picked != null) setState(() => _anchor = HarvestDay.fromDate(picked));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final span = _span;
    final trail = ref.watch(trailProvider(span)).value ?? const [];
    final tags = ref.watch(geotagsProvider(span)).value ?? const [];
    final saved = ref.watch(savedPlacesProvider).value ?? const [];
    final state = ref.watch(placesControllerProvider).value;
    final style = ref.watch(placesStyleUrlProvider).value;
    final mapBase = ref.watch(placesMapBaseProvider).value ?? MapBase.streets;
    final pinned = [
      for (final tag in tags)
        if (tag.hasPlace) tag,
    ];
    final stays = staysIn([for (final p in trail) p.fix], places: saved);

    final styleString = placesStyleString(mapBase, streetStyle: style);
    if (style != null && styleString != _style) {
      if (_style != null) {
        _styleReady = false;
        _drawn = '';
      }
      _style = styleString;
    }

    // A link followed while this screen is already open (it stays alive
    // behind the Records tabs).
    ref.listen(placesFocusRequestProvider, (previous, next) {
      if (next == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => _claimFocus(next));
    });
    if (_pendingFocus != null) {
      final pending = _pendingFocus!;
      final match = tags
          .where(
            (tag) =>
                tag.targetTable == pending.table &&
                tag.targetUuid == pending.uuid,
          )
          .firstOrNull;
      if (match != null) {
        _pendingFocus = null;
        final latitude = match.latitude;
        final longitude = match.longitude;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _selected = match.uuid);
          if (latitude != null && longitude != null) {
            unawaited(
              _map?.animateCamera(
                CameraUpdate.newLatLngZoom(LatLng(latitude, longitude), 16),
              ),
            );
          }
        });
      }
    }

    // Redraw whenever what is on the map changes.
    if (_styleReady) {
      unawaited(_draw(trail, pinned, stays, saved, _here));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? l10n.navPlaces),
        bottom: widget.tabs,
        actions: [_menu(l10n, state)],
      ),
      body: Column(
        children: [
          _DateStrip(
            label: _label(context, span),
            range: _range,
            canGoForward:
                span.to.compareTo(
                  ref.watch(currentHarvestDayProvider),
                ) <
                0,
            onRange: (range) => setState(() => _range = range),
            onStep: _step,
            onPick: () => unawaited(_pickDay()),
          ),
          if (state != null) _TrailStatus(state: state, today: span.to),
          Expanded(
            child: Stack(
              children: [
                if (style != null)
                  MapLibreMap(
                    styleString: styleString,
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(36.75, 3.06),
                      zoom: 11,
                    ),
                    onMapCreated: (controller) {
                      _map = controller;
                      controller.onCircleTapped.add(_onPinTapped);
                      controller.onSymbolTapped.add(_onPlaceTapped);
                    },
                    onMapLongClick: (_, coordinates) =>
                        unawaited(_savePlaceAt(coordinates)),
                    onStyleLoadedCallback: () {
                      setState(() => _styleReady = true);
                    },
                    attributionButtonPosition:
                        AttributionButtonPosition.bottomLeft,
                  ),
                Positioned(
                  right: HarvestSpacing.md,
                  bottom: 224,
                  child: Column(
                    children: [
                      _MapButton(
                        tooltip: l10n.placesLocateMe,
                        icon: Icons.my_location,
                        onPressed: () => unawaited(_locateMe()),
                      ),
                      const SizedBox(height: HarvestSpacing.sm),
                      _MapButton(
                        tooltip: l10n.placesLayers,
                        icon: Icons.layers_outlined,
                        onPressed: () => unawaited(_pickMapBase(mapBase)),
                      ),
                    ],
                  ),
                ),
                DraggableScrollableSheet(
                  initialChildSize: 0.3,
                  minChildSize: 0.12,
                  maxChildSize: 0.85,
                  builder: (context, scroll) => _Timeline(
                    scroll: scroll,
                    tags: tags,
                    stays: stays,
                    distanceM: trailMetres([for (final p in trail) p.fix]),
                    selected: _selected,
                    onTag: _focusTag,
                    onStay: _nameStay,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _label(BuildContext context, PlacesSpan span) {
    final locale = localeTag(context);
    return switch (_range) {
      PlacesRange.day => formatDay(context, span.from, weekday: true),
      PlacesRange.week =>
        '${formatDay(context, span.from)} – ${formatDay(context, span.to)}',
      PlacesRange.month => DateFormat.yMMMM(
        locale,
      ).format(span.from.toDateTime()),
    };
  }

  // ------------------------------------------------------------ drawing

  var _drawn = '';

  Future<void> _draw(
    List<TrailPoint> trail,
    List<Geotag> pins,
    List<Stay> stays,
    List<SavedPlace> saved,
    Fix? here,
  ) async {
    final map = _map;
    if (map == null) return;
    // Same data, same picture: rebuilds that change nothing on the map
    // must not flicker it.
    final signature =
        '${trail.length}:${trail.lastOrNull?.uuid}:${pins.length}:'
        '${pins.lastOrNull?.uuid}:${stays.length}:${saved.length}:'
        '${here?.latitude},${here?.longitude}:$_selected';
    if (signature == _drawn) return;
    _drawn = signature;

    final scheme = Theme.of(context).colorScheme;
    await map.clearLines();
    await map.clearCircles();
    await map.clearSymbols();

    if (trail.length > 1) {
      await map.addLine(
        LineOptions(
          geometry: [
            for (final p in trail) LatLng(p.fix.latitude, p.fix.longitude),
          ],
          lineColor: _hex(scheme.primary),
          lineWidth: 4,
          lineOpacity: 0.85,
        ),
      );
    }
    for (final stay in stays) {
      await map.addCircle(
        CircleOptions(
          geometry: LatLng(stay.latitude, stay.longitude),
          circleRadius: 14,
          circleColor: _hex(scheme.tertiary),
          circleOpacity: 0.25,
          circleStrokeColor: _hex(scheme.tertiary),
          circleStrokeWidth: 1,
        ),
      );
    }
    // The places I kept, as red pins with their names — the map's own
    // legend, drawn under everything that happened on a day.
    for (final place in saved) {
      await map.addSymbol(
        SymbolOptions(
          geometry: LatLng(place.latitude, place.longitude),
          textField: place.name,
          textSize: 12.5,
          textColor: '#202124',
          textHaloColor: '#FFFFFF',
          textHaloWidth: 1.5,
          textAnchor: 'top',
          textOffset: const Offset(0, 0.4),
        ),
        {'place': place.uuid},
      );
      await map.addCircle(
        CircleOptions(
          geometry: LatLng(place.latitude, place.longitude),
          circleRadius: 8,
          circleColor: '#EA4335',
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 2,
        ),
        {'place': place.uuid},
      );
    }
    // "You are here": the phone's own last fix, drawn in the Google
    // blue — an accuracy ring, a white border, a solid dot.
    if (here != null) {
      await map.addCircle(
        CircleOptions(
          geometry: LatLng(here.latitude, here.longitude),
          circleRadius: 22,
          circleColor: '#1A73E8',
          circleOpacity: 0.15,
        ),
      );
      await map.addCircle(
        CircleOptions(
          geometry: LatLng(here.latitude, here.longitude),
          circleRadius: 9,
          circleColor: '#1A73E8',
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 3,
        ),
      );
    }
    for (final tag in pins) {
      final color = geotagColor(tag.targetTable, scheme);
      await map.addCircle(
        CircleOptions(
          geometry: LatLng(tag.latitude!, tag.longitude!),
          circleRadius: tag.uuid == _selected ? 9 : 6,
          circleColor: _hex(color),
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 2,
        ),
        {'geotag': tag.uuid},
      );
    }

    final points = [
      for (final p in trail) LatLng(p.fix.latitude, p.fix.longitude),
      for (final tag in pins) LatLng(tag.latitude!, tag.longitude!),
    ];
    if (points.isNotEmpty && _selected == null) {
      await map.animateCamera(_fit(points));
    }
  }

  CameraUpdate _fit(List<LatLng> points) {
    if (points.length == 1) {
      return CameraUpdate.newLatLngZoom(points.single, 15);
    }
    var south = points.first.latitude;
    var north = south;
    var west = points.first.longitude;
    var east = west;
    for (final p in points) {
      south = math.min(south, p.latitude);
      north = math.max(north, p.latitude);
      west = math.min(west, p.longitude);
      east = math.max(east, p.longitude);
    }
    return CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(south, west),
        northeast: LatLng(north, east),
      ),
      left: 48,
      top: 48,
      right: 48,
      bottom: 220,
    );
  }

  void _onPinTapped(Circle circle) {
    final uuid = circle.data?['geotag'] as String?;
    if (uuid != null) {
      setState(() => _selected = uuid);
      return;
    }
    // A saved place's red dot is a circle too; it opens the same card
    // as its name.
    final place = circle.data?['place'] as String?;
    if (place != null) unawaited(_showPlace(place));
  }

  void _onPlaceTapped(Symbol symbol) {
    final uuid = symbol.data?['place'] as String?;
    if (uuid != null) unawaited(_showPlace(uuid));
  }

  /// One saved place, on a card: its name, its note, and what to do
  /// with it — edit, forget, or just look at it a moment.
  Future<void> _showPlace(String uuid) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(placesRepositoryProvider);
    final saved = ref.read(savedPlacesProvider).value ?? const [];
    final place = saved.where((p) => p.uuid == uuid).firstOrNull;
    if (place == null || !mounted) return;
    setState(() => _selected = null);
    await _map?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(place.latitude, place.longitude),
        15,
      ),
    );
    if (!mounted) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => _PlaceCard(place: place),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'edit':
        final draft = await showDialog<PlaceDraft>(
          context: context,
          builder: (_) => PlaceFormDialog(
            title: l10n.placesEditPlace,
            nameHint: l10n.placesNameHint,
            initialName: place.name,
            initialNotes: place.notes ?? '',
            initialRadiusM: place.radiusM,
          ),
        );
        if (draft == null || !mounted) return;
        await repository.updatePlace(
          place.uuid,
          name: draft.name,
          changeName: true,
          notes: draft.notes,
          changeNotes: true,
          radiusM: draft.radiusM,
        );
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.placesPlaceUpdated)),
        );
      case 'forget':
        final ok = await confirm(
          context,
          title: l10n.placesForgetPlace,
          body: l10n.placesForgetPlaceBody,
          confirmLabel: l10n.placesForgetPlace,
        );
        if (ok && mounted) {
          await repository.forgetPlace(place.uuid);
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.placesPlaceForgotten)),
          );
        }
    }
  }

  /// A long press drops a pin here: a name and a note, saved for good.
  Future<void> _savePlaceAt(LatLng coordinates) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final draft = await showDialog<PlaceDraft>(
      context: context,
      builder: (_) => PlaceFormDialog(
        title: l10n.placesSavePlace,
        nameHint: l10n.placesNameHint,
      ),
    );
    if (draft == null || !mounted) return;
    await ref.read(placesRepositoryProvider).savePlace(
      name: draft.name,
      latitude: coordinates.latitude,
      longitude: coordinates.longitude,
      radiusM: draft.radiusM,
      notes: draft.notes,
    );
    messenger.showSnackBar(SnackBar(content: Text(l10n.placesPlaceSaved)));
  }

  /// Centres the map on where I am now, asking for location first if
  /// Places never got the chance to.
  Future<void> _locateMe() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final gateway = ref.read(locationGatewayProvider);
    var access = await gateway.access();
    if (access == LocationAccess.none) {
      access = await gateway.requestWhileInUse();
    }
    if (access == LocationAccess.none || access == LocationAccess.serviceOff) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.placesNoFix)));
      return;
    }
    final fix = await gateway.currentFix() ?? await gateway.lastKnown();
    if (fix == null || !mounted) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.placesNoFix)));
      return;
    }
    setState(() => _here = fix);
    await _map?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(fix.latitude, fix.longitude), 17),
    );
  }

  /// Which view of the map is on: streets or satellite.
  Future<void> _pickMapBase(MapBase current) async {
    final l10n = AppLocalizations.of(context);
    final settings = ref.read(settingsRepositoryProvider);
    final base = await showModalBottomSheet<MapBase>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                l10n.placesLayers,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              dense: true,
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: Text(l10n.placesStreets),
              trailing: current == MapBase.streets
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(context, MapBase.streets),
            ),
            ListTile(
              leading: const Icon(Icons.satellite_alt_outlined),
              title: Text(l10n.placesSatellite),
              trailing: current == MapBase.satellite
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(context, MapBase.satellite),
            ),
          ],
        ),
      ),
    );
    if (base != null && !mounted) return;
    if (base != null) {
      await settings.setString(PlacesKeys.mapBase, base.name);
    }
  }

  void _focusTag(Geotag tag) {
    setState(() => _selected = tag.uuid);
    if (tag.hasPlace) {
      unawaited(
        _map?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(tag.latitude!, tag.longitude!), 16),
        ),
      );
    }
    final route = geotagRoute(tag);
    if (route != null) unawaited(context.push(route));
  }

  Future<void> _nameStay(Stay stay) async {
    final l10n = AppLocalizations.of(context);
    final name = await promptForText(
      context,
      title: l10n.placesNameStay,
      initial: stay.place?.name ?? '',
      hint: l10n.placesNameHint,
    );
    if (name == null || name.trim().isEmpty) return;
    final repository = ref.read(placesRepositoryProvider);
    final existing = stay.place;
    if (existing != null) {
      await repository.renamePlace(existing.uuid, name.trim());
    } else {
      await repository.savePlace(
        name: name.trim(),
        latitude: stay.latitude,
        longitude: stay.longitude,
      );
    }
  }

  // --------------------------------------------------------------- menu

  Widget _menu(
    AppLocalizations l10n,
    TrailState? state,
  ) => PopupMenuButton<_Menu>(
    tooltip: l10n.placesOptions,
    onSelected: (item) => unawaited(_onMenu(item)),
    itemBuilder: (_) => [
      CheckedPopupMenuItem(
        value: _Menu.trail,
        checked: state?.wanted ?? false,
        child: Text(l10n.placesTrailOn),
      ),
      if ((state?.wanted ?? false) && !(state?.paused ?? false)) ...[
        PopupMenuItem(value: _Menu.pause1h, child: Text(l10n.placesPause1h)),
        PopupMenuItem(
          value: _Menu.pauseTomorrow,
          child: Text(l10n.placesPauseTomorrow),
        ),
      ],
      if (state?.paused ?? false)
        PopupMenuItem(value: _Menu.resume, child: Text(l10n.placesResume)),
      CheckedPopupMenuItem(
        value: _Menu.accuracy,
        checked: ref.read(placesHighAccuracyProvider).value ?? false,
        child: Text(l10n.placesHighAccuracy),
      ),
      const PopupMenuDivider(),
      if (_range == PlacesRange.day)
        PopupMenuItem(
          value: _Menu.deleteDay,
          child: Text(l10n.placesDeleteDay),
        ),
      PopupMenuItem(value: _Menu.deleteAll, child: Text(l10n.placesDeleteAll)),
    ],
  );

  Future<void> _onMenu(_Menu item) async {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(placesControllerProvider.notifier);
    final repository = ref.read(placesRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final state = ref.read(placesControllerProvider).value;
    switch (item) {
      case _Menu.trail:
        final on = !(state?.wanted ?? false);
        final access = await controller.setTrail(
          on: on,
          title: l10n.placesNotificationTitle,
          text: l10n.placesNotificationText,
        );
        if (on && access != LocationAccess.always) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(l10n.placesTrailRefused),
              action: SnackBarAction(
                label: l10n.placesOpenSettings,
                onPressed: () =>
                    unawaited(ref.read(locationGatewayProvider).openSettings()),
              ),
            ),
          );
        }
      case _Menu.pause1h:
        await controller.pause(DateTime.now().add(const Duration(hours: 1)));
      case _Menu.pauseTomorrow:
        await controller.pause(
          ref.read(currentHarvestDayProvider).next.startsAt,
        );
      case _Menu.resume:
        await controller.resume();
      case _Menu.accuracy:
        final settings = ref.read(settingsRepositoryProvider);
        final on = ref.read(placesHighAccuracyProvider).value ?? false;
        await settings.setBool(PlacesKeys.highAccuracy, value: !on);
        // The recorder reads the setting when it starts.
        if (state?.running ?? false) {
          await controller.restart();
        }
      case _Menu.deleteDay:
        final day = _day;
        final at = await repository.deleteDay(day);
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.placesDayDeleted),
            action: SnackBarAction(
              label: l10n.undo,
              onPressed: () => unawaited(repository.restoreDay(day, at)),
            ),
          ),
        );
      case _Menu.deleteAll:
        if (!mounted) return;
        final ok = await confirm(
          context,
          title: l10n.placesDeleteAll,
          body: l10n.placesDeleteAllBody,
          confirmLabel: l10n.placesDeleteAll,
        );
        if (ok) await repository.deleteAllHistory();
    }
  }
}

String _hex(Color color) {
  final argb = color.toARGB32();
  return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}

/// A pin's colour, by what the action was.
Color geotagColor(String table, ColorScheme scheme) => switch (table) {
  'expenses' || 'money_txns' || 'debts' || 'debt_payments' => scheme.error,
  'memories' || 'albums' => scheme.tertiary,
  'notes' || 'note_attachments' || 'seed_notes' => scheme.secondary,
  _ => scheme.primary,
};

/// A pin's icon and its name, by what the action was.
({IconData icon, String label}) geotagKind(
  String table,
  AppLocalizations l10n,
) => switch (table) {
  'expenses' => (icon: Icons.payments_outlined, label: l10n.geoExpense),
  'check_ins' => (icon: Icons.eco_outlined, label: l10n.geoCheckIn),
  'memories' => (icon: Icons.photo_camera_outlined, label: l10n.geoPicture),
  'albums' => (icon: Icons.photo_library_outlined, label: l10n.geoAlbum),
  'notes' => (icon: Icons.edit_note, label: l10n.geoNote),
  'note_attachments' => (icon: Icons.mic_none, label: l10n.geoVoice),
  'commitments' => (icon: Icons.spa_outlined, label: l10n.geoSeed),
  'seed_notes' => (icon: Icons.sticky_note_2_outlined, label: l10n.geoSeedNote),
  'money_txns' => (
    icon: Icons.account_balance_wallet_outlined,
    label: l10n.geoMoney,
  ),
  'debts' => (icon: Icons.handshake_outlined, label: l10n.geoDebt),
  'debt_payments' => (
    icon: Icons.handshake_outlined,
    label: l10n.geoDebtPayment,
  ),
  'body_weights' => (
    icon: Icons.monitor_weight_outlined,
    label: l10n.geoWeight,
  ),
  'sleep_sessions' => (icon: Icons.bedtime_outlined, label: l10n.geoNight),
  'workout_sessions' => (icon: Icons.fitness_center, label: l10n.geoSession),
  'goals' => (icon: Icons.flag_outlined, label: l10n.geoGoal),
  'goal_items' => (icon: Icons.checklist, label: l10n.geoGoalItem),
  _ => (icon: Icons.place_outlined, label: table),
};

/// Where tapping a pin goes, for the actions that have a screen.
String? geotagRoute(Geotag tag) => switch (tag.targetTable) {
  'notes' => '${AppRoutes.records}/note/${tag.targetUuid}',
  'commitments' => '${AppRoutes.seed}/${tag.targetUuid}',
  'goals' => '${AppRoutes.goal}/${tag.targetUuid}',
  _ => null,
};

class _DateStrip extends StatelessWidget {
  const _DateStrip({
    required this.label,
    required this.range,
    required this.canGoForward,
    required this.onRange,
    required this.onStep,
    required this.onPick,
  });

  final String label;
  final PlacesRange range;
  final bool canGoForward;
  final ValueChanged<PlacesRange> onRange;
  final ValueChanged<int> onStep;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HarvestSpacing.sm,
        vertical: HarvestSpacing.xs,
      ),
      child: Column(
        children: [
          SegmentedButton<PlacesRange>(
            segments: [
              ButtonSegment(
                value: PlacesRange.day,
                label: Text(l10n.placesDay),
              ),
              ButtonSegment(
                value: PlacesRange.week,
                label: Text(l10n.placesWeek),
              ),
              ButtonSegment(
                value: PlacesRange.month,
                label: Text(l10n.placesMonth),
              ),
            ],
            selected: {range},
            showSelectedIcon: false,
            onSelectionChanged: (s) => onRange(s.first),
          ),
          Row(
            children: [
              IconButton(
                tooltip: l10n.placesPrevious,
                icon: const Icon(Icons.chevron_left),
                onPressed: () => onStep(-1),
              ),
              Expanded(
                child: TextButton(
                  onPressed: onPick,
                  child: Text(label, textAlign: TextAlign.center),
                ),
              ),
              IconButton(
                tooltip: l10n.placesNext,
                icon: const Icon(Icons.chevron_right),
                onPressed: canGoForward ? () => onStep(1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One line on what the trail is doing right now.
class _TrailStatus extends ConsumerWidget {
  const _TrailStatus({required this.state, required this.today});

  final TrailState state;
  final HarvestDay today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final String? text;
    if (state.access == LocationAccess.serviceOff) {
      text = l10n.placesServiceOff;
    } else if (state.paused) {
      text = l10n.placesPausedUntil(
        TimeOfDay.fromDateTime(state.pausedUntil!).format(context),
      );
    } else if (state.running) {
      final count =
          ref
              .watch(pointsOnProvider(ref.watch(currentHarvestDayProvider)))
              .value ??
          0;
      text = l10n.placesRecording(count);
    } else {
      text = null;
    }
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: HarvestSpacing.xs),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The span as a list: stays and actions in the order they happened.
class _Timeline extends ConsumerWidget {
  const _Timeline({
    required this.scroll,
    required this.tags,
    required this.stays,
    required this.distanceM,
    required this.selected,
    required this.onTag,
    required this.onStay,
  });

  final ScrollController scroll;
  final List<Geotag> tags;
  final List<Stay> stays;
  final double distanceM;
  final String? selected;
  final ValueChanged<Geotag> onTag;
  final ValueChanged<Stay> onStay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entries = <({DateTime at, Widget tile})>[
      for (final stay in stays)
        (
          at: stay.from,
          tile: ListTile(
            leading: Icon(Icons.radio_button_checked, color: scheme.tertiary),
            title: Text(
              stay.place?.name ?? l10n.placesStay(_duration(stay.length)),
            ),
            subtitle: Text(
              '${_time(context, stay.from)}–${_time(context, stay.to)}'
              '${stay.place == null ? '' : ' · ${_duration(stay.length)}'}',
            ),
            onTap: () => onStay(stay),
          ),
        ),
      for (final tag in tags)
        (
          at: tag.at,
          tile: _GeotagTile(
            tag: tag,
            selected: tag.uuid == selected,
            onTap: () => onTag(tag),
          ),
        ),
    ]..sort((a, b) => a.at.compareTo(b.at));

    return Material(
      elevation: 3,
      color: scheme.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(HarvestRadii.sheet),
      ),
      child: ListView(
        controller: scroll,
        padding: const EdgeInsets.only(bottom: HarvestSpacing.xl),
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: HarvestSpacing.sm),
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (distanceM > 0)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: HarvestSpacing.md,
              ),
              child: Text(
                l10n.placesDistance((distanceM / 1000).toStringAsFixed(1)),
                style: theme.textTheme.titleSmall,
              ),
            ),
          if (entries.isEmpty)
            EmptyState(
              compact: true,
              icon: Icons.place_outlined,
              title: l10n.placesNothing,
              body: l10n.placesNothingBody,
            )
          else
            for (final entry in entries) entry.tile,
        ],
      ),
    );
  }

  String _time(BuildContext context, DateTime at) =>
      TimeOfDay.fromDateTime(at).format(context);

  String _duration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    return hours == 0 ? '$minutes min' : '$hours h $minutes min';
  }
}

class _GeotagTile extends ConsumerWidget {
  const _GeotagTile({
    required this.tag,
    required this.selected,
    required this.onTap,
  });

  final Geotag tag;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final kind = geotagKind(tag.targetTable, l10n);
    final detail = ref
        .watch(
          geotagDetailProvider((table: tag.targetTable, uuid: tag.targetUuid)),
        )
        .value;
    return ListTile(
      selected: selected,
      leading: Icon(
        kind.icon,
        color: tag.hasPlace
            ? geotagColor(tag.targetTable, scheme)
            : scheme.outline,
      ),
      title: Text(
        detail ?? kind.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${TimeOfDay.fromDateTime(tag.at).format(context)} · ${kind.label}',
      ),
      onTap: onTap,
    );
  }
}

/// A floating map button, in the Google shape: a white card that casts
/// a shadow, with an icon that darkens when touched.
class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 2,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 22),
          ),
        ),
      ),
    );
  }
}

/// One saved place, shown when its pin is tapped: the name, the note
/// it carries, and Edit and Forget.
class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.place});

  final SavedPlace place;

  String _coord(double value) => value.toStringAsFixed(4);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          HarvestSpacing.md,
          HarvestSpacing.xs,
          HarvestSpacing.md,
          HarvestSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: HarvestSpacing.sm),
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.place, color: Color(0xFFEA4335)),
                const SizedBox(width: HarvestSpacing.sm),
                Expanded(
                  child: Text(
                    place.name,
                    style: theme.textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (place.notes case final notes? when notes.isNotEmpty) ...[
              const SizedBox(height: HarvestSpacing.sm),
              Text(notes, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: HarvestSpacing.sm),
            Text(
              '${_coord(place.latitude)}, ${_coord(place.longitude)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: HarvestSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.pop(context, 'forget'),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l10n.placesForgetPlace),
                ),
                const SizedBox(width: HarvestSpacing.sm),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context, 'edit'),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(l10n.placesEditPlace),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
