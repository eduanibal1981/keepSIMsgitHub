import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

final _countryService = CountryService();

String destinationCountryLabel(BuildContext context, String? iso) {
  if (iso == null) return '';
  final country = _countryService.findByCode(iso);
  final name =
      CountryLocalizations(
        Localizations.localeOf(context),
      ).countryName(countryCode: iso) ??
      country?.name ??
      iso;
  return country == null ? name : '$name (+${country.phoneCode})';
}

Future<String?> pickDestinationCountry(
  BuildContext context, {
  String? suggestedIso,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _CountryPicker(suggestedIso: suggestedIso),
);

class _CountryPicker extends StatefulWidget {
  final String? suggestedIso;
  const _CountryPicker({this.suggestedIso});
  @override
  State<_CountryPicker> createState() => _CountryPickerState();
}

class _CountryPickerState extends State<_CountryPicker> {
  String _query = '';
  final _supported = IsoCode.values.map((c) => c.name).toSet();
  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final countries =
        _countryService
            .getAll()
            .where(
              (c) =>
                  _supported.contains(c.countryCode) &&
                  '${destinationCountryLabel(context, c.countryCode)} ${c.name} ${c.countryCode}'
                      .toLowerCase()
                      .contains(_query.toLowerCase()),
            )
            .toList()
          ..sort((a, b) {
            if (a.countryCode == widget.suggestedIso) return -1;
            if (b.countryCode == widget.suggestedIso) return 1;
            return destinationCountryLabel(
              context,
              a.countryCode,
            ).compareTo(destinationCountryLabel(context, b.countryCode));
          });
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .68,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                ar ? 'بلد هذا الرقم' : 'Country for this number',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  labelText: ar
                      ? 'بحث عن بلد أو رمز'
                      : 'Search country or code',
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: countries.isEmpty
                  ? Center(
                      child: Text(ar ? 'لا توجد نتائج' : 'No countries found'),
                    )
                  : ListView.builder(
                      itemCount: countries.length,
                      itemBuilder: (context, index) {
                        final country = countries[index];
                        return ListTile(
                          title: Text(
                            destinationCountryLabel(
                              context,
                              country.countryCode,
                            ),
                          ),
                          subtitle: country.countryCode == widget.suggestedIso
                              ? Text(ar ? 'بلد مقترح' : 'Suggested country')
                              : null,
                          onTap: () =>
                              Navigator.pop(context, country.countryCode),
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
