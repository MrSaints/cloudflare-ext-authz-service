# cloudflare-ext-authz-service

An [Envoy](https://www.envoyproxy.io/) [External Authorization (ext_authz)](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/ext_authz_filter) service for ensuring requests are authenticated through [Cloudflare Access](https://www.cloudflare.com/teams/access/), built with [Contour](https://projectcontour.io/) in mind.

_This is still under development. It works, but use at your own risk._

---

**Why do I need this?**

To quote from Cloudflare's [documentation](https://developers.cloudflare.com/access/advanced-management/validating-json):

> To fully secure your application, you must ensure that no one can access your origin server directly and bypass the zero trust security checks Cloudflare Access enforces for the hostname. For example, if someone discovers an exposed external IP they can bypass Cloudflare and attack the origin directly.

In sum, this `ext_authz` service implementation is used to ensure requests are verified to be originating from Cloudflare, and not through direct access. It mitigates the need to build that logic into a sidecar proxy or into your application itself as you can instead configure your Ingress controller to delegate the authN to this service.
