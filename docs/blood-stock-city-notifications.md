# City-based blood stock notifications

This extends the existing BloodStock CRUD and Notification table. Registration, OTP/email verification, emergency contacts, verification queue, donor operations, and blood requests are unchanged.

## Ownership and recipient selection

The server resolves JWT user ID → active database manager/admin → User.branchId → BloodBankBranch. The branch has an operator-verified name and structured city. Stock operations use BloodStock.branchId. GET lists only that branch; reading, updating, or deleting another branch's row is forbidden. A manager cannot supply branchId or city, and cannot change location to a different branch. Branch assignment is available only through the trusted operator utility below, never a public registration/profile endpoint.

Donors and recipients use their existing DonorProfile.city. Despite its name, registration already creates that profile for recipients when their patient blood group is supplied; the Flutter registration form supplies blood group and city. Caregiver is the existing recipient role. No profile or registration behavior was changed. Users without a stored profile/city are excluded; hospital addresses and BloodRequest locations are not a substitute for home city.

Cities are compared with trim().toLowerCase() and exact equality. All active same-city donors and recipients receive an unread BLOOD_STOCK_UPDATE notification. Blood group does not restrict delivery. Managers/admins, inactive users, missing/blank cities, other cities, and the actor are excluded. The manager response exposes only stock data and notificationsSent, never recipient identities.

Notifications reuse Notification.userId, title, message, type, isRead and timestamp. No metadata or second notification table was added. Title/message contain blood group, branch name, city, units and status; the existing Flutter screen shows timestamp. It fetches again on opening. Flutter fallback is scoped to the requested user instead of fetching everybody's notifications after an error. There is no working FCM transport in this project; the existing FCM-token field and simulator are not push delivery. This feature persists in-app notifications only.

PATCH generates alerts only when units, status or blood group changes. Initial POST notifies only when status is Available and units are positive. The existing create validation still requires at least one unit; it was preserved. Unavailable/Reserved creation and DELETE are silent. Stock changes and createMany notification inserts share a transaction; an insert failure rolls back the stock write. Stock row locking ensures simultaneous identical updates notify once. The manager form shows the assigned branch as read-only and displays the returned count after saving.

## Apply the additive schema manually

The complete file is backend/prisma/blood-stock-city-notifications.sql. It creates only BloodBankBranch, adds nullable branchId columns/FKs to existing User and BloodStock, and adds a stock branch index. It does not create/recreate BloodStock or Notification, delete records, change stock values, or infer assignments. The existing bloodGroup/location uniqueness is retained. Existing rows remain with null branchId until deliberately assigned.

Run from the repository backend directory. Set DATABASE_URL in this shell to the existing PostgreSQL connection string from backend/.env, without editing that file. This command is for you to run after reviewing the SQL; Codex has not executed it:

```sh
cd blood-donor-emergency-app_Group_WE55/backend
export DATABASE_URL='YOUR_EXISTING_SUPABASE_POSTGRES_CONNECTION_STRING'
psql --dbname="$DATABASE_URL" --set=ON_ERROR_STOP=1 --file=prisma/blood-stock-city-notifications.sql
npx prisma format
npx prisma validate
npx prisma generate
```

Alternatively paste the complete SQL file into the Supabase SQL editor and execute it manually. The existing BloodStock table must already exist. This feature deliberately does not recreate that table if it is missing.

## Safely assign existing managers and stock

Complete assignments before restarting/deploying the updated backend to avoid an interim access interruption. Until assigned, managers receive an explanatory 403 and unassigned stock cannot be accessed through the manager CRUD; all legacy data remains in PostgreSQL. Assignment immediately restores access on the next API request; login/account replacement is unnecessary.

1. Inspect exact existing IDs and manually verify each branch's name, city, manager, and inventory ownership:

```sh
node src/scripts/setup-blood-stock-branches.js inspect
```

2. Create the real branch. The ID below is an explicit stable example; choose a distinct ID for every real branch and use its verified city, not a guessed substring of an address. Use branch-qualified names such as National Blood Bank - Colombo; the retained stock bloodGroup/location uniqueness can reject a new row if two branches use identical names for the same blood group.

```sh
node src/scripts/setup-blood-stock-branches.js create-branch --id lifelink-colombo --name 'National Blood Bank - Colombo' --city Colombo
```

3. Assign the existing coordinator by exact User ID, keeping their account, password, role, and other records:

```sh
node src/scripts/setup-blood-stock-branches.js assign-manager --manager-id 'EXISTING_MANAGER_USER_ID' --branch-id lifelink-colombo
```

4. Associate each verified existing inventory row by exact BloodStock ID. Repeat for EVERY row owned by that branch, including multiple historical rows with the same blood group. No new uniqueness constraint prevents assigning legitimate legacy rows:

