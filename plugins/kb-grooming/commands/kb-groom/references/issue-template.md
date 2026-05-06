## Documentation Issue: {{checkName}}

{{description}}

### Affected Files

{{#each files}}
- `{{file}}`{{#if line}} (line {{line}}){{/if}}: {{message}}
{{/each}}

### Suggested Actions

{{#each actions}}
- [ ] {{action}}
{{/each}}

### Context

- **Check type:** {{checkType}}
- **Severity:** {{maxSeverity}}
- **Findings:** {{findingCount}}

---
*Created by [kb-grooming](https://github.com/artem-from-ua/claude-plugins) plugin*
