using System.IO;
using System.Threading;
using System.Threading.Tasks;

namespace Command.Services
{
    public interface IScreenStreamService
    {
        bool IsStreamingActive { get; }
        Task WriteStreamAsync(Stream outputStream, int fps, int quality, double scale, CancellationToken cancellationToken);
    }
}
