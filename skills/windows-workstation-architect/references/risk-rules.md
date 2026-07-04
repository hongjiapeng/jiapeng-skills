# Risk Rules

Never implement these operations in v1:

- file deletion
- bulk file movement
- disk formatting
- repartitioning
- deleting volumes
- registry edits
- OneDrive folder redirection changes
- system directory modification
- administrator-required changes

Allowed operations:

- generate a plan
- create folders under a user-selected root
- dry-run folder creation
- validate whether planned folders exist

