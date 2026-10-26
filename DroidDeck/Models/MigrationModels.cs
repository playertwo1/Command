using System;
using System.Collections.Generic;
using System.Linq;

namespace DroidDeck.Models
{
    public enum MigrationCollisionPolicy
    {
        Skip,
        BackupAndOverwrite,
        Overwrite
    }

    public enum LegacyItemType
    {
        Profile,
        Secret,
        Configuration,
        GeneralData
    }

    public class LegacyItemCandidate
    {
        public string SourcePath { get; set; } = string.Empty;
        public string RelativePath { get; set; } = string.Empty;
        public string TargetPath { get; set; } = string.Empty;
        public LegacyItemType ItemType { get; set; }
        public bool IsSecret { get; set; }
        public long SizeBytes { get; set; }
        public bool TargetExists { get; set; }
    }

    public class MigrationPlan
    {
        public bool HasLegacyData { get; set; }
        public string LegacyRoamingPath { get; set; } = string.Empty;
        public string LegacyLocalPath { get; set; } = string.Empty;
        public string TargetRoamingPath { get; set; } = string.Empty;
        public string TargetLocalPath { get; set; } = string.Empty;
        public List<LegacyItemCandidate> Candidates { get; set; } = new();
        public int TotalCandidates => Candidates.Count;
        public int CollisionsCount => Candidates.Count(c => c.TargetExists);
    }

    public class MigratedItemResult
    {
        public string RelativePath { get; set; } = string.Empty;
        public bool Success { get; set; }
        public string ErrorCode { get; set; } = string.Empty;
        public string ErrorMessage { get; set; } = string.Empty;
        public bool Skipped { get; set; }
        public string? BackupPath { get; set; }
    }

    public class MigrationExecutionResult
    {
        public bool Success { get; set; }
        public bool ConsentProvided { get; set; }
        public string ErrorCode { get; set; } = string.Empty;
        public string ErrorMessage { get; set; } = string.Empty;
        public int MigratedCount { get; set; }
        public int SkippedCount { get; set; }
        public int FailedCount { get; set; }
        public List<MigratedItemResult> Details { get; set; } = new();
    }
}
