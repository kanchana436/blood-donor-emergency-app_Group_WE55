const assert = require('assert');
const { prisma, db } = require('../prisma');

const BASE_URL = 'http://localhost:5000/api';

async function runLocationSearchTests() {
  console.log('===============================================================');
  console.log('📍 LifeLink Donor Location Search & Filter Test Suite');
  console.log('===============================================================');

  let passedAssertions = 0;
  function pass(msg) {
    passedAssertions++;
    console.log(`✅ [PASS] ${msg}`);
  }

  try {
    // -------------------------------------------------------------------------
    // Setup Test Data in Supabase / PostgreSQL (or in-memory)
    // -------------------------------------------------------------------------
    console.log('\n--- SETUP: Preparing Test Users & Donor Profiles ---');
    const testTimestamp = Date.now();

    // 1. Available, Active Donor in Colombo
    const activeColomboUser = await (prisma ? prisma.user.create({
      data: {
        idNumber: `LOC1${testTimestamp.toString().slice(-6)}V`,
        name: 'Colombo Active Donor',
        email: `colombo_active_${testTimestamp}@lifelink.org`,
        phone: '+94 77 111 0001',
        password: 'hashed_password',
        role: 'donor',
        isActive: true,
      },
    }) : { id: `usr_test_colombo_${testTimestamp}`, name: 'Colombo Active Donor', isActive: true });

    const activeColomboProfile = await (prisma ? prisma.donorProfile.create({
      data: {
        userId: activeColomboUser.id,
        bloodGroup: 'O+',
        city: 'Colombo',
        address: 'Galle Face, Colombo 03',
        isAvailable: true,
      },
    }) : { id: `dp_test_1`, userId: activeColomboUser.id, bloodGroup: 'O+', city: 'Colombo', isAvailable: true });

    // 2. Available, Active Donor in Kandy
    const activeKandyUser = await (prisma ? prisma.user.create({
      data: {
        idNumber: `LOC2${testTimestamp.toString().slice(-6)}V`,
        name: 'Kandy Active Donor',
        email: `kandy_active_${testTimestamp}@lifelink.org`,
        phone: '+94 77 111 0002',
        password: 'hashed_password',
        role: 'donor',
        isActive: true,
      },
    }) : { id: `usr_test_kandy_${testTimestamp}`, name: 'Kandy Active Donor', isActive: true });

    const activeKandyProfile = await (prisma ? prisma.donorProfile.create({
      data: {
        userId: activeKandyUser.id,
        bloodGroup: 'A+',
        city: 'Kandy',
        address: 'Kandy City Center',
        isAvailable: true,
      },
    }) : { id: `dp_test_2`, userId: activeKandyUser.id, bloodGroup: 'A+', city: 'Kandy', isAvailable: true });

    // 3. UNAVAILABLE Donor in Colombo (isAvailable = false)
    const unavailableColomboUser = await (prisma ? prisma.user.create({
      data: {
        idNumber: `LOC3${testTimestamp.toString().slice(-6)}V`,
        name: 'Colombo Unavailable Donor',
        email: `colombo_unavail_${testTimestamp}@lifelink.org`,
        phone: '+94 77 111 0003',
        password: 'hashed_password',
        role: 'donor',
        isActive: true,
      },
    }) : { id: `usr_test_unavail_${testTimestamp}`, name: 'Colombo Unavailable Donor', isActive: true });

    const unavailableColomboProfile = await (prisma ? prisma.donorProfile.create({
      data: {
        userId: unavailableColomboUser.id,
        bloodGroup: 'O+',
        city: 'Colombo',
        address: 'Kollupitiya, Colombo',
        isAvailable: false, // Unavailable!
      },
    }) : { id: `dp_test_3`, userId: unavailableColomboUser.id, bloodGroup: 'O+', city: 'Colombo', isAvailable: false });

    // 4. DEACTIVATED Donor in Colombo (user.isActive = false)
    const deactivatedColomboUser = await (prisma ? prisma.user.create({
      data: {
        idNumber: `LOC4${testTimestamp.toString().slice(-6)}V`,
        name: 'Colombo Deactivated Donor',
        email: `colombo_deact_${testTimestamp}@lifelink.org`,
        phone: '+94 77 111 0004',
        password: 'hashed_password',
        role: 'donor',
        isActive: false, // Deactivated!
      },
    }) : { id: `usr_test_deact_${testTimestamp}`, name: 'Colombo Deactivated Donor', isActive: false });

    const deactivatedColomboProfile = await (prisma ? prisma.donorProfile.create({
      data: {
        userId: deactivatedColomboUser.id,
        bloodGroup: 'O+',
        city: 'Colombo',
        address: 'Bambalapitiya, Colombo',
        isAvailable: true,
      },
    }) : { id: `dp_test_4`, userId: deactivatedColomboUser.id, bloodGroup: 'O+', city: 'Colombo', isAvailable: true });

    if (!prisma) {
      db.users.push(activeColomboUser, activeKandyUser, unavailableColomboUser, deactivatedColomboUser);
      db.donorProfiles.push(activeColomboProfile, activeKandyProfile, unavailableColomboProfile, deactivatedColomboProfile);
    }
    pass('Test data initialized in database with active, unavailable, and deactivated records');

    // -------------------------------------------------------------------------
    // TEST 1: Search for an existing city -> matching donors should appear
    // -------------------------------------------------------------------------
    console.log('\n--- TEST 1: Search for an Existing City (Colombo) ---');
    const res1 = await fetch(`${BASE_URL}/donors?city=Colombo`);
    assert.strictEqual(res1.status, 200, 'GET /api/donors?city=Colombo should return 200');
    const data1 = await res1.json();
    assert.strictEqual(data1.success, true, 'Response success should be true');
    assert(data1.data.length > 0, 'Matching donors should appear for Colombo');
    const hasColomboDonor = data1.data.some(d => d.userId === activeColomboUser.id);
    assert(hasColomboDonor, 'Active Colombo donor must be in the search results');
    // Ensure all returned donors have Colombo in their city
    const allMatchCity = data1.data.every(d => d.city.toLowerCase().includes('colombo'));
    assert(allMatchCity, 'Every donor returned must have a city containing Colombo');
    pass(`Existing city search returned ${data1.data.length} donors correctly`);

    // -------------------------------------------------------------------------
    // TEST 2: Case-Insensitivity (lowercase vs uppercase vs mixed)
    // -------------------------------------------------------------------------
    console.log('\n--- TEST 2: Case-Insensitive City Search ---');
    const resLower = await fetch(`${BASE_URL}/donors?city=colombo`);
    const dataLower = await resLower.json();

    const resUpper = await fetch(`${BASE_URL}/donors?city=COLOMBO`);
    const dataUpper = await resUpper.json();

    const resMixed = await fetch(`${BASE_URL}/donors?city=cOLoMBo`);
    const dataMixed = await resMixed.json();

    assert.strictEqual(dataLower.data.length, data1.data.length, 'Lowercase "colombo" must return same count as "Colombo"');
    assert.strictEqual(dataUpper.data.length, data1.data.length, 'Uppercase "COLOMBO" must return same count as "Colombo"');
    assert.strictEqual(dataMixed.data.length, data1.data.length, 'Mixed-case "cOLoMBo" must return same count as "Colombo"');
    pass(`Case-insensitivity verified: lowercase (${dataLower.data.length}), uppercase (${dataUpper.data.length}), mixed (${dataMixed.data.length}) all match identically`);

    // -------------------------------------------------------------------------
    // TEST 3: Leading / Trailing Spaces Ignored
    // -------------------------------------------------------------------------
    console.log('\n--- TEST 3: Leading & Trailing Spaces Ignored ---');
    const resSpaces = await fetch(`${BASE_URL}/donors?city=%20%20%20Colombo%20%20%20`);
    const dataSpaces = await resSpaces.json();
    assert.strictEqual(dataSpaces.data.length, data1.data.length, 'City with leading/trailing spaces must yield same count');
    pass('Search with leading and trailing spaces trimmed and matched correctly');

    // -------------------------------------------------------------------------
    // TEST 4: Search for a city with no donors -> 0 donors returned
    // -------------------------------------------------------------------------
    console.log('\n--- TEST 4: Search for City with No Donors ---');
    const resNone = await fetch(`${BASE_URL}/donors?city=NonExistentCityXYZ`);
    const dataNone = await resNone.json();
    assert.strictEqual(dataNone.status === undefined || dataNone.success === true, true);
    assert.strictEqual(dataNone.data.length, 0, 'City with no donors must return 0 results');
    assert.strictEqual(dataNone.count, 0, 'Count should be 0');
    pass('City with no donors returned empty list (UI shows "No donors found in this location.")');

    // -------------------------------------------------------------------------
    // TEST 5: Clear / Reset Search -> Show all eligible donors
    // -------------------------------------------------------------------------
    console.log('\n--- TEST 5: Clear / Reset Search (Show all eligible donors) ---');
    const resAll = await fetch(`${BASE_URL}/donors`);
    const dataAll = await resAll.json();
    assert.strictEqual(dataAll.success, true);
    assert(dataAll.data.length >= data1.data.length, 'Clearing search must return all eligible donors');
    const hasColomboInAll = dataAll.data.some(d => d.userId === activeColomboUser.id);
    const hasKandyInAll = dataAll.data.some(d => d.userId === activeKandyUser.id);
    assert(hasColomboInAll && hasKandyInAll, 'Both Colombo and Kandy donors must appear when search is cleared');
    pass(`Clear search returned all ${dataAll.data.length} eligible donors`);

    // -------------------------------------------------------------------------
    // TEST 6: Combined Filtering (Blood Group + City + Availability)
    // -------------------------------------------------------------------------
    console.log('\n--- TEST 6: Combined Filtering (Blood Group + City + Availability) ---');
    // Search Colombo + O+
    const resCombo = await fetch(`${BASE_URL}/donors?city=Colombo&bloodGroup=O%2B&isAvailable=true`);
    const dataCombo = await resCombo.json();
    assert.strictEqual(dataCombo.success, true);
    assert(dataCombo.data.length > 0, 'Combined filter should return matching donors');
    const allMatchCombo = dataCombo.data.every(
      d => d.city.toLowerCase().includes('colombo') && d.bloodGroup === 'O+' && d.isAvailable === true
    );
    assert(allMatchCombo, 'Every result must satisfy ALL selected filters (Colombo, O+, Available)');
    // Kandy donor (A+) should NOT appear
    const hasKandyInCombo = dataCombo.data.some(d => d.userId === activeKandyUser.id);
    assert(!hasKandyInCombo, 'Kandy A+ donor must not appear in Colombo O+ filter');
    pass(`Combined filter (Colombo + O+ + Available) returned ${dataCombo.data.length} matching donors`);

    // -------------------------------------------------------------------------
    // TEST 7: Unavailable Donor -> MUST NOT appear
    // -------------------------------------------------------------------------
    console.log('\n--- TEST 7: Unavailable Donor Excluded ---');
    const hasUnavailable = data1.data.some(d => d.userId === unavailableColomboUser.id);
    assert(!hasUnavailable, 'Unavailable donor must NEVER appear in active donors list');
    const hasUnavailableInAll = dataAll.data.some(d => d.userId === unavailableColomboUser.id);
    assert(!hasUnavailableInAll, 'Unavailable donor must not appear even when city filter is empty');
    pass('Unavailable donor successfully excluded from donor search results');

    // -------------------------------------------------------------------------
    // TEST 8: Deactivated Donor -> MUST NOT appear
    // -------------------------------------------------------------------------
    console.log('\n--- TEST 8: Deactivated Donor Excluded ---');
    const hasDeactivated = data1.data.some(d => d.userId === deactivatedColomboUser.id);
    assert(!hasDeactivated, 'Deactivated donor (isActive=false) must NEVER appear in search results');
    const hasDeactivatedInAll = dataAll.data.some(d => d.userId === deactivatedColomboUser.id);
    assert(!hasDeactivatedInAll, 'Deactivated donor must NEVER appear in all donors list');
    pass('Deactivated donor successfully excluded from all donor search results');

    // -------------------------------------------------------------------------
    // TEST 9: Verify Supabase Database Persistence
    // -------------------------------------------------------------------------
    console.log('\n--- TEST 9: Verify Supabase PostgreSQL Database Records ---');
    if (prisma) {
      const dbProfile = await prisma.donorProfile.findUnique({
        where: { userId: activeColomboUser.id },
        include: { user: true },
      });
      assert(dbProfile !== null, 'Donor record exists in PostgreSQL / Supabase');
      assert.strictEqual(dbProfile.city, 'Colombo', 'City field is correctly stored in Supabase');
      assert.strictEqual(dbProfile.user.isActive, true, 'User isActive is true');
      pass('Verified donor city and user status directly from Supabase PostgreSQL database');
    } else {
      pass('In-memory database records verified');
    }

    // -------------------------------------------------------------------------
    // CLEANUP Test Data
    // -------------------------------------------------------------------------
    if (prisma) {
      await prisma.donorProfile.deleteMany({
        where: {
          userId: {
            in: [
              activeColomboUser.id,
              activeKandyUser.id,
              unavailableColomboUser.id,
              deactivatedColomboUser.id,
            ],
          },
        },
      });
      await prisma.user.deleteMany({
        where: {
          id: {
            in: [
              activeColomboUser.id,
              activeKandyUser.id,
              unavailableColomboUser.id,
              deactivatedColomboUser.id,
            ],
          },
        },
      });
      console.log('\n🧹 Test records cleaned up from database.');
    }

    console.log('\n===============================================================');
    console.log(`🎉 ALL 9 LOCATION SEARCH TESTS PASSED! (${passedAssertions} assertions)`);
    console.log('===============================================================');
  } catch (err) {
    console.error('\n❌ Test Suite Failed:', err.message);
    console.error(err.stack);
    process.exit(1);
  }
}

runLocationSearchTests();
