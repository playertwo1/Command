using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using DroidDeck.Controllers;
using DroidDeck.Models;
using DroidDeck.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace DroidDeck.Tests
{
    public class AppCatalogAndJobsTests
    {
        [Fact]
        public void AppCatalog_ContainsRequiredAllowlistApps_WithoutExposingPaths()
        {
            var catalog = new AppCatalogService(NullLogger<AppCatalogService>.Instance);
            var apps = catalog.GetAllowedApps();

            Assert.NotNull(apps);
            Assert.True(apps.Count >= 3);

            var obsidian = apps.FirstOrDefault(a => a.Id == "obsidian");
            Assert.NotNull(obsidian);
            Assert.Equal("Obsidian", obsidian.Name);
            Assert.False(obsidian.CanKill); // Não pode ser encerrado remotamente (F4-03)

            var orbit = apps.FirstOrDefault(a => a.Id == "orbit");
            Assert.NotNull(orbit);
            Assert.Equal("Orbit PJ", orbit.Name);
            Assert.False(orbit.CanKill);

            var notepad = apps.FirstOrDefault(a => a.Id == "test_notepad");
            Assert.NotNull(notepad);
            Assert.True(notepad.CanKill); // Autorizado para encerramento de teste (FL-5)
        }

        [Fact]
        public async Task AppCatalog_RejectsKill_ForProtectedApps()
        {
            var catalog = new AppCatalogService(NullLogger<AppCatalogService>.Instance);
            
            // Obsidian não tem flag CanKill
            var result = await catalog.KillAsync("obsidian");

            Assert.False(result.Success);
            Assert.Contains("protegido", result.ErrorMessage, StringComparison.OrdinalIgnoreCase);
        }

        [Fact]
        public async Task AppCatalog_RejectsKill_ForUnknownApps()
        {
            var catalog = new AppCatalogService(NullLogger<AppCatalogService>.Instance);
            
            var result = await catalog.KillAsync("cmd_exe");

            Assert.False(result.Success);
            Assert.Contains("não encontrado", result.ErrorMessage, StringComparison.OrdinalIgnoreCase);
        }

        [Fact]
        public void JobHistory_Idempotency_SameRequestId_ReturnsExistingJob()
        {
            var jobHistory = new JobHistoryService(NullLogger<JobHistoryService>.Instance);
            var reqId = Guid.NewGuid().ToString("N");

            var job1 = jobHistory.GetOrCreateJob(reqId, "app.launch", "obsidian", "device-test", out bool isExisting1);
            Assert.False(isExisting1);
            Assert.Equal("accepted", job1.Status);

            jobHistory.UpdateJob(job1.Id, "succeeded");

            // Segunda chamada com mesmo reqId e payload
            var job2 = jobHistory.GetOrCreateJob(reqId, "app.launch", "obsidian", "device-test", out bool isExisting2);
            Assert.True(isExisting2);
            Assert.Equal(job1.Id, job2.Id);
            Assert.Equal("succeeded", job2.Status);
        }

        [Fact]
        public void JobHistory_ReplayDifferentPayload_ThrowsConflict()
        {
            var jobHistory = new JobHistoryService(NullLogger<JobHistoryService>.Instance);
            var reqId = Guid.NewGuid().ToString("N");

            jobHistory.GetOrCreateJob(reqId, "app.launch", "obsidian", "device-test", out _);

            // Replay da mesma chave com alvo diferente (F4-05)
            Assert.Throws<InvalidOperationException>(() =>
            {
                jobHistory.GetOrCreateJob(reqId, "app.launch", "orbit", "device-test", out _);
            });
        }

        [Fact]
        public async Task AppsController_Launch_UnknownApp_ReturnsNotFound()
        {
            var catalog = new AppCatalogService(NullLogger<AppCatalogService>.Instance);
            var jobHistory = new JobHistoryService(NullLogger<JobHistoryService>.Instance);
            var controller = new AppsController(catalog, jobHistory, NullLogger<AppsController>.Instance);

            var response = await controller.LaunchApp("unknown_app", new LaunchAppRequest
            {
                RequestId = Guid.NewGuid().ToString("N")
            });

            Assert.IsType<NotFoundObjectResult>(response.Result);
        }

        [Fact]
        public async Task AppsController_Kill_WithoutConfirmation_ReturnsBadRequest()
        {
            var catalog = new AppCatalogService(NullLogger<AppCatalogService>.Instance);
            var jobHistory = new JobHistoryService(NullLogger<JobHistoryService>.Instance);
            var controller = new AppsController(catalog, jobHistory, NullLogger<AppsController>.Instance);

            var response = await controller.KillApp("test_notepad", new KillAppRequest
            {
                RequestId = Guid.NewGuid().ToString("N"),
                Confirmed = false // Sem confirmação deve falhar
            });

            var badReq = Assert.IsType<BadRequestObjectResult>(response.Result);
            Assert.NotNull(badReq.Value);
        }

        [Fact]
        public async Task AppsController_Kill_ProtectedApp_ReturnsForbidden()
        {
            var catalog = new AppCatalogService(NullLogger<AppCatalogService>.Instance);
            var jobHistory = new JobHistoryService(NullLogger<JobHistoryService>.Instance);
            var controller = new AppsController(catalog, jobHistory, NullLogger<AppsController>.Instance);

            var response = await controller.KillApp("obsidian", new KillAppRequest
            {
                RequestId = Guid.NewGuid().ToString("N"),
                Confirmed = true
            });

            var statusResult = Assert.IsType<ObjectResult>(response.Result);
            Assert.Equal(403, statusResult.StatusCode);
        }

        [Fact]
        public void JobsController_RetrievalAndClear_Works()
        {
            var jobHistory = new JobHistoryService(NullLogger<JobHistoryService>.Instance);
            var reqId = Guid.NewGuid().ToString("N");
            var job = jobHistory.GetOrCreateJob(reqId, "app.launch", "test_notepad", "device-1", out _);

            var controller = new JobsController(jobHistory);
            var jobsResult = controller.GetJobs("device-1");
            var okResult = Assert.IsType<OkObjectResult>(jobsResult.Result);
            var list = Assert.IsAssignableFrom<System.Collections.Generic.IReadOnlyList<CommandJob>>(okResult.Value);
            Assert.Contains(list, j => j.Id == job.Id);

            var singleResult = controller.GetJob(job.Id);
            var singleOk = Assert.IsType<OkObjectResult>(singleResult.Result);
            var singleJob = Assert.IsType<CommandJob>(singleOk.Value);
            Assert.Equal(job.Id, singleJob.Id);

            controller.ClearJobs(null);
            var clearedResult = controller.GetJobs(null);
            var clearedOk = Assert.IsType<OkObjectResult>(clearedResult.Result);
            var emptyList = Assert.IsAssignableFrom<System.Collections.Generic.IReadOnlyList<CommandJob>>(clearedOk.Value);
            Assert.Empty(emptyList);
        }
    }
}
