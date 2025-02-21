using System;
using System.Threading;
using Cysharp.Threading.Tasks;
using UnityEngine;

namespace GachaPerformance.Scripts
{
    /// <summary>
    /// ガチャガチャのアニメーションの制御
    /// </summary>
    public class GachaAnimation : MonoBehaviour
    {
        // 構造とそれぞれの初期位置。上が最前面。
        [SerializeField] private GachaPrizeGetButton _prizeGetButton; // position: 0, -230 px
        [SerializeField] private GachaPrizeBall _prizeBall; // position: 0, -1000 px
        [SerializeField] private GachaPrizeView _prizeView; // position: 0, 0
        [SerializeField] private GachaTapButton _tapButton; // position: 0, -300 px
        [SerializeField] private GachaMachine _machine; // position: 0, -500 px
        [SerializeField] private GachaMachineShadow _shadow; // position: 0, -192 px
        [SerializeField] private GachaScrim _scrim; // position: 0, 0
        public GachaAnimationState State { get; private set; } = GachaAnimationState.PreAppear;
        private CancellationTokenSource _waitConfirmCts;
        
        public void Initialize()
        {
            State = GachaAnimationState.PreAppear;
            _machine.Initialize();
            _shadow.Initialize();
            _tapButton.Initialize();
            _prizeView.Initialize();
            _prizeBall.Initialize();
            _prizeGetButton.Initialize();
        }
        
        public async UniTask AppearAsync(CancellationToken ct)
        {
            State = GachaAnimationState.Appear;
            var scrimTask = _scrim.FadeInAsync(duration: 0.5f, ct);
            var tapButtonTask = _tapButton.FadeInAsync(duration: 0.5f, ct);
            var machineAppearTask = MachineAppearAnimation();
            await UniTask.WhenAll(scrimTask, tapButtonTask, machineAppearTask);
            
            return;
            
            async UniTask MachineAppearAnimation()
            {
                var fallTask = _machine.FallAsync(duration: 0.4f, ct);
                var shadowTask = _shadow.AppearAsync(duration: 0.4f, ct);
                await UniTask.WhenAll(fallTask, shadowTask);
                await _machine.LandAsync(ct);
            }
        }
        
        public async UniTask IdleAsync(CancellationToken ct)
        {
            State = GachaAnimationState.Idle;
            await _machine.BeatLoopAsync(ct);
        }
        
        public async UniTask PlayGachaAsync(CancellationToken ct)
        {
            _waitConfirmCts = CancellationTokenSource.CreateLinkedTokenSource(ct);
            
            State = GachaAnimationState.Lottery;
             _tapButton.FadeOutAsync(duration: 0.25f, ct).Forget();
            _machine.RotateKnobAsync(duration: 0.6f, ct).Forget();
            _scrim.DarkerAsync(duration: 0.4f, ct).Forget();
            _machine.LotteryAsync(duration: 3.0f, ct).Forget();
            await UniTask.Delay(TimeSpan.FromSeconds(1.5f), cancellationToken: ct);
            
            _prizeView.EmissionRotateLoopAsync(speed: 20.0f, _waitConfirmCts.Token).Forget();
            await _prizeBall.AppearAsync(duration: 0.4f, ct);
            await UniTask.Delay(TimeSpan.FromSeconds(0.3f), cancellationToken: ct);
            var ballSplitTask = _prizeBall.SplitAsync(duration: 0.4f, 3.2f, ct);
            var maskOpenTask = _prizeView.MaskOpenAsync(duration: 0.8f, ct);
            await UniTask.WhenAll(ballSplitTask, maskOpenTask);
            await _prizeGetButton.ShowAsync(duration: 0.125f, ct);
            State = GachaAnimationState.WaitConfirm;
        }
        
        public async UniTask CloseAsync(CancellationToken ct)
        {
            State = GachaAnimationState.Closing;
            _machine.Hide();
            _shadow.Hide();
            var scrimTask = _scrim.FadeOutAsync(duration: 0.4f, ct);
            var prizeBallTask = _prizeBall.CloseAsync(duration: 0.4f, ct);
            var prizeViewTask = _prizeView.MaskCloseAsync(duration: 0.4f, ct);
            var prizeGetButtonTask = _prizeGetButton.HideAsync(duration: 0.2f, ct);
            await UniTask.WhenAll(scrimTask, prizeBallTask, prizeViewTask, prizeGetButtonTask);
            _waitConfirmCts.Cancel();
        }
    }
    
    public enum GachaAnimationState
    {
        PreAppear,
        Appear,
        Idle,
        Lottery,
        WaitConfirm,
        Closing,
    }
}
