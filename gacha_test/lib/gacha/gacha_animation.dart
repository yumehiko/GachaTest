import 'dart:async';
import 'package:flutter/material.dart';
import 'gacha_prize_get_button.dart';
import 'gacha_prize_ball.dart';
import 'gacha_prize_view.dart';
import 'gacha_tap_button.dart';
import 'gacha_machine.dart';
import 'gacha_machine_shadow.dart';
import 'gacha_scrim.dart';
import '../utils/cancellation_token.dart';

enum GachaAnimationState {
  preAppear,
  appear,
  idle,
  lottery,
  waitConfirm,
  closing,
}

/// ガチャ演出全体のアニメーションを制御するクラス
///
/// 以下の構造で各コンポーネントを表示します（上が最前面）:
/// - GachaPrizeGetButton：位置 (0, -230px)
/// - GachaPrizeBall：位置 (0, -1000px)
/// - GachaPrizeView：位置 (0, 0)
/// - GachaTapButton：位置 (0, -300px)
/// - GachaMachine：位置 (0, -500px)
/// - GachaMachineShadow：位置 (0, -192px)
/// - GachaScrim：位置 (0, 0)
///
/// ※ 各アニメーション処理には [ct]（キャンセル用トークン）と [ticker]（AnimationController 用 TickerProvider）を必要とします。
class GachaAnimation {
  final GachaPrizeGetButton prizeGetButton;
  final GachaPrizeBall prizeBall;
  final GachaPrizeView prizeView;
  final GachaTapButton tapButton;
  final GachaMachine machine;
  final GachaMachineShadow shadow;
  final GachaScrim scrim;

  /// アニメーションに利用する TickerProvider。通常、StatefulWidget の State で TickerProviderStateMixin を実装しているものを渡します。
  final TickerProvider ticker;

  GachaAnimation({
    required this.prizeGetButton,
    required this.prizeBall,
    required this.prizeView,
    required this.tapButton,
    required this.machine,
    required this.shadow,
    required this.scrim,
    required this.ticker,
  });

  GachaAnimationState state = GachaAnimationState.preAppear;
  CancellationTokenSource? _waitConfirmCts;

  /// 各コンポーネントの初期状態を設定します。
  void initialize() {
    state = GachaAnimationState.preAppear;
    machine.initialize();
    shadow.initialize();
    tapButton.initialize();
    prizeView.initialize();
    prizeBall.initialize();
    prizeGetButton.initialize();
  }

  /// 出現アニメーション
  ///
  /// ・スクリムとタップボタンのフェードインを同時に開始し、  
  /// ・マシーンの落下＋影の出現＋着地アニメーションを順次実行します。
  Future<void> appearAsync(CancellationToken ct) async {
    state = GachaAnimationState.appear;
    final scrimTask = scrim.fadeInAsync(
      duration: Duration(milliseconds: 500),
      ct: ct,
      ticker: ticker,
    );
    final tapButtonTask = tapButton.fadeInAsync(
      duration: Duration(milliseconds: 500),
      ct: ct,
      ticker: ticker,
    );
    final machineAppearTask = _machineAppearAnimation(ct);
    await Future.wait([scrimTask, tapButtonTask, machineAppearTask]);
  }

  Future<void> _machineAppearAnimation(CancellationToken ct) async {
    final fallTask = machine.fallAsync(
      duration: Duration(milliseconds: 400),
      ct: ct,
      ticker: ticker,
    );
    final shadowTask = shadow.appearAsync(
      duration: Duration(milliseconds: 400),
      ct: ct,
      ticker: ticker,
    );
    await Future.wait([fallTask, shadowTask]);
    await machine.landAsync(ct: ct, ticker: ticker);
  }

  /// アイドル状態（マシーンのビートループアニメーション）
  Future<void> idleAsync(CancellationToken ct) async {
    state = GachaAnimationState.idle;
    await machine.beatLoopAsync(ct: ct, ticker: ticker);
  }

  /// 抽選アニメーション
  ///
  /// ・タップボタンのフェードアウト、ノブ回転、スクリムの暗転、抽選アニメーションを同時に開始し、  
  /// ・一定時間後、景品演出（放射飾りの回転開始、景品ボールの出現、ボール分裂＋マスク開放、ゲットボタンの表示）を実行します。
  Future<void> playGachaAsync(CancellationToken ct) async {
    _waitConfirmCts = CancellationTokenSource.createLinked(ct);
    state = GachaAnimationState.lottery;
    // Fire-and-forget 各アニメーション
    tapButton.fadeOutAsync(
      duration: Duration(milliseconds: 250),
      ct: ct,
      ticker: ticker,
    );
    machine.rotateKnobAsync(
      duration: Duration(milliseconds: 600),
      ct: ct,
      ticker: ticker,
    );
    scrim.darkerAsync(
      duration: Duration(milliseconds: 400),
      ct: ct,
      ticker: ticker,
    );
    machine.lotteryAsync(
      duration: Duration(milliseconds: 3000),
      ct: ct,
      ticker: ticker,
    );
    await Future.delayed(Duration(milliseconds: 1500), () {
      ct.throwIfCancellationRequested();
    });

    // 景品演出開始
    // 放射飾りの回転ループ：-360° を 20 秒で実行（speed:20.0f 相当） ※fire-and-forget
    prizeView.emissionRotateLoopAsync(
      duration: Duration(seconds: 20),
      ct: _waitConfirmCts!.token,
      ticker: ticker,
    );
    await prizeBall.appearAsync(
      duration: Duration(milliseconds: 400),
      ct: ct,
      ticker: ticker,
    );
    await Future.delayed(Duration(milliseconds: 300), () {
      ct.throwIfCancellationRequested();
    });
    final ballSplitTask = prizeBall.splitAsync(
      duration: Duration(milliseconds: 400),
      distance: 3.2,
      ct: ct,
      ticker: ticker,
    );
    final maskOpenTask = prizeView.maskOpenAsync(
      duration: Duration(milliseconds: 800),
      ct: ct,
      ticker: ticker,
    );
    await Future.wait([ballSplitTask, maskOpenTask]);
    await prizeGetButton.showAsync(
      duration: Duration(milliseconds: 125),
      ct: ct,
      ticker: ticker,
    );
    state = GachaAnimationState.waitConfirm;
  }

  /// 終了アニメーション
  ///
  /// ・マシーンとその影を非表示にし、  
  /// ・スクリムのフェードアウト、景品ボールの閉じるアニメーション、マスクの閉鎖、ゲットボタンのフェードアウトを同時に実行します。
  Future<void> closeAsync(CancellationToken ct) async {
    state = GachaAnimationState.closing;
    machine.hide();
    shadow.hide();
    final scrimTask = scrim.fadeOutAsync(
      duration: Duration(milliseconds: 400),
      ct: ct,
      ticker: ticker,
    );
    final prizeBallTask = prizeBall.closeAsync(
      duration: Duration(milliseconds: 400),
      ct: ct,
      ticker: ticker,
    );
    final prizeViewTask = prizeView.maskCloseAsync(
      duration: Duration(milliseconds: 400),
      ct: ct,
      ticker: ticker,
    );
    final prizeGetButtonTask = prizeGetButton.hideAsync(
      duration: Duration(milliseconds: 200),
      ct: ct,
      ticker: ticker,
    );
    await Future.wait([scrimTask, prizeBallTask, prizeViewTask, prizeGetButtonTask]);
    _waitConfirmCts?.cancel();
  }
}
