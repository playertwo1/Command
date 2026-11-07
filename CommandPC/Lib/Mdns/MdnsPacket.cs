using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Text;

namespace Command.Lib.Mdns
{
    public enum DnsRecordType : ushort
    {
        A = 1,
        PTR = 12,
        TXT = 16,
        SRV = 33
    }

    public class DnsQuestion
    {
        public string Name { get; set; } = string.Empty;
        public DnsRecordType Type { get; set; }
        public ushort Class { get; set; } = 1;
        public bool UnicastResponse => (Class & 0x8000) != 0;
    }

    public class DnsResourceRecord
    {
        public string Name { get; set; } = string.Empty;
        public DnsRecordType Type { get; set; }
        public ushort Class { get; set; } = 1; // 0x8001 for cache-flush IN
        public uint Ttl { get; set; } = 120;
        public byte[] Data { get; set; } = Array.Empty<byte>();
    }

    public class MdnsPacket
    {
        public ushort TransactionId { get; set; }
        public ushort Flags { get; set; }
        public List<DnsQuestion> Questions { get; } = new();
        public List<DnsResourceRecord> Answers { get; } = new();
        public List<DnsResourceRecord> Additionals { get; } = new();

        public bool IsQuery => (Flags & 0x8000) == 0;
        public bool IsResponse => (Flags & 0x8000) != 0;

        public static MdnsPacket Parse(byte[] buffer, int length)
        {
            var packet = new MdnsPacket();
            if (length < 12) return packet;

            using var stream = new MemoryStream(buffer, 0, length, false);
            using var reader = new BinaryReader(stream);

            packet.TransactionId = ReadBigEndianUInt16(reader);
            packet.Flags = ReadBigEndianUInt16(reader);
            ushort qdCount = ReadBigEndianUInt16(reader);
            ushort anCount = ReadBigEndianUInt16(reader);
            ushort nsCount = ReadBigEndianUInt16(reader);
            ushort arCount = ReadBigEndianUInt16(reader);

            for (int i = 0; i < qdCount && stream.Position < stream.Length; i++)
            {
                string name = ReadName(stream);
                if (stream.Position + 4 > stream.Length) break;
                var type = (DnsRecordType)ReadBigEndianUInt16(reader);
                ushort qClass = ReadBigEndianUInt16(reader);
                packet.Questions.Add(new DnsQuestion { Name = name, Type = type, Class = qClass });
            }

            for (int i = 0; i < anCount && stream.Position < stream.Length; i++)
            {
                var record = ReadRecord(stream, reader);
                if (record != null) packet.Answers.Add(record);
            }

            // Skip authority records if any
            for (int i = 0; i < nsCount && stream.Position < stream.Length; i++)
            {
                ReadRecord(stream, reader);
            }

            for (int i = 0; i < arCount && stream.Position < stream.Length; i++)
            {
                var record = ReadRecord(stream, reader);
                if (record != null) packet.Additionals.Add(record);
            }

            return packet;
        }

        public byte[] ToBytes()
        {
            using var stream = new MemoryStream();
            using var writer = new BinaryWriter(stream);

            WriteBigEndianUInt16(writer, TransactionId);
            WriteBigEndianUInt16(writer, Flags);
            WriteBigEndianUInt16(writer, (ushort)Questions.Count);
            WriteBigEndianUInt16(writer, (ushort)Answers.Count);
            WriteBigEndianUInt16(writer, 0); // NS count
            WriteBigEndianUInt16(writer, (ushort)Additionals.Count);

            foreach (var q in Questions)
            {
                WriteName(stream, q.Name);
                WriteBigEndianUInt16(writer, (ushort)q.Type);
                WriteBigEndianUInt16(writer, q.Class);
            }

            foreach (var a in Answers)
            {
                WriteRecord(stream, writer, a);
            }

            foreach (var add in Additionals)
            {
                WriteRecord(stream, writer, add);
            }

            return stream.ToArray();
        }

        private static DnsResourceRecord? ReadRecord(MemoryStream stream, BinaryReader reader)
        {
            string name = ReadName(stream);
            if (stream.Position + 10 > stream.Length) return null;

            var type = (DnsRecordType)ReadBigEndianUInt16(reader);
            ushort rClass = ReadBigEndianUInt16(reader);
            uint ttl = ReadBigEndianUInt32(reader);
            ushort rdLength = ReadBigEndianUInt16(reader);

            if (stream.Position + rdLength > stream.Length) return null;
            byte[] rdata = reader.ReadBytes(rdLength);

            return new DnsResourceRecord
            {
                Name = name,
                Type = type,
                Class = rClass,
                Ttl = ttl,
                Data = rdata
            };
        }

