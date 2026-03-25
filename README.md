# WinPdfGenerator

Native PDF generator library for Windows, written in Odin.

## Características

- Genera documentos PDFs conformes a las especificaciones
- Biblioteca dinámica (DLL) para consumo desde cualquier lenguaje nativo de Windows
- API C-compatible con convención `cdecl`
- Sin dependencias externas - implementación pura en Odin
- Soporta: texto con fuentes, paths (líneas/curvas), imágenes, anotaciones, formularios, links

## Estructura del Proyecto

```
WinPdfGenerator/
├── winpdfgenerator/           # Biblioteca principal
│   ├── api.odin
│   ├── types.odin
│   ├── document.odin
│   ├── graphics.odin
│   ├── text_fonts.odin
│   ├── image_xobjects.odin
│   ├── color.odin
│   ├── filters.odin
│   ├── interactive.odin
│   ├── transparency.odin
│   ├── metadata.odin
│   ├── signatures.odin
│   └── encryption_security.odin
├── sample/                    # Ejemplos de uso
│   ├── SampleOdinCLI/
│   └── SampleCppCLI/
└── bin/                      # Salida de compilación (.dll, .lib)
```

## Build

```batch
:: Compilar biblioteca
odin build winpdfgenerator -build-mode:dll -out:bin/WinPdfGenerator.dll

:: Build DLL (release)
odin build winpdfgenerator -build-mode:dll -out:bin/WinPdfGenerator.dll -o:speed"
```

## Requisitos

- [Odin compiler](https://odin-lang.org)
- Windows SDK (para compilación)
