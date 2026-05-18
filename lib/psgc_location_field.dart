import 'package:flutter/material.dart';

import 'psgc_service.dart';

class PsgcLocationValue {
  final PsgcLocation? region;
  final PsgcLocation? province;
  final PsgcLocation? city;
  final PsgcLocation? barangay;

  const PsgcLocationValue({
    this.region,
    this.province,
    this.city,
    this.barangay,
  });
}

/// Cascading Region → Province → City → Barangay picker backed by the PSGC
/// API. Each level is fetched lazily the first time the user opens it (and
/// cached in [PsgcService] thereafter).
class PsgcLocationField extends StatefulWidget {
  final String? initialProvinceName;
  final String? initialCityName;
  final String? initialBarangayName;
  final ValueChanged<PsgcLocationValue> onChanged;

  const PsgcLocationField({
    super.key,
    this.initialProvinceName,
    this.initialCityName,
    this.initialBarangayName,
    required this.onChanged,
  });

  @override
  State<PsgcLocationField> createState() => _PsgcLocationFieldState();
}

class _PsgcLocationFieldState extends State<PsgcLocationField> {
  PsgcLocation? _region;
  PsgcLocation? _province;
  PsgcLocation? _city;
  PsgcLocation? _barangay;

  bool _bootstrapped = false;
  bool _loadingRegions = false;
  bool _loadingProvinces = false;
  bool _loadingCities = false;
  bool _loadingBarangays = false;
  String? _error;

  // True when NCR is selected (no provinces). Cities are loaded by region.
  bool get _provinceSkipped =>
      _region != null && _region!.code.startsWith('13');

  @override
  void initState() {
    super.initState();
    _initialFetch();
  }

  @override
  void didUpdateWidget(PsgcLocationField old) {
    super.didUpdateWidget(old);
    if (!_bootstrapped) return;

    final newProv = widget.initialProvinceName?.trim() ?? '';
    final newCity = widget.initialCityName?.trim() ?? '';
    final newBrgy = widget.initialBarangayName?.trim() ?? '';

    // Treat empty incoming values as "no signal" rather than "clear" — this
    // way our own onChanged callbacks (which may write '' for unset levels)
    // never wipe out the user's selections.
    final hasSignal =
        newProv.isNotEmpty || newCity.isNotEmpty || newBrgy.isNotEmpty;
    if (!hasSignal) return;

    final currProv = _province?.name ?? _region?.name ?? '';
    final currCity = _city?.name ?? '';
    final currBrgy = _barangay?.name ?? '';

    final diverged = (newProv.isNotEmpty && newProv != currProv) ||
        (newCity.isNotEmpty && newCity != currCity) ||
        (newBrgy.isNotEmpty && newBrgy != currBrgy);
    if (!diverged) return;

    _bootstrapped = false;
    _initialFetch();
  }

