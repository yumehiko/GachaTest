using System.Threading;
using Cysharp.Threading.Tasks;
using DG.Tweening;
using UnityEngine;

namespace GachaPerformance.Scripts
{
    /// <summary>
    /// ゲットボタン。実際の挙動はなく、単なる飾り。
    /// </summary>
    public class GachaPrizeGetButton : MonoBehaviour
    {
        // GachaPrizeGetButton.svg, size: 288 x 96 px, origin: center, position: 0, -230 px
        [SerializeField] private SpriteRenderer _button;
        
        public void Initialize()
        {
            _button.color = new Color(1, 1, 1, 0);
        }
        
        public async UniTask ShowAsync(float duration, CancellationToken ct)
        {
            await _button.DOFade(1, duration)
                .SetEase(Ease.OutQuad)
                .ToUniTask(TweenCancelBehaviour.KillAndCancelAwait, cancellationToken: ct);
        }
        
        public async UniTask HideAsync(float duration, CancellationToken ct)
        {
            await _button.DOFade(0, duration)
                .SetEase(Ease.OutQuad)
                .ToUniTask(TweenCancelBehaviour.KillAndCancelAwait, cancellationToken: ct);
        }
    }
}