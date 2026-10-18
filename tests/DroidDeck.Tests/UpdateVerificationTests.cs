using System;
using System.Security.Cryptography;
using System.Text;
using DroidDeck.Controllers;
using DroidDeck.Models;
using DroidDeck.Services;
using Microsoft.AspNetCore.Mvc;
using Moq;
using Xunit;

namespace DroidDeck.Tests
{
    public class UpdateVerificationTests
    {
        [Fact]
        public void GetStatus_ReturnsStandardContractAndSha256()
        {
            var service = new UpdateVerificationService();
            var status = service.GetStatus();

            Assert.NotNull(status);
            Assert.Equal("1.0.0", status.CurrentVersion);
            Assert.Equal("stable", status.Channel);
            Assert.False(status.UpdateAvailable);
            Assert.Equal("1.0.0", status.LatestVersion);
            Assert.True(status.IsVelopackReady);
            Assert.False(string.IsNullOrWhiteSpace(status.BinarySha256));
            Assert.True(status.CheckedAtUtc <= DateTime.UtcNow);
        }

        [Fact]
        public void VerifyPayload_MatchingChecksum_ReturnsValid()
        {
            var service = new UpdateVerificationService();
            byte[] dummyPackage = Encoding.UTF8.GetBytes("Command-Payload-v1.0.1");
            string payloadBase64 = Convert.ToBase64String(dummyPackage);
            string expectedSha256 = Convert.ToHexString(SHA256.HashData(dummyPackage)).ToLowerInvariant();

            // Teste case-insensitive
            var response = service.VerifyPayload(payloadBase64, expectedSha256.ToUpperInvariant());

            Assert.True(response.IsValid);
            Assert.Equal(expectedSha256, response.ActualSha256);
            Assert.Null(response.ErrorMessage);
        }

        [Fact]
        public void VerifyPayload_TamperedChecksum_ReturnsInvalid()
        {
            var service = new UpdateVerificationService();
            byte[] dummyPackage = Encoding.UTF8.GetBytes("Command-Payload-v1.0.1");
            string payloadBase64 = Convert.ToBase64String(dummyPackage);

            var response = service.VerifyPayload(payloadBase64, "deadbeefcafebabe111122223333444455556666777788889999aaaabbbbcccc");

            Assert.False(response.IsValid);
            Assert.NotNull(response.ErrorMessage);
        }

        [Theory]
        [InlineData("!!!invalid-base64@@@")]
        [InlineData(" ")]
        public void VerifyPayload_MalformedOrEmptyPayload_ReturnsInvalid(string malformed)
        {
            var service = new UpdateVerificationService();
            var response = service.VerifyPayload(malformed, "somehash");

            Assert.False(response.IsValid);
            Assert.NotNull(response.ErrorMessage);
        }

        [Fact]
        public void UpdateController_Endpoints_ReturnExpectedActionResults()
        {
            var updateService = new UpdateVerificationService();
            var stabilityMock = new Mock<ISystemStabilityMonitor>();
            var controller = new UpdateController(updateService, stabilityMock.Object);

            // GET update/status
            var statusResult = controller.GetUpdateStatus();
            var okStatus = Assert.IsType<OkObjectResult>(statusResult.Result);
            var status = Assert.IsType<UpdateStatusDto>(okStatus.Value);
            Assert.Equal("1.0.0", status.CurrentVersion);

            // POST update/verify
            byte[] bytes = Encoding.UTF8.GetBytes("TestPackage");
            string base64 = Convert.ToBase64String(bytes);
            string sha = Convert.ToHexString(SHA256.HashData(bytes));

            var verifyResult = controller.VerifyUpdatePackage(new VerifyUpdatePackageRequest(base64, sha));
            var okVerify = Assert.IsType<OkObjectResult>(verifyResult.Result);
            var verifyResp = Assert.IsType<VerifyUpdatePackageResponse>(okVerify.Value);
            Assert.True(verifyResp.IsValid);

            // POST update/verify null
            var badResult = controller.VerifyUpdatePackage(null!);
            Assert.IsType<BadRequestObjectResult>(badResult.Result);
        }
    }
}
