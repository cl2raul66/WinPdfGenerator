#+private
package winpdfgenerator

import aescrypto "core:crypto/aes"
import "core:crypto/hash"
import "core:fmt"
import "core:math/rand"
import "core:strings"

// ── Flags de Permisos (ISO 32000-2 Tabla 22) ──────────────────

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
	file_key:    [32]byte,
	o_value:     [48]byte,
	u_value:     [48]byte,
	oe_value:    [32]byte,
	ue_value:    [32]byte,
	perms_value: [16]byte,
	p_raw:       i32,
}

// ── Primitivas AES-256 ────────────────────────────────────────

// AES-256-ECB: cifra un único bloque de 16 bytes (para /Perms).
@(private)
aes256_ecb_encrypt_block :: proc(key: [32]byte, src: [16]byte) -> (dst: [16]byte) {
	k := key // copia local → addressable
	s := src
	ctx: aescrypto.Context_ECB
	aescrypto.init_ecb(&ctx, k[:])
	aescrypto.encrypt_ecb(&ctx, dst[:], s[:])
	aescrypto.reset_ecb(&ctx)
	return
}

// AES-256-CBC con IV de ceros: usado internamente para OE/UE (§7.6.4.3.4).
// El caller proporciona la clave derivada de 32 bytes.
// Retorna solo el ciphertext (sin IV), tamaño = len(plaintext).
// plaintext DEBE ser múltiplo de 16 bytes.
@(private)
aes256_cbc_zero_iv :: proc(key: [32]byte, plaintext: []byte) -> []byte {
	n := len(plaintext)
	out := make([]byte, n)
	k := key // copia local → addressable
	ctx: aescrypto.Context_ECB
	aescrypto.init_ecb(&ctx, k[:])
	defer aescrypto.reset_ecb(&ctx)

	prev: [16]byte // IV = 0x00...00
	for i := 0; i < n; i += 16 {
		block: [16]byte
		copy(block[:], plaintext[i:i+16])
		for j in 0 ..< 16 { block[j] ~= prev[j] }
		aescrypto.encrypt_ecb(&ctx, out[i:i+16], block[:])
		copy(prev[:], out[i:i+16])
	}
	return out
}

// AES-256-CBC con IV aleatorio: usado para cifrar streams y strings (§7.6.5).
// Retorna: IV (16 bytes) || ciphertext || PKCS7-padding.
encrypt_data :: proc(file_key: [32]byte, data: []byte) -> []byte {
	// PKCS7 padding
	pad_len := 16 - (len(data) % 16)
	padded  := make([]byte, len(data) + pad_len)
	defer delete(padded)
	copy(padded, data)
	for i in len(data) ..< len(padded) { padded[i] = byte(pad_len) }

	// IV aleatorio
	iv: [16]byte
	_ = rand.read(iv[:])

	out := make([]byte, 16 + len(padded))
	copy(out[:16], iv[:])

	k := file_key // copia local → addressable
	ctx: aescrypto.Context_ECB
	aescrypto.init_ecb(&ctx, k[:])
	defer aescrypto.reset_ecb(&ctx)

	prev := iv
	for i := 0; i < len(padded); i += 16 {
		block: [16]byte
		copy(block[:], padded[i:i+16])
		for j in 0 ..< 16 { block[j] ~= prev[j] }
		aescrypto.encrypt_ecb(&ctx, out[16+i:16+i+16], block[:])
		copy(prev[:], out[16+i:16+i+16])
	}
	return out
}

// ── SHA-256 helper ────────────────────────────────────────────

@(private)
sha256_of :: proc(parts: ..[]byte) -> [32]byte {
	ctx: hash.Context
	hash.init(&ctx, .SHA256)
	for p in parts { hash.update(&ctx, p) }
	buf: [32]byte
	hash.final(&ctx, buf[:])
	return buf
}

// ── Derivación de claves PDF AES-256 R=6 (ISO 32000-2 §7.6.4.3) ──────────

// Calcula U y UE a partir de la contraseña de usuario y la file_key.
// U  = SHA256(user_pw + vsalt) || vsalt || ksalt   (48 bytes, §7.6.4.3.3)
// UE = AES256-CBC(key=SHA256(user_pw + ksalt), IV=0, file_key)  (32 bytes)
@(private)
compute_u_ue :: proc(user_pw: string, file_key: [32]byte) -> (u: [48]byte, ue: [32]byte) {
	pw := transmute([]byte)user_pw

	vsalt: [8]byte; _ = rand.read(vsalt[:])
	ksalt: [8]byte; _ = rand.read(ksalt[:])

	// U: SHA256(pw + vsalt) || vsalt || ksalt
	h := sha256_of(pw, vsalt[:])
	copy(u[:32], h[:])
	copy(u[32:40], vsalt[:])
	copy(u[40:48], ksalt[:])

	// UE: AES256-CBC(SHA256(pw + ksalt), IV=0, file_key)
	key_enc := sha256_of(pw, ksalt[:])
	fk := file_key // copia local → addressable para slice
	enc := aes256_cbc_zero_iv(key_enc, fk[:])
	defer delete(enc)
	copy(ue[:], enc[:32])
	return
}