  Future<void> _initialFetch() async {
    if (mounted) setState(() => _loadingRegions = true);
    try {
      await PsgcService.fetchRegions();

      final hasInitial = (widget.initialProvinceName?.trim().isNotEmpty ??
              false) ||
          (widget.initialCityName?.trim().isNotEmpty ?? false) ||
          (widget.initialBarangayName?.trim().isNotEmpty ?? false);

      if (hasInitial) {
        final ws = await PsgcService.warmStart(
          provinceName: widget.initialProvinceName,
          cityName: widget.initialCityName,
          barangayName: widget.initialBarangayName,
        );
        if (!mounted) return;
        // Only overwrite the levels warm-start actually matched. Keeps the
        // user's existing selections when the incoming values come from a
        // source (e.g. Google geocoder) whose strings don't line up with
        // PSGC names.
        setState(() {
          if (ws.region != null) _region = ws.region;
          if (ws.province != null) {
            _province = ws.province;
          } else if (ws.region != null) {
            _province = null;
          }
          if (ws.city != null) {
            _city = ws.city;
          } else if (ws.region != null) {
            _city = null;
          }
          if (ws.barangay != null) {
            _barangay = ws.barangay;
          } else if (ws.city != null) {
            _barangay = null;
          }
        });
        _emit();
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load locations');
    } finally {
      if (mounted) {
        setState(() {
          _loadingRegions = false;
          _bootstrapped = true;
        });
      }
    }
  }

  void _emit() {
    widget.onChanged(PsgcLocationValue(
      region: _region,
      province: _province,
      city: _city,
      barangay: _barangay,
    ));
  }

  Future<void> _pickRegion() async {
    setState(() => _loadingRegions = true);
    final regions = await _safeFetch(PsgcService.fetchRegions);
    if (!mounted) return;
    setState(() => _loadingRegions = false);
    if (regions == null) return;

    final picked = await _showPicker(title: 'Select Region', items: regions);
    if (picked == null || picked == _region) return;
    setState(() {
      _region = picked;
      _province = null;
      _city = null;
      _barangay = null;
    });
    _emit();
  }

  Future<void> _pickProvince() async {
    if (_region == null) return;
    if (_provinceSkipped) {
      // NCR: jump straight to city picker.
      _pickCity();
      return;
    }
    setState(() => _loadingProvinces = true);
    final provs = await _safeFetch(
        () => PsgcService.fetchProvincesByRegion(_region!.code));
    if (!mounted) return;
    setState(() => _loadingProvinces = false);
    if (provs == null) return;

    final picked =
        await _showPicker(title: 'Select Province', items: provs);
    if (picked == null || picked == _province) return;
    setState(() {
      _province = picked;
      _city = null;
      _barangay = null;
    });
    _emit();
  }

  Future<void> _pickCity() async {
    if (_region == null) return;
    if (!_provinceSkipped && _province == null) return;
    setState(() => _loadingCities = true);
    final cities = await _safeFetch(() {
      if (_province != null) {
        return PsgcService.fetchCitiesByProvince(_province!.code);
      }
      return PsgcService.fetchCitiesByRegion(_region!.code);
    });
    if (!mounted) return;
    setState(() => _loadingCities = false);
    if (cities == null) return;

    final picked = await _showPicker(
        title: 'Select City / Municipality', items: cities);
    if (picked == null || picked == _city) return;
    setState(() {
      _city = picked;
      _barangay = null;
    });
    _emit();
  }

  Future<void> _pickBarangay() async {
    if (_city == null) return;
    setState(() => _loadingBarangays = true);
    final brgys =
        await _safeFetch(() => PsgcService.fetchBarangays(_city!.code));
    if (!mounted) return;
    setState(() => _loadingBarangays = false);
    if (brgys == null) return;

    final picked = await _showPicker(title: 'Select Barangay', items: brgys);
    if (picked == null || picked == _barangay) return;
    setState(() => _barangay = picked);
    _emit();
  }

  Future<List<PsgcLocation>?> _safeFetch(
      Future<List<PsgcLocation>> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not load list');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load locations. Check your connection.'),
          ),
        );
      }
      return null;
    }
  }

  Future<PsgcLocation?> _showPicker({
    required String title,
    required List<PsgcLocation> items,
  }) {
    return showModalBottomSheet<PsgcLocation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _PsgcPickerSheet(title: title, items: items),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provinceLabel = _provinceSkipped
        ? 'Province (Not applicable for NCR)'
        : 'Province';
    final provincePlaceholder = _region == null
        ? 'Select region first'
        : (_provinceSkipped
            ? 'Skipped — NCR has no provinces'
            : 'Select province');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row(
          label: 'Region',
          value: _region?.name,
          placeholder: 'Select region',
          loading: _loadingRegions && !_bootstrapped,
          enabled: !_loadingRegions,
          onTap: _loadingRegions ? null : _pickRegion,
        ),
        const SizedBox(height: 10),
        _row(
          label: provinceLabel,
          value: _province?.name,
          placeholder: provincePlaceholder,
          loading: _loadingProvinces,
          enabled: _region != null && !_provinceSkipped,
          onTap: _region == null || _loadingProvinces || _provinceSkipped
              ? null
              : _pickProvince,
        ),
        const SizedBox(height: 10),
        _row(
          label: 'City / Municipality',
          value: _city?.name,
          placeholder: _region == null
              ? 'Select region first'
              : (!_provinceSkipped && _province == null
                  ? 'Select province first'
                  : 'Select city / municipality'),
          loading: _loadingCities,
          enabled: _region != null &&
              (_provinceSkipped || _province != null) &&
              !_loadingCities,
          onTap: (_region == null ||
                  (!_provinceSkipped && _province == null) ||
                  _loadingCities)
              ? null
              : _pickCity,
        ),
        const SizedBox(height: 10),
        _row(
          label: 'Barangay',
          value: _barangay?.name,
          placeholder:
              _city == null ? 'Select city first' : 'Select barangay',
          loading: _loadingBarangays,
          enabled: _city != null && !_loadingBarangays,
          onTap:
              _city == null || _loadingBarangays ? null : _pickBarangay,
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!,
              style: TextStyle(color: Colors.red[700], fontSize: 12)),
        ],
      ],
    );
  }

  Widget _row({
    required String label,
    required String? value,
    required String placeholder,
    required bool loading,
    required bool enabled,
    VoidCallback? onTap,
  }) {
    final hasValue = value != null && value.isNotEmpty;
    final display = hasValue ? value : placeholder;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: enabled ? Colors.white : const Color(0xFFF6F6F6),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFDEDEDE)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      display,
                      style: TextStyle(
                        fontSize: 13,
                        color: hasValue
                            ? const Color(0xFF333333)
                            : const Color(0xFFAAAAAA),
                        fontWeight:
                            hasValue ? FontWeight.w500 : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  Icons.expand_more,
                  size: 22,
                  color: enabled ? Colors.black54 : Colors.grey[400],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PsgcPickerSheet extends StatefulWidget {
  final String title;
  final List<PsgcLocation> items;

  const _PsgcPickerSheet({required this.title, required this.items});

  @override
  State<_PsgcPickerSheet> createState() => _PsgcPickerSheetState();
}

class _PsgcPickerSheetState extends State<_PsgcPickerSheet> {
  String _query = '';
  late List<PsgcLocation> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
  }

  void _onQueryChanged(String v) {
    setState(() {
      _query = v;
      final q = v.toLowerCase().trim();
      if (q.isEmpty) {
        _filtered = widget.items;
      } else {
        _filtered = widget.items
            .where((e) => e.name.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.75;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  onChanged: _onQueryChanged,
                  decoration: InputDecoration(
                    hintText: 'Search…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: _filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _query.isEmpty
                              ? 'No options available'
                              : 'No matches for "$_query"',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final item = _filtered[i];
                          return ListTile(
                            dense: true,
                            visualDensity:
                                const VisualDensity(vertical: -2),
                            title: Text(
                              item.name,
                              style: const TextStyle(fontSize: 14),
                            ),
                            onTap: () => Navigator.pop(ctx, item),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
