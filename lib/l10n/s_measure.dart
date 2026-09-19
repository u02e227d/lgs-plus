import 'package:flutter/widgets.dart';

import 'app_lang.dart';
import 'locale_controller.dart';

/// 測定・工法・材料・試算表の UI 文言（品名は日文のまま）
class Ms {
  const Ms(this.lang);
  final AppLang lang;

  static Ms of(BuildContext context) => Ms(S.of(context).lang);

  String _p(String ja, String en, String zh, String vi) => switch (lang) {
        AppLang.ja => ja,
        AppLang.en => en,
        AppLang.zh => zh,
        AppLang.vi => vi,
      };

  String get measure => _p('測定', 'Measure', '测量', 'Đo');
  String get menu => _p('メニュー', 'Menu', '菜单', 'Menu');
  String get back => _p('戻る', 'Back', '返回', 'Quay lại');
  String get snapOn => _p('吸着ON', 'Snap on', '吸附开', 'Bám điểm bật');
  String get snapOff => _p('吸着OFF', 'Snap off', '吸附关', 'Bám điểm tắt');
  String get snapOnHint => _p(
        '吸着ON：ペン先が図面の線・角に吸い付きます',
        'Snap on: the pen snaps to lines and corners on the drawing',
        '吸附开：笔尖会吸到图纸的线和角上',
        'Bám điểm bật: ngòi bút dính vào nét và góc trên bản vẽ',
      );
  String get snapOffHint => _p(
        '吸着OFF：ペン先は指の位置のままです',
        'Snap off: the pen stays where you touch',
        '吸附关：笔尖停在手指位置，不再吸附',
        'Bám điểm tắt: ngòi dừng đúng chỗ chạm, không hút',
      );
  String get rotateCeilGrid =>
      _p('天井グリッド90°回転', 'Rotate ceiling grid 90°', '天花网格旋转90°', 'Xoay lưới trần 90°');

  String get toolPan => _p('移動', 'Move', '移动', 'Di chuyển');
  String get toolOpening => _p('開口補強', 'Opening', '开口补强', 'Gia cố lỗ');
  String get toolWall => _p('壁マウス', 'Wall pen', '墙笔', 'Bút tường');
  String get toolCeil => _p('天井マウス', 'Ceiling pen', '天花笔', 'Bút trần');
  String get toolDrop => _p('下りマウス', 'Drop pen', '下吊笔', 'Bút trần thả');

  String get modeOpening => _p('［開口補強］', '[Opening]', '［开口补强］', '[Lỗ]');
  String get modeDrop => _p('［下り］', '[Drop]', '［下吊］', '[Trần thả]');
  String get modeIron => _p('［鉄板専用］', '[Iron plate]', '［铁板专用］', '[Tôn]');
  String get modeMulti => _p('［多線］', '[Multi]', '［多线］', '[Nhiều nét]');
  String get modeSingle => _p('［単線］', '[Single]', '［单线］', '[Một nét]');

  String get hintGreenNext =>
      _p('緑：離すと完了／移動で次点', 'Green: release to finish / move for next point', '绿：松手完成／移动取下一点', 'Xanh: thả để xong / kéo điểm tiếp');
  String get hintRedHold =>
      _p('赤：1.5秒停頓で緑に', 'Red: hold 1.5s until green', '红：停1.5秒变绿', 'Đỏ: giữ 1,5 giây đến xanh');
  String get hintDefault =>
      _p('画完→線尾に番号表示。番号タップで材料選択／削除', 'After drawing, tap the number for materials / delete', '画完后线尾显示编号。点编号选材料或删除', 'Sau khi vẽ, chạm số để chọn vật tư / xóa');
  String get hintOpening =>
      _p('開口の両端を確定→形状・材料を選択', 'Set both ends of the opening, then choose shape and material', '确定开口两端后选择形状和材料', 'Chốt hai đầu lỗ rồi chọn hình và vật tư');
  String get hintDrop =>
      _p('始点→第1折＝幅、以降＝長さ（任意角・複数折可）。番号タップで設定', 'Start to first bend = width, then length. Tap number for settings', '起点到第一折=宽，之后=长。点编号设定', 'Điểm đầu đến gấp 1 = rộng, sau = dài. Chạm số để cài');
  String get dropGuideTitle =>
      _p('下りマウス — 画線の順', 'Drop pen — draw order', '下吊笔 — 画线顺序', 'Bút trần thả — thứ tự vẽ');
  String get dropGuideBody => _p(
        '最初に描く1辺は幅です。折ったあとの線は長さです。',
        'The first segment is width. After the bend, the line is length.',
        '先画的第一段是宽。折过之后的线是长。',
        'Đoạn đầu là rộng. Sau chỗ gấp là dài.',
      );
  String get dropGuideWidth => _p('幅', 'Width', '宽', 'Rộng');
  String get dropGuideLength => _p('長', 'Len.', '长', 'Dài');
  String dropBoardQty(int count, String area, String boardArea) => _p(
        '数量（自動）= 下り面積 ÷ ボード面積　切上げ　$count 枚（$area㎡ ÷ $boardArea㎡）',
        'Qty (auto) = drop area ÷ board area, rounded up: $count sheets ($area m² ÷ $boardArea m²)',
        '数量（自动）= 下吊面积 ÷ 板材面积　进位　$count 张（$area㎡ ÷ $boardArea㎡）',
        'SL (tự động) = diện tích trần thả ÷ tấm, làm tròn lên: $count tấm ($area m² ÷ $boardArea m²)',
      );
  String ceilHint(int n) => _p(
        '番号$n：3点以上で閉合。面積は図ごとに表示',
        'No.$n: close with 3+ points. Area shown per region',
        '编号$n：3点以上闭合。面积按图显示',
        'Số $n: khép từ 3 điểm. Diện tích theo vùng',
      );
  String hintModeDraw(String mode) => _p(
        '$mode 画完→線尾番号。番号タップで材料選択／削除',
        '$mode After drawing, tap the number for materials / delete',
        '$mode 画完后点线尾编号选材料或删除',
        '$mode Sau khi vẽ, chạm số để chọn vật tư / xóa',
      );

  String get openingConfirmTitle =>
      _p('開口補強の確認', 'Opening reinforcement', '开口补强确认', 'Xác nhận gia cố lỗ');
  String get openingConfirmBody => _p(
        '壁マウスの前に開口補強を設定してください。\n開口がない場合は「開口なし」で続行できます。',
        'Set opening reinforcement before the wall pen.\nIf there is no opening, continue with “No opening”.',
        '请在墙笔之前设定开口补强。\n没有开口时可点「无开口」继续。',
        'Hãy đặt gia cố lỗ trước khi vẽ tường.\nNếu không có lỗ, chọn “Không có lỗ”.',
      );
  String get goOpening => _p('開口補強へ', 'Go to opening', '去开口补强', 'Tới gia cố lỗ');
  String get noOpening => _p('開口なし', 'No opening', '无开口', 'Không có lỗ');
  String get multiModeSnack => _p(
        '多線モード：壁高さ・材料は同一に。画線後に番号が最新線尾へ移動します',
        'Multi-line: keep height and materials the same. The number moves to the latest line end.',
        '多线模式：墙高和材料须相同。画线后编号移到最新线尾。',
        'Nhiều nét: cùng chiều cao và vật tư. Số chuyển về đuôi nét mới nhất.',
      );
  String get ironModeSnack => _p(
        '鉄板専用：画線後は設定を出さず、続けて測れます。T をタップで長さ確認',
        'Iron plate: keep drawing after each line. Tap T to check length.',
        '铁板专用：画线后不弹出设定，可继续测。点 T 看长度。',
        'Tôn: vẽ xong không mở cài đặt, đo tiếp. Chạm T để xem chiều dài.',
      );
  String get openingModeSnack => _p(
        '開口補強：線色を選び、開口の両端を各1.5秒で確定',
        'Opening: pick a color and hold each end for 1.5 seconds.',
        '开口补强：选线色，开口两端各停1.5秒确定。',
        'Lỗ: chọn màu và giữ mỗi đầu 1,5 giây.',
      );

