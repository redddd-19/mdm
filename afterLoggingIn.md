- Once you log in successfully, go to settings, Users & Groups, Add User
- Assign Administrator permissions to new account
- Reboot computer and log into new admin account
- Delete the first admin account.
- Open terminal and run the following codes

1. **Inspect the hosts file:**
```bash
cat /etc/hosts

```


2. **Clean and standardize the `/etc/hosts` file with loopback blocks:**
```bash
sudo sh -c 'cat << "EOF" > /etc/hosts
##
# Host Database
#
# localhost is used to configure the loopback interface
# when the system is booting.  Do not change this entry.
##
127.0.0.1	localhost
255.255.255.255	broadcasthost
::1             localhost
0.0.0.0 iprofiles.apple.com
0.0.0.0 mdmenrollment.apple.com
0.0.0.0 deviceenrollment.apple.com
EOF'

```


3. **Re-verify the contents of `/etc/hosts`:**
```bash
cat /etc/hosts

```


4. **Flush local DNS and restart the mDNSResponder daemon:**
```bash
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder

```


5. **Verify System Integrity Protection (SIP) status:**
```bash
csrutil status

```


6. **Check system enrollment status:**
```bash
profiles status -type enrollment

```


7. **Check for installed configuration profiles:**
```bash
sudo profiles list

```



8. **List FileVault SecureToken/Volume Owner accounts with root privileges:**
```bash
sudo fdesetup list

```


10. **Attempt to retrieve the cloud configuration record from Apple servers:**
```bash
sudo profiles show -type enrollment

```


11. **Disable the background device enrollment launch daemon:**
```bash
sudo launchctl disable system/com.apple.ManagedClient.enroll

```