// Calcula O y OE a partir de la contraseña de propietario, la file_key y U.
// O  = SHA256(owner_pw + vsalt + U) || vsalt || ksalt  (48 bytes, §7.6.4.3.3)
// OE = AES256-CBC(key=SHA256(owner_pw + ksalt + U), IV=0, file_key) (32 bytes)
@(private)
compute_o_oe :: proc(owner_pw: string, file_key: [32]byte, u: [48]byte) -> (o: [48]byte, oe: [32]byte) {
	pw := transmute([]byte)owner_pw
	uv := u // copia local → addressable para slice

	vsalt: [8]byte; _ = rand.read(vsalt[:])
	ksalt: [8]byte; _ = rand.read(ksalt[:])

	// O: SHA256(pw + vsalt + U) || vsalt || ksalt
	h := sha256_of(pw, vsalt[:], uv[:])
	copy(o[:32], h[:])
	copy(o[32:40], vsalt[:])
	copy(o[40:48], ksalt[:])

	// OE: AES256-CBC(SHA256(pw + ksalt + U), IV=0, file_key)
	fk := file_key // copia local → addressable para slice
	key_enc := sha256_of(pw, ksalt[:], uv[:])
	enc := aes256_cbc_zero_iv(key_enc, fk[:])
	defer delete(enc)
	copy(oe[:], enc[:32])
	return
}

// ── /Perms (ISO 32000-2 §7.6.4.4.9) ─────────────────────────

@(private)
compute_perms_value :: proc(file_key: [32]byte, p: i32, encrypt_meta: bool) -> [16]byte {
	block: [16]byte

	p_u64 := u64(u32(p)) | 0xFFFFFFFF_00000000
	for i in 0 ..< 8 { block[i] = byte(p_u64 >> uint(i * 8)) }

	block[8] = encrypt_meta ? 'T' : 'F'
	block[9] = 'a'
	block[10] = 'd'
	block[11] = 'b'
	_ = rand.read(block[12:16])

	return aes256_ecb_encrypt_block(file_key, block)
}

// ── setup_encryption ─────────────────────────────────────────

setup_encryption :: proc(h: Security_Handler) -> (ctx: Encryption_Context, ok: bool) {
	_ = rand.read(ctx.file_key[:])

	p := u32(0xFFFFF0C0) | transmute(u32)h.permissions
	ctx.p_raw = i32(p)

	ctx.u_value, ctx.ue_value = compute_u_ue(h.user_password, ctx.file_key)
	ctx.o_value, ctx.oe_value = compute_o_oe(h.owner_password, ctx.file_key, ctx.u_value)
	ctx.perms_value = compute_perms_value(ctx.file_key, ctx.p_raw, h.encrypt_metadata)

	ok = true
	return
}

// ── Escritura del diccionario /Encrypt ───────────────────────
// Objeto directo en el cuerpo del PDF; nunca en un ObjStm (per spec).
// El XRef Stream lo referencia con /Encrypt N 0 R.

write_encrypt_dict :: proc(sb: ^strings.Builder, id: int, ctx: ^Encryption_Context) {
	fmt.sbprintf(sb, "%d 0 obj\n<<\n", id)
	fmt.sbprintf(sb, "  /Filter /Standard\n")
	fmt.sbprintf(sb, "  /V 5\n")       // AES-256 (§7.6.3 Tabla 20)
	fmt.sbprintf(sb, "  /R 6\n")       // Revisión 6 (§7.6.4.2)
	fmt.sbprintf(sb, "  /Length 32\n") // 32 bytes = 256 bits
	fmt.sbprintf(sb, "  /P %d\n",      ctx.p_raw)

	strings.write_string(sb, "  /O <")
	for b in ctx.o_value { fmt.sbprintf(sb, "%02X", b) }
	strings.write_string(sb, ">\n")

	strings.write_string(sb, "  /U <")
	for b in ctx.u_value { fmt.sbprintf(sb, "%02X", b) }
	strings.write_string(sb, ">\n")

	strings.write_string(sb, "  /OE <")
	for b in ctx.oe_value { fmt.sbprintf(sb, "%02X", b) }
	strings.write_string(sb, ">\n")

	strings.write_string(sb, "  /UE <")
	for b in ctx.ue_value { fmt.sbprintf(sb, "%02X", b) }
	strings.write_string(sb, ">\n")

	strings.write_string(sb, "  /Perms <")
	for b in ctx.perms_value { fmt.sbprintf(sb, "%02X", b) }
	strings.write_string(sb, ">\n")

	fmt.sbprintf(sb, "  /CF << /StdCF << /AuthEvent /DocOpen /CFM /AESV3 /Length 32 >> >>\n")
	fmt.sbprintf(sb, "  /StmF /StdCF\n")
	fmt.sbprintf(sb, "  /StrF /StdCF\n")
	fmt.sbprintf(sb, ">>\nendobj\n")
}
