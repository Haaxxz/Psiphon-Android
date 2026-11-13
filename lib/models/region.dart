class VpnRegion {
  final String code;
  final String name;
  final String? svgAsset;

  const VpnRegion({
    required this.code,
    required this.name,
    this.svgAsset,
  });

  bool get isAuto => code.isEmpty;

  String get displayAssetPath {
    if (isAuto) return 'assets/icons/flag-all.svg';
    return svgAsset ?? 'assets/flags/${code.toLowerCase()}.svg';
  }
}

/// Complete Psiphon 3 country roster — every country individually selectable.
const List<VpnRegion> kAllPsiphonRegions = [
  VpnRegion(code: '', name: 'Best performance'),
  VpnRegion(code: 'US', name: 'United States', svgAsset: 'assets/flags/us.svg'),
  VpnRegion(code: 'GB', name: 'United Kingdom', svgAsset: 'assets/flags/gb.svg'),
  VpnRegion(code: 'DE', name: 'Germany', svgAsset: 'assets/flags/de.svg'),
  VpnRegion(code: 'CA', name: 'Canada', svgAsset: 'assets/flags/ca.svg'),
  VpnRegion(code: 'NL', name: 'Netherlands', svgAsset: 'assets/flags/nl.svg'),
  VpnRegion(code: 'FR', name: 'France', svgAsset: 'assets/flags/fr.svg'),
  VpnRegion(code: 'CH', name: 'Switzerland', svgAsset: 'assets/flags/ch.svg'),
  VpnRegion(code: 'JP', name: 'Japan', svgAsset: 'assets/flags/jp.svg'),
  VpnRegion(code: 'SG', name: 'Singapore', svgAsset: 'assets/flags/sg.svg'),
  VpnRegion(code: 'AU', name: 'Australia', svgAsset: 'assets/flags/au.svg'),
  VpnRegion(code: 'SE', name: 'Sweden', svgAsset: 'assets/flags/se.svg'),
  VpnRegion(code: 'NO', name: 'Norway', svgAsset: 'assets/flags/no.svg'),
  VpnRegion(code: 'FI', name: 'Finland', svgAsset: 'assets/flags/fi.svg'),
  VpnRegion(code: 'DK', name: 'Denmark', svgAsset: 'assets/flags/dk.svg'),
  VpnRegion(code: 'IE', name: 'Ireland', svgAsset: 'assets/flags/ie.svg'),
  VpnRegion(code: 'AT', name: 'Austria', svgAsset: 'assets/flags/at.svg'),
  VpnRegion(code: 'BE', name: 'Belgium', svgAsset: 'assets/flags/be.svg'),
  VpnRegion(code: 'ES', name: 'Spain', svgAsset: 'assets/flags/es.svg'),
  VpnRegion(code: 'IT', name: 'Italy', svgAsset: 'assets/flags/it.svg'),
  VpnRegion(code: 'PT', name: 'Portugal', svgAsset: 'assets/flags/pt.svg'),
  VpnRegion(code: 'PL', name: 'Poland', svgAsset: 'assets/flags/pl.svg'),
  VpnRegion(code: 'CZ', name: 'Czechia', svgAsset: 'assets/flags/cz.svg'),
  VpnRegion(code: 'RO', name: 'Romania', svgAsset: 'assets/flags/ro.svg'),
  VpnRegion(code: 'BG', name: 'Bulgaria', svgAsset: 'assets/flags/bg.svg'),
  VpnRegion(code: 'HU', name: 'Hungary', svgAsset: 'assets/flags/hu.svg'),
  VpnRegion(code: 'HR', name: 'Croatia', svgAsset: 'assets/flags/hr.svg'),
  VpnRegion(code: 'RS', name: 'Serbia', svgAsset: 'assets/flags/rs.svg'),
  VpnRegion(code: 'SK', name: 'Slovakia', svgAsset: 'assets/flags/sk.svg'),
  VpnRegion(code: 'EE', name: 'Estonia', svgAsset: 'assets/flags/ee.svg'),
  VpnRegion(code: 'LV', name: 'Latvia', svgAsset: 'assets/flags/lv.svg'),
  VpnRegion(code: 'LT', name: 'Lithuania', svgAsset: 'assets/flags/lt.svg'),
  VpnRegion(code: 'GR', name: 'Greece', svgAsset: 'assets/flags/gr.svg'),
  VpnRegion(code: 'IS', name: 'Iceland', svgAsset: 'assets/flags/is.svg'),
  VpnRegion(code: 'UA', name: 'Ukraine', svgAsset: 'assets/flags/ua.svg'),
  VpnRegion(code: 'HK', name: 'Hong Kong', svgAsset: 'assets/flags/hk.svg'),
  VpnRegion(code: 'TW', name: 'Taiwan', svgAsset: 'assets/flags/tw.svg'),
  VpnRegion(code: 'KR', name: 'South Korea', svgAsset: 'assets/flags/kr.svg'),
  VpnRegion(code: 'IN', name: 'India', svgAsset: 'assets/flags/in.svg'),
  VpnRegion(code: 'ID', name: 'Indonesia', svgAsset: 'assets/flags/id.svg'),
  VpnRegion(code: 'MY', name: 'Malaysia', svgAsset: 'assets/flags/my.svg'),
  VpnRegion(code: 'NZ', name: 'New Zealand', svgAsset: 'assets/flags/nz.svg'),
  VpnRegion(code: 'BR', name: 'Brazil', svgAsset: 'assets/flags/br.svg'),
  VpnRegion(code: 'MX', name: 'Mexico', svgAsset: 'assets/flags/mx.svg'),
  VpnRegion(code: 'AR', name: 'Argentina', svgAsset: 'assets/flags/ar.svg'),
  VpnRegion(code: 'CL', name: 'Chile', svgAsset: 'assets/flags/cl.svg'),
  VpnRegion(code: 'CO', name: 'Colombia', svgAsset: 'assets/flags/co.svg'),
  VpnRegion(code: 'AE', name: 'United Arab Emirates', svgAsset: 'assets/flags/ae.svg'),
  VpnRegion(code: 'KE', name: 'Kenya', svgAsset: 'assets/flags/ke.svg'),
  VpnRegion(code: 'ZA', name: 'South Africa', svgAsset: 'assets/flags/za.svg'),
];

