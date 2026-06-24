# Bida Score — Project Notes

Flutter app ghi điểm bi-a (Vietnamese billiards). 4 modes: Bắn đền (penalty369),
Pool (race-to-X, biến thể 8/9/10-Ball/tuỳ ý chọn ở Setup), Chơi điểm (cashGame —
2 người, tính tiền theo ván thắng + lỗ 10, chốt hiệu số), và Giải đấu (league —
3 thể thức: vòng tròn / vòng bảng manual + knockout / đấu nhánh kép).
Target: Android (chính), iOS, Web (PWA via Docker).

## Build / Test / Run

```
flutter analyze        # phải sạch trước khi commit
flutter test           # 132 tests (app_flow + engine + providers + widgets)
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
│   ├── nine_ball_engine.dart  # race-to-X (Pool, dùng cho mọi biến thể)
│   ├── cash_game_engine.dart  # Chơi điểm
│   └── league_engine.dart     # Giải đấu (vòng tròn / bảng / double-elim)
├── providers/          # Riverpod NotifierProvider — wrap engine + ref disk
├── models/             # Plain data + JSON serialization
├── services/           # SharedPreferences persistence (static methods)
├── screens/            # ConsumerWidget UI
├── widgets/            # Shared widgets (BallIcon, BallActionButton, ...)
└── theme/app_colors.dart  # Palette dùng chung
```

**Routing**: `_AppShell` ở [app.dart](lib/app.dart) chọn shell theo `gameState.gameMode`:
- `penalty369` → SetupScreen / GameScreen / ResultScreen
- `pool` → NineBallSetupScreen / NineBallGameScreen / NineBallResultScreen.
  Setup có chip "Biến thể" (8/9/10-Ball/Khác) → lưu vào `NineBallState.variantLabel`
  → `MatchResult.modeLabel` khi kết thúc. Identifiers vẫn tên `NineBall*` vì
  Pool dùng race-to-X engine (đổi tên là refactor riêng nếu muốn).
  **Đồng hồ giây (shot clock)**: Setup có card "Đồng hồ giây" với chip
  Tắt(0)/30/45/60 + "Khác…" (custom 5–300s qua `_ShotClockInputDialog`),
  default 30s. Lưu vào `NineBallState.shotClockSeconds` (0 = tắt) — config
  hằng số/trận, persist qua `LastSetup.shotClockSeconds`
  (`setPoolConfig(variantLabel, shotClockSeconds)`) để Setup auto-fill lần
  sau. Game screen render `ShotClockBar` ở đáy KHI `shotClockSeconds > 0`:
  thanh ngang đếm ngược dùng `AnimationController` (duration = số giây),
  màu xanh lá (`>0.5`) → vàng (`>0.25`) → đỏ; nút "Chạy" `forward(from:0)`,
  đang chạy đổi thành "Đặt lại" (`reset`). Vào vùng đỏ (`remaining ≤ 0.25` &
  đang chạy) → hiệu ứng **rực lửa**: `_flameController` thứ 2 (420ms,
  `repeat(reverse)`, chỉ chạy trong vùng đỏ để khỏi tốn frame) lerp gradient
  lửa (đỏ thẫm→cam→vàng ở mép) + glow cam (`BoxShadow` nhấp nháy) + số giây
  nhấp nháy đỏ↔cam kèm `Shadow`. Hết giờ (`AnimationStatus.completed`)
  → chuông báo lặp `Timer.periodic(700ms)` gọi `SystemSound.play(alert)` +
  `HapticFeedback.heavyImpact()` (KHÔNG dùng package audio) + popup
  AlertDialog "Hết giờ!"; chạm "Đánh tiếp" mới cancel chuông + reset thanh
  cho chạy lại. Ticking sống trong StatefulWidget local — KHÔNG đẩy vào
  Riverpod (tránh spam `listenSelf` persist).
