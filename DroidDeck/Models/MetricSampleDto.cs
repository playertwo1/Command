using System;

namespace DroidDeck.Models
{
    /// <summary>
    /// Amostra instantânea de métricas de carga e temperatura para compor histórico deslizante (60s).
    /// </summary>
    public class MetricSampleDto
    {
        public DateTime TimestampUtc { get; set; } = DateTime.UtcNow;
        public float Cpu { get; set; }
        public float Ram { get; set; }
        public float Gpu { get; set; }
        public float? CpuTempC { get; set; }
        public float? GpuTempC { get; set; }
    }
}
