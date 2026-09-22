'use strict';

/**
 * KU Attendance — Cloud Functions
 *
 * The single authoritative endpoint for marking attendance. The Flutter client
 * NEVER writes attendance records directly (Firestore rules deny it); it calls
 * this callable, which runs with the Admin SDK and is the sole judge of:
 *
 *   1. Identity      — the caller is authenticated and is an active student.
 *   2. Session       — the session exists and is still active.
 *   3. Time          — the session has not expired, measured on the SERVER
 *                      clock (startedAt + durationMinutes), never the client's.
 *   4. OTP           — the submitted code matches the secret in the locked
 *                      `private/otp` subcollection (which students cannot read).
 *   5. Enrollment    — the student is enrolled in the session's course.
 *   6. Geofence      — the student is within `radius` metres of the lecturer,
 *                      by the Haversine formula, using server-held coordinates.
 *   7. No duplicates — a transaction on the record document (id == studentId)
 *                      makes a second mark structurally impossible.
 *
 * Every rejection is thrown as an HttpsError whose message is safe to show to
 * the user; the client maps the error code to a friendly message too.
 */

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

initializeApp();
const db = getFirestore();

// Must match lib/core/constants/app_constants.dart.
const REGION = 'us-central1';
const OTP_LENGTH = 4;
const MAX_ACCURACY_METERS = 50;
// Guards against a stuck GPS fix being replayed in a tight loop.
const MIN_SECONDS_BETWEEN_MARKS = 2;

const SESSIONS = 'attendanceSessions';
const RECORDS = 'records';
const PRIVATE = 'private';
const OTP_DOC = 'otp';
const USERS = 'users';
const ENROLLMENTS = 'enrollments';

const EARTH_RADIUS_METERS = 6371000.0;

function toRadians(deg) {
  return (deg * Math.PI) / 180.0;
}