  String get wallDrawTitle => _p('壁マウス — 画線モード', 'Wall pen — draw mode', '墙笔 — 画线模式', 'Bút tường — chế độ vẽ');
  String get singleLine => _p('単線', 'Single', '单线', 'Một nét');
  String get singleLineSub =>
      _p('1本の線ごとに番号が付きます', 'Each line gets its own number', '每条线一个编号', 'Mỗi nét một số');
  String get multiLine => _p('多線', 'Multi', '多线', 'Nhiều nét');
  String get multiLineSub => _p(
        '複数線を合算して1つの番号。壁高さ・材料は同一にしてください。交差点はスタッド3本を加算します',
        'Several lines share one number. Keep height and materials the same. Intersections add 3 studs.',
        '多条线合计一个编号。墙高和材料须相同。交叉点加3根立柱。',
        'Nhiều nét chung một số. Cùng chiều cao và vật tư. Giao điểm cộng 3 thanh.',
      );
  String get ironOnly => _p('鉄板専用', 'Iron plate', '铁板专用', 'Tôn');
  String get ironOnlySub => _p(
        '鉄板の延長を測ります。画線後は設定を出さず、T をタップで長さ確認',
        'Measure iron-plate length. Settings stay closed; tap T for length.',
        '测量铁板延长。画线后不弹出设定，点 T 看长度。',
        'Đo chiều dài tôn. Không mở cài đặt; chạm T để xem dài.',
      );

  String get mergeCeilTitle => _p('天井材料の統合', 'Merge ceiling materials', '合并天花材料', 'Gộp vật tư trần');
  String mergeCeilBody(int lastNum, int nextNum) => _p(
        '直前の天井（番号 $lastNum）と材料数量を統合しますか？\n\n・統合する → 同じ番号 $lastNum で続けて測定（面積は図ごとに表示）\n・統合しない → 新しい番号 $nextNum',
        'Merge materials with the last ceiling (No.$lastNum)?\n\n• Merge → keep measuring as No.$lastNum (area per region)\n• Don’t merge → new No.$nextNum',
        '要与上一天花（编号 $lastNum）合并材料数量吗？\n\n・合并 → 继续用编号 $lastNum（面积按图显示）\n・不合并 → 新编号 $nextNum',
        'Gộp vật tư với trần trước (số $lastNum)?\n\n• Gộp → tiếp tục số $lastNum (diện tích theo vùng)\n• Không gộp → số mới $nextNum',
      );
  String get mergeDropTitle => _p('下り材料の統合', 'Merge drop materials', '合并下吊材料', 'Gộp vật tư trần thả');
  String mergeDropBody(int lastNum, int nextNum) => _p(
        '直前の下り（番号 $lastNum）と材料数量を統合しますか？\n\n・統合する → 同じ番号 $lastNum で続けて測定\n・統合しない → 新しい番号 $nextNum',
        'Merge materials with the last drop (No.$lastNum)?\n\n• Merge → keep measuring as No.$lastNum\n• Don’t merge → new No.$nextNum',
        '要与上一处下吊（编号 $lastNum）合并材料数量吗？\n\n・合并 → 继续用编号 $lastNum\n・不合并 → 新编号 $nextNum',
        'Gộp vật tư với trần thả trước (số $lastNum)?\n\n• Gộp → tiếp tục số $lastNum\n• Không gộp → số mới $nextNum',
      );
  String mergeNo(int n) => _p('統合しない（$n）', 'Don’t merge ($n)', '不合并（$n）', 'Không gộp ($n)');
  String mergeYes(int n) => _p('統合する（$n）', 'Merge ($n)', '合并（$n）', 'Gộp ($n)');
  String ceilMouseMerged(int n) =>
      _p('天井マウス：番号 $n で統合測定', 'Ceiling pen: measuring as No.$n (merged)', '天花笔：编号 $n 合并测量', 'Bút trần: đo số $n (gộp)');
  String ceilMouse(int n) =>
      _p('天井マウス：番号 $n', 'Ceiling pen: No.$n', '天花笔：编号 $n', 'Bút trần: số $n');
  String dropMouseMerged(int n) =>
      _p('下りマウス：番号 $n で統合測定', 'Drop pen: measuring as No.$n (merged)', '下吊笔：编号 $n 合并测量', 'Bút trần thả: đo số $n (gộp)');
  String dropMouse(int n) =>
      _p('下りマウス：番号 $n', 'Drop pen: No.$n', '下吊笔：编号 $n', 'Bút trần thả: số $n');