- `cashGame` (Chơi điểm) → CashGameSetupScreen / CashGameScreen /
  CashGameResultScreen. 2 người, tính tiền theo ván thắng + lỗ 10:
  tap panel người = +1 ván thắng cộng dồn toàn trận (+`moneyPerRack`);
  nút +/- "Lỗ 10" nhập lỗ 10 của ván hiện tại (+/- `moneyPerBall`).
  Bấm "Chốt" khi có lỗ 10, khi ván thắng đổi so với lần chốt trước, hoặc
  khi còn hiệu số để đối trừ. Chốt sẽ lưu 1 `CashGameRackResult` (kể cả
  ván 0 lỗ 10 nếu điểm số đổi), reset `balls`, cập nhật `settledRackWins`,
  rồi trừ phần tiền chung của 2 bên bằng `settledOffsets` để màn chơi chỉ
  còn hiệu số (vd 120.000 vs 140.000 → 0 vs 20.000). `moneyOf(i)` trả tiền
  sau đối trừ; `grossMoneyOf(i)` là tổng thô trước đối trừ. Setup cấu hình
  mức tiền (default 40k/ván, 20k/lỗ 10) — lưu `cash_config_v1` để auto-fill.
  Có undo (snapshot stack). Landscape dùng layout riêng cho dễ nhìn: panel
  người chơi ngang lớn + cụm Lỗ 10/control bên cạnh. Kết thúc thủ công tự
  chốt phần chưa chốt nếu cần → MatchResult{modeLabel: 'Chơi điểm', score =
  tiền còn lại sau đối trừ} vào match history. Result screen hiện người thắng
  + chênh lệch (moneyDifference) phải trả và "Các ván đã chốt". `formatVnd`
  format "360.000"; lịch sử Chơi điểm cũng dùng format này thay vì số thô.
  KHÔNG persist state đang chơi qua kill (giống Pool).
