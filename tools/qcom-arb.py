#!/usr/bin/env python3
"""Print the Qualcomm anti-rollback version of signed firmware images (ELF, MBN v6/v7/v8).

The hash segment of a signed Qualcomm ELF starts with an MBN (v6-v8) header followed by the common
and OEM/QTI metadata; the metadata carries the anti_rollback_version that the boot chain
compares against fuses. Flashing an image whose version is lower than the fused one can
hard-brick the phone, so compare before downgrading firmware.

    qcom-arb.py <image> [<image> ...]
"""
import struct
import sys

HASH_SEGMENT = 2  # bits 24..26 of p_flags


def arb(path):
    with open(path, "rb") as f:
        data = f.read()
    if data[:4] != b"\x7fELF":
        return "not ELF"
    is64 = data[4] == 2
    if is64:
        phoff, = struct.unpack_from("<Q", data, 0x20)
        phentsize, phnum = struct.unpack_from("<HH", data, 0x36)
    else:
        phoff, = struct.unpack_from("<I", data, 0x1C)
        phentsize, phnum = struct.unpack_from("<HH", data, 0x2A)
    for i in range(phnum):
        off = phoff + i * phentsize
        if is64:
            _, flags, p_offset = struct.unpack_from("<IIQ", data, off)
        else:
            _, p_offset, _, _, _, _, flags = struct.unpack_from("<IIIIIII", data, off)
        if (flags >> 24) & 7 != HASH_SEGMENT:
            continue
        # MBN v7/v8 header: image_id, version, common_meta_size, qti_meta_size,
        # oem_meta_size, hash_table_size, qti_sig, qti_cert, oem_sig, oem_cert (10 x u32)
        (_, version, common_size, qti_size, oem_size) = struct.unpack_from("<5I", data, p_offset)
        if version not in (6, 7, 8):
            return f"MBN v{version} (unsupported)"
        meta = p_offset + 40
        # common metadata: major, minor, software_id, app_id, hash_alg, measurement_reg
        sw_id, = struct.unpack_from("<I", data, meta + 8)
        out = [f"sw_id=0x{sw_id:x}"]
        # QTI / OEM metadata: major, minor, anti_rollback_version, ...
        for name, base, size in (("qti", meta + common_size, qti_size),
                                 ("oem", meta + common_size + qti_size, oem_size)):
            if size >= 12:
                ver, = struct.unpack_from("<I", data, base + 8)
                out.append(f"{name}_arb={ver}")
        return " ".join(out)
    return "no hash segment"


if __name__ == "__main__":
    for p in sys.argv[1:]:
        try:
            print(f"{p}: {arb(p)}")
        except Exception as e:  # truncated or odd image
            print(f"{p}: error {e}")