  String get needMorePoints =>
      _p('点が足りません。赤→緑で2点以上取ってください', 'Need more points. Hold red→green for at least 2 points.', '点数不够。红变绿后至少取2点。', 'Thiếu điểm. Giữ đỏ→xanh ít nhất 2 điểm.');
  String get need3Points =>
      _p('3点以上（各点1.5秒）で領域を閉じてください', 'Close the region with 3+ points (1.5s each).', '请用3点以上（每点1.5秒）闭合区域。', 'Khép vùng từ 3 điểm (1,5 giây mỗi điểm).');
  String get returnToStartRing =>
      _p('始点の緑リングへ戻して閉合してください', 'Return to the green start ring to close.', '请回到起点绿环闭合。', 'Quay về vòng xanh điểm đầu để khép.');
  String get returnToStartRingShort =>
      _p('閉合するには始点の緑リングへ戻してください', 'Return to the green start ring to close.', '闭合请回到起点绿环。', 'Để khép, quay về vòng xanh điểm đầu.');
  String get openingFirstPoint =>
      _p('1点目確定。開口のもう一端へ移動して確定', 'First point set. Move to the other end of the opening.', '第1点已定。移到开口另一端确定。', 'Đã chốt điểm 1. Chuyển sang đầu kia của lỗ.');
  String greenConfirmMark(String mark) =>
      _p('緑：離すと$markを確定', 'Green: release to set $mark', '绿：松手确定$mark', 'Xanh: thả để chốt $mark');
  String get greenStartNext =>
      _p('緑：起点確定。マウス先端を次の点へ移動', 'Green: start set. Move the tip to the next point', '绿：起点已定。把笔尖移到下一点', 'Xanh: đã chốt đầu. Đưa ngòi tới điểm tiếp');
  String get greenPointContinue =>
      _p('緑：点を確定。続けて移動／終点なら離して完了', 'Green: point set. Keep moving, or release to finish', '绿：点已定。继续移动／终点则松手完成', 'Xanh: đã chốt điểm. Kéo tiếp / thả để xong');
  String get closeOkRelease =>
      _p('閉合OK：離すと面積を確定', 'Closed: release to set the area', '已闭合：松手确定面积', 'Đã khép: thả để chốt diện tích');
  String get greenNeed3 =>
      _p('緑：点を確定。3点以上で領域を閉じてください', 'Green: point set. Close the region with 3+ points', '绿：点已定。请用3点以上闭合区域', 'Xanh: đã chốt. Khép vùng từ 3 điểm');
  String get greenContinueClose =>
      _p('緑：続けて点を取る／始点リングへ戻ると閉合', 'Green: add more points, or return to the start ring to close', '绿：继续取点／回到起点环闭合', 'Xanh: lấy thêm điểm / về vòng đầu để khép');
  String get greenDropStart =>
      _p('緑：始点確定。折点へ（この区間＝幅）', 'Green: start set. Go to the bend (this span = width)', '绿：起点已定。移到折点（此段＝宽）', 'Xanh: đã chốt đầu. Tới chỗ gấp (đoạn này = rộng)');
  String get greenDropBend =>
      _p('緑：折点確定。任意角度で続けて（以降＝長さ）', 'Green: bend set. Continue at any angle (then = length)', '绿：折点已定。可任意角度继续（之后＝长）', 'Xanh: đã chốt gấp. Tiếp góc bất kỳ (sau = dài)');
  String get greenDropMore =>
      _p('緑：離すと確定／移動でさらに折点（長さ）', 'Green: release to finish / move for another bend (length)', '绿：松手确定／移动再取折点（长）', 'Xanh: thả để xong / kéo thêm chỗ gấp (dài)');
  String wallMergedOpen(int n, int chains, String net, String opening) => _p(
        '線 $n に追加（${chains}本合算）・面積 $net㎡（開口 −$opening㎡）',
        'Added to line $n ($chains merged) · area $net m² (openings −$opening m²)',
        '已加到线 $n（合计$chains条）·面积 $net㎡（开口 −$opening㎡）',
        'Thêm vào nét $n ($chains gộp) · $net m² (lỗ −$opening m²)',
      );
  String wallMerged(int n, int chains) => _p(
        '線 $n に追加（${chains}本合算）。番号は最新線尾。完了したら番号タップ',
        'Added to line $n ($chains merged). Number is at the latest end. Tap it when done',
        '已加到线 $n（合计$chains条）。编号在最新线尾。完成后点编号',
        'Thêm vào nét $n ($chains gộp). Số ở đuôi mới. Chạm số khi xong',
      );
  String wallAreaOpen(int n, String net, String opening) => _p(
        '線 $n：面積 $net㎡（開口 −$opening㎡ 控除済）。番号タップで材料',
        'Line $n: area $net m² (openings −$opening m² deducted). Tap the number for materials',
        '线 $n：面积 $net㎡（已扣开口 −$opening㎡）。点编号选材料',
        'Nét $n: $net m² (đã trừ lỗ −$opening m²). Chạm số để chọn vật tư',
      );
  String get ironLineAdded =>
      _p('鉄板線 T を追加。続けて画線できます。T をタップで長さ確認', 'Iron-plate T added. Keep drawing. Tap T for length', '已加铁板线 T。可继续画。点 T 看长度', 'Đã thêm nét T. Vẽ tiếp. Chạm T để xem dài');
  String wallMultiStarted(int n) => _p(
        '線 $n 開始（多線）。続けて画線で合算／番号タップで材料選択',
        'Line $n started (multi). Keep drawing to merge / tap the number for materials',
        '线 $n 已开始（多线）。继续画线合计／点编号选材料',
        'Nét $n bắt đầu (nhiều). Vẽ tiếp để gộp / chạm số chọn vật tư',
      );
  String wallLineAdded(int n) => _p(
        '線 $n を追加。線尾の番号をタップ → 材料選択 / 削除',
        'Line $n added. Tap the end number → materials / delete',
        '已加线 $n。点线尾编号 → 材料／删除',
        'Đã thêm nét $n. Chạm số cuối → vật tư / xóa',
      );
  String dropAddedExtra(int n, int extra) => _p(
        '下り $n を追加（追加幅 $extra）。番号タップで設定',
        'Drop $n added ($extra extra widths). Tap the number for settings',
        '已加下吊 $n（追加宽 $extra）。点编号设定',
        'Đã thêm trần thả $n ($extra rộng thêm). Chạm số để cài',
      );
  String dropAdded(int n) =>
      _p('下り $n を追加。番号タップで設定', 'Drop $n added. Tap the number for settings', '已加下吊 $n。点编号设定', 'Đã thêm trần thả $n. Chạm số để cài');
  String get dropPlusHint =>
      _p('／＋で②幅以降', ' / + for width ② onward', '／用＋测②宽之后', ' / + để đo rộng ② trở đi');
  String secWidthDrag(String mark) => _p(
        '$mark：もう一度タッチして目標へドラッグ→緑で確定',
        '$mark: touch again, drag to the target, then green to set',
        '$mark：再点一次并拖到目标→变绿后确定',
        '$mark: chạm lại, kéo tới đích, xanh để chốt',
      );
  String secWidthRecorded(String mark, int mm) =>
      _p('$mark $mm mm を記録', '$mark $mm mm recorded', '已记录 $mark $mm mm', 'Đã ghi $mark $mm mm');
  String secWidthUpdated(String mark, int mm) =>
      _p('$mark $mm mm／面積を更新', '$mark $mm mm / area updated', '已更新 $mark $mm mm／面积', 'Đã cập nhật $mark $mm mm / diện tích');
  String ceilMergedArea(int n, String area) => _p(
        '番号 $n に統合：面積 $area ㎡（番号タップで工法変更）',
        'Merged into No.$n: area $area m² (tap the number to change method)',
        '已合并到编号 $n：面积 $area ㎡（点编号改工法）',
        'Gộp vào số $n: $area m² (chạm số để đổi phương pháp)',
      );
  String get thisRegionOnly => _p('この領域のみ', 'This region only', '仅此区域', 'Chỉ vùng này');
  String get deleteCeilTitle => _p('天井面積を削除', 'Delete ceiling area', '删除天花面积', 'Xóa diện tích trần');
  String deleteCeilOne(int n) =>
      _p('番号 $n の天井領域を削除しますか？', 'Delete ceiling region No.$n?', '要删除编号 $n 的天花区域吗？', 'Xóa vùng trần số $n?');
  String deleteCeilGroup(int n, int count) => _p(
        '番号 $n は $count 個の領域があります。\nこの領域だけ削除しますか？番号全体を削除しますか？',
        'No.$n has $count regions.\nDelete only this region, or the whole number?',
        '编号 $n 有 $count 个区域。\n只删此区域，还是删整个编号？',
        'Số $n có $count vùng.\nXóa riêng vùng này hay cả số?',
      );
  String deleteGroupAll(int n) => _p('番号 $n すべて', 'All of No.$n', '编号 $n 全部', 'Tất cả số $n');
  String get deleteWallTitle => _p('壁線を削除', 'Delete wall line', '删除墙线', 'Xóa nét tường');
  String get deleteWallBody => _p(
        'この壁線を削除しますか？\n試算表に含まれている場合、対応する数量も除外されます。',
        'Delete this wall line?\nRelated estimate quantities will also be removed.',
        '要删除这条墙线吗？\n若已在试算表中，对应数量也会去掉。',
        'Xóa nét tường này?\nSố lượng trên bảng tính cũng bị loại.',
      );
  String get wallDeleted =>
      _p('線を削除しました（試算数量も更新）', 'Line deleted (estimate updated)', '已删除线（试算数量已更新）', 'Đã xóa nét (bảng tính đã cập nhật)');
  String get deleteThisLine => _p('この線を削除', 'Delete this line', '删除此线', 'Xóa nét này');
  String get deleteThisOpening => _p('この開口を削除', 'Delete this opening', '删除此开口', 'Xóa lỗ này');
  String get openingDeleted => _p('開口補強を削除しました', 'Opening reinforcement deleted', '已删除开口补强', 'Đã xóa gia cố lỗ');
  String openingUpdated(String pattern) =>
      _p('開口を更新（$pattern）', 'Opening updated ($pattern)', '开口已更新（$pattern）', 'Đã cập nhật lỗ ($pattern)');
  String openingAddedDeduct(String m2) => _p(
        '開口を追加（壁面積から $m2㎡ 控除）',
        'Opening added ($m2 m² deducted from wall area)',
        '已添加开口（从墙面积扣除 $m2㎡）',
        'Đã thêm lỗ (trừ $m2 m² khỏi tường)',
      );
  String openingAdded(String pattern, String material) => _p(
        '開口補強を追加（$pattern／$material）。壁マウスで画線すると面積から控除',
        'Opening added ($pattern / $material). Deducted when you draw a wall.',
        '已添加开口补强（$pattern／$material）。用墙笔画线后从面积扣除',
        'Đã thêm gia cố lỗ ($pattern / $material). Trừ diện tích khi vẽ tường.',
      );
  String get freeDeleteNote => _p(
        '測定した線の削除は無料版でもできます。',
        'Deleting measured lines is available on the free plan.',
        '删除已测线免费版也可以。',
        'Xóa nét đã đo vẫn dùng được bản miễn phí.',
      );
  String get freeDeleteOpeningNote => _p(
        '開口の削除は無料版でもできます。',
        'Deleting openings is available on the free plan.',
        '删除开口免费版也可以。',
        'Xóa lỗ vẫn dùng được bản miễn phí.',
      );