- `league` → LeagueListScreen (landing) → LeagueSetupScreen /
  LeaguePlayScreen / LeagueResultScreen của 1 giải cụ thể. Hỗ trợ
  **nhiều giải song song**: mỗi giải có `id` riêng (sinh ở engine), lưu
  vào list `active_leagues_v1` qua `ActiveLeaguesController` (listenSelf
  auto-persist). User switch giữa các giải không mất tỷ số.
  Setup có 3 tab thể thức (`LeagueFormat`):
  1. **Vòng tròn**: N người → N*(N-1)/2 fixtures.
  2. **Vòng bảng (manual)**: user tự chia bảng A, B, C... (default 2 bảng
     × 4 người), mỗi bảng đấu vòng tròn → top 2 vào nhánh knockout
     (single-elim + tranh 3-4). Engine xử lý seeding + knockout
     advancement; trận tranh 3-4 sinh tự động khi bán kết kết thúc
     (roundName `Tranh 3-4`, cùng roundIndex với chung kết).
     Setup có 2 cách nhập: **Nhập tay** hoặc **Bốc thăm**. Bốc thăm cho
     chọn số bảng + số người tối đa/bảng + tổng số người thực tế (cho phép
     bảng thiếu người, miễn mỗi bảng tối thiểu 2 người), nhập 1 hạt giống
     mỗi bảng và danh sách còn lại; bốc thăm INLINE bằng lưới
     `_InlineDrawWheelCard` (1 [`DrawWheel`](lib/widgets/draw_wheel.dart)/bảng).
     Bấm "Quay lượt X/Y": **mọi bảng còn slot quay ĐỒNG THỜI** thêm 1 người
     (`_spinGroupRound` → `_planGroupRound` chọn distinct mỗi bảng 1 người;
     đếm `_groupSpinFinished == _groupSpinExpected` rồi `_commitGroupRound`),
     người đã bốc **biến mất** khỏi mọi vòng (wheel co dần); bảng đủ người
     hiện badge ✓. Lượt 2 quay tiếp thêm 1 người/bảng... Khi quay đủ, setup tạo
     `manualGroups` rồi gọi engine như luồng nhập tay. Các
     heading cấu hình/bốc thăm (`Số bảng`, `Tối đa mỗi bảng`, `Tổng số người`,
     `Hạt giống`, `Danh sách bốc thăm`) dùng badge màu để nổi trên nền sáng.
  3. **Đấu nhánh kép (double-elim hybrid)**: N ∈ {4, 8, 16, 32}. Setup nhập
     thủ công từng cặp đấu lượt 1 (không random). Engine sinh trước TOÀN BỘ
     bracket (nhánh thắng + nhánh thua + GF) với placeholder slot — fill dần
     qua source linkage (`sourceWinnerOfP*Id`, `sourceLoserOfP*Id`).
     Luật hybrid: chỉ loser của WB lượt 1-2 xuống LB; từ WB lượt 3 trở đi
     ai thua bị loại luôn. LB sau khi nhận loser WB R2 chạy single-elim để
     lấy người vào GF. Tổng trận (7N/4−1): 4 người = 6, 8 = 13, 16 = 27, 32 = 55.
     Mỗi `updateScore` cascade fill lại dependent fixtures; nếu sửa winner/
     loser thì invalidate descendants để GF không giữ slot cũ. `clearScore`
     đệ quy invalidate descendants.
     Play screen double-elim KHÔNG có tab Bảng xếp hạng để bracket rộng hơn
     và luôn render tree bằng [`BracketTree`](lib/widgets/bracket_tree.dart):
     WB/LB đều là Stack + Positioned cards + CustomPaint vẽ đường nối, wrap
     `InteractiveViewer` cho pinch zoom + pan; GF là 1 card riêng. Trước khi
     xong lượt 1 chỉ hiện cây WB; sau lượt 1 mới mở thêm LB bên dưới. Nhãn
     round cuối hiển thị `Bán kết`, round ngay trước đó là `Tứ kết` nếu N > 8
     (riêng 8 người không ghi Tứ kết). Winner trong card tree có icon cúp.
     **Result screen** double-elim (cả `!isFromHistory` lẫn Lịch sử giải)
     render sơ đồ **butterfly** giống ảnh 1cue.vn: WB `BracketTree`
     (`interactive: false`) bên TRÁI → `_CenterPodium` (🏆 + champion + GF
     score pill + á quân) ở giữa → `_MirroredLbColumns` bên PHẢI (LB R1 ở
     ngoài cùng, LB Final cạnh cúp). Toàn bộ Row wrap chung 1
     `InteractiveViewer` cho pan/zoom đồng bộ; chiều cao stage = max(WB
     height, LB height). `BracketTree.interactive` flag để skip nested
     InteractiveViewer khi nhúng vào layout này.
     Score pill ở `_CenterPodium` luôn hiển thị **championScore – runnerUpScore**
     (so sánh `champion.id` với `fixture.player1Id`), KHÔNG dùng
     `fixture.score1 – fixture.score2` thô — tránh user đọc nhầm theo thứ
     tự p1/p2 fixture order (vd LB winner đánh bại WB winner trong GF: pill
     phải hiện "2 – 1" champion first, không phải "1 – 2" theo p1/p2).
     Setup cũng có 2 cách nhập: **Nhập cặp** hoặc **Bốc thăm**. Bốc thăm
     nhập 1 hạt giống cho mỗi cặp mở màn và danh sách đối thủ còn lại; bấm
     bốc thăm INLINE cùng lưới `_InlineDrawWheelCard` (1 wheel/cặp); bấm
     "Quay bốc đối thủ" → mọi cặp trống bốc ĐỒNG THỜI 1 lượt
     (`_spinDeRound`/`_planDeRound`/`_commitDeRound`), người bốc xong biến
     mất khỏi mọi vòng; heading trong phần bốc thăm dùng badge màu giống Đấu
     bảng. Kết quả trả về list theo thứ tự
     `[seed1, opponent1, seed2, opponent2, ...]` rồi gọi `startDoubleElim`.
     Vòng quay (`DrawWheel`) chia múi pastel + emoji con vật random gán theo
     tên (ổn định khi vòng co lại), nhãn counter-rotate luôn thẳng đứng.
  Tap 1 fixture → bottom sheet nhập tỷ số → `LeagueController.updateScore` →
  engine recalculate leaderboard hoặc cascade bracket → listenSelf upsert
  vào active list.
  Session (`league_session_v1`) lưu viewMode + currentId → app mở lại
  landing đúng màn user đang xem dở.
  Bấm "Kết thúc giải" → append vào `league_history_v1` + remove khỏi
  active list (thứ tự: history xong mới remove để không mất giải khi crash).
  **Tie-breaker** (vòng tròn + vòng bảng): Points → H2H mini-points
  (Copeland: số trận thắng đối đầu trong tier) → Overall GoalDifference →
  Overall GoalsFor → tên alphabet. Khi mini-points tied (Condorcet cycle)
  thì BỎ QUA mini-GD/mini-GF và nhảy thẳng xuống overall — vì mini-GD
  trong cycle không đại diện cho pairwise H2H.
  Bảng xếp hạng hiển thị 4 cột stats: Trận / TS Ván (= goalsFor) / HS / Điểm.
  Mỗi người chơi 1 màu chữ trong fixture list (`assignPlayerColors` sort
  theo id → stable qua re-rank).
  Engine có method `recalculate(state)` chạy lúc load seed từ disk (cả
  `LeagueController.build` lẫn `ActiveLeaguesController.build`) — cần thiết
  khi tiebreaker đổi giữa các phiên bản app, state cũ trên đĩa giữ thứ tự
  cũ không tự refresh.

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
  Setup screens (Bắn đền + Pool) dùng widget chung
  [`NameHistoryButton`](lib/widgets/name_history_button.dart) làm `suffixIcon`
  field tên (popup gợi ý + nút × xoá entry).
