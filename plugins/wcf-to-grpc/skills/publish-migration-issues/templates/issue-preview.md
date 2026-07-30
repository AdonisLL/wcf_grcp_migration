# Issue publication preview

## Repository metadata

- Issue set ID: `{{issue_set_id}}`
- Migration spec ID: `{{migration_spec_id}}`
- Target repository: `{{target_repository}}`
- Publication state: `{{publication_state}}`
- Preview digest: `{{preview_digest}}`

## Summary

| Metric | Value |
|---|---|
| Approved work packages | {{approved_work_packages}} |
| Issues rendered | {{issues_rendered}} |
| Already published | {{issues_published}} |
| Ready to publish | {{issues_ready}} |
| Labels referenced | {{labels_total}} |
| Labels missing | {{labels_missing}} |

## Labels planned for creation after confirmation

| Label ID | Name | Color | Description | Create if missing |
|---|---|---|---|---|
| {{label_id}} | `{{label_name}}` | `#{{label_color}}` | {{label_description}} | {{label_create_if_missing}} |

## Issues in dependency-safe order

| Order | Issue ID | Work package | State | Labels | Depends on | Duplicate result |
|---|---|---|---|---|---|---|
| {{publish_order}} | `{{issue_id}}` | `{{work_package_id}}` | {{issue_state}} | {{issue_labels}} | {{dependency_work_package_ids}} | {{duplicate_result}} |

## Planned mutations

{{planned_mutations}}

## Confirmation required before mutation

Publication may proceed only after a human confirms:

1. `previewDigest = {{preview_digest}}`
2. `targetRepository = {{target_repository}}`
3. label creation is allowed or denied explicitly
4. issue creation is allowed explicitly
5. dependency-link patching is allowed explicitly
6. the reviewer identity recorded in `approvedBy`

If any field changes, regenerate the preview and re-approve it.