  String get undoPoint => _p('点取消', 'Undo point', '撤销点', 'Hoàn tác điểm');
  String get clear => _p('クリア', 'Clear', '清除', 'Xóa');
  String get ceilBottomHint =>
      _p('始点リングへ戻して離す→番号表示。番号タップで工法選択', 'Return to the start ring and release → number. Tap for method.', '回到起点环松手→显示编号。点编号选工法。', 'Về vòng đầu rồi thả → số. Chạm để chọn phương pháp.');
  String get wallBottomHint =>
      _p('単線＝1本1番号／多線＝合算1番号（番号は最新線尾へ移動）', 'Single = one number each / Multi = one shared number at the latest end', '单线=一线一号／多线=合计一号（编号移到最新线尾）', 'Một nét = một số / Nhiều nét = một số ở đuôi mới');
  String get pinchHint =>
      _p('ピンチで拡大。壁線タップ＝色・十字入力／長押し＝削除。', 'Pinch to zoom. Tap a wall for color / long-press to delete.', '双指缩放。点墙线改颜色／长按删除。', 'Véo để phóng. Chạm nét để đổi màu / giữ để xóa.');

  String get materials => _p('材料選択', 'Materials', '材料选择', 'Chọn vật tư');
  String get materialsIron => _p('材料選択（鉄板）', 'Materials (iron plate)', '材料选择（铁板）', 'Vật tư (tôn)');
  String get methodSelect => _p('工法選択', 'Method', '工法选择', 'Chọn phương pháp');
  String get ceilMethodTitle => _p('天井工法選択', 'Ceiling method', '天花工法选择', 'Phương pháp trần');
  String get wallMethod => _p('工法', 'Method', '工法', 'Phương pháp');
  String get sqMethod => _p('SQ工法', 'SQ method', 'SQ工法', 'Phương pháp SQ');
  String get zairaiMethod => _p('在来工法', 'Conventional', '在来工法', 'Phương pháp truyền thống');
  String get studPitch => _p('スタッド間隔', 'Stud spacing', '立柱间距', 'Khoảng cách thanh');
  String get ceilSpec => _p('天井施工仕様', 'Ceiling spec', '天花施工规格', 'Quy cách trần');
  String get noenPitch => _p('野縁ピッチ', 'Furring pitch', '龙骨间距', 'Bước xương');
  String get rotate90 => _p('90°回転', 'Rotate 90°', '旋转90°', 'Xoay 90°');
  String get rotate90Done =>
      _p('90°回転済（再タップで戻す）', 'Rotated 90° (tap again to undo)', '已旋转90°（再点恢复）', 'Đã xoay 90° (chạm lại để hoàn)');
  String get applyToDrawing =>
      _p('確定して図面に反映', 'Apply to drawing', '确定并反映到图纸', 'Áp lên bản vẽ');
  String get goMaterialPage =>
      _p('材料設定ページへ', 'Material settings', '前往材料设定', 'Tới cài đặt vật tư');
  String get deleteThisArea => _p('この面積を削除', 'Delete this area', '删除此面积', 'Xóa diện tích này');
  String areaM2(String v) => _p('面積 $v ㎡', 'Area $v m²', '面积 $v ㎡', 'Diện tích $v m²');

