### 1. Create Your Permanent Admin Account (Grants SecureToken)

1. Log into the temporary bootstrap account created in Recovery (keep Wi-Fi off).
2. Open **System Settings > Users & Groups**, click **Add User**, set the account type to **Administrator**, and create your permanent admin account.
3. Restart the Mac and log into the new permanent admin account.
4. Open **System Settings > Users & Groups** and delete the temporary bootstrap account (select **Delete the home folder**).

---

### 2. Move and Run `mdm_shield.sh`

`MDMTool.sh` already pre-populated `/etc/hosts` with IPv4 and IPv6 blocks, cleared the cached `.cloudConfig` activation records, and saved `mdm_shield.sh` to `/Users/Shared/`. Move it into your home folder and run it:

```bash
mv /Users/Shared/mdm_shield.sh ~/mdm_shield.sh && ~/mdm_shield.sh

```

This single command replaces the manual `/etc/hosts`, DNS flush, `csrutil`, `profiles status`, and `launchctl` commands—it automatically:

* Verifies all 18 IPv4 (`0.0.0.0`) and IPv6 (`::`) blocks in `/etc/hosts`
* Flushes `mDNSResponder` and confirms `albert.apple.com` resolves to loopback
* Disables `system/com.apple.ManagedClient.enroll` and `system/com.apple.ManagedClient.cloudconfigurationd`
* Disables `gui/<UID>/com.apple.ManagedClientAgent.agent` and `enrollagent` (stopping the 8-hour nag popup)
* Restarts `followupd` to clear System Settings badges and prints `csrutil status` and `profiles status -type enrollment`

---

### 3. Final Account & Profile Verification

Run these three remaining checks not covered by `mdm_shield.sh`:

1. **Confirm FileVault SecureToken / Volume Ownership** (verify your new admin account appears and the deleted temporary account is gone):
```bash
sudo fdesetup list

```


2. **Confirm zero configuration profiles are installed:**
```bash
sudo profiles list

```


3. **Confirm cloud enrollment lookup is blocked** (should return an error stating it cannot determine if the machine is DEP enabled):
```bash
sudo profiles show -type enrollment

```



Once verified, turn Wi-Fi back on. For future macOS updates, toggle Wi-Fi off before restarting, log into your admin account, run `~/mdm_shield.sh`, and reconnect Wi-Fi.
