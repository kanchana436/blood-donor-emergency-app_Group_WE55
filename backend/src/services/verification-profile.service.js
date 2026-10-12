const validation = require('../utils/validation');
const userFields = ['name', 'idNumber', 'phone', 'email'];
const profileFields = ['bloodGroup', 'city', 'address', 'weightKg', 'medicalConditions', 'latitude', 'longitude'];
const validators = {
  name: validation.validateFullName, idNumber: validation.validateIdNumber,
  phone: validation.validatePhone, email: validation.validateEmail,
  bloodGroup: validation.validateBloodGroup, city: validation.validateCity,
  address: validation.validateLivingAddress, weightKg: validation.validateBodyWeight,
  latitude: value => Number.isFinite(value) && value >= -90 && value <= 90 ? { valid: true, value } : { valid: false, message: 'Invalid latitude' },
  longitude: value => Number.isFinite(value) && value >= -180 && value <= 180 ? { valid: true, value } : { valid: false, message: 'Invalid longitude' },
  medicalConditions: value => value === null || (typeof value === 'string' && value.length <= 10000)
    ? { valid: true, value: value === null ? null : value.trim() } : { valid: false, message: 'Invalid medical conditions' },
};
function issue(message, status = 400) { const e = new Error(message); e.status = status; return e; }
function cleanChanges(body, fields) {
  const data = {};
  for (const key of fields) {
    const raw = key === 'idNumber' && body.idNumber === undefined ? body.id_number : body[key];
    if (raw === undefined) continue;
    const result = validators[key](raw);
    if (!result.valid) throw issue(result.message);
    data[key] = result.value;
  }
  return data;
}
function snapshot(current, proposed) {
  const oldValues = {}, newValues = {}, changedFields = [];
  for (const [key, value] of Object.entries(proposed)) {
    const old = current[key] ?? null;
    if (old === value) continue;
    oldValues[key] = old; newValues[key] = value; changedFields.push(key);
  }
  return { oldValues, newValues, changedFields };
}
async function lockDonor(tx, id) {
  await tx.$queryRaw`SELECT "id" FROM "public"."User" WHERE "id" = ${id} FOR UPDATE`;
}
async function stageProfileChanges(prisma, id, body, medical) {
  const proposed = cleanChanges(body, medical ? profileFields : userFields);
  return prisma.$transaction(async tx => {
    await lockDonor(tx, id);
    const user = await tx.user.findUnique({ where: { id } });
    if (!user || !user.isActive || user.role !== 'donor') throw issue('An active donor account is required', 403);
    let profile = await tx.donorProfile.findUnique({ where: { userId: id } });
    const changes = snapshot(medical ? (profile || {}) : user, proposed);
    let verification = null;
    if (changes.changedFields.length) {
      const pending = await tx.verificationQueue.findFirst({ where: { submittedById: id, verificationType: 'DonorProfileUpdate', status: 'Pending' } });
      if (pending) throw issue('Your profile changes are already pending. Please wait for Blood Bank review before submitting more changes.', 409);
      if (medical && !profile && (!proposed.bloodGroup || !proposed.city)) throw issue('Blood group and city are required for a new donor medical profile');
      verification = await tx.verificationQueue.create({ data: {
        submittedById: id, verificationType: 'DonorProfileUpdate', title: 'Donor Profile Update Verification', status: 'Pending', ...changes,
      } });
    }
    // Availability is operational; it is not part of identity/medical verification.
    if (medical && profile && body.isAvailable !== undefined) {
      if (![true, false, 'true', 'false'].includes(body.isAvailable)) throw issue('Invalid availability');
      profile = await tx.donorProfile.update({ where: { userId: id }, data: { isAvailable: body.isAvailable === true || body.isAvailable === 'true' } });
    }
    const { password, ...safeUser } = user;
    return { data: medical ? (profile || { id: '', userId: id, bloodGroup: '', city: '', address: '', isAvailable: false, eligibilityStatus: 'Deferred' }) : safeUser, verification };
  });
}
async function reviewProfileChanges(tx, id, data) {
  // Lock donor first, same order as submission; re-read queue after the lock.
  const initial = await tx.verificationQueue.findUnique({ where: { id } });
  if (!initial) throw issue('Verification not found', 404);
  await lockDonor(tx, initial.submittedById);
  const record = await tx.verificationQueue.findUnique({ where: { id } });
  if (!record) throw issue('Verification not found', 404);
  if (record.verificationType === 'DonorProfileUpdate') {
    if (record.status !== 'Pending' && data.status && data.status !== record.status) throw issue('This profile request has already been reviewed', 409);
    if (data.status === 'Approved' && record.status === 'Pending') {
      const fields = record.changedFields;
      if (!Array.isArray(fields) || !fields.length || !record.newValues || !record.oldValues) throw issue('This request has no valid change snapshot');
      const user = await tx.user.findUnique({ where: { id: record.submittedById } });
      const profile = await tx.donorProfile.findUnique({ where: { userId: record.submittedById } });
      if (!user || !user.isActive) throw issue('Donor account is unavailable', 409);
      const userData = {}, profileData = {};
      for (const field of fields) {
        if (![...userFields, ...profileFields].includes(field) || !Object.hasOwn(record.newValues, field) || !Object.hasOwn(record.oldValues, field)) throw issue('Invalid change snapshot');
        const current = userFields.includes(field) ? user[field] : profile?.[field];
        if ((current ?? null) !== record.oldValues[field]) throw issue('Profile values changed since submission. Reject this request and ask the donor to resubmit.', 409);
        const cleaned = cleanChanges({ [field]: record.newValues[field] }, [field]);
        Object.assign(userFields.includes(field) ? userData : profileData, cleaned);
      }
      if (Object.keys(userData).length) await tx.user.update({ where: { id: user.id }, data: userData });
      if (Object.keys(profileData).length) {
        if (profile) await tx.donorProfile.update({ where: { userId: user.id }, data: profileData });
        else {
          if (!profileData.bloodGroup || !profileData.city) throw issue('Incomplete medical profile snapshot');
          await tx.donorProfile.create({ data: { userId: user.id, ...profileData } });
        }
      }
    }
  }
  // Never rewrite review attribution for an already completed review.
  if (record.status !== 'Pending' && data.status === record.status) {
    delete data.reviewedById; delete data.reviewedAt;
  }
  return tx.verificationQueue.update({ where: { id }, data });
}
module.exports = { stageProfileChanges, reviewProfileChanges, snapshot };
