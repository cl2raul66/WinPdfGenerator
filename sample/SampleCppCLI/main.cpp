#include <cstdio>
#include "winpdfgenerator.h"

int main() {
    generate_blank_pdf("bin/output_cpp.pdf");
    printf("PDF generado: bin/output_cpp.pdf\n");
    return 0;
}
