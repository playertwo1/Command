using System;
using System.Linq;
using Command.Services;
using Moq;
using Xunit;

namespace Command.Tests
{
    public sealed class RemoteControlSessionTests
    {
        [Fact]
        public void IniciarSessao_SucessoQuandoDesktopProntoEPapelFullControl()
        {
            var desktopMock = new Mock<IDesktopCaptureProvider>();
            desktopMock.Setup(d => d.CheckSessionState()).Returns(DesktopSessionState.Ready);

            var policy = new SecurityPolicyService();
            var clock = new TestClock(DateTimeOffset.UtcNow);
            var service = new RemoteControlSessionService(desktopMock.Object, policy, clock);

            var result = service.TryStartSession("device-1", "FullControl");

            Assert.Equal(SessionStartStatus.Success, result.Status);
            Assert.NotNull(result.Session);
            Assert.Equal("device-1", result.Session!.DeviceId);
            Assert.True(service.IsSessionActive);

            var audit = policy.GetAuditLog();
            Assert.Contains(audit, a => a.ActionType == "remote_input.session_start" && a.DeviceId == "device-1");
        }

        [Fact]
        public void IniciarSessao_RejeitaQuandoDesktopBloqueadoOuUac()
        {
            var desktopMock = new Mock<IDesktopCaptureProvider>();
            desktopMock.Setup(d => d.CheckSessionState()).Returns(DesktopSessionState.SessionLocked);

            var policy = new SecurityPolicyService();
            var service = new RemoteControlSessionService(desktopMock.Object, policy);

            var result = service.TryStartSession("device-1", "FullControl");

            Assert.Equal(SessionStartStatus.Locked, result.Status);
            Assert.Equal("SESSION_LOCKED", result.Reason);
            Assert.False(service.IsSessionActive);
        }

        [Fact]
        public void IniciarSessao_RejeitaPapelViewerOnly()
        {
            var desktopMock = new Mock<IDesktopCaptureProvider>();
            desktopMock.Setup(d => d.CheckSessionState()).Returns(DesktopSessionState.Ready);

            var policy = new SecurityPolicyService();
            var service = new RemoteControlSessionService(desktopMock.Object, policy);

            var result = service.TryStartSession("device-1", "ViewerOnly");

            Assert.Equal(SessionStartStatus.Forbidden, result.Status);
            Assert.False(service.IsSessionActive);
        }

        [Fact]
        public void IniciarSessao_ConflitoQuandoOutroDispositivoAtivo()
        {
            var desktopMock = new Mock<IDesktopCaptureProvider>();
            desktopMock.Setup(d => d.CheckSessionState()).Returns(DesktopSessionState.Ready);

            var policy = new SecurityPolicyService();
            var service = new RemoteControlSessionService(desktopMock.Object, policy);

            var res1 = service.TryStartSession("device-1", "FullControl");
            Assert.Equal(SessionStartStatus.Success, res1.Status);

            var res2 = service.TryStartSession("device-2", "FullControl");
            Assert.Equal(SessionStartStatus.Conflict, res2.Status);
            Assert.Equal("device-1", res2.ActiveDeviceId);
        }

        [Fact]
        public void TimeoutInatividade_ExpiraApos60Segundos()
        {
            var desktopMock = new Mock<IDesktopCaptureProvider>();
            desktopMock.Setup(d => d.CheckSessionState()).Returns(DesktopSessionState.Ready);

            var policy = new SecurityPolicyService();
            var clock = new TestClock(DateTimeOffset.UtcNow);
            var service = new RemoteControlSessionService(desktopMock.Object, policy, clock, TimeSpan.FromSeconds(60));

            service.TryStartSession("device-1", "FullControl");
            Assert.True(service.IsSessionActive);

            // 59 segundos: ainda ativa
            clock.Advance(TimeSpan.FromSeconds(59));
            Assert.True(service.IsSessionActive);

            // Passou de 60 segundos sem atividade: expirou
            clock.Advance(TimeSpan.FromSeconds(2));
            Assert.False(service.IsSessionActive);
            Assert.Null(service.ActiveSession);

            var audit = policy.GetAuditLog();
            Assert.Contains(audit, a => a.ActionType.StartsWith("remote_input.session_end:IdleTimeout"));
        }

        [Fact]
        public void EncerrarDaBandeja_FinalizaSessaoAtiva()
        {
            var desktopMock = new Mock<IDesktopCaptureProvider>();
            desktopMock.Setup(d => d.CheckSessionState()).Returns(DesktopSessionState.Ready);

            var policy = new SecurityPolicyService();
            var service = new RemoteControlSessionService(desktopMock.Object, policy);

            service.TryStartSession("device-1", "FullControl");
            Assert.True(service.IsSessionActive);

            Assert.True(service.ForceEndSession("TerminatedFromTray"));
            Assert.False(service.IsSessionActive);

            var audit = policy.GetAuditLog();
            Assert.Contains(audit, a => a.ActionType.StartsWith("remote_input.session_end:TerminatedFromTray"));
        }

        [Fact]
        public void RateLimiting_BloqueiaExcessoDeEventosPorSegundo()
        {
            var desktopMock = new Mock<IDesktopCaptureProvider>();
            desktopMock.Setup(d => d.CheckSessionState()).Returns(DesktopSessionState.Ready);

            var policy = new SecurityPolicyService();
            var clock = new TestClock(DateTimeOffset.UtcNow);
            var service = new RemoteControlSessionService(desktopMock.Object, policy, clock);

            service.TryStartSession("device-1", "FullControl");

            // 120 eventos no mesmo segundo são permitidos
            for (int i = 0; i < 120; i++)
            {
                var val = service.ValidateCanInput("device-1", "FullControl");
                Assert.Equal(SessionValidateStatus.Allowed, val.Status);
            }

            // O 121º é bloqueado por rate limit
            var blocked = service.ValidateCanInput("device-1", "FullControl");
            Assert.Equal(SessionValidateStatus.RateLimitExceeded, blocked.Status);

            // No próximo segundo, volta a permitir
            clock.Advance(TimeSpan.FromSeconds(1));
            var nextSec = service.ValidateCanInput("device-1", "FullControl");
            Assert.Equal(SessionValidateStatus.Allowed, nextSec.Status);
        }

        [Fact]
        public void Auditoria_NaoRegistraTextoTeclasOuCoordenadas()
        {
            var desktopMock = new Mock<IDesktopCaptureProvider>();
            desktopMock.Setup(d => d.CheckSessionState()).Returns(DesktopSessionState.Ready);

            var policy = new SecurityPolicyService();
            var service = new RemoteControlSessionService(desktopMock.Object, policy);

            service.TryStartSession("device-1", "FullControl");
            service.ValidateCanInput("device-1", "FullControl");
            service.TryEndSession("device-1", "UserRequested");

            var log = policy.GetAuditLog();
            foreach (var entry in log)
            {
                Assert.DoesNotContain("secret", entry.ActionType, StringComparison.OrdinalIgnoreCase);
                Assert.DoesNotContain("click", entry.ActionType, StringComparison.OrdinalIgnoreCase);
                Assert.DoesNotContain("move", entry.ActionType, StringComparison.OrdinalIgnoreCase);
                Assert.DoesNotContain("key", entry.ActionType, StringComparison.OrdinalIgnoreCase);
            }
        }

        private sealed class TestClock : TimeProvider
        {
            private DateTimeOffset _now;
            public TestClock(DateTimeOffset now) => _now = now;
            public override DateTimeOffset GetUtcNow() => _now;
            public void Advance(TimeSpan amount) => _now += amount;
        }
    }
}
