## How MDM creates/retrieves & stores certs

Certs for a hostname are stored in a directory of the same name. For example, certs for `test.example.com` are stored in `~/.mdm/certs/test.example.com/`

Wildcard certs are stored in a directory minus the leading "*". For example, certs for `*.exmple.com` are stored in `~/.mdm/certs/.example.com`

A user can add existing [Let's Encrypt](https://letsencrypt.org/) certs in these dirs, or set up a system to automatically deploy/retrieve certs to those direcorties much like the MDM demo domain for the Magento team.


## How MDM handles certs with a fallback strategy

1. MDM will first look for a current, valid, existing cert in the hostname dir.
2. If valid hostname cert is not available, MDM will look for a valid wildcard cert dir. If that exists, it will be copied to the hostname dir.
3. If the hostname and wildcard certs are not available, then MDM will create one in the hostname dir with `mkcert` (if enabled).
4. If `mkcert` is not enabled, then an invalid cert created for `localhost` will be used. Browsers will show the site as invalid but will likely allow the user to proceed. In Chrome, to bypass invalid certs, the user must type "_thisisunsafe_" in the site's tab.

## The preferred order explained

[Let's Encrypt](https://letsencrypt.org/) are real certs that should be accepted by **all browsers** on **all hosts**. Certs from `mkcert` are only valid on the host with the CA installed, and while they are valid for 10 yrs, more browsers are choosing to reject very long lived certs. `mkcert` also imposes additional responsibility on the user. If the user's CA is compromised, a "valid" spoofed cert may be created for a malicious web service attempting to steal credentials. While unlikely that the CA would be compromised without the rest of the user's system also being compromised, the user should understand this risk.

## (Re)starting new web services

Each time a new web service is added (or an existing one restarted), MDM will check that every found web service hostname resolves to `127.0.0.1` (a.k.a. `localhost`) and that a cert is provided by the fallback strategy outlined above. Then MDM will dynamically create the necessary nginx config for each service to be handle by the reverse proxy listening on local ports 80 & 443.
