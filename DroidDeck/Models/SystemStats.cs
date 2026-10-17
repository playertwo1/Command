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

        // Telemetria estendida v0.2 (Saúde, Térmica e Energia)
        public float? CpuTempC { get; set; }
        public float? GpuTempC { get; set; }
        public int? BatteryPercent { get; set; }
        public bool? IsCharging { get; set; }
        public bool HasBattery { get; set; }
    }
}
