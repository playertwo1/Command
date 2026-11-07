using System;
using System.Linq;
using Command.Actions.Providers;
using Command.Hubs;
using Command.Models;
using Command.Services;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace Command.Tests
{
    public class DeckSelectorOptionsTests
    {
        [Fact]
        public void WindowsSchema_IncludesShutdownRestartAndPowerMode()
        {
            var provider = new WindowsProvider(Mock.Of<IHubContext<DeckHub>>(), NullLogger<WindowsProvider>.Instance);
            var ops = provider.Describe().Fields.Single(f => f.Key == "operation").Options;

            Assert.Contains(ops, o => o.Value == "shutdown");
            Assert.Contains(ops, o => o.Value == "restart");
            Assert.Contains(ops, o => o.Value == "setPowerMode");
        }

        [Fact]
        public void ShutdownAndRestart_RequireConfirmation_LockDoesNot()
        {
            Assert.True(WindowsProvider.NeedsConfirmation(Windows("shutdown")));
            Assert.True(WindowsProvider.NeedsConfirmation(Windows("restart")));
            Assert.False(WindowsProvider.NeedsConfirmation(Windows("lock")));
            Assert.False(WindowsProvider.NeedsConfirmation(Windows("setPowerMode")));
        }

        [Fact]
        public void PowerMode_MapsKnownModesAndRejectsUnknown()
        {
            Assert.True(WindowsProvider.TryOverlay("efficiency", out var economy));
            Assert.Equal(new Guid("961cc777-2547-4f9d-8174-7d86181b8a7a"), economy);
            Assert.True(WindowsProvider.TryOverlay("balanced", out var balanced));
            Assert.Equal(Guid.Empty, balanced);
            Assert.True(WindowsProvider.TryOverlay("performance", out _));
            Assert.False(WindowsProvider.TryOverlay("cmd", out _));
        }

        [Fact]
        public void CatalogApp_IsSelectableWithoutFreePath()
        {
            var catalog = new AppCatalogService(NullLogger<AppCatalogService>.Instance);
            var provider = new CatalogAppProvider(catalog);
            var field = provider.Describe().Fields.Single();

            Assert.Equal("appId", field.Key);
            Assert.Equal("/api/apps", field.OptionsSource);
            Assert.False(ActionPolicy.IsPrivileged(new DeckAction { Type = "catalog_app" }));
            Assert.Contains(catalog.GetAllowedApps(), a => a.Id == "claude");
            Assert.Contains(catalog.GetAllowedApps(), a => a.Id == "codex");
        }

        private static DeckAction Windows(string operation) => new()
        {
            Type = "windows",
            Parameters = { ["operation"] = operation },
        };
    }
}
