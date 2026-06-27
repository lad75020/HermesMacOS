# Data Model: Local Runtime and Profile Management

## HermesLocalProfileInfo
- **Attributes**: name, path, default/active flags, provider, model, baseURL, file presence, skill count, gateway running state.
- **Relationships**: displayed in profile section and used to seed edit drafts.

## HermesLocalProfileDraft
- **Attributes**: name, provider, model, baseURL, createEnv, createSoul, cloneSkills.
- **Validation**: names normalize, default profile protections apply, duplicates are rejected.

## HermesLocalProfilesStore
- **Attributes**: profiles, active profile, profile directory, last output, error, busy state.
- **Relationships**: reads/writes profile directories and active profile marker.

## HermesLocalConfigurationRuntime
- **Attributes**: command outputs, running sections, Hermes executable/home, remote host.
- **Validation**: requires filesystem approval, wraps remote commands with SSH credentials, removes temporary identity files.

## Runtime model and MCP YAML stores
- **Attributes**: model/provider slots, raw YAML structures, validation/status/error state.
- **Validation**: malformed YAML or invalid server forms are rejected before write.
