/*
 * Minimal localoptions.h for dropbear 2026.94 on Samsung Tizen 9.
 * Enables:
 *   - ed25519 / RSA / ECDSA host and client keys
 *   - public key auth (we don't want passwords)
 *   - no utmp/wtmp/lastlog (Tizen doesn't populate them usefully)
 *   - server only; we don't need the ssh/scp client in the install payload
 */

#define DROPBEAR_SERVER         1
#define DROPBEAR_CLIENT         0
#define DROPBEAR_SMALL_CODE     1

#define DROPBEAR_ED25519        1
#define DROPBEAR_ECDSA          1
#define DROPBEAR_RSA            1
#define DROPBEAR_DSS            0

#define DO_MOTD                 0
#define DROPBEAR_LASTLOG        0
#define DROPBEAR_UTMP           0
#define DROPBEAR_WTMP           0
#define DROPBEAR_PUTUTLINE      0
#define DROPBEAR_PUTUTXLINE     0

#define DROPBEAR_SVR_PASSWORD_AUTH   0
#define DROPBEAR_SVR_PUBKEY_AUTH     1
#define DROPBEAR_SVR_MULTIUSER       0

#define SFTPSERVER_PATH         ""
