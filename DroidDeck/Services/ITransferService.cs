using System;
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
            string? requestId = null,
            string? conflictPolicy = null);

        Task<ChunkUploadResult> UploadChunkAsync(
            string uploadId,
            string rootId,
            string fileName,
            long offset,
            long totalSize,
            bool isLastChunk,
            Stream chunkStream,
            string? expectedSha256,
            string requestingDeviceId,
            string? requestId = null,
            string? conflictPolicy = null);

        ResumableUploadStatusResult GetUploadStatus(string uploadId, string rootId, string fileName);

        int CleanOrphanedParts(TimeSpan? olderThan = null);

        FileDownloadResult GetFileForDownload(
            string rootId,
            string fileName,
            string requestingDeviceId,
            long? offset = null,
            long? length = null);

        DirectoryBrowseResult BrowseDirectory(string rootId, string? subPath, string requestingDeviceId);
    }
}
