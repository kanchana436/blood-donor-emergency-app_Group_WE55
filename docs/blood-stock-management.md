# Blood stock management

Managers/admins enter a dedicated manager navigation after login or email verification. It contains Blood Stock and the existing Profile screen. Recipient navigation is unchanged. Switching the profile to donor/recipient mode uses the existing behavior; sign in again to return to manager navigation. Selecting manager in the role picker does not grant stock access: the API checks the authenticated user's active role in PostgreSQL.

Stock operations always use the existing authenticated ApiService and Prisma. There is no mock fallback. Supabase failures are reported as errors. Server-managed `updatedAt` is displayed as Last Updated in the device's local timezone.

## Database model

```prisma
model BloodStock {
  id             String   @id @default(uuid())
  bloodGroup     String
  availableUnits Int      @default(0)
  location       String
  status         String   @default("Available")
  createdAt      DateTime @default(now())
  updatedAt      DateTime @updatedAt

  @@unique([bloodGroup, location])
}
```

UUIDs and timestamps are managed by Prisma. Locations are trimmed before persistence. Uniqueness is blood group plus exact trimmed location (case-sensitive). Status values: Available, Unavailable, Reserved. Creation requires 1–2147483647 units; updates allow 0–2147483647. Critical validation is repeated in the backend. PATCH permits only the four editable fields and at least one must be supplied. Last Updated is automatic and should not be sent in request bodies. DELETE permanently removes only the selected BloodStock row; the model has no foreign keys or cascading relations.

## Setup commands

From the project root:

```sh
cd backend
npx prisma validate
```

Ensure the existing backend `.env` has the intended Supabase `DATABASE_URL`, existing `JWT_SECRET`, and `PORT=5001`. Do not paste credentials into source files or documentation. Review `prisma/blood-stock.sql`, then apply it once:

```sh
npx prisma db execute --file prisma/blood-stock.sql --schema prisma/schema.prisma
npx prisma generate
npm start
```

The SQL transaction creates only BloodStock and its unique index. It neither alters existing tables nor removes data; an existing BloodStock table causes an error rather than replacing it. It is intentionally standalone additive SQL, not a reset or full-schema synchronization. This repository currently has no Prisma migration history; record this addition in the team's deployment history and baseline it when adopting Prisma Migrate.

Use another terminal for backend integration tests, with the server above running against the same database and `.env`:

```sh
cd backend
npm run test:blood-stock
```

Requires Node with built-in fetch (Node 18+). Tests use the existing PORT, defaulting to 5001. Optionally set BLOOD_STOCK_TEST_URL to the server's API URL. The suite first checks the stock table exists, then creates uniquely named real manager/donor accounts and stock fixtures. It tests real API requests and checks persistence directly through Prisma. Cleanup targets only IDs created by this test. If the process is interrupted, review the uniquely named blood-stock-test-* fixtures before removing them.

From the project root:

```sh
flutter analyze --no-pub
flutter test --no-pub
flutter run
```

The existing Android emulator URL remains `http://10.0.2.2:5001/api`; the service has no second base URL. If the app previously saved a custom API URL, its existing saved setting takes precedence.

## API endpoints

Every endpoint requires `Authorization: Bearer <token>` from an active manager/admin account in PostgreSQL.

| Method | Endpoint | Behavior |
| --- | --- | --- |
| POST | /api/blood-stock | Create; 201 |
| GET | /api/blood-stock | List all; 200 |
| GET | /api/blood-stock?bloodGroup=O%2B | Filter O+; 200 |
| GET | /api/blood-stock/:id | Read one; 200 |
| PATCH | /api/blood-stock/:id | Update supplied fields; 200 |
| DELETE | /api/blood-stock/:id | Permanently delete selected row; 200 |

Errors: 400 invalid fields/filter, 401 missing/invalid JWT or nonexistent authenticated account, 403 inactive/non-manager account, 404 unknown stock ID, 409 duplicate group/location, 500 database/server failure. Database error details are logged server-side rather than returned to clients.

### Create

POST /api/blood-stock:

```json
{
  "bloodGroup": "O+",
  "availableUnits": 12,
  "location": "National Blood Centre",
  "status": "Available"
}
```

Example successful response (timestamps and UUID are illustrative):

