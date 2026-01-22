# IT-Tools

Collection of handy online tools for developers.

**Image**: `corentinth/it-tools:latest`
**Namespace**: `tools`
**IP**: `10.10.2.32`

## Environment Variables

IT-Tools is a client-side application with minimal server configuration. Most tools run in the browser.

| Variable | Description | Default |
|----------|-------------|---------|
| (No specific environment variables) | - | - |

## Deployment

IT-Tools runs as a static web application and doesn't require special configuration:

```yaml
services:
  it-tools:
    image: corentinth/it-tools:latest
    ports:
      - "8080:80"
```

## Available Tools

IT-Tools includes 70+ tools for various purposes:

### Converters
- JSON to YAML/XML/CSV
- Base64 encode/decode
- Color converter
- Date/time converter

### Generators
- UUID generator
- Password generator
- Lorem ipsum
- Hash generator

### Networking
- IPv4 subnet calculator
- MAC address lookup
- URL parser

### Development
- JWT decoder
- JSON diff
- Regex tester
- SQL formatter

### Security
- Hash generator (MD5, SHA, etc.)
- Bcrypt hash generator
- Token generator

## Volume Mounts

No persistent storage required - all tools are client-side.

## Documentation

- [IT-Tools GitHub](https://github.com/CorentinTh/it-tools)
- [Live Demo](https://it-tools.tech/)
