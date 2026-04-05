# WinPdfGenerator

PDF file generator engine, it is a class library for native PDF file generation in Windows, written in Odin.

## Características

- Genera documentos PDFs conformes a las especificaciones
- Biblioteca dinámica (DLL) para consumo desde cualquier lenguaje nativo de Windows
- API C-compatible con convención `cdecl`
- Sin dependencias externas - implementación pura en Odin
- Soporta: texto con fuentes, paths (líneas/curvas), imágenes y anotaciones
- Para futuro: formularios y links

## Estructura del Proyecto

```
WinPdfGenerator/
├── winpdfgenerator/           # Biblioteca principal
│   ├── api.odin
│   ├── core.odin
│   ├── document.odin
│   ├── file.odin
│   ├── functions.odin
│   ├── graphics.odin
│   ├── metadata.odin
│   ├── signatures.odin
│   ├── text_fonts.odin
│   ├── color.odin
│   ├── filters.odin
│   ├── image_xobjects.odin
│   ├── interactive.odin
│   ├── transparency.odin
│   ├── encryption_security.odin
│   ├── icc_profiles.odin
│   ├── patterns.odin
│   └── types.odin
├── sample/                    # Ejemplos de uso
│   ├── SampleOdinCLI/
│   ├── SampleCppCLI/
│   └── SampleSimple/          # Ejemplo simple
└── bin/                       # Salida de compilación (.dll, .lib)
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
