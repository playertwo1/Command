namespace DroidDeck.Models
{
    /// <summary>
    /// Status de um serviço do Windows permitido na allowlist de monitoramento.
    /// </summary>
    public class ServiceStatusDto
    {
        public string Name { get; set; } = string.Empty;
        public string DisplayName { get; set; } = string.Empty;
        public string Status { get; set; } = "Unknown";
        public bool IsRunning { get; set; }
    }
}
