using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using Command.Lib.Mdns;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Command.Tests
{
    public class MdnsDiscoveryTests
    {
        [Fact]
        public void MdnsPacket_EncodeAndDecode_TxtRecord()
        {
            var original = new Dictionary<string, string>
            {
                ["txtvers"] = "1",
                ["name"] = "MyPC",
                ["port"] = "4787",
                ["controlPort"] = "4788",
                ["certPin"] = "abcd1234ef5678"
            };

            byte[] bytes = MdnsPacket.EncodeTxt(original);
            Assert.NotEmpty(bytes);

            var decoded = MdnsPacket.DecodeTxt(bytes);
            Assert.Equal("1", decoded["txtvers"]);
            Assert.Equal("MyPC", decoded["name"]);
            Assert.Equal("4787", decoded["port"]);
            Assert.Equal("4788", decoded["controlPort"]);
            Assert.Equal("abcd1234ef5678", decoded["certPin"]);
        }

        [Fact]
        public void MdnsPacket_EncodeAndRead_Name()
        {
            using var ms = new MemoryStream();
            MdnsPacket.WriteName(ms, "_command._tcp.local");
            ms.Position = 0;

            string name = MdnsPacket.ReadName(ms);
            Assert.Equal("_command._tcp.local", name);
        }

        [Fact]
        public void MdnsPacket_SerializeAndParse_Query()
        {
            var packet = new MdnsPacket
            {
                TransactionId = 0x1234,
                Flags = 0x0000 // Query
            };
            packet.Questions.Add(new DnsQuestion
            {
                Name = "_command._tcp.local",
                Type = DnsRecordType.PTR,
                Class = 0x8001 // QU unicast-response requested
            });

            byte[] bytes = packet.ToBytes();
            Assert.NotNull(bytes);
            Assert.True(bytes.Length >= 12);

            var parsed = MdnsPacket.Parse(bytes, bytes.Length);
            Assert.Equal(0x1234, parsed.TransactionId);
            Assert.True(parsed.IsQuery);
            Assert.Single(parsed.Questions);
            Assert.Equal("_command._tcp.local", parsed.Questions[0].Name);
            Assert.Equal(DnsRecordType.PTR, parsed.Questions[0].Type);
            Assert.True(parsed.Questions[0].UnicastResponse);
        }

        [Fact]
        public void MdnsDiscoveryServer_BuildResponsePacket_ContainsRequiredRecordsAndSanitizedTxt()
        {
            var server = new MdnsDiscoveryServer(NullLogger<MdnsDiscoveryServer>.Instance);
            var response = server.BuildResponsePacket(ttl: 120, queryId: 0x4321);

            Assert.Equal(0x4321, response.TransactionId);
            Assert.True(response.IsResponse);

            // Respostas esperadas: PTR, SRV, TXT
            Assert.True(response.Answers.Count >= 3);

            var ptr = response.Answers.Find(a => a.Type == DnsRecordType.PTR);
            Assert.NotNull(ptr);
            Assert.Equal("_command._tcp.local", ptr.Name);

            var srv = response.Answers.Find(a => a.Type == DnsRecordType.SRV);
            Assert.NotNull(srv);
            Assert.EndsWith("._command._tcp.local", srv.Name);

            var txt = response.Answers.Find(a => a.Type == DnsRecordType.TXT);
            Assert.NotNull(txt);
            var decodedTxt = MdnsPacket.DecodeTxt(txt.Data);
            Assert.Equal("1", decodedTxt["txtvers"]);
            Assert.Equal("CommandBridge", decodedTxt["model"]);
            Assert.True(decodedTxt.ContainsKey("name"));
            Assert.True(decodedTxt.ContainsKey("id"));
            Assert.True(decodedTxt.ContainsKey("port"));
            Assert.True(decodedTxt.ContainsKey("controlPort"));
            Assert.True(decodedTxt.ContainsKey("certPin"));

            // Regra estrita: NUNCA expor tokens, senhas ou catálogo no mDNS
            Assert.False(decodedTxt.ContainsKey("token"));
            Assert.False(decodedTxt.ContainsKey("password"));
            Assert.False(decodedTxt.ContainsKey("secret"));
            Assert.False(decodedTxt.ContainsKey("apiKey"));
        }

        [Fact]
        public void MdnsPacket_SerializeResponse_CanBeParsedBack()
        {
            var server = new MdnsDiscoveryServer(NullLogger<MdnsDiscoveryServer>.Instance);
            var response = server.BuildResponsePacket(ttl: 120, queryId: 0x9999);

            byte[] bytes = response.ToBytes();
            var parsed = MdnsPacket.Parse(bytes, bytes.Length);

            Assert.Equal(0x9999, parsed.TransactionId);
            Assert.True(parsed.IsResponse);
            Assert.Equal(response.Answers.Count, parsed.Answers.Count);
        }
    }
}
