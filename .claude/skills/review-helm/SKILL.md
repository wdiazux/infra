# Review Helm Skill

Reviews Helm charts for API versions, best practices, and deprecated values.

## Purpose

This skill validates:
- Chart API version (v1 vs v2)
- Required Chart.yaml fields
- Values.yaml structure and defaults
- Template best practices
- Deprecated Helm features

## When to Use

Invoke this skill when:
- Creating new Helm charts
- Updating existing charts
- Before packaging/releasing charts
- After upgrading Helm version

## Checks Performed

### Critical

1. **Chart API Version**
   - v1 is deprecated, use apiVersion: v2
   - Check `Chart.yaml` apiVersion field

2. **Missing Required Fields**
   - `name` - Required
   - `version` - Required (SemVer)
   - `apiVersion` - Required

### Warning

1. **Missing Recommended Fields**
   - `description` - Recommended
   - `appVersion` - Recommended
   - `type` (application/library) - Recommended

2. **Values Issues**
   - Hardcoded values that should be configurable
   - Missing default values for required fields
   - Unused values (defined but not referenced)

3. **Template Issues**
   - Missing `{{- include "chart.labels" . }}` for standard labels
   - Hardcoded namespaces in templates
   - Missing NOTES.txt

### Info

1. **Documentation**
   - Missing README.md
   - Missing values schema (values.schema.json)

## Documentation Lookup

Use Context7 for:
- `helm/helm` - Helm documentation
- Chart best practices

## Workflow

1. Find Chart.yaml files
2. Parse chart metadata
3. Scan values.yaml
4. Check templates for issues
5. Generate report

## Usage

```
/review-helm
/review-helm path/to/chart/
```
