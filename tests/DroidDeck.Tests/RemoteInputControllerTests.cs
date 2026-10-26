using System.Security.Claims;
using DroidDeck.Controllers;
using DroidDeck.Lib.Input;
using DroidDeck.Models;
using DroidDeck.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Moq;
using Xunit;

namespace DroidDeck.Tests
{
    public sealed class RemoteInputControllerTests
    {
        private static RemoteInputController CreateController(
            IRemoteControlSessionService sessionService,
            IRemoteInputInjector injector,
            string deviceId = "device-1",
            string role = "FullControl")
        {
            var controller = new RemoteInputController(sessionService, injector);
            var claims = new[]
            {
                new Claim("device_id", deviceId),
                new Claim("device_role", role)
            };
            var identity = new ClaimsIdentity(claims, "PairedDevice");
            controller.ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext
                {
                    User = new ClaimsPrincipal(identity)
                }
            };
            return controller;
        }

        [Fact]
        public void StartSession_RetornaOkComSessao()
        {
            var sessionMock = new Mock<IRemoteControlSessionService>();
            var session = new RemoteControlSession("sess-1", "device-1", System.DateTimeOffset.UtcNow, System.DateTimeOffset.UtcNow);
            sessionMock.Setup(s => s.TryStartSession("device-1", "FullControl"))
                .Returns(SessionStartResult.Succeeded(session));

            var injectorMock = new Mock<IRemoteInputInjector>();
            var controller = CreateController(sessionMock.Object, injectorMock.Object);

            var result = controller.StartSession() as OkObjectResult;
            Assert.NotNull(result);
            Assert.Equal(200, result.StatusCode);
        }

        [Fact]
        public void StartSession_Retorna423QuandoDesktopBloqueado()
        {
            var sessionMock = new Mock<IRemoteControlSessionService>();
            sessionMock.Setup(s => s.TryStartSession("device-1", "FullControl"))
                .Returns(SessionStartResult.Locked("SESSION_LOCKED"));

            var injectorMock = new Mock<IRemoteInputInjector>();
            var controller = CreateController(sessionMock.Object, injectorMock.Object);

            var result = controller.StartSession() as ObjectResult;
            Assert.NotNull(result);
            Assert.Equal(423, result.StatusCode);
        }

        [Fact]
        public void StartSession_Retorna403QuandoViewerOnly()
        {
            var sessionMock = new Mock<IRemoteControlSessionService>();
            sessionMock.Setup(s => s.TryStartSession("device-1", "ViewerOnly"))
                .Returns(SessionStartResult.Forbidden("INSUFFICIENT_DEVICE_ROLE"));

            var injectorMock = new Mock<IRemoteInputInjector>();
            var controller = CreateController(sessionMock.Object, injectorMock.Object, role: "ViewerOnly");

            var result = controller.StartSession() as ObjectResult;
            Assert.NotNull(result);
            Assert.Equal(403, result.StatusCode);
        }

        [Fact]
        public void StartSession_Retorna409QuandoConflitoDeOutroDispositivo()
        {
            var sessionMock = new Mock<IRemoteControlSessionService>();
            sessionMock.Setup(s => s.TryStartSession("device-2", "FullControl"))
                .Returns(SessionStartResult.Conflict("device-1"));

            var injectorMock = new Mock<IRemoteInputInjector>();
            var controller = CreateController(sessionMock.Object, injectorMock.Object, deviceId: "device-2");

            var result = controller.StartSession() as ObjectResult;
            Assert.NotNull(result);
            Assert.Equal(409, result.StatusCode);
        }

        [Fact]
        public void Move_ChamaInjetorQuandoValido()
        {
            var sessionMock = new Mock<IRemoteControlSessionService>();
            sessionMock.Setup(s => s.ValidateCanInput("device-1", "FullControl"))
                .Returns(SessionValidateResult.Allowed);

            var injectorMock = new Mock<IRemoteInputInjector>();
            var controller = CreateController(sessionMock.Object, injectorMock.Object);

            var result = controller.Move(new MouseMoveRequest(15.2, -8.7)) as NoContentResult;
            Assert.NotNull(result);
            Assert.Equal(204, result.StatusCode);
            injectorMock.Verify(i => i.SendMouseMove(15, -9), Times.Once);
        }

        [Theory]
        [InlineData(double.NaN, 0)]
        [InlineData(0, double.PositiveInfinity)]
        [InlineData(1001, 0)]
        [InlineData(0, -1001)]
        public void Move_RejeitaCoordenadasInvalidasOuExcedidas(double dx, double dy)
        {
            var sessionMock = new Mock<IRemoteControlSessionService>();
            var injectorMock = new Mock<IRemoteInputInjector>();
            var controller = CreateController(sessionMock.Object, injectorMock.Object);

            var result = controller.Move(new MouseMoveRequest(dx, dy)) as BadRequestObjectResult;
            Assert.NotNull(result);
            Assert.Equal(400, result.StatusCode);
            injectorMock.Verify(i => i.SendMouseMove(It.IsAny<int>(), It.IsAny<int>()), Times.Never);
        }

