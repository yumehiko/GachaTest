using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using Cysharp.Threading.Tasks;
using DG.Tweening;
using UnityEngine;

namespace GachaPerformance.Scripts
{
    public class GachaMachine : MonoBehaviour
    {
        /*
         * Machine構造レイヤーメモ。上のものほど前面になる。
         * - GachaMachineFront.svg - 304 x 456 px, origin: bottom, position: 0, 0 px
         * - GachaMachineKnob.svg - 80 x 80 px, origin: center, position: 0, 132 px
         * - この階層に内部ボールを16個配置
         * - GachaMachine.svg - 304 x 456 px, origin: bottom, position: 0, 0 px
         */
        
        [SerializeField] private List<GachaInsideBall> _gachaBalls = new List<GachaInsideBall>(); // 16個。
        [SerializeField] private List<Color> _ballColors = new List<Color>();
        /*
         * Color 一覧：
         * - #E60000
         * - #F27900
         * - #F2DE00
         * - #24D900
         * - #00AAFF
         * - #C000E6
         */
        [SerializeField] private SpriteRenderer _knob; // GachaMachineKnob.svg
        private readonly Vector2 _glassOrigin = new Vector2(0.0f, 3.0f); // ガチャ内部ボールの領域の中心座標
        private const float ContainerRadius = 1.0f;

        public void Initialize()
        {
            gameObject.SetActive(true);
            transform.position = new Vector3(0.0f, 5.0f, 0.0f); // 初期位置。画面上側の見えない位置。
            transform.rotation = Quaternion.identity;
            transform.localScale = new Vector3(1.0f, 1.2f, 1.0f);
            _knob.transform.rotation = Quaternion.identity;
            
            // 内部ガチャボールの初期設定
            var ballPositions = GenerateBallPositions(_glassOrigin, ContainerRadius, 0.32f, 64);
            for (int i = 0; i < _gachaBalls.Count; i++)
            {
                var ball = _gachaBalls[i];
                ball.transform.localPosition = new Vector3(ballPositions[i].x, ballPositions[i].y, ball.transform.position.z);
                ball.SetRandomAngle();
                var randomColor = _ballColors[UnityEngine.Random.Range(0, _ballColors.Count)];
                ball.SetColor(randomColor);
            }
        }
        
        public async UniTask FallAsync(float duration, CancellationToken ct)
        {
            var moveTask = transform.DOLocalMove(new Vector3(0.0f, -2.24f, 0.0f), duration)
                .SetEase(Ease.InQuad)
                .ToUniTask(TweenCancelBehaviour.KillAndCancelAwait, cancellationToken: ct);
            var machineScaleTask = transform.DOScale(Vector3.one, duration)
                .SetEase(Ease.InQuad)
                .ToUniTask(TweenCancelBehaviour.KillAndCancelAwait, cancellationToken: ct);
            
            await UniTask.WhenAll(moveTask, machineScaleTask);
        }
        
        public async UniTask LandAsync(CancellationToken ct)
        {
            var shakeTask = ShakingAnimation();
            var reboundTask = ReboundAnimation();
            await UniTask.WhenAll(shakeTask, reboundTask);
            
            return;
            
            async UniTask ShakingAnimation()
            {
                await transform.DOShakePosition(0.4f, new Vector3(0.2f, 0.0f, 0.0f), 30, 90)
                    .SetEase(Ease.Linear)
                    .ToUniTask(TweenCancelBehaviour.KillAndCancelAwait, cancellationToken: ct);
            }
            
            async UniTask ReboundAnimation()
            {
                await transform.DOScale(new Vector3(1.1f, 0.8f, 1.0f), 0.125f)
                    .SetEase(Ease.OutQuad)
                    .ToUniTask(TweenCancelBehaviour.KillAndCancelAwait, cancellationToken: ct);
                await transform.DOScale(new Vector3(0.95f, 1.05f, 1.0f),0.125f)
                    .SetEase(Ease.OutQuad)
                    .ToUniTask(TweenCancelBehaviour.KillAndCancelAwait, cancellationToken: ct);
                await transform.DOScale(Vector3.one, 0.125f)
                    .SetEase(Ease.OutQuad)
                    .ToUniTask(TweenCancelBehaviour.KillAndCancelAwait, cancellationToken: ct);
            }
        }
        
        public async UniTask BeatLoopAsync(CancellationToken ct)
        {
            try
            {
                var beatScale = new Vector3(1.05f, 0.95f, 1.0f);
                while (!ct.IsCancellationRequested)
                {
                    transform.localScale = beatScale;
                    await transform.DOScale(Vector3.one, 0.5f).SetEase(Ease.OutQuad)
                        .ToUniTask(TweenCancelBehaviour.KillAndCancelAwait, cancellationToken: ct);
                }
            }
            finally
            {
                transform.localScale = Vector3.one;
            }
        }
        
        public async UniTask RotateKnobAsync(float duration, CancellationToken ct)
        {
            await _knob.transform.DORotate(new Vector3(0, 0, -90), duration * 0.4f)
                .SetEase(Ease.OutQuad)
                .ToUniTask(TweenCancelBehaviour.KillAndCancelAwait, cancellationToken: ct);
            
            await UniTask.Delay(TimeSpan.FromSeconds(duration * 0.2f), cancellationToken: ct);
            
            await _knob.transform.DORotate(new Vector3(0, 0, -180), duration * 0.4f)
                .SetEase(Ease.OutQuad)
                .ToUniTask(TweenCancelBehaviour.KillAndCancelAwait, cancellationToken: ct);
            
            // ノブの回転をリセットしておく
            _knob.transform.rotation = Quaternion.identity;
        }

