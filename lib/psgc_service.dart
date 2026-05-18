import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

class PsgcLocation {
  final String code;
  final String name;

  const PsgcLocation({required this.code, required this.name});

  @override
  bool operator ==(Object other) =>
      other is PsgcLocation && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

class PsgcWarmStart {
  final PsgcLocation? region;
  final PsgcLocation? province;
  final PsgcLocation? city;
  final PsgcLocation? barangay;

  const PsgcWarmStart({this.region, this.province, this.city, this.barangay});
}

class _Province {
  final PsgcLocation loc;
  final String regionCode;
  const _Province(this.loc, this.regionCode);
}

class _City {
  final PsgcLocation loc;
  final String regionCode;
  final String? provinceCode;
  const _City(this.loc, this.regionCode, this.provinceCode);
}

class _Barangay {
  final PsgcLocation loc;
  // Either cityCode or municipalityCode in the source data — whichever
  // is set is the barangay's direct parent.
  final String parentCode;
  const _Barangay(this.loc, this.parentCode);
}

// ──────────────────────────────────────────────────────────────────
// compute() entrypoints — must be top-level for isolate dispatch.
// They keep JSON parsing (especially the ~11 MB barangays file) off
// the UI thread.
// ──────────────────────────────────────────────────────────────────

List<List<String>> _parseRegions(String raw) {
  final data = json.decode(raw) as List;
  final out = <List<String>>[];
  for (final e in data) {
    final m = e as Map<String, dynamic>;
    out.add([m['code']?.toString() ?? '', m['name']?.toString() ?? '']);
  }
  return out;
}

List<List<String>> _parseProvinces(String raw) {
  final data = json.decode(raw) as List;
  final out = <List<String>>[];
  for (final e in data) {
    final m = e as Map<String, dynamic>;
    out.add([
      m['code']?.toString() ?? '',
      m['name']?.toString() ?? '',
      m['regionCode']?.toString() ?? '',
    ]);
  }
  return out;
}

List<List<String>> _parseCities(String raw) {
  final data = json.decode(raw) as List;
  final out = <List<String>>[];
  for (final e in data) {
    final m = e as Map<String, dynamic>;
    final pc = m['provinceCode'];
    out.add([
      m['code']?.toString() ?? '',
      m['name']?.toString() ?? '',
      m['regionCode']?.toString() ?? '',
      // PSGC API encodes "no parent" as boolean false. Normalise to ''.
      (pc == null || pc == false) ? '' : pc.toString(),
    ]);
  }
  return out;
}

List<List<String>> _parseBarangays(String raw) {
  final data = json.decode(raw) as List;
  final out = <List<String>>[];
  for (final e in data) {
    final m = e as Map<String, dynamic>;
    final cc = m['cityCode'];
    final mc = m['municipalityCode'];
    final parent = (cc != null && cc != false)
        ? cc.toString()
        : (mc != null && mc != false ? mc.toString() : '');
    out.add([
      m['code']?.toString() ?? '',
      m['name']?.toString() ?? '',
      parent,
    ]);
  }
  return out;
}

/// Reads the bundled PSGC dataset (regions, provinces, cities, barangays)
/// from `assets/psgc/` and exposes lazy, cached lookups for the cascading
/// location picker. No network is involved — everything ships with the app.
class PsgcService {
  static const String _dir = 'assets/psgc';

  static List<PsgcLocation>? _regions;
  static List<_Province>? _provinces;
  static List<_City>? _cities;
  static List<_Barangay>? _barangays;

  static Future<List<PsgcLocation>>? _regionsLoading;
  static Future<List<_Province>>? _provincesLoading;
  static Future<List<_City>>? _citiesLoading;
  static Future<List<_Barangay>>? _barangaysLoading;

  // ── public lookups ────────────────────────────────────────────

  static Future<List<PsgcLocation>> fetchRegions() => _ensureRegions();

