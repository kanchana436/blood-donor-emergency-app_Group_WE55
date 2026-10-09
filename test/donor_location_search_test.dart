import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifelink/screens/recipient/nearby_donors_map_screen.dart';
import 'package:lifelink/services/donor_service.dart';

void main() {
  group('Donor Location Search & Filter Unit Tests', () {
    late DonorService donorService;

    setUp(() {
      donorService = DonorService();
    });

    test('1. Search for existing city returns matching donors', () async {
      final results = await donorService.searchDonors(city: 'Colombo');
      expect(results, isNotEmpty);
      expect(results.every((d) => d.city.toLowerCase().contains('colombo')), isTrue);
    });

    test('2. Search is case-insensitive (lowercase, uppercase, mixed-case)', () async {
      final lower = await donorService.searchDonors(city: 'colombo');
      final upper = await donorService.searchDonors(city: 'COLOMBO');
      final mixed = await donorService.searchDonors(city: 'cOLoMBo');

      expect(lower.length, equals(upper.length));
      expect(lower.length, equals(mixed.length));
      expect(lower.isNotEmpty, isTrue);
    });

    test('3. Search ignores leading and trailing spaces', () async {
      final normal = await donorService.searchDonors(city: 'Colombo');
      final spaces = await donorService.searchDonors(city: '   Colombo   ');

      expect(spaces.length, equals(normal.length));
    });

    test('4. Search for a city with no donors returns empty list', () async {
      final results = await donorService.searchDonors(city: 'NonExistentCityXYZ');
      expect(results, isEmpty);
    });

    test('5. Clear search returns all eligible donors', () async {
      final allDonors = await donorService.searchDonors();
      final filteredDonors = await donorService.searchDonors(city: 'Colombo');

      expect(allDonors.length, greaterThanOrEqualTo(filteredDonors.length));
      expect(allDonors.any((d) => d.city.toLowerCase().contains('kandy')), isTrue);
    });

    test('6. Combined filtering (Blood Group + City + Availability)', () async {
      final combo = await donorService.searchDonors(
        city: 'Colombo',
        bloodGroup: 'O+',
        isAvailable: true,
      );

      expect(combo, isNotEmpty);
      expect(
        combo.every((d) =>
            d.city.toLowerCase().contains('colombo') &&
            d.bloodGroup == 'O+' &&
            d.isAvailable == true),
        isTrue,
      );
    });

    test('7. Unavailable donors are excluded from default search', () async {
      // In mockStore, 'usr_donor_104' is an unavailable donor in Colombo
      final results = await donorService.searchDonors(city: 'Colombo', isAvailable: true);
      expect(results.any((d) => d.userId == 'usr_donor_104'), isFalse);
    });

    test('8. Deactivated donors are NEVER displayed', () async {
      // In mockStore, 'usr_donor_105' is a deactivated donor (user.isActive = false)
      final results = await donorService.searchDonors(city: 'Colombo');
      expect(results.any((d) => d.userId == 'usr_donor_105'), isFalse);

      final allResults = await donorService.searchDonors();
      expect(allResults.any((d) => d.userId == 'usr_donor_105'), isFalse);
    });
  });

  group('NearbyDonorsMapScreen Widget Tests', () {
    testWidgets('Search UI elements render correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NearbyDonorsMapScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Check Label "Search by City"
      expect(find.text('Search by City'), findsOneWidget);

      // Check Placeholder "Enter city"
      expect(find.text('Enter city'), findsOneWidget);

      // Check Search button
      expect(find.text('Search'), findsOneWidget);

      // Check Blood Group ChoiceChips
      expect(find.text('All'), findsWidgets);
      expect(find.text('O+'), findsWidgets);
      expect(find.text('A+'), findsWidgets);
    });

    testWidgets('Empty search shows "No donors found in this location."', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NearbyDonorsMapScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Enter a non-existent city
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'NonExistentCityXYZ');
      await tester.pumpAndSettle();

      // Tap search button
      final searchBtn = find.byKey(const Key('btn_search_city'));
      await tester.tap(searchBtn);
      await tester.pumpAndSettle();

      // Verify empty state text
      expect(find.text('No donors found in this location.'), findsOneWidget);
      expect(find.text('Show All Eligible Donors'), findsOneWidget);

      // Scroll to button and tap to clear/reset filters
      await tester.ensureVisible(find.text('Show All Eligible Donors'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show All Eligible Donors'));
      await tester.pumpAndSettle();

      // Donors should reappear
      expect(find.text('No donors found in this location.'), findsNothing);
      expect(find.text('Eligible Donors'), findsOneWidget);
    });
  });
}