  String get confirmEstimate => _p('積算確定', 'Confirm takeoff', '确定积算', 'Xác nhận khối lượng');
  String get invalidHeight =>
      _p('高さを正しく入力してください', 'Enter a valid height', '请输入正确高度', 'Nhập chiều cao hợp lệ');
  String get wallHeight => _p('壁高さ H (mm)', 'Wall height H (mm)', '墙高 H (mm)', 'Chiều cao tường H (mm)');
  String get wallHeightShort => _p('壁高さ', 'Wall height', '墙高', 'Chiều cao tường');
  String get wallHeightHelper =>
      _p('50形は2.7m以下、65/75形は4.0m以下が目安', 'Guide: 50-type ≤2.7 m, 65/75-type ≤4.0 m', '参考：50型≤2.7m，65/75型≤4.0m', 'Gợi ý: loại 50 ≤2,7 m; 65/75 ≤4,0 m');
  String get measuredValue => _p('測定値', 'Measured', '测量值', 'Đã đo');
  String wallLenM(String v) => _p('壁長 $v m', 'Wall length $v m', '墙长 $v m', 'Dài tường $v m');
  String corners(int n) =>
      _p('曲がり角 $n（各LGS 3本）', 'Corners $n (3 LGS each)', '转角 $n（每处LGS 3根）', 'Góc $n (3 LGS mỗi góc)');
  String wallThick(String v) => _p('壁厚 $v mm', 'Wall thickness $v mm', '墙厚 $v mm', 'Dày tường $v mm');
  String wallAreaNet(String net, String gross, String opening) => _p(
        '壁面積 $net m²（総 $gross − 開口 $opening）',
        'Wall area $net m² (gross $gross − openings $opening)',
        '墙面积 $net m²（总 $gross − 开口 $opening）',
        'Diện tích tường $net m² (gộp $gross − lỗ $opening)',
      );
  String wallAreaApprox(String net) =>
      _p('壁面積（概算） $net m²', 'Wall area (approx.) $net m²', '墙面积（约） $net m²', 'Diện tích tường (ước) $net m²');
  String get syncFromDims => _p('材料寸法から同期', 'Sync from sizes', '从材料尺寸同步', 'Đồng bộ từ kích thước');
  String get lgsBase => _p('LGS 下地', 'LGS framing', 'LGS 基层', 'Khung LGS');
  String get runner => _p('ランナー', 'Runner', '地龙骨', 'Runner');
  String get runnerW => _p('ランナー幅', 'Runner width', '地龙骨宽', 'Rộng runner');
  String get runnerL => _p('ランナー長さ', 'Runner length', '地龙骨长', 'Dài runner');
  String get studType => _p('スタッド種別', 'Stud type', '立柱类型', 'Loại thanh');
  String get channelType => _p('コの字型', 'Channel', '槽型', 'Chữ U');
  String get squareStud => _p('角スタッド', 'Square stud', '方立柱', 'Thanh vuông');
  String get studLen => _p('スタッド長さ', 'Stud length', '立柱长度', 'Dài thanh');
  String get studLenDirect =>
      _p('スタッド長さ（直接入力）', 'Stud length (manual)', '立柱长度（直接输入）', 'Dài thanh (nhập tay)');
  String get studW => _p('スタッド幅', 'Stud width', '立柱宽', 'Rộng thanh');
  String get studWSquare =>
      _p('スタッド幅（角スタッド型番）', 'Stud width (square-stud code)', '立柱宽（方立柱型号）', 'Rộng thanh (mã vuông)');
  String get directInput => _p('直接入力', 'Manual', '直接输入', 'Nhập tay');
  String get nuki => _p('振れ止め', 'Nogging', '横撑', 'Thanh ngang');
  String get nukiW => _p('振れ止め幅', 'Nogging width', '横撑宽', 'Rộng thanh ngang');
  String get nukiL => _p('振れ止め長さ', 'Nogging length', '横撑长', 'Dài thanh ngang');
  String get runnerSpacer => _p('ランナースペーサー', 'Runner spacer', '地龙骨垫块', 'Đệm runner');
  String get runnerSpacerType =>
      _p('ランナースペーサー種別', 'Runner spacer type', '地龙骨垫块类型', 'Loại đệm runner');
  String get spacerAuto =>
      _p('スタッド幅 ＜ ランナー幅のため自動選択（スタッド本数×2）', 'Auto-selected because stud < runner (studs × 2)', '因立柱宽＜地龙骨宽而自动选择（立柱数×2）', 'Tự chọn vì thanh < runner (số thanh × 2)');
  String get otherLgs => _p('その他（LGS）', 'Other (LGS)', '其他（LGS）', 'Khác (LGS)');
  String get glassWool => _p('グラスウール', 'Glass wool', '玻璃棉', 'Bông thủy tinh');
  String get glassWoolDensity =>
      _p('グラスウール密度', 'Glass-wool density', '玻璃棉密度', 'Mật độ bông thủy tinh');
  String get board => _p('ボード', 'Board', '板材', 'Tấm');
  String get faceLayout => _p('面構成', 'Faces', '面构成', 'Mặt');
  String get faceA => _p('A面ボード', 'Face A board', 'A面板', 'Tấm mặt A');
  String get faceB => _p('B面ボード', 'Face B board', 'B面板', 'Tấm mặt B');
  String get none => _p('なし', 'None', '无', 'Không');
  String get oneSide => _p('片面', 'One side', '单面', 'Một mặt');
  String get rockFelt => _p('ロックフェルト', 'Rock felt', '岩棉毡', 'Nỉ đá');
  String get rockFeltSize => _p('ロックフェルト寸法', 'Rock-felt size', '岩棉毡尺寸', 'Kích thước nỉ đá');
  String get tigerU => _p('タイガーUタイト', 'Tiger U-tight', 'Tiger U紧固', 'Tiger U-tight');
  String get tigerUType => _p('タイガーUタイト種類', 'Tiger U-tight type', 'Tiger U种类', 'Loại Tiger U-tight');
  String get ironPlate => _p('鉄板', 'Iron plate', '铁板', 'Tôn');
  String get ironAutoDraw =>
      _p('鉄板専用の画線です（自動選択）', 'Iron-plate line (auto-selected)', '铁板专用画线（自动选择）', 'Nét tôn (tự chọn)');
  String get ironAutoT =>
      _p('T線があるため自動選択', 'Auto-selected because a T line exists', '因有T线而自动选择', 'Tự chọn vì có nét T');
  String get width => _p('幅', 'Width', '宽', 'Rộng');
  String get length => _p('長さ', 'Length', '长', 'Dài');
  String get stockLen => _p('定尺', 'Stock length', '定尺', 'Chiều dài định mức');
  String get stockLenFull => _p('定尺長さ', 'Stock length', '定尺长度', 'Chiều dài định mức');
  String get tiers => _p('段', 'Tiers', '段', 'Tầng');
  String nTiers(int n) => _p('$n段', '$n tiers', '$n段', '$n tầng');
  String ironDrawLen(String v) =>
      _p('画線長さ $v（鉄板Tの全長）', 'Drawn length $v (full T length)', '画线长度 $v（铁板T全长）', 'Dài nét $v (toàn bộ T)');
  String get ironDrawNone =>
      _p('画線長さ —（Tの測定値がありません）', 'Drawn length — (no T measurement)', '画线长度 —（没有T测量值）', 'Dài nét — (chưa đo T)');
  String ironQty(int n, int segs, String stockM) => _p(
        '数量 $n 枚（総長×$segs段÷定尺 ${stockM}m）',
        'Qty $n sheets (total × $segs tiers ÷ $stockM m stock)',
        '数量 $n 张（总长×$segs段÷定尺 ${stockM}m）',
        'SL $n tấm (tổng × $segs tầng ÷ $stockM m)',
      );
  String get ironQtyNone => _p('数量 —', 'Qty —', '数量 —', 'SL —');
  String get reinforce => _p('補強材', 'Reinforcement', '补强材', 'Thanh gia cố');
  String reinforceQty(int n) =>
      _p('数量 $n 本（開口補強の割付）', 'Qty $n pcs (opening layout)', '数量 $n 根（开口补强分配）', 'SL $n cây (bố trí lỗ)');
  String get reinforceQtyNone =>
      _p('数量 —（開口の補強割付がありません）', 'Qty — (no opening layout)', '数量 —（没有开口补强分配）', 'SL — (chưa bố trí lỗ)');
  String get reinforceLenDirect =>
      _p('補強材長さ（直接入力）', 'Reinforcement length (manual)', '补强材长度（直接输入）', 'Dài gia cố (nhập tay)');
  String get anglePiece => _p('アングルピース', 'Angle piece', '角钢件', 'Mảnh góc');
  String angleQty(int n) =>
      _p('数量 $n 個（開口図形の線×2）', 'Qty $n (opening lines × 2)', '数量 $n 个（开口图形线×2）', 'SL $n (nét lỗ × 2)');
  String get angleQtyNone =>
      _p('数量 —（開口図形がありません）', 'Qty — (no opening shape)', '数量 —（没有开口图形）', 'SL — (chưa có hình lỗ)');
  String get size => _p('サイズ', 'Size', '尺寸', 'Kích thước');
  String get angleDirect =>
      _p('アングルピース（直接入力）', 'Angle piece (manual)', '角钢件（直接输入）', 'Mảnh góc (nhập tay)');
  String angleMax(int mm) => _p(
        'アングルピースはランナー幅（${mm}mm）以下にしてください',
        'Angle piece must be ≤ runner width (${mm}mm)',
        '角钢件须不超过地龙骨宽（${mm}mm）',
        'Mảnh góc phải ≤ rộng runner (${mm}mm)',
      );
  String get angleHint =>
      _p('数量＝開口図形の線本数×2（例：④は線5本→10個）', 'Qty = opening lines × 2 (e.g. type ④ with 5 lines → 10)', '数量=开口图形线数×2（例：④为5线→10个）', 'SL = số nét lỗ × 2 (vd: ④ 5 nét → 10)');
  String extraKind(String kind) => switch (kind) {
        'runner' => runner,
        'stud' => _p('スタッド', 'Stud', '立柱', 'Thanh'),
        'reinforce' => reinforce,
        'fure_dome' => nuki,
        'iron' => ironPlate,
        'w_bar' => wBar,
        'single_bar' => sBar,
        'sq_stud' => sqStud,
        'bolt' => fullBolt,
        'channel' => channel,
        'mikiri' => _p('見切り', 'Trim', '收边', 'Nẹp'),
        _ => kind,
      };
  String extraSizeTitle(String kind) =>
      _p('別寸法を追加（${extraKind(kind)}）', 'Add extra size (${extraKind(kind)})', '添加其他尺寸（${extraKind(kind)}）', 'Thêm kích thước (${extraKind(kind)})');
  String get extraSizeTooltip => _p('別寸法を追加', 'Add extra size', '添加其他尺寸', 'Thêm kích thước');
  String get extraSizeSub => _p('追加寸法', 'Extra sizes', '追加尺寸', 'Kích thước thêm');
  String get itemName => _p('品名', 'Name', '品名', 'Tên');
  String get unit => _p('単位', 'Unit', '单位', 'Đơn vị');
  String get qty => _p('数量', 'Qty', '数量', 'SL');
  String get addRow => _p('行を追加', 'Add row', '添加行', 'Thêm dòng');
  String get deleteRow => _p('行を削除', 'Delete row', '删除行', 'Xóa dòng');
  String get boardName => _p('ボード名称', 'Board name', '板材名称', 'Tên tấm');
  String get nameHint => _p('名称入力', 'Enter name', '输入名称', 'Nhập tên');
  String get addThickness => _p('厚さを追加', 'Add thickness', '添加厚度', 'Thêm độ dày');
  String thicknessLayer(int i) => _p('厚さ（$i層）', 'Thickness (layer $i)', '厚度（第$i层）', 'Dày (lớp $i)');
  String sizeLayer(int i) => _p('サイズ（$i層）', 'Size (layer $i)', '尺寸（第$i层）', 'Cỡ (lớp $i)');
  String get addLayer => _p('層を追加', 'Add layer', '添加层', 'Thêm lớp');
  String get deleteLayer => _p('層を削除', 'Remove layer', '删除层', 'Xóa lớp');
  String layerN(int i) => _p('層$i', 'Layer $i', '第$i层', 'Lớp $i');
  String get thickness => _p('厚さ', 'Thickness', '厚度', 'Độ dày');
  String get basicSettings => _p('基本設定', 'Basic settings', '基本设定', 'Cài đặt cơ bản');
  String get goMaterials => _p('材料選択へ', 'Go to materials', '前往材料选择', 'Tới chọn vật tư');

