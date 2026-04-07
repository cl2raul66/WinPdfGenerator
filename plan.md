### Plan Arquitectónico Revisado e Integrado

#### Fase 0 — Compresión real (prerequisito bloqueante)
Sin zlib funcional, los ObjStm y el XRef Stream serían inválidos. Todo lo demás depende de esto.

#### Fase 1 — Separar `serialize_document` en un pipeline de fases explícitas

La función monolítica debe dividirse en responsabilidades discretas:

```
1. collect()   → inventario de todos los objetos y su tipo
2. classify()  → decidir qué va en ObjStm y qué es objeto directo
3. assign()    → asignar números de objeto a todo (incluyendo los ObjStm mismos)
4. render()    → serializar cuerpos (content streams, imágenes, fuentes, ObjStm)
5. xref()      → construir el XRef Stream con offsets reales
```

Este pipeline resuelve la dependencia circular: `assign()` ocurre antes de `render()`, y `xref()` ocurre al final cuando todos los offsets son conocidos.

#### Fase 2 — Nuevo módulo `object_stream.odin`

Responsabilidades según la propuesta:
- Acumular objetos no-stream con sus números de objeto
- Al cerrar el stream: construir la tabla de índices con offsets **relativos**, calcular `/First`, serializar el cuerpo sin `obj`/`endobj`, comprimir con FlateDecode
- Respetar las exclusiones: no streams, no gen ≠ 0, no diccionario de cifrado
- Respetar el límite de objetos por stream (parámetro configurable)
- Soporte para `/Extends` si se implementan actualizaciones incrementales

#### Fase 3 — Nuevo módulo `xref_stream.odin`

Reemplaza `write_xref` y `write_trailer` de `file.odin`:
- Entradas en formato binario con ancho de campo variable (`/W [w1 w2 w3]`)
- Tres tipos de entrada: `0` (libre), `1` (objeto directo con offset), `2` (objeto en ObjStm con `obj_stm_num + index`)
- El tipo `2` es el que referencia objetos dentro de ObjStm — actualmente imposible de expresar con la tabla xref textual
- El diccionario integra lo que hoy está en `write_trailer`: `/Size`, `/Root`, `/ID`, `/Encrypt` si aplica

#### Fase 4 — Completar cifrado (`encryption_security.odin`)

Con la arquitectura de pipeline ya establecida, el diccionario `/Encrypt` se clasifica en `classify()` como objeto directo (nunca en ObjStm, per spec), y se conecta `setup_encryption` al flujo de serialización.

---

### Impacto sobre módulos existentes

| Módulo | Acción |
|---|---|
| `core.odin` — `serialize_document` | Reescritura completa siguiendo el pipeline |
| `file.odin` — `write_xref`, `write_trailer` | Eliminados, reemplazados por `xref_stream.odin` |
| `filters.odin` | Implementación real de zlib (Fase 0) |
| `object_stream.odin` | Nuevo |
| `xref_stream.odin` | Nuevo |
| `types.odin`, `document.odin`, demás módulos | Sin cambios estructurales |

El orden correcto de implementación es estrictamente: **Fase 0 → Fase 1 → Fase 2 → Fase 3 → Fase 4**, porque cada fase es prerequisito de la siguiente.
