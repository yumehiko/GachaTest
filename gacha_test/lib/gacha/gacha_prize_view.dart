import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/cancellation_token.dart';

/// ガチャの景品表示を管理するクラス
///
/// 以下のレイヤー構造で表示されます（上が最前面）：
///
/// - GachaPrizeBackBase.svg (1024 x 1024 px, origin: center)
/// - GachaEmission.svg (2048 x 2048 px, origin: center) ※放射飾り（回転アニメーション）
/// - GachaPrizeAmount.svg (512 x 512 px, origin: center)
/// - GachaPrizeUnit.svg (198 x 82 px, origin: center, offset: (0, -122))
///
/// また、全体は GachaPrizeMaskCircle.svg に相当するマスクでクリッピングされ、
/// マスクのスケールアニメーションで表示・非表示が制御されます。
class GachaPrizeView {
  // マスクのスケール（初期値は 0：非表示状態。最終的に 1.0 になる）
  final ValueNotifier<double> _maskScale = ValueNotifier<double>(0.0);
  // 放射飾りの回転角度（度）
  final ValueNotifier<double> _emissionRotation = ValueNotifier<double>(0.0);

  GachaPrizeView();

  /// 初期状態を設定します。
  void initialize() {
    // マスクは初期状態で縦方向が 0 ＝ 非表示
    _maskScale.value = 0.0;
    // 放射飾りは回転なし
    _emissionRotation.value = 0.0;
  }

  /// マスクを開くアニメーション
  ///
  /// 中央から円形に拡大し、景品ビューを表示します。
  Future<void> maskOpenAsync({
    required Duration duration,
    required CancellationToken ct,
    required TickerProvider ticker,
  }) async {
    ct.throwIfCancellationRequested();
    final controller = AnimationController(vsync: ticker, duration: duration);
    final animation = Tween<double>(
      begin: _maskScale.value,
      end: 1.0,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.linear));
    final completer = Completer<void>();

    void listener() {
      _maskScale.value = animation.value;
      if (controller.status == AnimationStatus.completed) {
        completer.complete();
      }
    }
    controller.addListener(listener);
    controller.forward();
    if (ct.isCancelled) {
      controller.dispose();
      throw CancellationException();
    }
    await completer.future;
    controller.removeListener(listener);
    controller.dispose();
  }

  /// マスクを閉じるアニメーション
  ///
  /// 中央に向かって縮小し、景品ビューを非表示にします。
  Future<void> maskCloseAsync({
    required Duration duration,
    required CancellationToken ct,
    required TickerProvider ticker,
  }) async {
    ct.throwIfCancellationRequested();
    final controller = AnimationController(vsync: ticker, duration: duration);
    final animation = Tween<double>(
      begin: _maskScale.value,
      end: 0.0,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutQuad));
    final completer = Completer<void>();

    void listener() {
      _maskScale.value = animation.value;
      if (controller.status == AnimationStatus.completed) {
        completer.complete();
      }
    }
    controller.addListener(listener);
    controller.forward();
    if (ct.isCancelled) {
      controller.dispose();
      throw CancellationException();
    }
    await completer.future;
    controller.removeListener(listener);
    controller.dispose();
  }

  /// 放射飾りの回転ループアニメーション
  ///
  /// 指定された duration ごとに -360° の回転を実行します。
  Future<void> emissionRotateLoopAsync({
    required Duration duration,
    required CancellationToken ct,
    required TickerProvider ticker,
  }) async {
    while (!ct.isCancelled) {
      ct.throwIfCancellationRequested();
      final controller = AnimationController(vsync: ticker, duration: duration);
      final startRotation = _emissionRotation.value;
      final animation = Tween<double>(
        begin: startRotation,
        end: startRotation - 360,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.linear));
      final completer = Completer<void>();

      void listener() {
        _emissionRotation.value = animation.value;
        if (controller.status == AnimationStatus.completed) {
          completer.complete();
        }
      }
      controller.addListener(listener);
      controller.forward();
      try {
        await completer.future;
      } catch (e) {
        controller.dispose();
        break;
      }
      controller.removeListener(listener);
      controller.dispose();
    }
  }

  /// 景品表示の各レイヤーを重ねた Widget を構築します（マスク未適用）
  Widget buildWidget() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 背景ベース
        SvgPicture.asset(
          'assets/gacha/GachaPrizeBackBase.svg',
          width: 1024,
          height: 1024,
          alignment: Alignment.center,
        ),
        // 放射飾り（回転アニメーション）
        ValueListenableBuilder<double>(
          valueListenable: _emissionRotation,
          builder: (context, rotation, child) {
            return Transform.rotate(
              angle: rotation * pi / 180,
              child: SvgPicture.asset(
                'assets/gacha/GachaEmission.svg',
                width: 2048,
                height: 2048,
                alignment: Alignment.center,
              ),
            );
          },
        ),
        // 景品額
        SvgPicture.asset(
          'assets/gacha/GachaPrizeAmount.svg',
          width: 512,
          height: 512,
          alignment: Alignment.center,
        ),
        // 景品単位（下にオフセット）
        Transform.translate(
          offset: const Offset(0, -122),
          child: SvgPicture.asset(
            'assets/gacha/GachaPrizeUnit.svg',
            width: 198,
            height: 82,
            alignment: Alignment.center,
          ),
        ),
      ],
    );
  }

  /// マスク（円形クリッピング）を適用した景品表示 Widget を構築します。
  ///
  /// マスクは、_maskScale の値に応じて表示が変化します。
  Widget buildMaskedWidget() {
    return ValueListenableBuilder<double>(
      valueListenable: _maskScale,
      builder: (context, maskScale, child) {
        return ClipOval(
          child: Transform.scale(
            scale: maskScale,
            alignment: Alignment.center,
            child: child,
          ),
        );
      },
      child: buildWidget(),
    );
  }
}