  String get crossDedicated => _p('クロス専用', 'Finish only', '墙纸专用', 'Chỉ hoàn thiện');
  String get crossDedicatedOn => _p('クロス専用 ✓', 'Finish only ✓', '墙纸专用 ✓', 'Chỉ hoàn thiện ✓');
  String get crossDedicatedWall =>
      _p('クロス専用（壁）', 'Finish only (wall)', '墙纸专用（墙）', 'Chỉ hoàn thiện (tường)');
  String get crossDedicatedCeil =>
      _p('クロス専用（天井）', 'Finish only (ceiling)', '墙纸专用（天花）', 'Chỉ hoàn thiện (trần)');
  String get checkAreaName =>
      _p('面積または品名を確認してください', 'Check the area or product name', '请核对面积或品名', 'Kiểm tra diện tích hoặc tên');
  String get measuredArea => _p('測定面積', 'Measured area', '测量面积', 'Diện tích đo');
  String get crossName => _p('品名・品番（クロス）', 'Name / code (finish)', '品名／番号（墙纸）', 'Tên / mã (hoàn thiện)');
  String get nameCode => _p('品名・品番', 'Name / code', '品名／番号', 'Tên / mã');
  String qtyByWidth(String w) =>
      _p('数量（面積÷$w）', 'Qty (area÷$w)', '数量（面积÷$w）', 'SL (diện tích÷$w)');
  String qtyFormula(String w) =>
      _p('数量 = 面積 ÷ クロス幅 $w m', 'Qty = area ÷ finish width $w m', '数量 = 面积 ÷ 墙纸宽 $w m', 'SL = diện tích ÷ khổ $w m');
  String get paste => _p('クロス糊', 'Adhesive', '墙纸胶', 'Keo');
  String get pasteQty => _p('数量（10m=1kg）', 'Qty (10 m = 1 kg)', '数量（10m=1kg）', 'SL (10 m = 1 kg)');
  String get underPate => _p('下地パテ材', 'Base putty', '基层腻子', 'Bột nền');
  String get underPateName => _p('下パテ品名', 'Putty name', '腻子品名', 'Tên bột');
  String get unitKg => _p('単位（kg）', 'Unit (kg)', '单位（kg）', 'Đơn vị (kg)');
  String get needKg => _p('必要量（理論kg）', 'Required (kg)', '需要量（理论kg）', 'Lượng cần (kg)');
  String selectedName(String name) =>
      _p('選択中: $name', 'Selected: $name', '已选: $name', 'Đang chọn: $name');
  String get unselected => _p('（未選択）', '(none)', '（未选）', '(chưa chọn)');
  String get fiberTape => _p('ファイバーテープ', 'Fiber tape', '纤维胶带', 'Băng sợi');
  String get tapeLenM => _p('テープ長さ (m)', 'Tape length (m)', '胶带长度 (m)', 'Dài băng (m)');
  String get tapeLenDirect =>
      _p('テープ長さ（直接入力）', 'Tape length (manual)', '胶带长度（直接输入）', 'Dài băng (nhập tay)');
  String get pcs => _p('個', 'pcs', '个', 'cái');
  String get qtyCeil => _p('数量（切上げ）', 'Qty (rounded up)', '数量（进位）', 'SL (làm tròn lên)');
  String get toEstimate => _p('試算表へ', 'To estimate', '前往试算表', 'Tới bảng tính');
  String get clearAndBack => _p('クリアして戻る', 'Clear and back', '清除并返回', 'Xóa và quay lại');
  String get singleFaceWall => _p('単面壁', 'One-sided wall', '单面墙', 'Tường một mặt');
  String get bothSides => _p('両面', 'Both sides', '双面', 'Hai mặt');
  String get oneSideA =>
      _p('片面（A面のみ）', 'One side (A only)', '单面（仅A面）', 'Một mặt (chỉ A)');
  String get bothFaceWall => _p('両面壁', 'Both-sided wall', '双面墙', 'Tường hai mặt');
  String finishWallThick(String thick, String runner, bool withBoard) => _p(
        '仕上壁厚 約 ${thick}mm（ランナー$runner${withBoard ? ' + ボード' : ''}）',
        'Finished thickness ≈ ${thick}mm (runner $runner${withBoard ? ' + board' : ''})',
        '完成墙厚约 ${thick}mm（地龙骨$runner${withBoard ? ' + 板' : ''}）',
        'Dày hoàn thiện ≈ ${thick}mm (runner $runner${withBoard ? ' + tấm' : ''})',
      );
  String get rockFeltAuto => _p(
        'Z・強化・ハイパー・スーパー／厚さ21mmで自動選択',
        'Auto-selected for Z / reinforced / Hyper / Super, 21 mm thick',
        'Z、强化、Hyper、Super／厚21mm时自动选择',
        'Tự chọn cho Z / gia cường / Hyper / Super, dày 21 mm',
      );
  String rockFeltWxL(String w) =>
      _p('幅${w}mm×長さ1000mm', 'W ${w}mm × L 1000mm', '宽${w}mm×长1000mm', 'Rộng ${w}mm × dài 1000mm');
  String get tiger720jumbo =>
      _p('720ml15本入りジャンボタイプ', '720 ml × 15 jumbo', '720ml×15支加大装', '720 ml × 15 jumbo');
  String get tiger320std =>
      _p('320ml30本入りスタンダードタイプ', '320 ml × 30 standard', '320ml×30支标准装', '320 ml × 30 chuẩn');
  String bothFaceNote(String v) =>
      _p('片面 $v㎡ × 2面（図面は破線表示）', 'One side $v m² × 2 faces (dashed on drawing)', '单面 $v㎡ × 2面（图纸为虚线）', 'Một mặt $v m² × 2 (nét đứt trên bản vẽ)');

  String get dropSettings => _p('下り設定', 'Drop settings', '下吊设定', 'Cài đặt trần thả');
  String dropSettingsNo(int n) =>
      _p('下り設定　番号 $n', 'Drop settings  No.$n', '下吊设定　编号 $n', 'Cài đặt trần thả  số $n');
  String get dropLen => _p('下り長さ (mm)', 'Drop length (mm)', '下吊长度 (mm)', 'Dài trần thả (mm)');
  String get dropLenHelp =>
      _p('第1折点以降の合計', 'Total after the first bend', '第一折点之后的合计', 'Tổng sau gấp 1');
  String get widthMm => _p('幅 (mm)', 'Width (mm)', '宽 (mm)', 'Rộng (mm)');
  String get widthHelp =>
      _p('始点→第1折点', 'Start → first bend', '起点→第一折点', 'Đầu → gấp 1');
  String get heightMm => _p('高さ (mm)', 'Height (mm)', '高度 (mm)', 'Cao (mm)');
  String get dropShape => _p('下り形状', 'Drop shape', '下吊形状', 'Hình trần thả');
  String get enterLWH =>
      _p('長さ・幅・高さを入力してください', 'Enter length, width, and height', '请输入长、宽、高', 'Nhập dài, rộng và cao');
  String get deleteThisDrop => _p('この下りを削除', 'Delete this drop', '删除此下吊', 'Xóa trần thả này');
  String get save => _p('保存', 'Save', '保存', 'Lưu');
  String get wBarH => _p('Wバー高さ', 'W-bar height', 'W条高度', 'Cao thanh W');
  String get wBarL => _p('Wバー長さ', 'W-bar length', 'W条长度', 'Dài thanh W');
  String get sBarH => _p('シングルバー高さ', 'Single-bar height', '单条高度', 'Cao thanh đơn');
  String get sBarL => _p('シングルバー長さ', 'Single-bar length', '单条长度', 'Dài thanh đơn');
  String get ukeW => _p('野縁受け（チャンネル）幅', 'Channel width', '主龙骨（槽）宽', 'Rộng kênh');
  String get channelL => _p('チャンネル長さ', 'Channel length', '槽长', 'Dài kênh');
  String get wClipUke => _p('Wクリップ 野縁受け幅', 'W-clip channel width', 'W夹 主龙骨宽', 'Rộng kênh kẹp W');
  String get sClipUke =>
      _p('シングルクリップ 野縁受け幅', 'Single-clip channel width', '单夹 主龙骨宽', 'Rộng kênh kẹp đơn');

  String get openingDeleteTitle =>
      _p('開口補強を削除', 'Delete opening reinforcement', '删除开口补强', 'Xóa gia cố lỗ');
  String get openingDeleteBody =>
      _p('この開口マーカーを削除しますか？', 'Delete this opening marker?', '要删除此开口标记吗？', 'Xóa dấu lỗ này?');
  String get openingReset => _p('開口補強 — 再設定', 'Opening — reset', '开口补强 — 重设', 'Gia cố lỗ — đặt lại');
  String get openingPickShape =>
      _p('開口補強 — 形状選択', 'Opening — choose shape', '开口补强 — 选择形状', 'Gia cố lỗ — chọn hình');
  String get materialContent => _p('材料内容', 'Materials', '材料内容', 'Nội dung vật tư');
  String get openingH => _p('開口高さ (mm)', 'Opening height (mm)', '开口高度 (mm)', 'Cao lỗ (mm)');
  String get openingW => _p('開口幅 (mm)', 'Opening width (mm)', '开口宽度 (mm)', 'Rộng lỗ (mm)');
  String get lintelTiers => _p('まぐさ段数', 'Lintel tiers', '过梁段数', 'Số tầng đà');
  String nDan(int n) => _p('$n段', '$n tiers', '$n段', '$n tầng');
  String get update => _p('更新', 'Update', '更新', 'Cập nhật');
  String get confirm => _p('確定', 'OK', '确定', 'Xác nhận');

