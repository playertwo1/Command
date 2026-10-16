namespace DroidDeck.Integrations
{
    /// <summary>
    /// Uma integracao (Discord, OBS, Spotify...), do jeito que a lista de integracoes do app
    /// a mostra. As com conta herdam de <see cref="AccountIntegration"/>; as mais antigas tem
    /// controlador proprio (/api/obs, /api/discord...), mantido pela compatibilidade da API.
    /// </summary>
    public interface IIntegration
    {
        /// <summary>Nome curto e estavel: "obs", "spotify"...</summary>
        string Name { get; }

        string Title { get; }

        bool IsConnected { get; }

        /// <summary>Conta, canal ou servidor conectado, quando faz sentido.</summary>
        string? AccountName => null;
    }
}
