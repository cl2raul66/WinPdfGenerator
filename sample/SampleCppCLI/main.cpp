#include <cstdio>
#include "winpdfgenerator.h"

bool generar_documento_en_blanco(const char* filename) {
    void* doc = pdf_document_create();

    void* builder = page_info_builder_create(1, 595, 842);
    void* info = page_info_builder_build(builder);

    void* page = pdf_document_start_page(doc, info);
    pdf_document_finish_page(doc, page);

    bool success = pdf_document_write_to_file(doc, filename) != 0;
    pdf_document_close(doc);

    return success;
}

void mostrar_menu() {
    printf("=================================\n");
    printf("  Generador de PDF - Menu\n");
    printf("=================================\n");
    printf("1. Documento en blanco (A4 Vertical)\n");
    printf("0. Salir\n");
    printf("\n");
    printf("Seleccione opcion: ");
}

int main() {
    while (true) {
        mostrar_menu();

        int opcion;
        if (scanf("%d", &opcion) != 1) {
            printf("Error al leer la opcion.\n");
            while (getchar() != '\n');
            continue;
        }

        switch (opcion) {
            case 1:
                if (generar_documento_en_blanco("bin/SampleCpp - Blank Document.pdf")) {
                    printf("PDF generado exitosamente: bin/SampleCpp - Blank Document.pdf\n");
                } else {
                    printf("Error al generar el PDF\n");
                }
                break;
            case 0:
                printf("Saliendo...\n");
                return 0;
            default:
                printf("Opcion invalida. Intente de nuevo.\n");
                break;
        }
        printf("\n");
    }

    return 0;
}
