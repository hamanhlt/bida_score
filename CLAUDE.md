# Bida Score — Project Notes

Flutter app ghi điểm bi-a (Vietnamese billiards). 4 modes: Bắn đền (penalty369),
10-Ball, 9-Ball, 8-Ball. Target: Android (chính), iOS, Web (PWA via Docker).

## Build / Test / Run

```
flutter analyze        # phải sạch trước khi commit
flutter test           # 26 tests trong test/app_flow_test.dart
flutter run            # debug build (chọn device)
flutter build web --release
```

Web deploy: `Dockerfile` multi-stage — stage 1 (`cirruslabs/flutter:stable`)
chạy `flutter build web --release`, stage 2 (`nginx:1.27-alpine`) serve static
(SPA fallback + gzip qua `nginx.conf`). Trên server chỉ cần `git pull` rồi
`docker compose up -d --build` — không cần build local. Build lần đầu ~5-10 phút.
PiP (Android): native MethodChannel trong `android/app/.../MainActivity.kt`.

## Kiến trúc

```
lib/
├── main.dart           # preload state từ disk → ProviderScope.overrides
├── app.dart            # MaterialApp + theme + _AppShell routing theo mode
├── logic/              # Engine pure functions (không Riverpod, không I/O)
│   ├── game_engine.dart       # Bắn đền
│   └── nine_ball_engine.dart  # race-to-X (9/8/10-Ball share)
├── providers/          # Riverpod NotifierProvider — wrap engine + ref disk
├── models/             # Plain data + JSON serialization
├── services/           # SharedPreferences persistence (static methods)
├── screens/            # ConsumerWidget UI
├── widgets/            # Shared widgets (BallIcon, BallActionButton, ...)
└── theme/app_colors.dart  # Palette dùng chung
```

**Routing**: `_AppShell` ở [app.dart](lib/app.dart) chọn shell theo `gameState.gameMode`:
- `penalty369` → SetupScreen / GameScreen / ResultScreen
- `nineBall` / `eightBall` / `tenBall` → NineBallSetupScreen / NineBallGameScreen / NineBallResultScreen (cùng controller)

## State management pattern

**Engine pure** (input state → output state, throw on validation fail):
```dart
NineBallState winRack(NineBallState state, int winnerIndex) { ... }
```

**Controller** wrap engine + ref disk + listenSelf auto-save:
```dart
class GameController extends Notifier<GameState> {
  @override GameState build() {
    listenSelf((_, next) => unawaited(GamePersistence.save(next)));
    return ref.read(initialGameStateProvider) ?? GameState.initial();
  }
  void winRack(int idx) => state = _engine.winRack(state, idx);
}
```

**Preload pattern** ở `main.dart`: load từ disk → override seed providers → engine khởi
tạo state từ seed. Cold start có data ngay, không cần loading screen.

## Persistence (SharedPreferences)

Mỗi service 1 storage key với version suffix (vd `match_history_v1`):
- `GamePersistence` → state Bắn đền đang chơi (gồm `scoreEvents` per-turn log)
- `SetupPersistence` → setup gần nhất (auto-fill Setup screen)
- `PlayerNameHistoryStorage` → LRU 50 tên đã nhập (pool dùng chung mọi mode).
  `GameController.startGame` + `NineBallController.startGame` đều `addAll(names)`.
  Setup screens (Bắn đền + 9/8/10-Ball) dùng widget chung
  [`NameHistoryButton`](lib/widgets/name_history_button.dart) làm `suffixIcon`
  field tên (popup gợi ý + nút × xoá entry).
- `MatchHistoryController` → list trận đã kết thúc (Dismissible swipe-to-delete).
  Cả Bắn đền lẫn race-to-X đều ghi vào đây (race-to-X ghi khi đạt race target
  trong `winRack` hoặc bấm "Kết thúc trận" — xem `NineBallController._recordHistoryIfFinished`).
  Tap trận → `MatchDetailScreen`: `MatchResult.events` (Bắn đền) → cây ván/lượt
  (`RoundHistoryView`); `MatchResult.rackWinners` (race-to-X) → play-by-play từng
  rack + tỉ số chạy (`_RackPlayByPlay`). 1 trong 2 list được điền, cái kia rỗng.
- `CoverImageStorage` (`cover_image_v1`) → ảnh bìa tuỳ chỉnh (base64 bytes).
  User long-press banner ở Mode Selection → bottom sheet → `image_picker`
  (gallery, maxWidth 1280, quality 80) → `coverImageProvider.set(bytes)`.
  Null → banner mặc định `assets/banner.jpg`. `Image.memory` vs `Image.asset`.
  iOS cần `NSPhotoLibraryUsageDescription` trong Info.plist.

JSON encode/decode + try-catch fallback `clear()` nếu data hỏng.

## Lịch sử ghi điểm (Bắn đền)

Widget dùng chung [`RoundHistoryView`](lib/widgets/round_history_view.dart)
(`events`, `totalRounds`) — render cây Ván 1..N (kể cả ván trống "Chưa ghi điểm"),
mỗi ván xổ ra list lượt. Dùng bởi:
- `HistoryScreen` (trong trận): `events: state.scoreEvents, totalRounds: state.roundNumber`
- `MatchDetailScreen` (từ Dashboard): `events: match.events, totalRounds: match.roundsPlayed`

Thêm người chơi giữa trận: `GameEngine.addPlayer` → append Player(score:0) cuối list,
không đụng điểm/lịch sử ai, record undo snapshot. Nút ở AppBar PopupMenu →
`_AddPlayerDialog` (StatefulWidget). Engine throw `ArgumentError` nếu tên rỗng/trùng
→ game_screen bắt + SnackBar.

