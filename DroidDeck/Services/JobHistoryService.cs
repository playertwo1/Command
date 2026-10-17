using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using DroidDeck.Lib;
using DroidDeck.Models;
using Microsoft.Extensions.Logging;

namespace DroidDeck.Services
{
    public class JobHistoryService : IJobHistoryService
    {
        private readonly ILogger<JobHistoryService> _logger;
        private readonly object _lock = new();
        private readonly List<CommandJob> _jobs = new();
        private readonly Dictionary<string, CommandJob> _byRequestId = new(StringComparer.OrdinalIgnoreCase);
        private readonly string _storagePath;
        private const int MaxJobs = 100;

        public JobHistoryService(ILogger<JobHistoryService> logger)
        {
            _logger = logger;
            _storagePath = Path.Combine(AppPaths.LocalDir, "jobs_history.json");
            LoadFromDisk();
        }

        public CommandJob GetOrCreateJob(string requestId, string actionType, string targetId, string? deviceId, out bool isExisting)
        {
            if (string.IsNullOrWhiteSpace(requestId))
            {
                throw new ArgumentException("Request ID é obrigatório para rastreabilidade e idempotência.", nameof(requestId));
            }

            lock (_lock)
            {
                if (_byRequestId.TryGetValue(requestId, out var existing))
                {
                    // Proteção contra replay com payload divergente (F4-05)
                    if (!string.Equals(existing.ActionType, actionType, StringComparison.OrdinalIgnoreCase) ||
                        !string.Equals(existing.TargetId, targetId, StringComparison.OrdinalIgnoreCase))
                    {
                        throw new InvalidOperationException($"Conflito de idempotência: RequestId '{requestId}' já utilizado com payload divergente.");
                    }

                    isExisting = true;
                    return existing;
                }

                var job = new CommandJob
                {
                    Id = Guid.NewGuid().ToString("N"),
                    RequestId = requestId,
                    ActionType = actionType,
                    TargetId = targetId,
                    Status = "accepted",
                    CreatedAtUtc = DateTime.UtcNow,
                    DeviceId = deviceId
                };

                _jobs.Insert(0, job);
                _byRequestId[requestId] = job;

                // Prune old jobs if exceeding capacity
                while (_jobs.Count > MaxJobs)
                {
                    var oldest = _jobs[^1];
                    _jobs.RemoveAt(_jobs.Count - 1);
                    _byRequestId.Remove(oldest.RequestId);
                }

                SaveToDisk();
                isExisting = false;
                return job;
            }
        }

        public void UpdateJob(string id, string status, string? errorMessage = null)
        {
            lock (_lock)
            {
                var job = _jobs.FirstOrDefault(j => j.Id == id);
                if (job != null)
                {
                    job.Status = status;
                    if (status is "succeeded" or "failed" or "cancelled")
                    {
                        job.CompletedAtUtc = DateTime.UtcNow;
                    }
                    if (!string.IsNullOrEmpty(errorMessage))
                    {
                        job.ErrorMessage = errorMessage;
                    }
                    SaveToDisk();
                }
            }
        }

        public IReadOnlyList<CommandJob> GetJobs(string? deviceId = null, int limit = 50)
        {
            lock (_lock)
            {
                var query = _jobs.AsEnumerable();
                if (!string.IsNullOrWhiteSpace(deviceId))
                {
                    query = query.Where(j => string.Equals(j.DeviceId, deviceId, StringComparison.OrdinalIgnoreCase) || j.DeviceId == null);
                }
                return query.Take(Math.Max(1, Math.Min(limit, MaxJobs))).ToList();
            }
        }

        public CommandJob? GetJob(string id)
        {
            lock (_lock)
            {
                return _jobs.FirstOrDefault(j => j.Id == id || j.RequestId == id);
            }
        }

        public void ClearHistory(string? deviceId = null)
        {
            lock (_lock)
            {
                if (string.IsNullOrWhiteSpace(deviceId))
                {
                    _jobs.Clear();
                    _byRequestId.Clear();
                }
                else
                {
                    var toRemove = _jobs.Where(j => string.Equals(j.DeviceId, deviceId, StringComparison.OrdinalIgnoreCase)).ToList();
                    foreach (var job in toRemove)
                    {
                        _jobs.Remove(job);
                        _byRequestId.Remove(job.RequestId);
                    }
                }
                SaveToDisk();
            }
        }

        private void LoadFromDisk()
        {
            lock (_lock)
            {
                try
                {
                    if (File.Exists(_storagePath))
                    {
                        var json = File.ReadAllText(_storagePath);
                        var loaded = JsonSerializer.Deserialize<List<CommandJob>>(json);
                        if (loaded != null)
                        {
                            _jobs.Clear();
                            _byRequestId.Clear();
                            foreach (var j in loaded)
                            {
                                _jobs.Add(j);
                                if (!string.IsNullOrEmpty(j.RequestId))
                                {
                                    _byRequestId[j.RequestId] = j;
                                }
                            }
                        }
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Não foi possível carregar histórico de jobs do disco ({Path}).", _storagePath);
                }
            }
        }

        private void SaveToDisk()
        {
            try
            {
                var json = JsonSerializer.Serialize(_jobs, new JsonSerializerOptions { WriteIndented = true });
                File.WriteAllText(_storagePath, json);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Não foi possível salvar histórico de jobs no disco ({Path}).", _storagePath);
            }
        }
    }
}
