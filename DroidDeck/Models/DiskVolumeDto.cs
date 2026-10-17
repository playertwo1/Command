namespace DroidDeck.Models
{
    /// <summary>
    /// Volume de armazenamento fixo local do computador (ex.: C:, D:).
    /// </summary>
    public class DiskVolumeDto
    {
        public string Name { get; set; } = string.Empty;
        public string Label { get; set; } = string.Empty;
        public float TotalGB { get; set; }
        public float AvailableGB { get; set; }
        public float UsagePercent { get; set; }
    }
}