const Set<String> kBundledFlagCodes = {
  'AE', 'AR', 'AT', 'AU', 'BE', 'BG', 'BR', 'CA', 'CH', 'CL', 'CN', 'CO',
  'CZ', 'DE', 'DK', 'EE', 'EG', 'ES', 'FI', 'FR', 'GB', 'GR', 'HK', 'HR',
  'HU', 'ID', 'IE', 'IL', 'IN', 'IS', 'IT', 'JP', 'KE', 'KR', 'KZ', 'LT',
  'LV', 'MA', 'MX', 'MY', 'NG', 'NL', 'NO', 'NZ', 'PE', 'PH', 'PL', 'PT',
  'RO', 'RS', 'RU', 'SA', 'SE', 'SG', 'SI', 'SK', 'TH', 'TR', 'TW', 'UA',
  'US', 'VE', 'VN', 'ZA',
};

const Map<String, String> kExtraCountryNames = {
  'CN': 'China',
  'EG': 'Egypt',
  'IL': 'Israel',
  'KZ': 'Kazakhstan',
  'MA': 'Morocco',
  'NG': 'Nigeria',
  'PE': 'Peru',
  'PH': 'Philippines',
  'RU': 'Russia',
  'SA': 'Saudi Arabia',
  'SI': 'Slovenia',
  'TH': 'Thailand',
  'TR': 'Turkey',
  'VE': 'Venezuela',
  'VN': 'Vietnam',
};

VpnRegion resolveRegion(String code) {
  final upper = code.trim().toUpperCase();
  for (final region in kAllPsiphonRegions) {
    if (region.code == upper) return region;
  }
  final name = kExtraCountryNames[upper] ?? (upper.isEmpty ? 'Best performance' : upper);
  return VpnRegion(
    code: upper,
    name: name,
    svgAsset: kBundledFlagCodes.contains(upper)
        ? 'assets/flags/${upper.toLowerCase()}.svg'
        : null,
  );
}

List<VpnRegion> buildFullRegionList(List<String> serverAvailableCodes) {
  final knownCodes = kAllPsiphonRegions.map((r) => r.code).toSet();
  final extras = <VpnRegion>[];
  for (final raw in serverAvailableCodes) {
    final code = raw.trim().toUpperCase();
    if (code.isNotEmpty && !knownCodes.contains(code)) {
      knownCodes.add(code);
      extras.add(resolveRegion(code));
    }
  }
  extras.sort((a, b) => a.name.compareTo(b.name));
  return [...kAllPsiphonRegions, ...extras];
}