        public async UniTask LotteryAsync(float duration, CancellationToken ct)
        {
            // 抽選アニメーション。
            // すべてのボールをランダムな方向に弾き飛ばしまくる

            var lotteryAnimationCts = CancellationTokenSource.CreateLinkedTokenSource(ct);
            var bounceTasks = _gachaBalls.Select(ball =>
                ball.BounceLoopAsync(_glassOrigin, ContainerRadius, 12.0f, lotteryAnimationCts.Token));
            var rotateTasks = _gachaBalls.Select(ball => ball.RotateLoopAsync(360.0f, lotteryAnimationCts.Token));
            transform.rotation = Quaternion.Euler(0.0f, 0.0f, -2.0f);
            var shakeTask = transform.DORotate(new Vector3(0.0f, 0.0f, 2.0f), 0.05f)
                .SetEase(Ease.Linear)
                .SetLoops(-1, LoopType.Yoyo)
                .ToUniTask(TweenCancelBehaviour.KillAndCancelAwait, cancellationToken: lotteryAnimationCts.Token);
            // すべてのtasksが終わるか、タイムアウト
            var timeoutTask = UniTask.Delay(TimeSpan.FromSeconds(duration), ignoreTimeScale: true, cancellationToken: lotteryAnimationCts.Token);
            await UniTask.WhenAny(UniTask.WhenAll(bounceTasks), UniTask.WhenAll(rotateTasks), shakeTask, timeoutTask);
            lotteryAnimationCts.Cancel();
        }

        public void Hide()
        {
            gameObject.SetActive(false);
        }

        /// <summary>
        /// 円形領域内で、各点間がminDistance以上離れている点群を生成し、
        /// Y座標が低い順にソートしたリストを返す。
        /// </summary>
        /// <param name="center">円の中心</param>
        /// <param name="containerRadius">円の半径</param>
        /// <param name="minDistance">各点間の最低距離</param>
        /// <param name="desiredCount">生成する点数（上限）</param>
        /// <param name="k">Poisson Disk Samplingで各点周辺に試行する候補数</param>
        /// <param name="seed">乱数シード（任意）</param>
        /// <returns>充填順（下側から）の点リスト</returns>
        private List<Vector2> GenerateBallPositions(Vector2 center, float containerRadius, float minDistance, int desiredCount, int k = 30, int? seed = null) 
        {
            /*
             * 流れ：
             * - 円周上にランダムな点を生成（この座標がないと容器内に重力にしたがって張り付いた感じが得られない）
             * - 容器内のランダムな座標に点を生成
             * -- 点同士の最低距離を確保する（ガチャボール自体のサイズを表現する）
             * - Y座標が低い順にソート
             */
            
            var rand = seed.HasValue ? new System.Random(seed.Value) : new System.Random();
            var points = new List<Vector2>();
            var activeList = new List<Vector2>();

            // 円周上のランダムな点を生成
            const int targetCircumferencePoints = 32; // 円周上の点の最大数
            int validCircumferencePoints = 0;
            int attempts = 0;
            const int maxAttempts = targetCircumferencePoints * 8; // 無限ループ回避のための上限
            while (validCircumferencePoints < targetCircumferencePoints && attempts < maxAttempts) {
                attempts++;
                float angle = (float)(rand.NextDouble() * 2 * Mathf.PI);
                var candidate = center + new Vector2(containerRadius * Mathf.Cos(angle), containerRadius * Mathf.Sin(angle));
                // 既存の候補との距離がminDistance以上かチェック
                if (!points.All(p => Vector2.Distance(candidate, p) >= minDistance)) continue;
                points.Add(candidate);
                activeList.Add(candidate);
                validCircumferencePoints++;
            }
            
            // Poisson Disk Samplingで内部の点を生成
            while (activeList.Count > 0 && points.Count < desiredCount) {
                int index = rand.Next(activeList.Count);
                var point = activeList[index];
                bool candidateAccepted = false;

                // 周辺にk個の候補点を生成
                for (int i = 0; i < k; i++) {
                    float angle = (float)(rand.NextDouble() * 2 * Mathf.PI);
                    float distance = minDistance * (1 + (float)rand.NextDouble());
                    var candidate = point + new Vector2(Mathf.Cos(angle), Mathf.Sin(angle)) * distance;

                    // 候補点が円内にあるかチェック
                    if (Vector2.Distance(candidate, center) > containerRadius)
                        continue;

                    // 既存の点すべてとの距離がminDistance以上かチェック
                    bool valid = points.All(p => !(Vector2.Distance(candidate, p) < minDistance));
                    if (!valid) continue;
                    points.Add(candidate);
                    activeList.Add(candidate);
                    candidateAccepted = true;
                    break;
                }
                if (!candidateAccepted) {
                    activeList.RemoveAt(index);
                }
            }

            points.Sort((a, b) => a.y.CompareTo(b.y));

            return points;
        }
    }
}