  static Future<List<PsgcLocation>> fetchProvincesByRegion(
      String regionCode) async {
    final all = await _ensureProvinces();
    return all
        .where((p) => p.regionCode == regionCode)
        .map((p) => p.loc)
        .toList();
  }

  static Future<List<PsgcLocation>> fetchAllProvinces() async {
    final all = await _ensureProvinces();
    return all.map((p) => p.loc).toList();
  }

  static Future<List<PsgcLocation>> fetchCitiesByRegion(
      String regionCode) async {
    final all = await _ensureCities();
    return all
        .where((c) => c.regionCode == regionCode)
        .map((c) => c.loc)
        .toList();
  }

  static Future<List<PsgcLocation>> fetchCitiesByProvince(
      String provinceCode) async {
    final all = await _ensureCities();
    return all
        .where((c) => c.provinceCode == provinceCode)
        .map((c) => c.loc)
        .toList();
  }

  static Future<List<PsgcLocation>> fetchBarangays(String cityCode) async {
    final all = await _ensureBarangays();
    return all
        .where((b) => b.parentCode == cityCode)
        .map((b) => b.loc)
        .toList();
  }

  /// Best-effort: given saved province / city / barangay strings, resolve them
  /// back into PSGC entries so the cascade can be pre-selected on edit.
  /// Never throws.
  static Future<PsgcWarmStart> warmStart({
    String? provinceName,
    String? cityName,
    String? barangayName,
  }) async {
    PsgcLocation? region;
    PsgcLocation? province;
    PsgcLocation? city;
    PsgcLocation? barangay;

    try {
      final regions = await _ensureRegions();
      final pn = provinceName?.trim() ?? '';
      final cn = cityName?.trim() ?? '';
      final bn = barangayName?.trim() ?? '';

      _Province? provRec;
      if (pn.isNotEmpty) {
        final allProv = await _ensureProvinces();
        provRec = _findLoose(allProv, pn, (p) => p.loc.name);
        if (provRec != null) {
          province = provRec.loc;
          region = regions.cast<PsgcLocation?>().firstWhere(
                (r) => r?.code == provRec!.regionCode,
                orElse: () => null,
              );
        }
      }

      // NCR fallback: derive region from city (NCR has no provinces) or
      // from a province slot that contains an NCR alias like "Metro Manila".
      if (region == null) {
        final ncrAliases = <String>{
          'metro manila',
          'national capital region',
          'ncr',
          'national capital region (ncr)',
        };
        final pnNorm = _norm(pn);
        if (ncrAliases.contains(pnNorm)) {
          region = regions.cast<PsgcLocation?>().firstWhere(
                (r) => r?.code.startsWith('13') ?? false,
                orElse: () => null,
              );
        }
      }
      if (region == null && cn.isNotEmpty) {
        final allCities = await _ensureCities();
        final ncrCandidates = allCities
            .where((c) => c.regionCode.startsWith('13'))
            .toList();
        final found = _findLoose(ncrCandidates, cn, (c) => c.loc.name);
        if (found != null) {
          city = found.loc;
          region = regions.cast<PsgcLocation?>().firstWhere(
                (r) => r?.code == found.regionCode,
                orElse: () => null,
              );
        }
      }

      if (region != null && city == null && cn.isNotEmpty) {
        final allCities = await _ensureCities();
        final candidates = provRec != null
            ? allCities
                .where((c) => c.provinceCode == provRec!.loc.code)
                .toList()
            : allCities
                .where((c) => c.regionCode == region!.code)
                .toList();
        final match = _findLoose(candidates, cn, (c) => c.loc.name);
        if (match != null) city = match.loc;
      }

      if (city != null && bn.isNotEmpty) {
        final all = await _ensureBarangays();
        final candidates =
            all.where((b) => b.parentCode == city!.code).toList();
        final match = _findLoose(candidates, bn, (b) => b.loc.name);
        if (match != null) barangay = match.loc;
      }
    } catch (e) {
      debugPrint('PsgcService.warmStart failed: $e');
    }

    return PsgcWarmStart(
      region: region,
      province: province,
      city: city,
      barangay: barangay,
    );
  }

