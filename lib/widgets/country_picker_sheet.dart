import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/region.dart';
import '../theme/psiphon_theme.dart';

class CountryPickerSheet extends StatefulWidget {
  final String selectedCode;
  final List<String> availableServerRegions;
  final ValueChanged<String> onSelect;

  const CountryPickerSheet({
    super.key,
    required this.selectedCode,
    required this.availableServerRegions,
    required this.onSelect,
  });

  @override
  State<CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<CountryPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final allRegions = buildFullRegionList(widget.availableServerRegions);
    final liveSet = widget.availableServerRegions.map((e) => e.toUpperCase()).toSet();
    final q = _query.trim().toLowerCase();

    final filtered = q.isEmpty
        ? allRegions
        : allRegions.where((r) {
            return r.name.toLowerCase().contains(q) ||
                r.code.toLowerCase().contains(q);
          }).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Server Region',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: PsiphonPalette.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'All countries unlocked • individual selection enabled',
                          style: TextStyle(
                            fontSize: 12,
                            color: PsiphonPalette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: PsiphonPalette.connectedEmerald.withAlpha(41),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: PsiphonPalette.connectedEmerald.withAlpha(102),
                      ),
                    ),
                    child: Text(
                      '${allRegions.length - 1} countries',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: PsiphonPalette.connectedEmerald,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                style: const TextStyle(color: PsiphonPalette.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search country or code (e.g. Germany, JP)',
                  hintStyle: const TextStyle(
                    color: PsiphonPalette.textSecondary,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: PsiphonPalette.textSecondary,
                  ),
                  filled: true,
                  fillColor: PsiphonPalette.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: PsiphonPalette.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: PsiphonPalette.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: PsiphonPalette.orbCoral),
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                itemCount: filtered.length,
                itemBuilder: (context, idx) {
                  final region = filtered[idx];
                  final selected =
                      region.code == widget.selectedCode.toUpperCase();
                  final isLive = region.isAuto || liveSet.contains(region.code);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Material(
                      color: selected
                          ? PsiphonPalette.surfaceElevated
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          widget.onSelect(region.code);
                          Navigator.of(context).pop();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                          child: Row(
                            children: [
                              RegionFlagIcon(region: region, size: 28),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  region.name,
                                  style: TextStyle(
                                    color: PsiphonPalette.textPrimary,
                                    fontSize: 15,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                              if (!region.isAuto) ...[
                                if (isLive)
                                  Container(
                                    width: 7,
                                    height: 7,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: const BoxDecoration(
                                      color: PsiphonPalette.connectedEmerald,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                Text(
                                  region.code,
                                  style: const TextStyle(
                                    color: PsiphonPalette.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(width: 10),
                              Icon(
                                selected
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                size: 20,
                                color: selected
                                    ? PsiphonPalette.orbCoral
                                    : Colors.white24,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class RegionFlagIcon extends StatelessWidget {
  final VpnRegion region;
  final double size;

  const RegionFlagIcon({
    super.key,
    required this.region,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    if (region.isAuto) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: SvgPicture.asset(
            'assets/icons/flag-all.svg',
            width: size,
            height: size * 0.78,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    if (kBundledFlagCodes.contains(region.code)) {
      return ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: SvgPicture.asset(
            region.displayAssetPath,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: PsiphonPalette.surfaceElevated,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        region.code,
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          color: PsiphonPalette.textPrimary,
        ),
      ),
    );
  }
}
