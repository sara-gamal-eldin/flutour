// lib/route_service.dart — OSRM routing + Nominatim geocoding (no API keys required)
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final int durationSeconds;

  RouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationSeconds,
  });
}

class RouteService {
  /// Last successfully fetched route — reused instantly by the active ride screen
  static RouteResult? lastResult;

  static Future<RouteResult?> fetchRoute(LatLng from, LatLng to) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving'
        '/${from.longitude},${from.latitude}'
        ';${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if ((json['code'] as String?) != 'Ok') return null;
      final routes = json['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;
      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>;
      final coords = (geometry['coordinates'] as List)
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      if (coords.length < 2) return null;
      final distKm = (route['distance'] as num).toDouble() / 1000;
      final durSec = (route['duration'] as num).toInt();
      final result = RouteResult(points: coords, distanceKm: distKm, durationSeconds: durSec);
      lastResult = result;
      return result;
    } catch (_) {
      return null;
    }
  }

  static String etaLabel(int seconds) {
    if (seconds < 60) return '$seconds s';
    final mins = seconds ~/ 60;
    if (mins < 60) return '$mins min';
    return '${mins ~/ 60}h ${mins % 60}min';
  }
}

// ===== GEOCODING =====
class GeoSuggestion {
  final String name;
  final LatLng location;
  GeoSuggestion({required this.name, required this.location});
}

class GeocodingService {

  // ── Curated Luxor-area landmarks for instant offline matching ──────────────
  // Shown as popular places when no query is typed, and matched instantly
  // when the query matches part of a name or its Arabic equivalent.
  static final List<GeoSuggestion> popularPlaces = [
    // Tourist sites — East Bank
    GeoSuggestion(name: 'Luxor Temple',              location: LatLng(25.6987, 32.6390)),
    GeoSuggestion(name: 'Karnak Temple',              location: LatLng(25.7188, 32.6571)),
    GeoSuggestion(name: 'Luxor Museum',               location: LatLng(25.7010, 32.6390)),
    GeoSuggestion(name: 'Mummification Museum',       location: LatLng(25.6993, 32.6388)),
    // Tourist sites — West Bank
    GeoSuggestion(name: 'Valley of the Kings',        location: LatLng(25.7402, 32.6014)),
    GeoSuggestion(name: 'Hatshepsut Temple',          location: LatLng(25.7379, 32.6073)),
    GeoSuggestion(name: 'Colossi of Memnon',          location: LatLng(25.7205, 32.6099)),
    GeoSuggestion(name: 'Medinet Habu',               location: LatLng(25.7192, 32.5999)),
    GeoSuggestion(name: 'Ramesseum',                  location: LatLng(25.7291, 32.6076)),
    GeoSuggestion(name: 'Deir el-Medina',             location: LatLng(25.7308, 32.6024)),
    GeoSuggestion(name: 'Valley of the Queens',       location: LatLng(25.7264, 32.5984)),
    GeoSuggestion(name: 'Tomb of Nefertari',          location: LatLng(25.7264, 32.5984)),
    // Transport
    GeoSuggestion(name: 'Luxor Airport',              location: LatLng(25.6710, 32.7061)),
    GeoSuggestion(name: 'Luxor Train Station',        location: LatLng(25.6957, 32.6398)),
    GeoSuggestion(name: 'Luxor Bus Station',          location: LatLng(25.6946, 32.6412)),
    GeoSuggestion(name: 'West Bank Ferry Landing',    location: LatLng(25.6972, 32.6356)),
    GeoSuggestion(name: 'Luxor Bridge',               location: LatLng(25.6836, 32.6534)),
    // Landmarks / areas
    GeoSuggestion(name: 'Nile Corniche',              location: LatLng(25.6872, 32.6370)),
    GeoSuggestion(name: 'Luxor Souk (Bazaar)',        location: LatLng(25.6976, 32.6415)),
    GeoSuggestion(name: 'Karnak Village',             location: LatLng(25.7210, 32.6610)),
    GeoSuggestion(name: 'Al-Awamiya District',        location: LatLng(25.7050, 32.6480)),
    // Hotels
    GeoSuggestion(name: 'Winter Palace Hotel',        location: LatLng(25.6938, 32.6393)),
    GeoSuggestion(name: 'Hilton Luxor Hotel',         location: LatLng(25.6985, 32.6405)),
    GeoSuggestion(name: 'Steigenberger Nile Palace',  location: LatLng(25.6977, 32.6386)),
    GeoSuggestion(name: 'Sonesta St. George Hotel',   location: LatLng(25.6960, 32.6390)),
    GeoSuggestion(name: 'Ibis Luxor Hotel',           location: LatLng(25.6946, 32.6400)),
    GeoSuggestion(name: 'Maritim Jolie Ville Luxor',  location: LatLng(25.7002, 32.6214)),
    GeoSuggestion(name: 'Mercure Luxor Karnak',       location: LatLng(25.7158, 32.6549)),
    // Services
    GeoSuggestion(name: 'Luxor International Hospital', location: LatLng(25.6889, 32.6371)),
    // Nearby cities
    GeoSuggestion(name: 'Esna',                       location: LatLng(25.2939, 32.5539)),
    GeoSuggestion(name: 'Edfu',                       location: LatLng(24.9779, 32.8734)),
    GeoSuggestion(name: 'Qena',                       location: LatLng(26.1638, 32.7246)),
    GeoSuggestion(name: 'Aswan',                      location: LatLng(24.0889, 32.8998)),
  ];

