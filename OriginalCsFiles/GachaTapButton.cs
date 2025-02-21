using System.Threading;
using Cysharp.Threading.Tasks;
using DG.Tweening;
using UnityEngine;

namespace GachaPerformance.Scripts
{
    /// <summary>
    /// タップボタン。実際のタップ挙動はなく、単なる飾り。
    /// </summary>
    public class GachaTapButton : MonoBehaviour
    {
        // GachaTapButton.svg,
        // size: 288 x 96 px, origin: center, position: 0, -300px
        [SerializeField] private SpriteRenderer _renderer;

        public void Initialize()
        {
            // 透明度を0にする
            _renderer.color = new Color(1, 1, 1, 0);
        }

        public async UniTask FadeInAsync(float duration, CancellationToken ct)
        {
            await _renderer.DOFade(1, duration)
                .SetEase(Ease.OutQuad)
                .ToUniTask(TweenCancelBehaviour.KillAndCancelAwait, cancellationToken: ct);
        }

        public async UniTask FadeOutAsync(float duration, CancellationToken ct)
        {
            await _renderer.DOFade(0, duration)
                .SetEase(Ease.OutQuad)
                .ToUniTask(TweenCancelBehaviour.KillAndCancelAwait, cancellationToken: ct);
        }
    }
}