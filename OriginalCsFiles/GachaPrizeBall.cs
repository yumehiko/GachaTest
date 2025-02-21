using System.Threading;
using Cysharp.Threading.Tasks;
using DG.Tweening;
using UnityEngine;

namespace GachaPerformance.Scripts
{
    public class GachaPrizeBall : MonoBehaviour
    {
        // 構造
        // このボール自体の初期位置は 0, -1000 px（画面下端の見えない位置にある）サイズは512 x 512 px
        
        // 以下レイヤー。上が最前面。
        // GachaPrizeBallTopLine.svg, size: 512 x 512 px, origin: center, position: 0, 0 px
        [SerializeField] private SpriteRenderer _ballTopLine;
        
        // GachaPrizeBallTop.svg, size: 512 x 512 px, origin: center, position: 0, 0 px
        [SerializeField] private SpriteRenderer _ballTop;
        
        // GachaPrizeBallBottomLine.svg, size: 512 x 512 px, origin: center, position: 0, 0 px
        [SerializeField] private SpriteRenderer _ballBottomLine;
        
        // GachaPrizeBallBottom.svg, size: 512 x 512 px, origin: center, position: 0, 0 px
        [SerializeField] private SpriteRenderer _ballBottom;
        
        
        // コントロール用：
        // TopLineとTopをまとめる親オブジェクト
        [SerializeField] private Transform _ballTopParent;
        
        // BottomLineとBottomをまとめる親オブジェクト
        [SerializeField] private Transform _ballBottomParent;
        
        public void Initialize()
        {
            transform.localPosition = new Vector3(0, -10.0f, 0);
            _ballTopParent.localPosition = Vector3.zero;
            _ballBottomParent.localPosition = Vector3.zero;
        }
        
        public async UniTask AppearAsync(float duration, CancellationToken ct)
        {
            await transform.DOMove(Vector3.zero, duration)
                .SetEase(Ease.OutQuad)
                .ToUniTask(TweenCancelBehaviour.KillAndCancelAwait, cancellationToken: ct);
        }
        
        public async UniTask SplitAsync(float duration, float distance, CancellationToken ct)
        {
            var top = _ballTopParent.DOLocalMoveY(distance, duration)
                .SetEase(Ease.OutQuad)
                .ToUniTask(TweenCancelBehaviour.KillAndCancelAwait, cancellationToken: ct);
            var bottom = _ballBottomParent.DOLocalMoveY(-distance, duration)
                .SetEase(Ease.OutQuad)
                .ToUniTask(TweenCancelBehaviour.KillAndCancelAwait, cancellationToken: ct);
            await UniTask.WhenAll(top, bottom);
        }
        
        public async UniTask CloseAsync(float duration, CancellationToken ct)
        {
            await SplitAsync(duration, 10.0f, ct);
            
        }
    }
}