  // Arabic ↔ index in popularPlaces (for matching Arabic-language queries)
  static const _arabicMap = <String, int>{
    'معبد الأقصر': 0,
    'الكرنك': 1,
    'متحف الأقصر': 2,
    'متحف التحنيط': 3,
    'وادي الملوك': 4,
    'معبد حتشبسوت': 5,
    'تمثالي ممنون': 6,
    'مدينة هابو': 7,
    'الرامسيوم': 8,
    'دير المدينة': 9,
    'وادي الملكات': 10,
    'مقبرة نفرتاري': 11,
    'مطار الأقصر': 12,
    'محطة قطار الأقصر': 13,
    'موقف أتوبيس الأقصر': 14,
    'معدية الضفة الغربية': 15,
    'كوبري الأقصر': 16,
    'الكورنيش': 17,
    'سوق الأقصر': 18,
    'قرية الكرنك': 19,
    'فندق وينتر بالاس': 21,
    'فندق هيلتون الأقصر': 22,
    'مستشفى الأقصر الدولي': 28,
    'أسنا': 29,
    'إدفو': 30,
    'قنا': 31,
    'أسوان': 32,
  };

  // ── Category keyword → OSM tag filter (Overpass) ─────────────────────────
  // Supports English and Arabic category queries.
  static const _categoryTags = <String, String>{
    // Accommodation
    'hotel':          '"tourism"="hotel"',
    'hotels':         '"tourism"="hotel"',
    'فندق':           '"tourism"="hotel"',
    'فنادق':          '"tourism"="hotel"',
    'hostel':         '"tourism"="hostel"',
    'resort':         '"tourism"="resort"',
    'منتجع':          '"tourism"="resort"',
    // Food & drink
    'restaurant':     '"amenity"="restaurant"',
    'restaurants':    '"amenity"="restaurant"',
    'مطعم':           '"amenity"="restaurant"',
    'مطاعم':          '"amenity"="restaurant"',
    'cafe':           '"amenity"="cafe"',
    'coffee':         '"amenity"="cafe"',
    'كافيه':          '"amenity"="cafe"',
    'مقهى':           '"amenity"="cafe"',
    'fast food':      '"amenity"="fast_food"',
    'وجبات سريعة':    '"amenity"="fast_food"',
    // Health
    'pharmacy':       '"amenity"="pharmacy"',
    'pharmacies':     '"amenity"="pharmacy"',
    'صيدلية':         '"amenity"="pharmacy"',
    'صيدليات':        '"amenity"="pharmacy"',
    'hospital':       '"amenity"="hospital"',
    'hospitals':      '"amenity"="hospital"',
    'مستشفى':         '"amenity"="hospital"',
    'clinic':         '"amenity"="clinic"',
    'عيادة':          '"amenity"="clinic"',
    // Finance
    'bank':           '"amenity"="bank"',
    'banks':          '"amenity"="bank"',
    'بنك':            '"amenity"="bank"',
    'بنوك':           '"amenity"="bank"',
    'atm':            '"amenity"="atm"',
    'صراف':           '"amenity"="atm"',
    // Shopping
    'supermarket':    '"shop"="supermarket"',
    'سوبرماركت':      '"shop"="supermarket"',
    'market':         '"amenity"="marketplace"',
    'bazaar':         '"amenity"="marketplace"',
    'سوق':            '"amenity"="marketplace"',
    // Worship
    'mosque':         '"amenity"="place_of_worship"]["religion"="muslim"',
    'مسجد':           '"amenity"="place_of_worship"]["religion"="muslim"',
    'مساجد':          '"amenity"="place_of_worship"]["religion"="muslim"',
    'church':         '"amenity"="place_of_worship"]["religion"="christian"',
    'كنيسة':          '"amenity"="place_of_worship"]["religion"="christian"',
    // Other
    'school':         '"amenity"="school"',
    'مدرسة':          '"amenity"="school"',
    'gas station':    '"amenity"="fuel"',
    'petrol':         '"amenity"="fuel"',
    'بنزينة':         '"amenity"="fuel"',
    'police':         '"amenity"="police"',
    'شرطة':           '"amenity"="police"',
    'بوليس':          '"amenity"="police"',
    'parking':        '"amenity"="parking"',
    'موقف':           '"amenity"="parking"',
    'toilet':         '"amenity"="toilets"',
    'toilets':        '"amenity"="toilets"',
    'دورة مياه':      '"amenity"="toilets"',
  };

