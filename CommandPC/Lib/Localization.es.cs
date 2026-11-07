using System;
using System.Collections.Generic;

namespace Command.Lib
{
    public static partial class L
    {
        private static readonly Dictionary<string, string> EsUi = new(StringComparer.Ordinal)
        {
            ["Rodando na bandeja — servidor em {url}"] = "En la bandeja — servidor en {url}",
            ["Para o celular encontrar e conectar no Command, o Firewall do Windows precisa liberar as portas {tcp} (TCP) e {udp} (UDP), só para a sua rede local.\n\nLiberar agora? O Windows vai pedir permissão de administrador."] = "Para que el teléfono encuentre y se conecte a Command, el Firewall de Windows debe permitir los puertos {tcp} (TCP) y {udp} (UDP), solo en tu red local.\n\n¿Permitir ahora? Windows solicitará permiso de administrador.",
            ["Firewall liberado para a rede local."] = "Firewall permitido en la red local.",
            ["O firewall não foi alterado. Você pode tentar de novo pelo menu da bandeja."] = "El firewall no se modificó. Puedes intentarlo de nuevo desde el menú de la bandeja.",
            ["A versão {version} foi baixada e entra na próxima vez que o Command abrir. Para atualizar agora, use o menu da bandeja."] = "La versión {version} se descargó y se aplicará la próxima vez que se abra Command. Para actualizar ahora, usa el menú de la bandeja.",
            ["Atualizações remotas estão desativadas neste instalador piloto."] = "Las actualizaciones remotas están desactivadas en este instalador piloto.",
            ["Procurando atualização…"] = "Buscando actualizaciones…",
            ["Procurar atualização"] = "Buscar actualizaciones",
            ["Você está na versão mais recente ({version})."] = "Tienes la versión más reciente ({version}).",
            ["Ver releases do Command"] = "Ver versiones de Command",
            ["Atualizações desativadas neste piloto"] = "Actualizaciones desactivadas en este piloto",
            ["Command (sem instalador)"] = "Command (sin instalador)",
            ["Command v{version}"] = "Command v{version}",
            ["Abrir no navegador"] = "Abrir en el navegador",
            ["Parear dispositivo (QR)…"] = "Vincular dispositivo (QR)…",
            ["Iniciar com o Windows"] = "Iniciar con Windows",
            ["Liberar no firewall (rede local)"] = "Permitir en el firewall (red local)",
            ["Reiniciar para atualizar (v{version})"] = "Reiniciar para actualizar (v{version})",
            ["Sair"] = "Salir",
            ["Command — Parear dispositivo"] = "Command — Vincular dispositivo",
            ["No app Command, vá em Configurar → Parear (QR)\ne escaneie este código para conectar com segurança."] = "En la app Command, ve a Configuración → Vincular (QR)\ny escanea este código para conectarte de forma segura.",
            ["IP: {ip}    Chave: {key}"] = "IP: {ip}    Clave: {key}",
            ["Fechar"] = "Cerrar",
        };
    }
}
