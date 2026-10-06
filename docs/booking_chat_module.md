# Booking, Chat & Counselor Dashboard module

Owner: **Rathnayaka**. Folders: `lib/features/booking`, `lib/features/chat`,
`lib/features/counselor_dashboard`.

## 1. Interfaces and CRUD

| # | Interface | File | Create | Read | Update | Delete |
|---|-----------|------|--------|------|--------|--------|
| 1 | Book a Session | `booking/presentation/screens/book_session_screen.dart` | Book appointment | Counselors, live free slots | – | – |
| 2 | Booking Confirmation | `booking/presentation/screens/booking_confirmation_screen.dart` | – | Booking summary | – | – |
| 3 | My Appointments | `booking/presentation/screens/my_appointments_screen.dart` | – | Upcoming / past (live) | Cancel | Remove from history |
| 4 | Reschedule | `booking/presentation/screens/reschedule_screen.dart` | – | Current booking, free slots | New date/time | – |
| 5 | Chat inbox | `chat/presentation/screens/chat_list_screen.dart` | Start chat | Conversations (live) | – | Swipe to delete chat |
| 6 | Anonymous Chat | `chat/presentation/screens/chat_screen.dart` | Send message | Messages (live) | Edit own message | Delete own message |
| 7 | Counselor Dashboard | `counselor_dashboard/presentation/screens/counselor_dashboard_screen.dart` | Session note | Requests, sessions, stats | Accept (with meeting details) / decline (with reason) / complete | – |
| 8 | Student Home | `booking/presentation/screens/student_home_screen.dart` | – | Counselors (search + topic filter), next session, updates | – | – |
| 9 | Counselor Details | `booking/presentation/screens/counselor_details_screen.dart` | Book appointment, start chat | Profile, open slots, meeting types | – | – |
| 10 | My Availability (counselor) | `counselor_dashboard/presentation/screens/availability_screen.dart` | Add days off | Saved schedule | Weekly hours, meeting types | Remove day off, reset schedule |

**Meeting types:** Video call, Phone call, In person, Text chat. Each counselor
chooses which types they offer; students can only book those. When accepting, the
counselor adds the meeting details (video link, room, call note), which the
student sees on the booking. When declining, the counselor picks or writes a
reason, which the student also sees.

## 2. Architecture

```
Screen (UI)  ──context.watch/read──►  Provider (ChangeNotifier: state + validation)
                                          │
                                          ▼
                              Repository (abstract interface)
                               ├─ FirestoreBookingRepository / FirestoreChatRepository  (production)
                               └─ InMemory…Repository                                  (tests, offline demo)
```

* **Provider** for state management. Screens never talk to Firestore directly.
* **Repository pattern**, so the UI and providers can be tested without Firebase.
* **Real-time**: every list is a Firestore `snapshots()` stream. When a counselor
  accepts a booking, the student's screen updates with no refresh.

## 3. Firestore data model

```
users/{uid}                  name, role ('student' | 'counselor' | 'admin'), title,
                             specialization, about, languages[]
appointments/{id}            studentId, studentAlias, counselorId, counselorName,
                             dateTime, mode ('online'|'inPerson'), reason,
                             status ('pending'|'confirmed'|'declined'|'cancelled'|'completed'),
                             counselorNote, meetingInfo, declineReason,
                             createdAt, updatedAt
availability/{counselorId}   hours {"1": [9,10,…], …}, meetingTypes[], daysOff[],
                             updatedAt  (no document = default weekdays 9–5)
booked_slots/{counselorId_yyyyMMddHHmm}
                             counselorId, studentId, appointmentId, dateTime
chats/{studentId_counselorId}
                             studentId, studentAlias, counselorId, counselorName,
                             participants[], lastMessage, updatedAt
chats/{id}/messages/{id}     senderId, text, sentAt, editedAt
```

**Preventing double booking:** every reserved slot has a document with a fixed id
(`counselorId_yyyyMMddHHmm`). Booking runs in a Firestore **transaction**: if that
document already exists, the booking is rejected (`SlotUnavailableException`).
The security rules (`firestore.rules`) only allow *creating* a slot document,
never overwriting one. Cancel, decline and delete release the slot.

All queries are single-field equality queries, so **no composite indexes** are needed.

## 4. How to run

### Offline demo (no Firebase needed)
```
flutter pub get
flutter run -t lib/dev/booking_chat_demo_main.dart --dart-define=USE_FIREBASE=false
```
Choose **Continue as student** or **Continue as counselor**. Both roles share the
same data, so a booking made as the student appears on the counselor's dashboard
after tapping **Switch**.

### With Firebase (default on Android)
The app is connected to the team project **`mindcheck-app-c6452`**
(`android/app/google-services.json`, `lib/firebase_options.dart`).
1. A project owner creates the **Firestore database** (test mode, `asia-south1`).
2. `flutter run -t lib/dev/booking_chat_demo_main.dart` on an Android emulator or phone.
3. Tap **Add demo counselors to Firestore** once.
4. After login is merged, publish `firestore.rules` (Firebase console → Firestore → Rules).

> The demo runs without signing in. With the rules above, Firestore only
> accepts requests from signed-in users, so for a Firebase demo before auth is
> merged, use test-mode rules temporarily.