```sh
node src/scripts/setup-blood-stock-branches.js assign-stock --stock-id 'EXISTING_BLOOD_STOCK_ID' --branch-id lifelink-colombo
node src/scripts/setup-blood-stock-branches.js inspect
```

Assign every other manager and stock row to its verified branch using the same procedure. Several coordinators may share the same branch; each coordinator has one assigned branch. Do not assign unrelated rows merely to make them visible. Legacy stock location text, blood group, units and status remain unchanged; subsequent normal edits also preserve that location text. Assignment updates Prisma's audit timestamp but generates no availability notifications. Notifications and new rows use the verified branch name/city.

The utility reads the existing .env but does not edit it, apply schema SQL, delete records, change roles, automatically merge stock, or infer branch membership. It refuses a different existing assignment. Repeating the same assignment is safe. If an existing assignment is wrong, review ownership with a trusted database administrator before an explicit correction; the application has no reassignment control. Users without a verified existing profile city remain excluded; do not fabricate location or patient blood groups for old accounts.

## Backend checks

From backend, run the offline HTTP integration suite (actual routes and JWT middleware, isolated fake persistence; no PostgreSQL):

```sh
npm run test:blood-stock-city
```

After applying the additive schema, use the existing .env and start the API in one terminal:

```sh
PORT=5001 npm start
```

In another terminal in backend:

```sh
BLOOD_STOCK_TEST_URL=http://127.0.0.1:5001/api npm run test:blood-stock
```

The extended existing PostgreSQL integration suite checks the schema before writes, creates unique test-only branch/user/profile/stock fixtures, checks city delivery and exclusion, ownership, original validation/CRUD, duplicate suppression and concurrent identical saves, then cleans only the exact fixture IDs (notifications/profiles cascade with test users). It never runs schema SQL or resets data.

From the Flutter project root:

```sh
flutter analyze
flutter test test/blood_stock_management_test.dart test/blood_stock_notification_test.dart
flutter devices
flutter run
```

Choose an Android emulator when prompted. The existing API default is http://10.0.2.2:5001/api. For a physical device or another platform, use the existing API URL setting with the backend's reachable address.

## Manual notification test

Use a branch with city Colombo and active donor/recipient accounts whose existing DonorProfile.city is Colombo. Confirm a different-city account is available for exclusion checks. No additional Firebase configuration is required.

Manager: Blood Bank / Hospital → Continue as Coordinator → Manager Login → Manager Dashboard → Blood Stock Management → Edit O+ → change units to 15 and status to Available → Save. The branch field must be read-only and the snackbar must show the local count. Saving the exact same values again must show 0 local users notified.

Donor: Donor Login → Notifications → All or Unread → see O+ Blood Stock Update with branch/city, 15 units, Available and time.

Recipient/Caregiver: Recipient/Caregiver Login → Notifications → All or Unread → see the same local update. Reopen Notifications to fetch new rows when using an already signed-in session. The existing Emergency filter intentionally excludes stock updates.

Different-city and inactive accounts receive no persisted stock update. Test the in-app list; this is not OS push delivery. Delete inventory only when you intentionally want to remove that row; deletion never sends an availability alert.

## Changed files

Created: backend/prisma/blood-stock-city-notifications.sql; backend/src/services/blood-stock-notification.service.js; backend/src/scripts/test-blood-stock-city-notifications.js; backend/src/scripts/setup-blood-stock-branches.js; test/blood_stock_notification_test.dart; this document.

Modified: backend/package.json; backend/prisma/schema.prisma; backend/src/middleware/blood-stock-auth.middleware.js; backend/src/routes/blood-stock.routes.js; backend/src/scripts/test-blood-stock-crud.js; lib/models/blood_stock_model.dart; lib/services/blood_stock_service.dart; lib/providers/blood_stock_provider.dart; lib/screens/manager/blood_stock_management_screen.dart; lib/providers/notification_provider.dart; lib/services/notification_service.dart; lib/screens/notifications/notifications_screen.dart; test/blood_stock_management_test.dart; docs/blood-stock-management.md.

## Validation for this implementation

Prisma format, validate and generate passed. Offline city/stock HTTP integration: 23 tests passed. Existing profile-verification regression: 1 test passed. Flutter analyze: no issues. Full Flutter suite: 67 tests passed, including the manager count/read-only branch test and donor/recipient stock notification rendering. JavaScript syntax and git diff whitespace checks passed.

The live PostgreSQL integration test connected successfully but stopped during schema preflight because public.BloodBankBranch does not exist yet. No test fixtures were created. Apply the reviewed additive SQL manually, assign real branches, restart the updated API, then run the exact live test command above. Database SQL and branch assignments were not executed by Codex. No commits or pushes were made.