```json
{
  "success": true,
  "data": {
    "id": "b2c596f5-9d4c-4e4a-b901-194850fd04e4",
    "bloodGroup": "O+",
    "availableUnits": 12,
    "location": "National Blood Centre",
    "status": "Available",
    "createdAt": "2026-10-08T12:00:00.000Z",
    "updatedAt": "2026-10-08T12:00:00.000Z"
  },
  "message": "Blood stock created"
}
```

### Read

GET /api/blood-stock returns `{ "success": true, "data": [...] }`. Save the returned ID and GET /api/blood-stock/:id to get `{ "success": true, "data": { ... } }`. Encode plus signs as `%2B` in filters; Flutter does this automatically.

### Update

PATCH /api/blood-stock/:id:

```json
{
  "availableUnits": 0,
  "status": "Unavailable",
  "location": "National Blood Centre"
}
```

Returns the updated row with `success: true` and `message: "Blood stock updated"`. Re-read by ID and confirm the new values and updated timestamp.

### Delete

DELETE /api/blood-stock/:id returns:

```json
{ "success": true, "message": "Blood stock deleted" }
```

GET the same ID afterward: expect 404. An unrelated record should remain unchanged.

### Validation checks

Submit negative, fractional or string units: expect 400. Submit bloodGroup C+: expect 400. Submit an empty location or invalid status: expect 400. Repeat the same group/location: expect 409, including when surrounding location whitespace differs. Attempt to update another row to an existing group/location: expect 409. Omit the JWT: expect 401. Use a donor/recipient JWT: expect 403. Changing only a role claim on a signed donor token does not grant access; the database role is authoritative.

Example error:

```json
{ "success": false, "message": "Stock already exists for this blood group and location" }
```

## Flutter walkthrough

1. Log in with an active, verified manager/admin account stored in Supabase. The authenticated role determines manager navigation.
2. Tap Add stock. Select a blood group, enter positive whole units, location and status, then Add. Verify the success message and list row.
3. Tap Refresh or pull down. Filter O+ and check that it remains visible. Restart/login again and confirm persistence.
4. Tap the row's edit icon. Change units/status/location, then Save. Zero units are permitted on update. Check Last Updated.
5. Try invalid input and a duplicate record; errors should keep the form open. Save is disabled while the request is pending.
6. Tap Delete. Cancel first to verify the record remains. Confirm on the next attempt; refresh to verify it is gone.
7. Log in as a recipient: their navigation should retain its existing tabs with no stock management tab.

## Prisma Studio verification

From backend:

```sh
npx prisma studio
```

Open BloodStock in Studio. After creating in Flutter, filter by the returned ID or location and compare bloodGroup, availableUnits, location, status, createdAt and updatedAt. After editing, refresh Studio and compare changed values. After deletion, refresh and confirm that exact ID is absent. Check an unrelated record remains unchanged. Use the same DATABASE_URL as the running API.

## Files changed

Modified:
- backend/prisma/schema.prisma
- backend/src/server.js
- backend/package.json
- lib/core/constants/api_constants.dart (only adds the stock endpoint; preserves the existing URL edit)
- lib/main.dart
- lib/screens/auth/login_screen.dart
- lib/screens/auth/email_verification_screen.dart

Created:
- backend/prisma/blood-stock.sql
- backend/src/routes/blood-stock.routes.js
- backend/src/middleware/blood-stock-auth.middleware.js
- backend/src/scripts/test-blood-stock-crud.js
- lib/models/blood_stock_model.dart
- lib/services/blood_stock_service.dart
- lib/providers/blood_stock_provider.dart
- lib/screens/manager/manager_main_navigation.dart
- lib/screens/manager/blood_stock_management_screen.dart
- test/blood_stock_management_test.dart
- docs/blood-stock-management.md

backend/.env.example and recipient navigation were not edited. Existing uncommitted work is preserved.

## Verification performed

- Prisma validate: passed.
- Prisma client generation: passed.
- Backend JavaScript syntax checks: passed.
- Flutter analyze: passed with no issues.
- Full Flutter suite: 53 tests passed, including four new stock tests.
- Real Supabase integration preflight: connected, then stopped because public.BloodStock is absent. No test fixtures were created. The SQL has not been applied; live CRUD integration remains pending until table setup and backend startup.
