using System.Threading.Tasks;
using Command.Models;

namespace Command.Services
{
    public interface ILegacyDataMigrationService
    {
        string LegacyRoamingPath { get; }
        string LegacyLocalPath { get; }
        string TargetRoamingPath { get; }
        string TargetLocalPath { get; }

        MigrationPlan BuildPlan();

        Task<MigrationExecutionResult> ExecuteMigrationAsync(
            bool explicitConsent,
            MigrationCollisionPolicy collisionPolicy = MigrationCollisionPolicy.BackupAndOverwrite);
    }
}
