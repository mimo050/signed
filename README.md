# signed

Automatic IPA resigning via GitHub Actions.

## Usage
1. Place the unsigned IPA inside the `uploads/` directory.
2. Add repository secrets:
   - `IOS_P12_BASE64`: base64-encoded `.p12` certificate.
   - `IOS_P12_PASSWORD`: password for the certificate.
   - `IOS_PROVISION_BASE64`: base64-encoded provisioning profile containing device UDIDs.
3. Trigger the **Resign IPA (Ad Hoc Multi-UDID)** workflow:
   - Push an IPA to `uploads/`, or
   - Run it manually from the Actions tab and specify the IPA path.

The workflow signs the IPA with Team ID `66856YQ2FS`, bundle ID `com.xlop.myapp`,
and production push entitlement, then uploads a `*-resigned.ipa` artifact.