        [Fact]
        public void Click_ChamaInjetorComBotaoEActionValidos()
        {
            var sessionMock = new Mock<IRemoteControlSessionService>();
            sessionMock.Setup(s => s.ValidateCanInput("device-1", "FullControl"))
                .Returns(SessionValidateResult.Allowed);

            var injectorMock = new Mock<IRemoteInputInjector>();
            var controller = CreateController(sessionMock.Object, injectorMock.Object);

            var result = controller.Click(new MouseClickRequest("left", "click")) as NoContentResult;
            Assert.NotNull(result);
            Assert.Equal(204, result.StatusCode);
            injectorMock.Verify(i => i.SendMouseButton(MouseButton.Left, MouseAction.Click), Times.Once);
        }

        [Fact]
        public void Click_ComCoordenadasNormalizadas_ChamaSendMouseClickAt()
        {
            var sessionMock = new Mock<IRemoteControlSessionService>();
            sessionMock.Setup(s => s.ValidateCanInput("device-1", "FullControl"))
                .Returns(SessionValidateResult.Allowed);

            var injectorMock = new Mock<IRemoteInputInjector>();
            var controller = CreateController(sessionMock.Object, injectorMock.Object);

            var result = controller.Click(new MouseClickRequest("left", "click", 0.5, 0.25)) as NoContentResult;
            Assert.NotNull(result);
            Assert.Equal(204, result.StatusCode);
            injectorMock.Verify(i => i.SendMouseClickAt(MouseButton.Left, MouseAction.Click, 0.5, 0.25), Times.Once);
        }

        [Theory]
        [InlineData(-0.1, 0.5)]
        [InlineData(1.1, 0.5)]
        [InlineData(0.5, double.NaN)]
        public void Click_CoordenadasInvalidas_Retorna400(double nx, double ny)
        {
            var sessionMock = new Mock<IRemoteControlSessionService>();
            var injectorMock = new Mock<IRemoteInputInjector>();
            var controller = CreateController(sessionMock.Object, injectorMock.Object);

            var result = controller.Click(new MouseClickRequest("left", "click", nx, ny)) as BadRequestObjectResult;
            Assert.NotNull(result);
            Assert.Equal(400, result.StatusCode);
            injectorMock.Verify(i => i.SendMouseClickAt(It.IsAny<MouseButton>(), It.IsAny<MouseAction>(), It.IsAny<double>(), It.IsAny<double>()), Times.Never);
        }

        [Fact]
        public void Click_RejeitaBotaoInvalidoCom400()
        {
            var sessionMock = new Mock<IRemoteControlSessionService>();
            var injectorMock = new Mock<IRemoteInputInjector>();
            var controller = CreateController(sessionMock.Object, injectorMock.Object);

            var result = controller.Click(new MouseClickRequest("invalid_button")) as BadRequestObjectResult;
            Assert.NotNull(result);
            Assert.Equal(400, result.StatusCode);
            injectorMock.Verify(i => i.SendMouseButton(It.IsAny<MouseButton>(), It.IsAny<MouseAction>()), Times.Never);
        }

        [Fact]
        public void Scroll_ChamaInjetorQuandoValido()
        {
            var sessionMock = new Mock<IRemoteControlSessionService>();
            sessionMock.Setup(s => s.ValidateCanInput("device-1", "FullControl"))
                .Returns(SessionValidateResult.Allowed);

            var injectorMock = new Mock<IRemoteInputInjector>();
            var controller = CreateController(sessionMock.Object, injectorMock.Object);

            var result = controller.Scroll(new MouseScrollRequest(0, 120)) as NoContentResult;
            Assert.NotNull(result);
            Assert.Equal(204, result.StatusCode);
            injectorMock.Verify(i => i.SendMouseScroll(0, 120), Times.Once);
        }

        [Fact]
        public void Key_PermiteTeclaDaAllowlistEChamaInjetor()
        {
            var sessionMock = new Mock<IRemoteControlSessionService>();
            sessionMock.Setup(s => s.ValidateCanInput("device-1", "FullControl"))
                .Returns(SessionValidateResult.Allowed);

            var injectorMock = new Mock<IRemoteInputInjector>();
            var controller = CreateController(sessionMock.Object, injectorMock.Object);

            var result = controller.Key(new KeyInputRequest("Ctrl+C")) as NoContentResult;
            Assert.NotNull(result);
            Assert.Equal(204, result.StatusCode);
            injectorMock.Verify(i => i.SendKey("^c"), Times.Once);
        }

        [Fact]
        public void Key_RejeitaEntradaForaDaAllowlistCom400()
        {
            var sessionMock = new Mock<IRemoteControlSessionService>();
            var injectorMock = new Mock<IRemoteInputInjector>();
            var controller = CreateController(sessionMock.Object, injectorMock.Object);

            var result = controller.Key(new KeyInputRequest("powershell -c evil")) as BadRequestObjectResult;
            Assert.NotNull(result);
            Assert.Equal(400, result.StatusCode);
            injectorMock.Verify(i => i.SendKey(It.IsAny<string>()), Times.Never);
        }

