using System.Threading;
using Cysharp.Threading.Tasks;
using DG.Tweening;
using UnityEngine;

namespace GachaPerformance.Scripts
{
    public class GachaMachineShadow : MonoBehaviour
    {
        // GachaMachineShadow.svg, size: 320 x 64 px, origin: center, position: 0, -192 px
        [SerializeField] private SpriteRenderer _renderer;

        public void Initialize()
        {
            gameObject.SetActive(true);
            transform.localScale = Vector3.zero;
        }
        
        public async UniTask AppearAsync(float duration, CancellationToken ct)
        {
            // 色を変える。元のsvgは白色なので、色を黒に変える。
            _renderer.color = new Color(0.0f, 0.0f, 0.0f, 0.12f);
            await _renderer.transform.DOScale(1, duration)
                .SetEase(Ease.OutQuad)
                .ToUniTask(TweenCancelBehaviour.KillAndCancelAwait, cancellationToken: ct);
        }
        
        public async UniTask DisappearAsync(float duration, CancellationToken ct)
        {
            await _renderer.DOFade(0, duration)
                .SetEase(Ease.OutQuad)
                .ToUniTask(TweenCancelBehaviour.KillAndCancelAwait, cancellationToken: ct);
        }

        public void Hide()
        {
            gameObject.SetActive(false);
        }
    }
}