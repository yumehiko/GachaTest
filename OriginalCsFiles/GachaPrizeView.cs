using System.Threading;
using Cysharp.Threading.Tasks;
using UnityEngine;
using DG.Tweening;

namespace GachaPerformance.Scripts
{
    /// <summary>
    /// ガチャの景品の表示。背景と一体化した画面全体に表示される一連のアニメーション。全体をマスクできる円形オブジェクトがあり、マスクの拡大縮小によって表示を制御する。
    /// </summary>
    public class GachaPrizeView : MonoBehaviour
    {
        // レイヤー構造。上が最前面。

        // GachaPrizeAmount.svg, size: 512 x 512 px, origin: center, position: 0, 0 px
        [SerializeField] private SpriteRenderer _amount;

        // GachaPrizeUnit.svg, size: 198 x 82 px, origin: center, position: 0, -122 px
        [SerializeField] private SpriteRenderer _unit;
        
        // GachaEmission.svg, size: 2048 x 2048 px, origin: center, position: 0, 0 px
        [SerializeField] private SpriteRenderer _emission;
        
        // GachaPrizeBackBase.svg, size: 1024 x 1024 px, origin: center, position: 0, 0 px
        [SerializeField] private SpriteRenderer _backBase;
        
        // GachaPrizeMaskCircle.svg, size: 2048 x 2048 px, origin: center, position: 0, 0 px *マスク用オブジェクト
        [SerializeField] private SpriteMask _mask;
        
        public void Initialize()
        {
            _mask.transform.localScale = new Vector3(1.0f, 0.0f, 1.0f);
            _emission.transform.localRotation = Quaternion.identity;
        }
        
        /// <summary>
        /// マスクを開くアニメーション。円形で中央から拡大され、それに伴ってViewが表示される。
        /// </summary>
        /// <param name="duration"></param>
        /// <param name="ct"></param>
        public async UniTask MaskOpenAsync(float duration, CancellationToken ct)
        {
            await _mask.transform.DOScale(1, duration)
                .SetEase(Ease.Linear)
                .ToUniTask(TweenCancelBehaviour.KillAndCancelAwait, cancellationToken: ct);
        }
        
        /// <summary>
        /// マスクを閉じるアニメーション。円形で中央に向かって縮小され、それに伴ってViewが非表示になる。
        /// </summary>
        /// <param name="duration"></param>
        /// <param name="ct"></param>
        public async UniTask MaskCloseAsync(float duration, CancellationToken ct)
        {
            await _mask.transform.DOScale(0, duration)
                .SetEase(Ease.OutQuad)
                .ToUniTask(TweenCancelBehaviour.KillAndCancelAwait, cancellationToken: ct);
        }
        
        /// <summary>
        /// 放射飾りが回転するループ。
        /// </summary>
        /// <param name="speed"></param>
        /// <param name="ct"></param>
        public async UniTask EmissionRotateLoopAsync(float speed, CancellationToken ct)
        {
            while (!ct.IsCancellationRequested)
            {
                await _emission.transform.DORotate(new Vector3(0, 0, -360), speed, RotateMode.FastBeyond360)
                    .SetEase(Ease.Linear)
                    .SetSpeedBased()
                    .SetLoops(-1, LoopType.Restart)
                    .ToUniTask(TweenCancelBehaviour.KillAndCancelAwait, cancellationToken: ct);
            }
        }
        
    }
}