### Build an APK
```
flutter build apk --release -t lib/dev/booking_chat_demo_main.dart
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

### Run the tests
```
flutter test test/features
```

## 5. Integration with the rest of the app

Wrap the app's navigator with `BookingChatScope` once the user has logged in
(see the comment in `lib/features/booking/booking_chat_scope.dart`):

```dart
MaterialApp(
  builder: (context, child) => user == null
      ? child!
      : BookingChatScope(
          user: SessionUser(id: user.uid, name: user.name,
              role: user.role == 'counselor' ? UserRole.counselor : UserRole.student),
          child: child!,
        ),
)
```

Then use these screens in the bottom navigation:
* Students: `BookSessionScreen`, `MyAppointmentsScreen`, `ChatListScreen`
* Counselors: `CounselorDashboardScreen`, `ChatListScreen`

Needs from teammates:
* **Auth (Shanikha):** `uid`, `name`, `role` of the logged-in user; `users` docs with `role: 'counselor'`.
* **Navigation (Shanikha):** tabs pointing at the screens above.
* **Notifications (Ruwandi), optional:** listen to `appointments` status changes.

## 6. Functional test cases (automated, `test/features`)

| ID | Requirement | Steps | Expected result |
|----|-------------|-------|-----------------|
| TC-B01 | View counselors | Open Book Session | Counselor list shown |
| TC-B02 | Book session | Pick counselor, free slot, confirm | Appointment saved as *Pending* |
| TC-B03 | Validation | Book a past time | Rejected with message |
| TC-B04 | Validation | Book outside 9–5 / lunch hour | Rejected |
| TC-B05 | No double booking | Two students book the same slot | Second gets "slot just booked" |
| TC-B06 | Live availability | Book a slot | Slot shows as *Booked* to others |
| TC-B07 | Validation | Reason > 300 chars | Rejected |
| TC-B08 | Reschedule | Move session to new free slot | New time saved, back to *Pending*, old slot freed |
| TC-B09 | Reschedule | Move to a taken slot | Rejected |
| TC-B10 | Cancel | Cancel and confirm the dialog | Status *Cancelled*, slot freed |
| TC-B11 | Delete | Remove a past session | Removed from history |
| TC-B12 | Security | Change another student's booking | Rejected |
| TC-B13 | Validation | Cancel an already-cancelled session | Rejected |
| TC-C01 | Send message | Type and send | Appears for counselor in real time |
| TC-C02 | Validation | Send empty message | Send button disabled / rejected |
| TC-C03 | Validation | Message > 1000 chars | Rejected |
| TC-C04 | Edit message | Long-press own message → Edit | Text updated, marked *edited* |
| TC-C05 | Delete message | Long-press own message → Delete | Removed, preview updated |
| TC-C06 | Security | Edit/delete someone else's message | Rejected |
| TC-C07 | Delete chat | Swipe conversation → Delete | Removed for both sides |
| TC-C08 | Anonymity | Counselor opens chat | Sees alias, not the real name |
| TC-C09 | Continuity | Reopen chat with same counselor | Same conversation |
| TC-D01 | Accept | Counselor taps Accept | Student sees *Confirmed* |
| TC-D02 | Decline | Counselor declines | Student sees *Declined*, slot freed |
| TC-D03 | Complete | Mark started session complete | Completed count +1 |
| TC-D04 | Note | Add a session note | Note saved |
| TC-D05 | Security | Student tries to accept | Rejected |
| TC-D06 | Anonymity | Dashboard lists requests | Only aliases shown |
| TC-D07 | Accept details | Accept with a room / link | Student sees the meeting details |
| TC-D08 | Decline reason | Decline with a reason | Student sees "Declined" and the reason |
| TC-A01 | Availability | Counselor opens only 2 PM on a day | Students only see 2 PM; 10 AM is rejected |
| TC-A02 | Days off | Counselor adds a day off | No bookings possible that day |
| TC-A03 | Meeting types | Counselor offers in person only | Video booking rejected, in person accepted |
| TC-A04 | Validation | Save with no meeting types | Rejected |
| TC-A05 | Security | Student edits a counselor's availability | Rejected |
| TC-A06 | Reset | Reset schedule | Back to default hours |
| TC-UI01–06 | UI flows | Book end to end, cancel, accept with details, chat send, home search, book from details page | Pass on the real screens |

## 7. Usability test tasks (for the 5-participant test)

1. Book an online session with a stress & anxiety counselor for next week.
2. Move that session to a different day.
3. Send the counselor a message saying you'll be 5 minutes late, then fix a typo in it.
4. Cancel a session you no longer need.
5. (Counselor role) Accept one request and add a video link, then decline another with a reason.
6. (Counselor role) Close Friday afternoons and add next Monday as a day off.

Measure: completion (yes/no), time on task, errors, SEQ (1–7) after each task,
SUS questionnaire at the end.

## 8. HCI design decisions (for the viva)

* **Team visual style** (`lib/core/constants/app_colors.dart`, `lib/core/theme/app_theme.dart`),
  following the 60-30-10 rule:
  * 60% background `#F7F5FA` (soft lavender off-white)
  * 30% sage `#7FB3A8`: appointment cards, stat tiles, avatars, selected time slots
  * 10% accent: purple `#9B7EDE` for buttons and CTAs, coral `#FF9F87` for the helpline banner
  * No harsh red: errors and destructive actions use a soft terracotta `#C0563F`
  * Fonts: Poppins (headings), Nunito Sans (body), via `google_fonts`

* **Error prevention**: booked and past slots are disabled, so users can't pick
  an invalid time. Destructive actions (cancel, delete) always ask for
  confirmation.
* **Visibility of system status**: status chips (Pending / Confirmed / …) use
  icon + colour + text (colour-blind safe). Buttons show progress while saving.
* **Privacy by design**: counselors only see an anonymous alias
  (e.g. "Calm Owl"). The alias is stable, so returning students are recognisable
  without revealing who they are.
* **Recognition over recall**: the selected counselor/date/time summary sits
  above the Confirm button, and the confirmation screen repeats every detail.
* **Safety**: the student chat screen shows the 1926 National Mental Health
  Helpline.
* **Accessibility**: semantic labels on chips, bubbles and stat cards; 48 dp
  touch targets; light and dark theme.
