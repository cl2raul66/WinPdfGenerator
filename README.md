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
├── winpdfgenerator/                # Biblioteca principal
│   ├── api.odin                    # API pública de la biblioteca
│   ├── core.odin                   # Núcleo del motor de escritura PDF
│   ├── document.odin               # Gestión del documento PDF
│   ├── file.odin                   # Escritura del archivo PDF
│   ├── functions.odin              # Funciones de operadores PDF
│   ├── graphics.odin               # Operadores gráficos
│   ├── metadata.odin               # Metadatos del documento
│   ├── signatures.odin             # Firmas digitales
│   ├── text_fonts.odin             # Texto y fuentes
│   ├── color.odin                  # Definición de colores
│   ├── filters.odin                # Filtros de compresión
│   ├── image_xobjects.odin         # Imágenes y objetos externos
│   ├── interactive.odin            # Elementos interactivos
│   ├── transparency.odin           # Transparencia
│   ├── encryption_security.odin    # Cifrado y seguridad
│   ├── icc_profiles.odin           # Perfiles de color ICC
│   ├── patterns.odin               # Patrones de relleno
│   ├── xref_stream.odin            # Tabla de referencias cruzadas
│   ├── object_stream.odin          # Flujos de objetos comprimidos
│   └── types.odin                  # Definiciones de tipos
├── sample/                         # Ejemplos de uso
│   ├── SampleSimple/
│   ├── SampleOdinCLI/
│   └── SampleCppCLI/
└── bin/                            # Salida de compilación (.dll, .lib)
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
