"""Read the kernel image signature from the QE EUR TV via browser physmap stub."""
import sys, struct, time
sys.path.insert(0, str(__import__('pathlib').Path(__file__).resolve().parent))
import physmap as T

print("[*] Connecting to physmap stub via gateway...", flush=True)
rpc = T.RPC(timeout=10, hello_timeout=25)
print(f"[+] Connected. magic={rpc.magic!r}", flush=True)

for addr in [0x20008000, 0x40008000]:
    try:
        sig = rpc.read(addr, 64)
        words = [struct.unpack_from('<I', sig, i)[0] for i in range(0, 64, 4)]
        print(f"\n[*] phys {addr:#010x} first 64 bytes:", flush=True)
        for i in range(0, 16):
            print(f"    +{i*4:02x}: {words[i]:#010x}", flush=True)
        print(f"    hex: {sig[:8].hex()}", flush=True)
        print(f"    IMG_SIG bytes: [{', '.join(f'0x{b:02X}' for b in sig[:8])}]", flush=True)
    except Exception as e:
        print(f"[!] phys {addr:#010x}: read failed: {e}", flush=True)

# Also check if the NA signature exists anywhere nearby
na_sig = bytes([0xEE, 0x44, 0x00, 0xEB, 0x00, 0x90, 0x0F, 0xE1])
try:
    got = rpc.read(0x20008000, 8)
    if got == na_sig:
        print("\n[+] QE EUR kernel sig MATCHES NA sig — same kernel image!")
    else:
        print(f"\n[!] QE EUR kernel sig DIFFERS from NA")
        print(f"    NA:     {na_sig.hex()}")
        print(f"    QE EUR: {got.hex()}")
        print(f"    C# array: static readonly byte[] IMG_SIG = {{ {', '.join(f'0x{b:02X}' for b in got)} }};")
except Exception as e:
    print(f"[!] Compare failed: {e}", flush=True)

rpc.close()