  String get ironMeasure => _p('鉄板測定', 'Iron-plate measure', '铁板测量', 'Đo tôn');
  String get ironTLength =>
      _p('画線長さ（Tの全長）', 'Drawn length (full T)', '画线长度（T全长）', 'Dài nét (toàn bộ T)');
  String get deleteThisLineQ => _p('この線を削除しますか？', 'Delete this line?', '要删除此线吗？', 'Xóa nét này?');

  String get ceilMaterialTitle => _p('天井材料設定', 'Ceiling materials', '天花材料设定', 'Cài đặt vật tư trần');
  String get ceilTotalArea => _p('天井総面積', 'Total ceiling area', '天花总面积', 'Tổng diện tích trần');
  String get other => _p('その他', 'Other', '其他', 'Khác');
  String get otherBoard => _p('その他（ボード）', 'Other (board)', '其他（板材）', 'Khác (tấm)');
  String get dimConfirm => _p('寸法確認', 'Check sizes', '尺寸确认', 'Kiểm tra kích thước');
  String get dimMismatch =>
      _p('寸法が一致しません。よろしいですか？', 'Sizes do not match. Continue?', '尺寸不一致。确定吗？', 'Kích thước không khớp. Tiếp tục?');
  String get resetAuto => _p('自動計算に戻す', 'Back to auto', '恢复自动计算', 'Về tự động');
  String get customInput => _p('カスタム入力', 'Custom', '自定义', 'Tùy chỉnh');
  String get locked => _p('ロック中', 'Locked', '已锁定', 'Đã khóa');
  String get unlocked => _p('解錠中', 'Unlocked', '已解锁', 'Đã mở');
  String get unlockFirst =>
      _p('解錠ボタンを押してから選択してください', 'Unlock first, then select', '请先解锁再选择', 'Hãy mở khóa rồi chọn');
  String get savedSwipeDelete =>
      _p('保存済み（左にスワイプで削除）', 'Saved (swipe left to delete)', '已保存（左滑删除）', 'Đã lưu (vuốt trái để xóa)');
  String get customNameHint =>
      _p('品名（カスタム・入力で保存）', 'Name (custom — save on Done)', '品名（自定义，点完成保存）', 'Tên (tùy chỉnh — lưu khi Xong)');
  String get customSaveHint =>
      _p('入力後「完了」で保存', 'Enter then tap Done to save', '输入后点「完成」保存', 'Nhập rồi chạm Xong để lưu');
  String get extraSizeHint =>
      _p('追加する寸法だけを選んで確定してください。', 'Select only the extra sizes to add, then confirm.', '请只勾选要追加的尺寸后确定。', 'Chỉ chọn kích thước thêm rồi xác nhận.');
  String get extraNameCode => _p('品名・品番', 'Name / code', '品名／番号', 'Tên / mã');
  String qtyWithUnit(String unit) => _p('数量（$unit）', 'Qty ($unit)', '数量（$unit）', 'SL ($unit)');
  String get lineColor => _p('線色', 'Line color', '线色', 'Màu nét');
  String strokeW(String v) => _p('太さ $v', 'Width $v', '粗细 $v', 'Đậm $v');
  String get strokeLabel => _p('線太さ', 'Stroke', '线粗', 'Nét');
  String get triadHint =>
      _p('線尾番号＝線ごと｜タップ→材料・試算／削除｜長押し→削除', 'End number = each line | tap = materials / delete | long-press = delete', '线尾编号=每条线｜点=材料・试算／删除｜长按=删除', 'Số cuối = mỗi nét | chạm = vật tư / xóa | giữ = xóa');

  String get estimate => _p('試算表', 'Estimate', '试算表', 'Bảng tính');
  String get estimateBoard => _p('ボード試算表', 'Board estimate', '板材试算表', 'Bảng tấm');
  String get estimateLgs => _p('LGS試算表', 'LGS estimate', 'LGS试算表', 'Bảng LGS');
  String get estimateCeil => _p('天井試算表', 'Ceiling estimate', '天花试算表', 'Bảng tính trần');
  String get estimateCross => _p('クロス試算表', 'Finish estimate', '墙纸试算表', 'Bảng hoàn thiện');
  String get estimateDrop => _p('下り試算表', 'Drop estimate', '下吊试算表', 'Bảng trần thả');
  String estimateKindTitle(String jp) => switch (jp) {
        'ボード試算表' => estimateBoard,
        'LGS試算表' => estimateLgs,
        'クロス試算表' => estimateCross,
        '下り試算表' => estimateDrop,
        _ => estimate,
      };
  String get boardOnly => _p('ボードのみ', 'Board only', '仅板材', 'Chỉ tấm');
  String get boardOnlyView => _p('ボードのみ表示', 'Board only', '仅显示板材', 'Chỉ hiện tấm');
  String get ceilBaseOnly => _p('天井下地のみ', 'Ceiling frame only', '仅天花基层', 'Chỉ khung trần');
  String get lgsOnlyView => _p('LGSのみ表示', 'LGS only', '仅显示LGS', 'Chỉ hiện LGS');
  String get allItems => _p('すべて', 'All', '全部', 'Tất cả');
  String pageN(int n) => _p('— $n 枚目 —', '— Page $n —', '— 第$n页 —', '— Trang $n —');
  String viewBoard(int n) => _p('表示: ボードのみ（$n件）', 'View: board only ($n)', '显示: 仅板材（$n条）', 'Hiện: chỉ tấm ($n)');
  String viewLgs(int n) => _p('表示: LGSのみ（$n件）', 'View: LGS only ($n)', '显示: 仅LGS（$n条）', 'Hiện: chỉ LGS ($n)');
  String viewCross(int n) => _p('表示: クロスのみ（$n件）', 'View: finish only ($n)', '显示: 仅墙纸（$n条）', 'Hiện: chỉ hoàn thiện ($n)');
  String viewAll(int n) => _p('表示: すべて（$n件）', 'View: all ($n)', '显示: 全部（$n条）', 'Hiện: tất cả ($n)');
  String get date => _p('日付', 'Date', '日期', 'Ngày');
  String get projectName => _p('プロジェクト名', 'Project', '项目名', 'Dự án');
  String get nameOrCode => _p('品名/品番', 'Name / code', '品名／番号', 'Tên / mã');
  String get spec => _p('仕様', 'Spec', '规格', 'Quy cách');
  String get wastePct => _p('ロス率％', 'Waste %', '损耗％', 'Hao hụt %');
  String get total => _p('合計', 'Total', '合计', 'Tổng');
  String get noLines => _p('明細がありません', 'No lines', '没有明细', 'Chưa có dòng');
  String get pickKindFirst => _p(
        '「ボード」「LGS」「クロス」のいずれかを選んでから保存してください',
        'Choose Board, LGS, or Finish before saving',
        '请先选择「板材」「LGS」或「墙纸」再保存',
        'Hãy chọn Tấm, LGS hoặc Hoàn thiện trước khi lưu',
      );
  String savedKind(String kind) => _p('$kindを保存しました', 'Saved $kind', '已保存$kind', 'Đã lưu $kind');
  String get wall => _p('壁', 'Wall', '墙', 'Tường');
  String get ceiling => _p('天井', 'Ceiling', '天花', 'Trần');
  String get drop => _p('下り', 'Drop', '下吊', 'Trần thả');
  String get cross => _p('クロス', 'Finish', '墙纸', 'Hoàn thiện');
  String get wallCeil => _p('壁/天井', 'Wall/Ceiling', '墙/天花', 'Tường/Trần');

  String datePattern() => switch (lang) {
        AppLang.ja || AppLang.zh => 'yyyy年M月d日',
        AppLang.en => 'MMM d, yyyy',
        AppLang.vi => 'd/M/yyyy',
      };