  // ── Public API ─────────────────────────────────────────────────────────────

  static Future<List<GeoSuggestion>> searchEgypt(String query) async {
    final q = query.trim();
    if (q.length < 2) return [];

    // Instant local match — no network required
    final local = _matchLocal(q);

    // Category search (e.g. "hotels", "مطاعم") → Overpass POI query
    final osmFilter = _categoryTags[q.toLowerCase()];
    if (osmFilter != null) {
      try {
        final pois = await _overpass(osmFilter);
        if (pois.isNotEmpty) return _merge(local, pois);
      } catch (_) {}
    }

    try {
      // Place-name search: Photon + Nominatim in parallel
      final both = await Future.wait([
        _photon(q),
        _nominatim(q, cc: 'eg'),
      ]);
      final combined = _dedup([...both[0], ...both[1]]);
      if (combined.isNotEmpty) return _merge(local, combined);

      // Last resort: Nominatim without country restriction
      final global = await _nominatim(q);
      return _merge(local, global);
    } catch (_) {
      return local;
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  static List<GeoSuggestion> _matchLocal(String q) {
    final lower = q.toLowerCase();
    final seen = <String>{};
    final out   = <GeoSuggestion>[];

    // Arabic match
    for (final entry in _arabicMap.entries) {
      if (entry.key.contains(lower) || lower.contains(entry.key.substring(0, entry.key.length > 2 ? 3 : entry.key.length))) {
        final s = popularPlaces[entry.value];
        if (seen.add(s.name)) out.add(s);
      }
    }

    // English match
    for (final s in popularPlaces) {
      if (s.name.toLowerCase().contains(lower) && seen.add(s.name)) out.add(s);
    }

    return out.take(5).toList();
  }

  /// Overpass API — finds all POIs of a given OSM category in the Luxor area.
  /// Free, no API key, covers Egypt/OSM data.
  /// Overpass bbox format: south,west,north,east
  static Future<List<GeoSuggestion>> _overpass(String osmFilter) async {
    const bbox = '25.55,32.45,25.80,32.80'; // Luxor city + surroundings
    final query =
        '[out:json][timeout:15];'
        '(node[$osmFilter]($bbox);way[$osmFilter]($bbox););'
        'out center 25;';

    final url = Uri.parse('https://overpass-api.de/api/interpreter');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'data=${Uri.encodeComponent(query)}',
    ).timeout(const Duration(seconds: 12));

    if (res.statusCode != 200) return [];
    final body    = jsonDecode(res.body) as Map<String, dynamic>;
    final elements = body['elements'] as List? ?? [];

    final out = <GeoSuggestion>[];
    for (final e in elements) {
      final tags = e['tags'] as Map<String, dynamic>? ?? {};
      final name = (tags['name:en'] as String?)?.trim() ??
                   (tags['name']    as String?)?.trim();
      if (name == null || name.isEmpty) continue;

      double? lat, lon;
      if (e['type'] == 'node') {
        lat = (e['lat'] as num?)?.toDouble();
        lon = (e['lon'] as num?)?.toDouble();
      } else {
        lat = (e['center']?['lat'] as num?)?.toDouble();
        lon = (e['center']?['lon'] as num?)?.toDouble();
      }
      if (lat == null || lon == null) continue;

      final city = (tags['addr:city'] as String?)?.trim() ?? 'Luxor';
      out.add(GeoSuggestion(name: '$name, $city', location: LatLng(lat, lon)));
    }
    return out;
  }

  /// Photon geocoder — Elasticsearch on top of OSM, free, no API key.
  /// Better fuzzy matching and partial-word search than Nominatim.
  /// Egypt bounding box: west=24.70, south=22.00, east=36.90, north=31.67
  static Future<List<GeoSuggestion>> _photon(String q) async {
    final url = Uri.parse(
      'https://photon.komoot.io/api/'
      '?q=${Uri.encodeComponent(q)}'
      '&limit=15'
      '&lang=en'
      '&bbox=24.70,22.00,36.90,31.67',
    );
    final res = await http.get(url, headers: {
      'User-Agent': 'FluTour/1.0 flutour.dev@gmail.com',
    }).timeout(const Duration(seconds: 6));

    if (res.statusCode != 200) return [];
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final features = body['features'] as List? ?? [];
    return features.map((f) {
      final coords = (f['geometry']['coordinates'] as List);
      final lon = (coords[0] as num).toDouble();
      final lat = (coords[1] as num).toDouble();
      final props = f['properties'] as Map<String, dynamic>;
      return GeoSuggestion(name: _formatPhoton(props), location: LatLng(lat, lon));
    }).toList();
  }

  /// Nominatim geocoder — structured OSM search with Arabic language support.
  static Future<List<GeoSuggestion>> _nominatim(String q, {String? cc}) async {
    final buf = StringBuffer(
      'q=${Uri.encodeComponent(q)}'
      '&format=json'
      '&limit=15'
      '&dedupe=1'
      '&addressdetails=1'
      '&namedetails=1',
    );
    if (cc != null) buf.write('&countrycodes=$cc');

    final url = Uri.parse('https://nominatim.openstreetmap.org/search?$buf');
    final res = await http.get(url, headers: {
      'Accept-Language': 'ar,en',
      'User-Agent': 'FluTour/1.0 flutour.dev@gmail.com',
    }).timeout(const Duration(seconds: 6));

    if (res.statusCode != 200) return [];
    final list = jsonDecode(res.body) as List;
    return list.map((item) {
      final lat = double.parse(item['lat'] as String);
      final lon = double.parse(item['lon'] as String);
      return GeoSuggestion(name: _formatNominatim(item), location: LatLng(lat, lon));
    }).toList();
  }

  /// Name from Photon GeoJSON feature properties.
  static String _formatPhoton(Map<String, dynamic> p) {
    final name     = (p['name']     as String?)?.trim();
    final street   = (p['street']   as String?)?.trim();
    final district = (p['district'] as String?)?.trim();
    final city     = (p['city']     as String?)?.trim();
    final state    = (p['state']    as String?)?.trim();

    final primary = name ?? street;
    if (primary == null || primary.isEmpty) {
      return [city, state].whereType<String>().take(2).join(', ');
    }
    final ctx = <String>[];
    if (district != null && district != primary) ctx.add(district);
    if (city     != null && city     != primary && !ctx.contains(city)) ctx.add(city);
    else if (state != null && state  != primary && ctx.isEmpty) ctx.add(state);
    return ctx.isEmpty ? primary : '$primary, ${ctx.take(2).join(', ')}';
  }

  /// Name from Nominatim JSON item using namedetails + addressdetails.
  static String _formatNominatim(Map<String, dynamic> item) {
    final nd   = item['namedetails'] as Map<String, dynamic>?;
    final addr = item['address']     as Map<String, dynamic>?;

    final primary = ((nd?['name:en'] as String?) ??
                     (nd?['name']    as String?) ??
                     (item['name']   as String?))?.trim();

    if (primary != null && primary.isNotEmpty) {
      final ctx = <String>[];
      if (addr != null) {
        final suburb  = (addr['suburb']  as String?)?.trim();
        final quarter = (addr['quarter'] as String?)?.trim();
        final city    = ((addr['city']   as String?) ??
                         (addr['town']   as String?) ??
                         (addr['village'] as String?))?.trim();
        final state   = (addr['state']  as String?)?.trim();
        if (suburb  != null && suburb  != primary) ctx.add(suburb);
        else if (quarter != null && quarter != primary) ctx.add(quarter);
        if (city  != null && city  != primary && !ctx.contains(city)) ctx.add(city);
        else if (state != null && state != primary && ctx.isEmpty) ctx.add(state);
      }
      return ctx.isEmpty ? primary : '$primary, ${ctx.take(2).join(', ')}';
    }

    final parts = (item['display_name'] as String).split(', ');
    return parts.take(3).join(', ');
  }

  /// Remove near-duplicate coordinates (within ~100 m).
  static List<GeoSuggestion> _dedup(List<GeoSuggestion> items) {
    final out = <GeoSuggestion>[];
    for (final s in items) {
      final dupe = out.any((m) =>
          (m.location.latitude  - s.location.latitude ).abs() < 0.001 &&
          (m.location.longitude - s.location.longitude).abs() < 0.001);
      if (!dupe) out.add(s);
    }
    return out;
  }

  /// Merge local (curated) suggestions with remote results, local first.
  static List<GeoSuggestion> _merge(
      List<GeoSuggestion> local, List<GeoSuggestion> remote) {
    final out = <GeoSuggestion>[...local];
    for (final r in remote) {
      final dupe = out.any((m) =>
          (m.location.latitude  - r.location.latitude ).abs() < 0.001 &&
          (m.location.longitude - r.location.longitude).abs() < 0.001);
      if (!dupe) out.add(r);
    }
    return out.take(14).toList();
  }
}
