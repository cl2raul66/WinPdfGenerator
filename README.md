# WinPdfGenerator

PDF file generator engine, it is a class library for native PDF file generation in Windows, written in Odin.

## Ideología

- Motor de escritura de codigo PDF.
- No visualiza PDFs.
- No edita o modifica PDFs existentes.
- No gestiona el desbordamiento en las dimensiones de página (no paginación automática).
- No maneja contenido dinámico o interactivo (formularios, links, etc.) — solo generación estática.

## Características

- Genera documentos PDFs conformes a las especificaciones.
- Biblioteca dinámica (DLL) para consumo desde cualquier lenguaje nativo de Windows.
- API C-compatible para máxima interoperabilidad.
- Implementación pura en Odin y sus paquetes oficiales (Base Library, Core Library y Vendor Library).

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