        [Fact]
        public void Text_EnviaTextoAte500Caracteres()
        {
            var sessionMock = new Mock<IRemoteControlSessionService>();
            sessionMock.Setup(s => s.ValidateCanInput("device-1", "FullControl"))
                .Returns(SessionValidateResult.Allowed);

            var injectorMock = new Mock<IRemoteInputInjector>();
            var controller = CreateController(sessionMock.Object, injectorMock.Object);

            string safeText = new string('a', 500);
            var result = controller.Text(new TextInputRequest(safeText)) as NoContentResult;
            Assert.NotNull(result);
            Assert.Equal(204, result.StatusCode);
            injectorMock.Verify(i => i.SendText(safeText), Times.Once);
        }

        [Fact]
        public void Text_RejeitaTextoMaiorQue500CaracteresCom413()
        {
            var sessionMock = new Mock<IRemoteControlSessionService>();
            var injectorMock = new Mock<IRemoteInputInjector>();
            var controller = CreateController(sessionMock.Object, injectorMock.Object);

            string oversizedText = new string('a', 501);
            var result = controller.Text(new TextInputRequest(oversizedText)) as ObjectResult;
            Assert.NotNull(result);
            Assert.Equal(413, result.StatusCode);
            injectorMock.Verify(i => i.SendText(It.IsAny<string>()), Times.Never);
        }

        [Fact]
        public void Input_SemSessaoAtiva_Retorna409()
        {
            var sessionMock = new Mock<IRemoteControlSessionService>();
            sessionMock.Setup(s => s.ValidateCanInput("device-1", "FullControl"))
                .Returns(SessionValidateResult.NoActiveSession("NO_ACTIVE_SESSION"));

            var injectorMock = new Mock<IRemoteInputInjector>();
            var controller = CreateController(sessionMock.Object, injectorMock.Object);

            var result = controller.Move(new MouseMoveRequest(10, 10)) as ObjectResult;
            Assert.NotNull(result);
            Assert.Equal(409, result.StatusCode);
        }

        [Fact]
        public void Input_ExcessoDeEventos_Retorna429()
        {
            var sessionMock = new Mock<IRemoteControlSessionService>();
            sessionMock.Setup(s => s.ValidateCanInput("device-1", "FullControl"))
                .Returns(SessionValidateResult.RateLimitExceeded("RATE_LIMIT_EXCEEDED"));

            var injectorMock = new Mock<IRemoteInputInjector>();
            var controller = CreateController(sessionMock.Object, injectorMock.Object);

            var result = controller.Move(new MouseMoveRequest(10, 10)) as ObjectResult;
            Assert.NotNull(result);
            Assert.Equal(429, result.StatusCode);
        }

        [Fact]
        public void DispatcherGeral_EncaminhaEventosTipados()
        {
            var sessionMock = new Mock<IRemoteControlSessionService>();
            sessionMock.Setup(s => s.ValidateCanInput("device-1", "FullControl"))
                .Returns(SessionValidateResult.Allowed);

            var injectorMock = new Mock<IRemoteInputInjector>();
            var controller = CreateController(sessionMock.Object, injectorMock.Object);

            var resMove = controller.Input(new RemoteInputBatchRequest { Type = "move", Dx = 5, Dy = -3 }) as NoContentResult;
            Assert.NotNull(resMove);
            injectorMock.Verify(i => i.SendMouseMove(5, -3), Times.Once);

            var resClick = controller.Input(new RemoteInputBatchRequest { Type = "click", Button = "right", Action = "click" }) as NoContentResult;
            Assert.NotNull(resClick);
            injectorMock.Verify(i => i.SendMouseButton(MouseButton.Right, MouseAction.Click), Times.Once);

            var resScroll = controller.Input(new RemoteInputBatchRequest { Type = "scroll", DeltaX = 0, DeltaY = -120 }) as NoContentResult;
            Assert.NotNull(resScroll);
            injectorMock.Verify(i => i.SendMouseScroll(0, -120), Times.Once);

            var resKey = controller.Input(new RemoteInputBatchRequest { Type = "key", Key = "Enter" }) as NoContentResult;
            Assert.NotNull(resKey);
            injectorMock.Verify(i => i.SendKey("{ENTER}"), Times.Once);

            var resText = controller.Input(new RemoteInputBatchRequest { Type = "text", Text = "teste" }) as NoContentResult;
            Assert.NotNull(resText);
            injectorMock.Verify(i => i.SendText("teste"), Times.Once);

            var resUnknown = controller.Input(new RemoteInputBatchRequest { Type = "arbitrary_shell" }) as BadRequestObjectResult;
            Assert.NotNull(resUnknown);
            Assert.Equal(400, resUnknown.StatusCode);
        }
    }
}
