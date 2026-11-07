using System.Collections.Generic;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;
using Command.Controllers;
using Command.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Command.Hubs;

namespace Command.Tests
{
    public class MixerControllerTests
    {
        [Fact]
        public void GetAllOutputs_ReturnsOk()
        {
                var mockEnum = new Mock<Command.Audio.IAudioDeviceEnumerator>();
                var mockLoggerSvc = new Mock<ILogger<MixerService>>();
                mockEnum.Setup(e => e.EnumerateAudioEndPoints(It.IsAny<NAudio.CoreAudioApi.DataFlow>(), It.IsAny<NAudio.CoreAudioApi.DeviceState>()))
                    .Returns(new List<Command.Audio.IAudioDevice>());

                var service = new MixerService(mockLoggerSvc.Object, mockEnum.Object);
                var mockLogger = new Mock<ILogger<MixerController>>();
                // O controller passou a emitir eventos pelo hub; o teste so precisa que a
                // dependencia exista (nao verifica broadcast aqui).
                var mockHub = new Mock<IHubContext<DeckHub>>();

                var controller = new MixerController(service, mockLogger.Object, mockHub.Object);
            var result = controller.GetAllOutputs() as OkObjectResult;

            Assert.NotNull(result);
            Assert.Equal(200, result.StatusCode);
        }
    }
}
