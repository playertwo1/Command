using System.Collections.Generic;

namespace Command.Models
{
    /// <summary>
    /// Resumo de consumo de processo sanitizado (apenas PID, nome, RAM e CPU; sem caminhos ou parâmetros).
    /// </summary>
    public class TopProcessDto
    {
        public int Pid { get; set; }
        public string Name { get; set; } = string.Empty;
        public float MemoryMB { get; set; }
        public float? CpuPercent { get; set; }
    }

    /// <summary>
    /// Resposta de processos mais consumidores agrupados por memória e por CPU.
    /// </summary>
    public class TopProcessesResponseDto
    {
        public List<TopProcessDto> ByMemory { get; set; } = new();
        public List<TopProcessDto> ByCpu { get; set; } = new();
    }
}
