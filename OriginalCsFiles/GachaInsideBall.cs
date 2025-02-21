using System.Threading;
using Cysharp.Threading.Tasks;
using DG.Tweening;
using UnityEngine;

namespace GachaPerformance.Scripts
{
    /// <summary>
    /// ガチャマシーン内部のボールを表すクラス
    /// </summary>
    public class GachaInsideBall : MonoBehaviour
    {
        // レイヤー構造。上が最前面。
        // GachaInsideBallFront.svg, size: 64 x 64 px, origin: center, position: 0, 0 px
        [SerializeField] private SpriteRenderer _front;
        
        // GachaInsideBallWhite.svg, size: 64 x 64 px, origin: center, position: 0, 0 px
        [SerializeField] private SpriteRenderer _white;
        
        // GachaInsideBallCoin.svg, size: 32 x 32 px, origin: center, position: 0, 0 px
        [SerializeField] private SpriteRenderer _coin;
        
        // GachaInsideBallBack.svg, size: 64 x 64 px, origin: center, position: 0, 0 px
        [SerializeField] private SpriteRenderer _back;
        
        
        /// <summary>
        /// ボールを容器内部ランダムな方向の円周上まで弾き飛ばす。
        /// </summary>
        public async UniTask BounceLoopAsync(Vector2 containerCenter, float containerRadius, float speed, CancellationToken ct)
        {
            while (!ct.IsCancellationRequested)
            {
                Vector2 targetPosition = Random.insideUnitCircle.normalized * containerRadius + containerCenter;
                await transform.DOLocalMove(targetPosition, speed)
                    .SetSpeedBased()
                    .SetEase(Ease.Linear)
                    .ToUniTask(TweenCancelBehaviour.KillAndCancelAwait, cancellationToken: ct);
            }
        }
        
        public async UniTask RotateLoopAsync(float speed, CancellationToken ct)
        {
            while (!ct.IsCancellationRequested)
            {
                await transform.DOLocalRotate(new Vector3(0, 0, 360), speed, RotateMode.FastBeyond360)
                    .SetEase(Ease.Linear)
                    .SetSpeedBased()
                    .ToUniTask(TweenCancelBehaviour.KillAndCancelAwait, cancellationToken: ct);
            }
        }
        
        public void SetColor(Color color)
        {
            _back.color = color;
            _front.color = color;
        }
        
        public void SetRandomAngle()
        {
            int angle = Random.Range(0, 360);
            transform.localRotation = Quaternion.Euler(0, 0, angle);
        }
    }
}