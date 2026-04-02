#+private
package winpdfgenerator

import "core:fmt"
import "core:math/rand"
import "core:strings"

// ── Flags de Permisos (ISO 32000-2 Tabla 22) ──────────────────────────

Permission_Flag :: enum u32 {
	Print      = 2,
	Modify     = 3,
	Copy       = 4,
	Annotate   = 5,
	Fill_Forms = 8,
	Extract    = 9,
	Assemble   = 10,
	Print_High = 11,
}

Permissions :: bit_set[Permission_Flag; u32]

Security_Handler :: struct {
	user_password:    string,
	owner_password:   string,
	permissions:      Permissions,
	encrypt_metadata: bool,
}

Encryption_Context :: struct {
	file_key:    [32]byte, // AES-256 = 256 bits (§7.6.3)
	o_value:     [48]byte, // R=6: 48 bytes (§7.6.4.3.3)
	u_value:     [48]byte,
	oe_value:    [32]byte, // R=6: 32 bytes (§7.6.4.3.4)
	ue_value:    [32]byte,
	perms_value: [16]byte, // R=6: 16 bytes (§7.6.4.4.9)
	p_raw:       i32,
}

setup_encryption :: proc(h: Security_Handler) -> (ctx: Encryption_Context, ok: bool) {
	// CORRECCIÓN: rand.read requiere capturar el resultado.
	_ = rand.read(ctx.file_key[:])

	p := u32(0xFFFFF0C0)
	p |= transmute(u32)h.permissions
	ctx.p_raw = i32(p)

	ctx.perms_value = compute_perms_value(ctx.file_key, ctx.p_raw, h.encrypt_metadata)
	ok = true
	return
}

// CORRECCIÓN: os.Handle no disponible en esta versión de Odin.
// Cambiado a ^strings.Builder para evitar dependencia del tipo de archivo del SO.
write_encrypt_dict :: proc(sb: ^strings.Builder, id: int, ctx: ^Encryption_Context) {
	fmt.sbprintf(sb, "%d 0 obj\n<<\n", id)
	fmt.sbprintf(sb, "  /Filter /Standard\n")
	fmt.sbprintf(sb, "  /V 5\n")      // AES-256 (§7.6.3 Tabla 20)
	fmt.sbprintf(sb, "  /R 6\n")      // Revisión 6 (§7.6.4.2)
	fmt.sbprintf(sb, "  /Length 32\n") // 32 bytes = 256 bits
	fmt.sbprintf(sb, "  /P %d\n", ctx.p_raw)
	fmt.sbprintf(sb, "  /O <%X>\n", ctx.o_value)
	fmt.sbprintf(sb, "  /U <%X>\n", ctx.u_value)
	fmt.sbprintf(sb, "  /OE <%X>\n", ctx.oe_value)
	fmt.sbprintf(sb, "  /UE <%X>\n", ctx.ue_value)
	fmt.sbprintf(sb, "  /Perms <%X>\n", ctx.perms_value)
	fmt.sbprintf(sb, "  /CF << /StdCF << /AuthEvent /DocOpen /CFM /AESV3 /Length 32 >> >>\n")
	fmt.sbprintf(sb, "  /StmF /StdCF\n")
	fmt.sbprintf(sb, "  /StrF /StdCF\n")
	fmt.sbprintf(sb, ">>\nendobj\n")
}

@(private)
compute_perms_value :: proc(file_key: [32]byte, p: i32, encrypt_meta: bool) -> [16]byte {
	block: [16]byte

	p_u64 := u64(u32(p)) | 0xFFFFFFFF_00000000
	for i in 0..<8 {
		block[i] = byte(p_u64 >> uint(i * 8))
	}

	block[8]  = encrypt_meta ? 'T' : 'F'
	block[9]  = 'a'
	block[10] = 'd'
	block[11] = 'b'

	// CORRECCIÓN: rand.read requiere capturar el resultado.
	_ = rand.read(block[12:16])

	// TODO: cifrar block con AES-256 ECB usando file_key (core:crypto/aes)
	return block
}

encrypt_data :: proc(file_key: [32]byte, data: []byte) -> []byte {
	iv: [16]byte
	// CORRECCIÓN: rand.read requiere capturar el resultado.
	_ = rand.read(iv[:])
	// TODO: AES-256-CBC con PKCS#7 padding (RFC 8018), IV antepuesto al resultado
	_ = iv
	return nil
}
