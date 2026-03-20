# WinPdfGenerator

Native PDF 2.0 (ISO 32000-2) generator library for Windows, written in Odin.

## Características

- Genera documentos PDF 2.0 conformes a ISO 32000-2
- Biblioteca dinámica (DLL) para consumo desde cualquier lenguaje nativo de Windows
- API C-compatible con convención `cdecl`
- Sin dependencias externas - implementación pura en Odin
- Soporta: texto, gráficos, rectángulos, líneas, colores

## Estructura del Proyecto

```
WinPdfGenerator/
├── src/                    # Código fuente Odin
│   ├── core/               # Núcleo compartido (errores, tipos base)
│   ├── pdf20/              # Motor PDF 2.0
│   └── exports.odin        # API pública con @(export)
├── bindings/               # Bindings para lenguajes de consumo
│   ├── c/                  # Cabecera C/C++ (winpdf.h)
│   └── csharp/            # Declaraciones C# DllImport (WinPdf.cs)
├── examples/               # Ejemplos de uso
│   ├── csharp/             # Ejemplo .NET Native AOT
│   └── cpp/                # Ejemplo C++ nativo
├── bin/                    # Salida de compilación (.dll)
└── docs/                   # Documentación
```

## Build

```batch
:: Debug build
build.bat

:: Release build
build_release.bat
```

Salida: `bin/WinPdfGenerator.dll`

## Uso Rápido

### C#

```csharp
using WinPdf;

IntPtr doc = WinPdf.DocumentCreate();
IntPtr page = WinPdf.DocumentAddPage(doc, 595.28, 841.89);
WinPdf.PageAddText(page, 50, 50, "Hello!");
WinPdf.DocumentSave(doc, "output.pdf");
WinPdf.DocumentDestroy(doc);
```

### C++

```cpp
#include "winpdf.h"

WinPdf_Document doc = WinPdf_Document_Create();
WinPdf_Page page = WinPdf_Document_AddPage(doc, 595.28, 841.89);
WinPdf_Page_AddText(page, 50, 50, "Hello!");
WinPdf_Document_Save(doc, "output.pdf");
WinPdf_Document_Destroy(doc);
```

## API

Ver [docs/API.md](docs/API.md) para documentación completa.

## Requisitos

- Odin compiler (https://odin-lang.org)
- Windows SDK (para compilación)
