using System.Threading;
using Cysharp.Threading.Tasks;
using DG.Tweening;
using UnityEngine;

namespace GachaPerformance.Scripts
{
    public class GachaScrim : MonoBehaviour
    {
        // ここではSpriteRendererを使っているが、実際には画面全体を覆う矩形でよい。
        [SerializeField] private SpriteRenderer _background;
        
        public async UniTask FadeInAsync(float duration, CancellationToken ct)
        {
            await _background.DOFade(0.5f, duration)
                .SetEase(Ease.OutQuad)
                .ToUniTask(TweenCancelBehaviour.KillAndCancelAwait, cancellationToken: ct);
        }
        
        public async UniTask DarkerAsync(float duration, CancellationToken ct)
        {
            await _background.DOFade(0.7f, duration)
                .SetEase(Ease.OutQuad)
                .ToUniTask(TweenCancelBehaviour.KillAndCancelAwait, cancellationToken: ct);
        }
        
        public async UniTask FadeOutAsync(float duration, CancellationToken ct)
        {
            await _background.DOFade(0f, duration)
                .SetEase(Ease.OutQuad)
                .ToUniTask(TweenCancelBehaviour.KillAndCancelAwait, cancellationToken: ct);
        }
    }
}