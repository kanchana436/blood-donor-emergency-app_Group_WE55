// Blood Compatibility Rules
const canDonateTo = {
  'O-': ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'], // Universal Donor
  'O+': ['O+', 'A+', 'B+', 'AB+'],
  'A-': ['A+', 'A-', 'AB+', 'AB-'],
  'A+': ['A+', 'AB+'],
  'B-': ['B+', 'B-', 'AB+', 'AB-'],
  'B+': ['B+', 'AB+'],
  'AB-': ['AB+', 'AB-'],
  'AB+': ['AB+'],
};

function isCompatible(donorGroup, recipientGroup) {
  const allowed = canDonateTo[donorGroup];
  return allowed ? allowed.includes(recipientGroup) : false;
}

// Haversine distance in kilometers
function calculateDistance(lat1, lon1, lat2, lon2) {
  const p = 0.017453292519943295; // Math.PI / 180
  const a =
    0.5 -
    Math.cos((lat2 - lat1) * p) / 2 +
    (Math.cos(lat1 * p) * Math.cos(lat2 * p) * (1 - Math.cos((lon2 - lon1) * p))) / 2;
  return 12742 * Math.asin(Math.sqrt(a)); // 2 * R; R = 6371 km
}

/**
 * Matching Algorithm:
 * Returns ranked suitable donors for an emergency request
 */
function findSuitableDonors(request, availableDonors, maxDistanceKm = 30) {
  const matches = [];

  for (const donor of availableDonors) {
    // 1. Availability check
    if (!donor.isAvailable) continue;

    // 2. Eligibility check
    if (donor.eligibilityStatus && donor.eligibilityStatus.toLowerCase() !== 'eligible') continue;

    // 3. Blood group compatibility check
    if (!isCompatible(donor.bloodGroup, request.bloodGroup)) continue;

    // 4. Distance calculation
    const distanceKm = calculateDistance(
      request.latitude || 6.9271,
      request.longitude || 79.8612,
      donor.latitude || 6.9271,
      donor.longitude || 79.8612
    );

    if (distanceKm <= maxDistanceKm) {
      matches.push({
        id: `dr_${Date.now()}_${matches.length}`,
        requestId: request.id,
        donorId: donor.userId,
        donorName: donor.userName || 'Verified Donor',
        donorPhone: donor.userPhone || '+94 77 123 4567',
        donorBloodGroup: donor.bloodGroup,
        status: 'Pending',
        distanceKm: Math.round(distanceKm * 10) / 10,
        respondedAt: new Date().toISOString(),
      });
    }
  }

  // Sort by closest distance first
  return matches.sort((a, b) => a.distanceKm - b.distanceKm);
}

module.exports = {
  isCompatible,
  calculateDistance,
  findSuitableDonors,
};