- `BallConfigHistoryStorage` (`ball_config_history_v1`) → LRU 20 cấu hình bi
  (pair số + điểm) đã nhập. `GameController.startGame` `addAll(ballConfigs)`.
  Setup screen Bắn đền: mỗi field (số bi, điểm) có `suffixIcon` `_IntHistoryButton`
  riêng — popup distinct values từ history pair (chọn số riêng / điểm riêng,
  không cụm). `LinkedHashSet.toList()` giữ thứ tự mới-nhất-trước.
- `MatchHistoryController` → list trận đã kết thúc (Dismissible swipe-to-delete).
  Bắn đền / Pool / Chơi điểm đều ghi vào đây. Pool ghi khi đạt race target trong
  `winRack` hoặc bấm "Kết thúc trận" — xem `NineBallController._recordHistoryIfFinished`,
  `modeLabel` = biến thể đã chọn ở Setup. Chơi điểm ghi `score` là tiền còn
  lại sau đối trừ và UI lịch sử format tiền bằng `formatVnd`.
  Tap trận → `MatchDetailScreen`: `MatchResult.events` (Bắn đền) → cây ván/lượt
  (`RoundHistoryView`); `MatchResult.rackWinners` (Pool) → play-by-play từng
  rack + tỉ số chạy (`_RackPlayByPlay`). 1 trong 2 list được điền, cái kia rỗng.
  Tab Lịch sử filter: Bắn đền (`modeLabel == 'Bắn đền'`), Chơi điểm
  (`modeLabel == 'Chơi điểm'`), Pool (mọi cái khác — gồm cả legacy
  "8/9/10-Ball" cho backward-compat).
- `CoverImageStorage` (`cover_image_v1`) → ảnh bìa tuỳ chỉnh (base64 bytes).
  User long-press banner ở Mode Selection → bottom sheet → `image_picker`
  (gallery, maxWidth 1280, quality 80) → `coverImageProvider.set(bytes)`.
  Null → banner mặc định `assets/banner.jpg`. `Image.memory` vs `Image.asset`.
  iOS cần `NSPhotoLibraryUsageDescription` trong Info.plist.
- `CashConfigStorage` (`cash_config_v1`) → mức tiền Chơi điểm gần nhất
  ({moneyPerRack, moneyPerBall}, tức tiền/ván + tiền/lỗ 10) để Setup
  auto-fill. `CashGameController.startGame` gọi `cashConfigProvider.set(...)`.
- League trio:
  - `ActiveLeaguesStorage` (`active_leagues_v1`) → list giải đang chơi
    (status=inProgress). Per-entry try/catch — 1 entry hỏng không wipe
    cả list. Migrate 1 lần từ key cũ `active_league_v1`.
  - `LeagueSessionStorage` (`league_session_v1`) → `{viewMode, currentId}`
    để mở app trở lại đúng màn (list / current league).
  - `LeagueHistoryStorage` (`league_history_v1`) → giải đã chốt. Identity
    qua `id` (engine sinh, legacy fallback `_legacyId(startedAt, json)`).

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
- **Tương phản chữ/nền**: nền tối dùng chữ/icon sáng, nền sáng dùng chữ/icon tối.
  Với container/chip/card tự set màu nền, dùng `AppColors.readableOn(background)`
  để chọn màu chữ thay vì hardcode.
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

Layout dùng `_SideColumn` per side (hàng đầu = nút "−1" + tên căn giữa theo
cụm, rồi Material panel chiếm phần còn lại) trong outer `Row` với Race chip ở
giữa. "−1" để cạnh tên (không phải dưới panel) để panel điểm cao/to hơn. Để
giữ cân bằng:
- Cả 2 side dùng cùng widget `_SideColumn` → tự động equal width via Row Expanded.
- Material panel ở Column với `crossAxisAlignment: stretch` → fill width.
- Outer Row `crossAxisAlignment: stretch` → fill height.
- Race chip wrap `Center` để không stretch dọc.

## Memory + workflow notes

- Auto memory tại `~/.claude/projects/d--projects-bida-score/memory/` — Claude tự
  cập nhật khi học được pattern/preference mới.
- Debug notes thủ công: tạo file `.claude/debug-notes.md` (gitignored) khi đang
  debug session dài. Format: Bug → Nguyên nhân → Đã thử → Hướng sửa.
