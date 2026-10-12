# ♻ RetornaCírculo · Prototipo de validación

[![CI](https://github.com/Fernandamv96/retornacirculo/actions/workflows/ci.yml/badge.svg)](https://github.com/Fernandamv96/retornacirculo/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-BD93F9)](LICENSE)

> Prototipo de validación — CREA INACAP 2026 · Innovación y Emprendimiento I

Hub con los **artefactos de diseño** de RetornaCírculo, una propuesta de plataforma B2B para trazar el retorno de envases industriales según la Ley REP 20.920: dashboard demostrativo, wireframes imprimibles, esquema de base de datos y contratos de API.

**Demo:** <https://retornacirculo.vercel.app> · [Presentación del proyecto](https://retornacirculo.vercel.app/presentacion%20retornacirculo.html)

![Hub de artefactos de RetornaCírculo](docs/preview.png)

> La versión con registro de envases está en [retornacirculo-saas](https://github.com/Fernandamv96/retornacirculo-saas).

## ¿Qué problema resuelve?

Valida la idea con potenciales clientes antes de construirla: muestra cómo se vería la operación (KPIs, cumplimiento REP, certificados) y cómo se integraría (modelo de datos y API).

## Contenido

| Archivo | Qué es |
|---------|--------|
| `index.html` | Hub de artefactos + código para incrustar el dashboard |
| `dashboard.html` | Dashboard demostrativo (datos simulados) |
| `wireframes.html` | 4 pantallas imprimibles (A4) |
| `presentacion retornacirculo.html` | Presentación del proyecto |
| `schema.sql` | Esquema PostgreSQL propuesto |
| `data-model.json` | Contratos de API y ejemplos de payload (diseño) |

## Cómo correrlo localmente

```bash
npm ci && npm start     # http://localhost:8000
npm run lint            # html-validate
```

## 🔒 Calidad y seguridad

- CI en cada push y PR: `html-validate`, además de CodeQL, Dependabot y gitleaks en pre-commit.
- Para reportar vulnerabilidades, mira [SECURITY.md](SECURITY.md).

## 💡 Qué aprendí

- A prototipar para validar con clientes antes de programar el backend.
- A traducir una obligación legal (Ley REP) en requisitos de producto y en un modelo de datos.

## 👥 Equipo

Proyecto CREA · INACAP Valparaíso · 2026

## 📄 Licencia

[MIT](LICENSE) © 2026 Fernanda (Fernandamv96)