/** Great-circle distance in metres — mirrors Geo.distanceMeters in Dart. */
function distanceMeters(lat1, lon1, lat2, lon2) {
  const dLat = toRadians(lat2 - lat1);
  const dLon = toRadians(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRadians(lat1)) *
      Math.cos(toRadians(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return EARTH_RADIUS_METERS * c;
}

function isValidCoordinate(lat, lng) {
  return (
    typeof lat === 'number' &&
    typeof lng === 'number' &&
    lat >= -90 &&
    lat <= 90 &&
    lng >= -180 &&
    lng <= 180 &&
    !(lat === 0 && lng === 0)
  );
}

function enrollmentId(courseId, studentId) {
  return `${courseId}__${studentId}`;
}

exports.markAttendance = onCall({ region: REGION }, async (request) => {
  // 1. Authentication -------------------------------------------------------
  const auth = request.auth;
  if (!auth || !auth.uid) {
    throw new HttpsError('unauthenticated', 'You must be signed in to mark attendance.');
  }
  const uid = auth.uid;

  // 2. Input validation -----------------------------------------------------
  const data = request.data || {};
  const sessionId = data.sessionId;
  const otp = data.otp;
  const latitude = data.latitude;
  const longitude = data.longitude;
  const accuracy = data.accuracy;
  const isMocked = data.isMocked === true;

  if (typeof sessionId !== 'string' || sessionId.length === 0) {
    throw new HttpsError('invalid-argument', 'Missing session.');
  }
  if (typeof otp !== 'string' || !new RegExp(`^\\d{${OTP_LENGTH}}$`).test(otp)) {
    throw new HttpsError('invalid-argument', `Enter the ${OTP_LENGTH}-digit code from your lecturer.`);
  }
  if (!isValidCoordinate(latitude, longitude)) {
    throw new HttpsError('invalid-argument', 'Your location could not be read. Try again.');
  }
  if (isMocked) {
    throw new HttpsError('failed-precondition', 'Mock locations are not allowed. Turn off any fake GPS app.');
  }
  if (typeof accuracy === 'number' && accuracy > MAX_ACCURACY_METERS) {
    throw new HttpsError(
      'failed-precondition',
      'Your location is not precise enough. Move to an open area and try again.'
    );
  }

  // 3. Identity: active student --------------------------------------------
  const userSnap = await db.collection(USERS).doc(uid).get();
  if (!userSnap.exists) {
    throw new HttpsError('permission-denied', 'Your profile was not found.');
  }
  const user = userSnap.data();
  if (user.role !== 'student') {
    throw new HttpsError('permission-denied', 'Only students can mark attendance.');
  }
  if (user.isActive === false) {
    throw new HttpsError('permission-denied', 'Your account is disabled. Contact the administrator.');
  }

  // 4. Session exists and is active ----------------------------------------
  const sessionRef = db.collection(SESSIONS).doc(sessionId);
  const sessionSnap = await sessionRef.get();
  if (!sessionSnap.exists) {
    throw new HttpsError('not-found', 'This attendance session no longer exists.');
  }
  const session = sessionSnap.data();
  if (session.isActive !== true) {
    throw new HttpsError('failed-precondition', 'This session has been closed.');
  }

  // 5. Server-clock expiry --------------------------------------------------
  const startedAt = session.startedAt; // Firestore Timestamp
  if (!startedAt || typeof startedAt.toMillis !== 'function') {
    throw new HttpsError('failed-precondition', 'This session is not ready yet. Try again in a moment.');
  }
  const durationMinutes = Number(session.durationMinutes) || 0;
  const expiryMillis = startedAt.toMillis() + durationMinutes * 60 * 1000;
  if (Date.now() > expiryMillis) {
    throw new HttpsError('deadline-exceeded', 'This session has expired.');
  }

  // 6. OTP matches the secret in the locked subcollection -------------------
  const otpSnap = await sessionRef.collection(PRIVATE).doc(OTP_DOC).get();
  const expectedOtp = otpSnap.exists ? otpSnap.data().otp : null;
  if (!expectedOtp || String(expectedOtp) !== otp) {
    throw new HttpsError('permission-denied', 'Incorrect attendance code.');
  }

  // 7. Enrollment -----------------------------------------------------------
  const courseId = session.courseId;
  const enrollSnap = await db
    .collection(ENROLLMENTS)
    .doc(enrollmentId(courseId, uid))
    .get();
  if (!enrollSnap.exists || enrollSnap.data().isActive !== true) {
    throw new HttpsError('permission-denied', 'You are not enrolled in this course.');
  }

  // 8. Geofence (server-held lecturer coordinates) --------------------------
  const distance = distanceMeters(
    Number(session.latitude),
    Number(session.longitude),
    latitude,
    longitude
  );
  const radius = Number(session.radius) || 0;
  if (distance > radius) {
    throw new HttpsError(
      'failed-precondition',
      `You are too far from the class (${Math.round(distance)} m away, limit ${Math.round(radius)} m).`
    );
  }

  // 9. Duplicate-safe write in a transaction --------------------------------
  const recordRef = sessionRef.collection(RECORDS).doc(uid);

  await db.runTransaction(async (tx) => {
    const existing = await tx.get(recordRef);
    if (existing.exists) {
      const prev = existing.data();
      // Structural dedupe: the record already exists for this student.
      // (A soft rate-limit guard for rapid retries within the same session.)
      if (prev.markedAt && typeof prev.markedAt.toMillis === 'function') {
        const since = (Date.now() - prev.markedAt.toMillis()) / 1000;
        if (since < MIN_SECONDS_BETWEEN_MARKS) {
          throw new HttpsError('resource-exhausted', 'Please wait a moment and try again.');
        }
      }
      throw new HttpsError('already-exists', 'You have already marked attendance for this session.');
    }

    // Re-assert the session is still open at write time.
    const freshSession = await tx.get(sessionRef);
    if (!freshSession.exists || freshSession.data().isActive !== true) {
      throw new HttpsError('failed-precondition', 'This session has been closed.');
    }

    tx.set(recordRef, {
      studentId: uid,
      studentName: user.name || '',
      admissionNumber: user.admissionNumber || null,
      courseId: courseId,
      courseCode: session.courseCode || null,
      courseName: session.courseName || null,
      sessionId: sessionId,
      latitude: latitude,
      longitude: longitude,
      distanceFromLecturer: Math.round(distance * 10) / 10,
      status: 'present',
      markedAt: FieldValue.serverTimestamp(),
    });

    tx.update(sessionRef, { presentCount: FieldValue.increment(1) });
  });

  return {
    status: 'present',
    distance: Math.round(distance * 10) / 10,
    message: 'Attendance marked successfully.',
  };
});
