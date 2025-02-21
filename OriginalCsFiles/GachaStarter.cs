using System;
using System.Threading;
using Cysharp.Threading.Tasks;
using UnityEngine;

namespace GachaPerformance.Scripts
{
    /// <summary>
    /// Clickableで、クリックするとGachaAnimationを開始する
    /// </summary>
    public class GachaStarter : MonoBehaviour
    {
        [SerializeField] private GachaAnimation _gachaAnimation;

        private CancellationTokenSource _animationCts;
        private CancellationTokenSource _idleCts;
        
        private void OnMouseDown()
        {
            switch (_gachaAnimation.State)
            {
                case GachaAnimationState.PreAppear:
                    AppearGachaAnimation().Forget();
                    break;
                case GachaAnimationState.Idle:
                    _idleCts.Cancel();
                    _gachaAnimation.PlayGachaAsync(_animationCts.Token).Forget();
                    break;
                case GachaAnimationState.Appear:
                    break;
                case GachaAnimationState.Lottery:
                    break;
                case GachaAnimationState.WaitConfirm:
                    CloseGachaAnimation().Forget();
                    break;
                case GachaAnimationState.Closing:
                    break;
                default:
                    throw new ArgumentOutOfRangeException();
            }
            
            return;
            
            async UniTask AppearGachaAnimation()
            {
                _animationCts = new CancellationTokenSource();
                _gachaAnimation.Initialize();
                await _gachaAnimation.AppearAsync(_animationCts.Token);
                _idleCts = CancellationTokenSource.CreateLinkedTokenSource(_animationCts.Token);
                _gachaAnimation.IdleAsync(_idleCts.Token).Forget();
            }
            
            async UniTask CloseGachaAnimation()
            {
                await _gachaAnimation.CloseAsync(_animationCts.Token);
                _gachaAnimation.Initialize();
                _animationCts.Dispose();
                _animationCts = null;
            }
        }
        

        private void OnDestroy()
        {
            _animationCts?.Cancel();
            _animationCts?.Dispose();
            _idleCts?.Cancel();
            _idleCts?.Dispose();
        }
    }
}