        private static void WriteRecord(MemoryStream stream, BinaryWriter writer, DnsResourceRecord record)
        {
            WriteName(stream, record.Name);
            WriteBigEndianUInt16(writer, (ushort)record.Type);
            WriteBigEndianUInt16(writer, record.Class);
            WriteBigEndianUInt32(writer, record.Ttl);
            WriteBigEndianUInt16(writer, (ushort)record.Data.Length);
            writer.Write(record.Data);
        }

        public static string ReadName(MemoryStream stream)
        {
            var parts = new List<string>();
            long originalPos = -1;
            int jumpCount = 0;

            while (stream.Position < stream.Length)
            {
                int len = stream.ReadByte();
                if (len <= 0) break;

                // DNS pointer compression (0xC0)
                if ((len & 0xC0) == 0xC0)
                {
                    if (stream.Position >= stream.Length) break;
                    int b2 = stream.ReadByte();
                    int pointer = ((len & 0x3F) << 8) | b2;

                    if (originalPos == -1) originalPos = stream.Position;
                    if (jumpCount++ > 10) break; // cycle protection

                    stream.Position = pointer;
                    continue;
                }

                if (stream.Position + len > stream.Length) break;
                byte[] labelBytes = new byte[len];
                stream.Read(labelBytes, 0, len);
                parts.Add(Encoding.UTF8.GetString(labelBytes));
            }

            if (originalPos != -1)
            {
                stream.Position = originalPos;
            }

            return string.Join(".", parts);
        }

        public static void WriteName(MemoryStream stream, string name)
        {
            if (string.IsNullOrWhiteSpace(name))
            {
                stream.WriteByte(0);
                return;
            }

            string[] labels = name.Trim('.').Split('.');
            foreach (var label in labels)
            {
                byte[] bytes = Encoding.UTF8.GetBytes(label);
                stream.WriteByte((byte)Math.Min(bytes.Length, 63));
                stream.Write(bytes, 0, Math.Min(bytes.Length, 63));
            }
            stream.WriteByte(0);
        }

        public static byte[] EncodeName(string name)
        {
            using var ms = new MemoryStream();
            WriteName(ms, name);
            return ms.ToArray();
        }

        public static byte[] EncodeSrv(ushort priority, ushort weight, ushort port, string target)
        {
            using var ms = new MemoryStream();
            using var writer = new BinaryWriter(ms);
            WriteBigEndianUInt16(writer, priority);
            WriteBigEndianUInt16(writer, weight);
            WriteBigEndianUInt16(writer, port);
            WriteName(ms, target);
            return ms.ToArray();
        }

        public static byte[] EncodeTxt(IDictionary<string, string> entries)
        {
            using var ms = new MemoryStream();
            foreach (var kv in entries)
            {
                string item = $"{kv.Key}={kv.Value}";
                byte[] bytes = Encoding.UTF8.GetBytes(item);
                ms.WriteByte((byte)Math.Min(bytes.Length, 255));
                ms.Write(bytes, 0, Math.Min(bytes.Length, 255));
            }
            return ms.ToArray();
        }

        public static Dictionary<string, string> DecodeTxt(byte[] data)
        {
            var dict = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            int offset = 0;
            while (offset < data.Length)
            {
                int len = data[offset++];
                if (offset + len > data.Length) break;
                string text = Encoding.UTF8.GetString(data, offset, len);
                offset += len;

                int eq = text.IndexOf('=');
                if (eq > 0)
                {
                    string key = text.Substring(0, eq).Trim();
                    string val = text.Substring(eq + 1).Trim();
                    dict[key] = val;
                }
            }
            return dict;
        }

        private static ushort ReadBigEndianUInt16(BinaryReader reader)
        {
            byte[] bytes = reader.ReadBytes(2);
            if (bytes.Length < 2) return 0;
            return (ushort)((bytes[0] << 8) | bytes[1]);
        }

        private static uint ReadBigEndianUInt32(BinaryReader reader)
        {
            byte[] bytes = reader.ReadBytes(4);
            if (bytes.Length < 4) return 0;
            return (uint)((bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3]);
        }

        private static void WriteBigEndianUInt16(BinaryWriter writer, ushort value)
        {
            writer.Write((byte)((value >> 8) & 0xFF));
            writer.Write((byte)(value & 0xFF));
        }

        private static void WriteBigEndianUInt32(BinaryWriter writer, uint value)
        {
            writer.Write((byte)((value >> 24) & 0xFF));
            writer.Write((byte)((value >> 16) & 0xFF));
            writer.Write((byte)((value >> 8) & 0xFF));
            writer.Write((byte)(value & 0xFF));
        }
    }
}