  // ── lazy loaders (singleton, in-flight de-duped) ──────────────

  static Future<List<PsgcLocation>> _ensureRegions() async {
    final cached = _regions;
    if (cached != null) return cached;
    final inflight = _regionsLoading;
    if (inflight != null) return inflight;
    final fut = _loadRegions();
    _regionsLoading = fut;
    try {
      _regions = await fut;
      return _regions!;
    } finally {
      _regionsLoading = null;
    }
  }

  static Future<List<_Province>> _ensureProvinces() async {
    final cached = _provinces;
    if (cached != null) return cached;
    final inflight = _provincesLoading;
    if (inflight != null) return inflight;
    final fut = _loadProvinces();
    _provincesLoading = fut;
    try {
      _provinces = await fut;
      return _provinces!;
    } finally {
      _provincesLoading = null;
    }
  }

  static Future<List<_City>> _ensureCities() async {
    final cached = _cities;
    if (cached != null) return cached;
    final inflight = _citiesLoading;
    if (inflight != null) return inflight;
    final fut = _loadCities();
    _citiesLoading = fut;
    try {
      _cities = await fut;
      return _cities!;
    } finally {
      _citiesLoading = null;
    }
  }

  static Future<List<_Barangay>> _ensureBarangays() async {
    final cached = _barangays;
    if (cached != null) return cached;
    final inflight = _barangaysLoading;
    if (inflight != null) return inflight;
    final fut = _loadBarangays();
    _barangaysLoading = fut;
    try {
      _barangays = await fut;
      return _barangays!;
    } finally {
      _barangaysLoading = null;
    }
  }

  static Future<List<PsgcLocation>> _loadRegions() async {
    final raw = await rootBundle.loadString('$_dir/regions.json');
    final rows = await compute(_parseRegions, raw);
    final list = rows
        .map((r) => PsgcLocation(code: r[0], name: r[1]))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  static Future<List<_Province>> _loadProvinces() async {
    final raw = await rootBundle.loadString('$_dir/provinces.json');
    final rows = await compute(_parseProvinces, raw);
    final list = rows
        .map((r) => _Province(PsgcLocation(code: r[0], name: r[1]), r[2]))
        .toList()
      ..sort((a, b) => a.loc.name.compareTo(b.loc.name));
    return list;
  }

  static Future<List<_City>> _loadCities() async {
    final raw = await rootBundle.loadString('$_dir/cities.json');
    final rows = await compute(_parseCities, raw);
    final list = rows
        .map((r) => _City(
              PsgcLocation(code: r[0], name: r[1]),
              r[2],
              r[3].isEmpty ? null : r[3],
            ))
        .toList()
      ..sort((a, b) => a.loc.name.compareTo(b.loc.name));
    return list;
  }

  static Future<List<_Barangay>> _loadBarangays() async {
    final raw = await rootBundle.loadString('$_dir/barangays.json');
    final rows = await compute(_parseBarangays, raw);
    final list = rows
        .map((r) => _Barangay(PsgcLocation(code: r[0], name: r[1]), r[2]))
        .toList()
      ..sort((a, b) => a.loc.name.compareTo(b.loc.name));
    return list;
  }

  // ── string matching ──────────────────────────────────────────

  static T? _findLoose<T>(
      List<T> list, String name, String Function(T) nameOf) {
    final n = _norm(name);
    if (n.isEmpty) return null;
    for (final item in list) {
      if (_norm(nameOf(item)) == n) return item;
    }
    for (final item in list) {
      final nn = _norm(nameOf(item));
      if (nn.contains(n) || n.contains(nn)) return item;
    }
    return null;
  }

  static String _norm(String s) {
    var v = s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
    v = v
        .replaceAll('city of ', '')
        .replaceAll(' city', '')
        .replaceAll('barangay ', '')
        .replaceAll('brgy. ', '')
        .replaceAll('brgy ', '');
    return v.trim();
  }
}