## Conventions

- **Tiếng Việt**: text UI + comments + commit messages — toàn bộ tiếng Việt.
- **Color literals**: dùng `Color(0xFFXXXXXX)` hex trong UI riêng; share via
  `AppColors` ([theme/app_colors.dart](lib/theme/app_colors.dart)) khi 2+ chỗ dùng.
- **Engine throws** `ArgumentError` cho validation fail → caller bắt + setState
  errorText. State không update nếu validation fail.
- **Fire-and-forget persist**: `unawaited(GamePersistence.save(state))` trong
  `listenSelf` — không block UI, ok nếu thỉnh thoảng mất 1 frame cuối.
- **Tests**: `_setLargeViewport(tester)` dùng `tester.view.physicalSize` cho
  portrait đủ chỗ render player cards.

## Ball icon: ảnh thật ưu tiên, fallback tự vẽ

`BallActionButton` (Bắn đền) + `BallIcon` (mode card) check [`hasBallImage(n)`](lib/widgets/ball_assets.dart):
- Có ảnh (`assets/ball/biN.png`, hiện n ∈ {3,4,5,6,9,10}) → `Image.asset` (`fit: cover`,
  `filterQuality: medium` để downscale 1024px→~96px không nhòe) trong `ClipOval`.
  Ảnh đã có số bi sẵn → `BallActionButton` chỉ overlay "+điểm" ở đáy (`_PointsPill`).
  `errorBuilder` → fallback bi tự vẽ (asset lỗi trên device, hoặc `flutter test` không
  load được asset).
- Không có ảnh → tự vẽ gradient + sọc + số (palette: 1=vàng `0xFFE8C442`, 2=xanh dương
  `0xFF1F4FB0`, 3=đỏ `0xFFC0392B`, 4=tím, 5=cam, 6=xanh lá, 7=nâu, 8=đen; 9–15 = sọc cùng màu 1–7+8).

Thêm ảnh bi mới: bỏ `biN.png` vào `assets/ball/` (dir đã register ở pubspec) + thêm `N`
vào `kBallImageNumbers`.

**Test**: tap nút bi qua `find.byKey(ValueKey('ball_$number'))` — KHÔNG dùng
`widgetWithText` vì ảnh không có Text widget cho số. (Trong test, `Image.asset` thường
fail → `errorBuilder` render bi vẽ → không throw.)

## Score screen palette (NineBallGameScreen)

- P1 panel (left): vivid blue `0xFF2962E0`
- P2 panel (right): vivid red `0xFFD93838`
- Half bg pastel: `0xFFD0DCEF` (blue), `0xFFEDC8C8` (red)
- Race chip: gold `0xFFF2B544` + dark text `0xFF16322C`
- Score digit: white, `BoxFit.contain` trong FittedBox (KHÔNG dùng `fitHeight` — clip portrait)
- `_SideColumn` Column: `crossAxisAlignment: stretch` để Material panel fill width
- Outer score Row: `crossAxisAlignment: stretch` để panel fill height
- Race chip wrap `Center` để không bị stretch dọc

## Gotchas

- **`kIsWeb` guard**: `Platform.isAndroid` throw trên web → check `!kIsWeb && Platform.isAndroid` trước khi gọi platform code.
- **Kotlin daemon "Storage already registered"**: thêm `kotlin.incremental=false` vào `android/gradle.properties`.
- **Asset registration**: file trong `assets/` phải khai báo trong `pubspec.yaml`
  → `flutter.assets:` mới load được qua `Image.asset` runtime (`flutter_launcher_icons`
  config riêng — không tự register).
- **TextEditingController dispose**: tạo controller trong function rồi `dispose()` ngay
  sau `Navigator.pop` → assertion `_dependents.isEmpty` fail. Tách dialog thành
  `StatefulWidget` để controller dispose qua `State.dispose`.
- **PopupMenuItem inner tap**: InkWell con bên trong PopupMenuItem ăn tap riêng
  (gesture arena) → không trigger `onSelected` của Item cha. Dùng pattern này cho
  delete icon trong popup gợi ý tên (xem [setup_screen.dart](lib/screens/setup_screen.dart) `_NameHistoryButton`).
- **PiP only Android**: nút PiP guard `!kIsWeb && Platform.isAndroid` để ẩn ở web/iOS.
- **Auto-rotate**: KHÔNG lock orientation. NineBallGameScreen layout responsive cho cả portrait + landscape (via Expanded + FittedBox.contain).

## Khi sửa UI score screen

File: [lib/screens/nine_ball_game_screen.dart](lib/screens/nine_ball_game_screen.dart)

Layout dùng `_SideColumn` per side (name + Material panel + −1 button) trong outer
`Row` với Race chip ở giữa. Để giữ cân bằng:
- Cả 2 side dùng cùng widget `_SideColumn` → tự động equal width via Row Expanded.
- Material panel ở Column với `crossAxisAlignment: stretch` → fill width.
- Outer Row `crossAxisAlignment: stretch` → fill height.
- Race chip wrap `Center` để không stretch dọc.

## Memory + workflow notes

- Auto memory tại `~/.claude/projects/d--projects-bida-score/memory/` — Claude tự
  cập nhật khi học được pattern/preference mới.
- Debug notes thủ công: tạo file `.claude/debug-notes.md` (gitignored) khi đang
  debug session dài. Format: Bug → Nguyên nhân → Đã thử → Hướng sửa.
