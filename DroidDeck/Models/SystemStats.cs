namespace DroidDeck.Models
{
    public class SystemStats
    {
        public float CpuUsage { get; set; }
        public float RamUsage { get; set; }
        public float RamTotal { get; set; }
        public float RamAvailable { get; set; }
        public float NetUpKBps { get; set; }
        public float NetDownKBps { get; set; }
        public float GpuUsage { get; set; }
        public float DiskUsage { get; set; }
        public float DiskTotalGB { get; set; }
        public float DiskAvailableGB { get; set; }
        public long UptimeSeconds { get; set; }
    }
}
