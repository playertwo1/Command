using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using DroidDeck.Models;

namespace DroidDeck.Services
{
    public interface ITransferService
    {
        string InboundRootPath { get; }
        string OutboundRootPath { get; }

        IEnumerable<TransferItemDto> ListFiles(string rootId, string requestingDeviceId);

        Task<UploadTransferResult> UploadFileAsync(
            string rootId,
            string fileName,
            Stream contentStream,
            string? expectedSha256,
            string requestingDeviceId,
            string? requestId = null);

        FileDownloadResult GetFileForDownload(string rootId, string fileName, string requestingDeviceId);
        DirectoryBrowseResult BrowseDirectory(string rootId, string? subPath, string requestingDeviceId);
    }
}