  String get delete => _p('削除', 'Delete', '删除', 'Xóa');
  String get height => _p('高さ', 'Height', '高度', 'Cao');
  String get lengthMm => _p('長さ (mm)', 'Length (mm)', '长度 (mm)', 'Dài (mm)');
  String get typeWidth => _p('種類（幅）', 'Type (width)', '种类（宽）', 'Loại (rộng)');
  String get typeXY => _p('タイプ（横×縦）', 'Type (W×H)', '类型（横×纵）', 'Loại (ngang×dọc)');
  String get ukeWidth => _p('野縁受け幅', 'Channel width', '主龙骨宽', 'Rộng kênh');
  String get uke => _p('野縁受け', 'Channel', '主龙骨', 'Kênh');
  String get sqType => _p('SQ種類', 'SQ type', 'SQ种类', 'Loại SQ');
  String get nutQty => _p('ナット数量', 'Nut qty', '螺母数量', 'SL đai ốc');
  String get hangerQty => _p('ハンガー数量', 'Hanger qty', '吊件数量', 'SL móc');
  String get boltType => _p('ボルト種類', 'Bolt type', '螺栓种类', 'Loại bu lông');
  String get fittingH => _p('金具高さ', 'Fitting height', '五金高度', 'Cao phụ kiện');
  String get boardNamePick => _p('ボード品名', 'Board name', '板材品名', 'Tên tấm');
  String get custom => _p('カスタム', 'Custom', '自定义', 'Tùy chỉnh');
  String get customName => _p('品名（カスタム）', 'Name (custom)', '品名（自定义）', 'Tên (tùy chỉnh)');
  String get lengthPick => _p('長さ選択', 'Length', '选择长度', 'Chọn dài');
  String get wBar => _p('Wバー', 'W-bar', 'W条', 'Thanh W');
  String get sBar => _p('シングルバー', 'Single bar', '单条', 'Thanh đơn');
  String get wClip => _p('Wクリップ', 'W-clip', 'W夹', 'Kẹp W');
  String get sClip => _p('シングルクリップ', 'Single clip', '单夹', 'Kẹp đơn');
  String get wBarJoint => _p('Wバージョイント', 'W-bar joint', 'W条接头', 'Nối thanh W');
  String get sBarJoint =>
      _p('シングルバージョイント', 'Single-bar joint', '单条接头', 'Nối thanh đơn');
  String get sqStud => _p('SQ角スタッド', 'SQ square stud', 'SQ方立柱', 'Thanh vuông SQ');
  String get studClip => _p('角スタクリップ', 'Stud clip', '方柱夹', 'Kẹp thanh vuông');
  String get fullBolt => _p('全ネジボルト', 'Threaded rod', '全螺纹螺栓', 'Bu lông suốt');
  String get nut => _p('ナット', 'Nut', '螺母', 'Đai ốc');
  String get hangerOpt => _p('ハンガーオプション', 'Hanger option', '吊件选项', 'Tùy chọn móc');
  String get channel => _p('野縁受け（チャンネル）', 'Channel', '主龙骨（槽）', 'Kênh');
  String get channelJoint => _p('チャンネルジョイント', 'Channel joint', '槽接头', 'Nối kênh');
  String layerBoard(int i) =>
      _p('第$i層 ボード', 'Layer $i board', '第$i层 板材', 'Lớp $i tấm');
  String get dropLType => _p('L型', 'L-type', 'L型', 'Chữ L');
  String get dropBeam => _p('梁型', 'Beam', '梁型', 'Dầm');
  String get layersX1 => _p('1層', '1 layer', '1层', '1 lớp');
  String get layersX2 => _p('2層', '2 layers', '2层', '2 lớp');
  String get layersX3 => _p('3層', '3 layers', '3层', '3 lớp');

  String get dropLenH => _p('長さ', 'Length', '长', 'Dài');
  String get dropAreaMulti =>
      _p('面積（各区間の幅＋高さ）×長さ', 'Area (each width + height) × length', '面积（各段宽＋高）×长', 'Diện tích (mỗi rộng + cao) × dài');
  String get dropAreaSimple =>
      _p('面積（幅＋高さ）×長さ', 'Area (width + height) × length', '面积（宽＋高）×长', 'Diện tích (rộng + cao) × dài');
  String areaSq(String v) => _p('平米数　$v　㎡', 'Area  $v  m²', '平米　$v　㎡', 'Diện tích  $v  m²');
  String get layersTimesFaces => _p('（層数×面）', '(layers × faces)', '（层数×面）', '(lớp × mặt)');
  String get tigerU720 => _p('720（標準）', '720 (std)', '720（标准）', '720 (chuẩn)');

  String displayArea(String raw) {
    final t = raw.trim();
    if (t == '天井' || t.startsWith('天井')) return ceiling;
    if (t == '壁' || t.startsWith('壁')) return wall;
    if (t == '下り') return drop;
    if (t == 'クロス') return cross;
    if (t.contains('天井') && t.contains('壁')) return wallCeil;
    return t.isEmpty ? wall : t;
  }

  String displayMethod(String raw) {
    final t = raw.trim();
    if (t == 'SQ工法' || t == 'SQ') return sqMethod;
    if (t == '在来工法' || t == '在来') return zairaiMethod;
    return t;
  }

  String displayDropShape(String raw) {
    final t = raw.trim();
    if (t.contains('梁')) return dropBeam;
    if (t.contains('L型') || t.startsWith('L')) return dropLType;
    if (t == '下り') return drop;
    return t;
  }

  String displaySheetKind(String raw) {
    final t = raw.trim();
    if (t == 'ボード') return board;
    if (t == 'LGS') return 'LGS';
    if (t == 'クロス') return cross;
    if (t == '下り') return drop;
    return t;
  }

  String get sqHint => _p(
        'SQ：角スタッド芯々指定ピッチ・両端は図形縁に密着。スタッド長>2200mmで野縁受け1列。全ネジはその列上（辺縁100mm・間隔≤900mm）',
        'SQ: square studs at the set pitch, flush to both edges. Channel row if stud > 2200 mm. Rods on that row (100 mm from edge, ≤900 mm spacing).',
        'SQ：方立柱按设定间距，两端贴图缘。立柱长>2200mm时加一列主龙骨。全螺纹在该列上（边100mm、间距≤900mm）。',
        'SQ: thanh vuông theo bước, sát hai mép. Thêm kênh nếu thanh > 2200 mm. Bu lông trên hàng đó (100 mm mép, ≤900 mm).',
      );
  String get zairai15x3 => _p(
        '在来1.5×3：中心Wから±227/455で展開・両縁W密着',
        'Conventional 1.5×3: from center W at ±227/455, W flush both edges',
        '在来1.5×3：从中心W按±227/455展开，两缘贴W',
        'Truyền thống 1,5×3: từ W giữa ±227/455, W sát hai mép',
      );
  String get zairai3x3 => _p(
        '在来3×3：中心Wから±303/606/910で展開・両縁W密着',
        'Conventional 3×3: from center W at ±303/606/910, W flush both edges',
        '在来3×3：从中心W按±303/606/910展开，两缘贴W',
        'Truyền thống 3×3: từ W giữa ±303/606/910, W sát hai mép',
      );
  String zairai36(String pitch) => _p(
        '在来3×6：縁Wからピッチ$pitchで展開・対縁W密着',
        'Conventional 3×6: from edge W at pitch $pitch, W flush opposite edge',
        '在来3×6：从缘W按间距$pitch展开，对缘贴W',
        'Truyền thống 3×6: từ mép W bước $pitch, W sát mép đối',
      );
  String get zairaiBoltNote => _p(
        '在来：全ネジは辺縁100mmに必ず1列・対辺も同様、前後左右≤900mm。ボード2層以上は材料設定の層数に従いバー配置は3×6版',
        'Conventional: rod row 100 mm from each edge, ≤900 mm both ways. 2+ board layers follow material layers; bar layout uses 3×6.',
        '在来：全螺纹在两边各100mm必有一列，前后左右≤900mm。板2层以上按材料层数，条布置用3×6。',
        'Truyền thống: hàng bu lông 100 mm mỗi mép, ≤900 mm. Từ 2 lớp tấm theo cài đặt; bố trí thanh 3×6.',
      );
}
