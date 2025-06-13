"""
ICN Storage System

Legacy compatibility module that re-exports ICN storage functions from the unified experiment storage system.
This system follows the exact PerfChecker.jl pattern since ICN performance is system-dependent.
"""

# Re-export ICN-specific functions from the unified experiment storage system
# These are defined in experiment_storage.jl with legacy compatibility aliases

# The actual implementations are in experiment_storage.jl
# This file just ensures backward compatibility for existing code
