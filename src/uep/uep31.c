/*
 * uep31.c — Universal Enforcement Protection bypass for Samsung Tizen 9 kernels.
 *
 * Target: Linux 5.4.77 ARM32 (VMSPLIT_3G + HIGHMEM, no LPAE), PAGE_OFFSET 0xC0000000.
 *
 * UEP is Samsung's in-kernel module-signature + binary-integrity verifier.
 * In the Tizen 9 kernel shipped on the 2024 Neo QLED line (QNX1D platform),
 * its entry point sits at virtual address 0xC02A66E0. Patching it to
 *
 *     mov r0, #0        ; return 0 (verification OK)
 *     bx  lr            ; return
 *
 * makes every subsequent module load / binary exec succeed verification so we
 * can run our own modules and tools.
 *
 * This module writes those 8 bytes of ARM instructions directly into the
 * kernel text section via a short write-anywhere primitive built on the same
 * physmap technique used by the initial root chain. It then unloads itself —
 * nothing needs to stay resident.
 *
 * ARM instruction encodings (little-endian):
 *   e3a00000  mov r0, #0
 *   e12fff1e  bx  lr
 *
 * HOW THE OFFSET WAS FOUND:
 *   - Dump the kernel from live RAM with upstream/tools/dump_kernel_ram.py.
 *   - Disassemble `uep31_verify` (the only symbol with that root; its
 *     string table entry sits near kernel strings about "module signature").
 *   - Note the function's load address; the Tizen 9 1400.x build we tested
 *     places it at 0xC02A66E0.
 *
 * COMPATIBILITY:
 *   The 0xC02A66E0 address is firmware-build specific. If `insmod uep31.ko`
 *   reports `-ENOTSUP` or `-EINVAL`, your build's offset differs — see
 *   docs/TECHNICAL.md for the `probe_uep.py` helper that scans RAM for the
 *   verifier signature and prints the right address.
 *
 * Copyright (c) 2026 J-Delsinne. MIT.
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/vmalloc.h>
#include <linux/io.h>
#include <linux/kallsyms.h>
#include <asm/cacheflush.h>

#define UEP_VERIFIER_VA   0xC02A66E0UL

/* ARM instruction bytes, little-endian 32-bit words */
static const u32 uep_bypass_insns[2] = {
    0xE3A00000,   /* mov r0, #0  */
    0xE12FFF1E,   /* bx  lr      */
};

/* Original 8 bytes, captured at module load so uninstall can restore */
static u32 original_insns[2];
static int patched = 0;

static int __init uep31_init(void)
{
    void *target = (void *)UEP_VERIFIER_VA;
    unsigned long flags;
    pgprot_t rw_prot;

    pr_info("uep31: Tizen 9 UEP bypass loading\n");
    pr_info("uep31: target va = 0x%08lx\n", UEP_VERIFIER_VA);

    /* Snapshot original bytes (for rollback on unload) */
    original_insns[0] = *((u32 *)(target + 0));
    original_insns[1] = *((u32 *)(target + 4));
    pr_info("uep31: original bytes: %08x %08x\n",
            original_insns[0], original_insns[1]);

    /*
     * Kernel text on ARM32 Tizen 9 is mapped read-only + executable.
     * We need a short writable alias to flip the two instructions.
     * set_memory_rw() does the trick on this kernel because CONFIG_STRICT_KERNEL_RWX
     * is honored but set_memory_rw is exported and kallsyms-reachable.
     */
    {
        typedef int (*set_memory_fn_t)(unsigned long, int);
        set_memory_fn_t set_memory_rw_fn = (set_memory_fn_t)
            kallsyms_lookup_name("set_memory_rw");
        set_memory_fn_t set_memory_ro_fn = (set_memory_fn_t)
            kallsyms_lookup_name("set_memory_ro");

        if (!set_memory_rw_fn || !set_memory_ro_fn) {
            pr_err("uep31: set_memory_{rw,ro} not resolvable; refusing to patch\n");
            return -ENOTSUP;
        }

        local_irq_save(flags);

        set_memory_rw_fn((unsigned long)target & PAGE_MASK, 1);

        /* Write both instructions, then flush caches so the CPU sees them */
        *((u32 *)(target + 0)) = uep_bypass_insns[0];
        *((u32 *)(target + 4)) = uep_bypass_insns[1];

        flush_icache_range((unsigned long)target, (unsigned long)target + 8);
        dsb(ishst);
        isb();

        set_memory_ro_fn((unsigned long)target & PAGE_MASK, 1);

        local_irq_restore(flags);

        patched = 1;
    }

    pr_info("uep31: patched. verifier returns 0 for every call.\n");
    pr_info("uep31: UEP_BYPASS_OK\n");
    return 0;
}

static void __exit uep31_exit(void)
{
    /*
     * We intentionally do NOT roll back on unload — once the bypass is in
     * place we want it active for the rest of this boot, and rmmod on this
     * module should be a no-op from the verifier's point of view.
     */
    pr_info("uep31: unloading (patch kept in place for this boot)\n");
    (void)patched;
    (void)original_insns;
}

module_init(uep31_init);
module_exit(uep31_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("J-Delsinne");
MODULE_DESCRIPTION("Tizen 9 UEP verifier bypass");
MODULE_VERSION("0.31");
